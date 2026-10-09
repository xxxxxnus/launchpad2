#[cfg(any(target_os = "macos", test))]
mod gesture;
mod model;
#[cfg(target_os = "macos")]
mod mac {
    use crate::model::*;
    use std::{
        ffi::{c_char, CStr, CString},
        path::PathBuf,
        sync::{Mutex, OnceLock},
    };
    static MODEL: OnceLock<Mutex<Model>> = OnceLock::new();
    fn state_path() -> PathBuf {
        PathBuf::from(std::env::var_os("HOME").unwrap())
            .join("Library/Application Support/Launchpad2/layout.v1")
    }
    fn state() -> &'static Mutex<Model> {
        MODEL.get_or_init(|| Mutex::new(Model::load(&state_path())))
    }
    extern "C" {
        fn lp_run();
        fn lp_app_name(path: *const c_char) -> *mut c_char;
        fn lp_free_native(s: *mut c_char);
    }
    unsafe fn string(p: *const c_char) -> String {
        if p.is_null() {
            String::new()
        } else {
            CStr::from_ptr(p).to_string_lossy().into_owned()
        }
    }
    #[no_mangle]
    pub extern "C" fn lp_refresh() {
        let mut paths = Vec::new();
        let home = PathBuf::from(std::env::var_os("HOME").unwrap());
        for root in [
            PathBuf::from("/Applications"),
            PathBuf::from("/System/Applications"),
            PathBuf::from("/System/Library/CoreServices/Applications"),
            home.join("Applications"),
        ] {
            bundles(&root, 4, &mut paths);
        }
        paths.sort();
        paths.dedup();
        let apps = paths
            .into_iter()
            .filter_map(|p| {
                let path = p.to_string_lossy().into_owned();
                let c = CString::new(path.clone()).ok()?;
                let name = unsafe {
                    let n = lp_app_name(c.as_ptr());
                    let s = string(n);
                    lp_free_native(n);
                    s
                };
                if name.is_empty() {
                    return None;
                }
                Some(App {
                    id: path.clone(),
                    name,
                    path,
                })
            })
            .collect();
        let mut m = state().lock().unwrap();
        m.reconcile(apps);
    }
    #[no_mangle]
    pub unsafe extern "C" fn lp_items(query: *const c_char, folder: *const c_char) -> *mut c_char {
        let q = string(query);
        let f = string(folder);
        let m = state().lock().unwrap();
        let items = if !q.is_empty() {
            m.search(&q)
        } else if !f.is_empty() {
            m.items
                .iter()
                .find(|i| i.id == f)
                .map(|i| {
                    i.apps
                        .iter()
                        .filter_map(|id| m.apps.get(id))
                        .map(|a| Item {
                            id: a.id.clone(),
                            name: a.name.clone(),
                            apps: vec![a.id.clone()],
                        })
                        .collect()
                })
                .unwrap_or_default()
        } else {
            m.items.clone()
        };
        let s = items
            .iter()
            .map(|i| {
                format!(
                    "{}\t{}\t{}\t{}",
                    encode(&i.id),
                    encode(&i.name),
                    i.apps.len(),
                    i.apps
                        .iter()
                        .take(9)
                        .filter_map(|id| m.apps.get(id))
                        .map(|a| encode(&a.path))
                        .collect::<Vec<_>>()
                        .join(",")
                )
            })
            .collect::<Vec<_>>()
            .join("\n");
        CString::new(s).unwrap().into_raw()
    }
    #[no_mangle]
    pub unsafe extern "C" fn lp_free(s: *mut c_char) {
        if !s.is_null() {
            drop(CString::from_raw(s));
        }
    }
    #[no_mangle]
    pub unsafe extern "C" fn lp_action(
        action: i32,
        source: *const c_char,
        target: *const c_char,
        index: usize,
    ) {
        let s = string(source);
        let t = string(target);
        let mut m = state().lock().unwrap();
        if (0..=6).contains(&action) {
            m.checkpoint();
        }
        match action {
            0 => m.reorder(&s, index),
            1 => m.group(&s, &t),
            2 => m.rename(&s, &t),
            3 => m.extract(&s, index),
            4 => m.hide(&s),
            5 => m.restore(),
            6 => m.reorder_child(&t, &s, index),
            7 => m.undo(),
            8 => m.redo(),
            _ => return,
        }
        if let Err(e) = m.save(&state_path()) {
            eprintln!("Could not save layout: {e}");
        }
    }
    #[no_mangle]
    pub unsafe extern "C" fn lp_diagnostic_group(source: *const c_char, target: *const c_char) {
        state()
            .lock()
            .unwrap()
            .group(&string(source), &string(target));
    }
    static PINCHES: OnceLock<Mutex<std::collections::HashMap<usize, crate::gesture::Pinch>>> =
        OnceLock::new();
    static THRESHOLD: std::sync::atomic::AtomicU32 = std::sync::atomic::AtomicU32::new(240);
    #[no_mangle]
    pub extern "C" fn lp_gesture_threshold(value: f32) {
        THRESHOLD.store(
            (value.clamp(0.15, 0.40) * 1000.0) as u32,
            std::sync::atomic::Ordering::Relaxed,
        );
    }
    #[no_mangle]
    pub extern "C" fn lp_gesture_reset() {
        if let Some(p) = PINCHES.get() {
            p.lock().unwrap().clear();
        }
    }
    #[no_mangle]
    pub unsafe extern "C" fn lp_gesture_frame(
        device: usize,
        points: *const crate::gesture::Point,
        count: usize,
        time: f64,
    ) -> i32 {
        if count > 16 || points.is_null() {
            return 0;
        }
        let mut pinches = PINCHES
            .get_or_init(|| Mutex::new(std::collections::HashMap::new()))
            .lock()
            .unwrap();
        pinches.entry(device).or_default().update(
            std::slice::from_raw_parts(points, count),
            time,
            THRESHOLD.load(std::sync::atomic::Ordering::Relaxed) as f32 / 1000.0,
        )
    }
    pub fn run() {
        let args: Vec<_> = std::env::args().collect();
        if args.get(1).is_some_and(|s| s == "--gesture-probe") {
            extern "C" {
                fn lp_gesture_probe() -> i32;
            }
            println!("Compatible touch surfaces: {}", unsafe {
                lp_gesture_probe()
            });
            return;
        }
        if args.get(1).is_some_and(|s| s == "--self-check") {
            lp_refresh();
            let m = state().lock().unwrap();
            let now = std::time::Instant::now();
            for _ in 0..1000 {
                std::hint::black_box(m.search("sa"));
            }
            println!(
                "Scanned {} apps, {} top-level icons; 1000 searches: {:?}",
                m.apps.len(),
                m.items.len(),
                now.elapsed()
            );
            return;
        }
        if args.get(1).is_some_and(|s| s == "--preview") {
            if let Some(path) = args.get(2) {
                std::env::set_var("LP_PREVIEW", path);
                if args.get(3).is_some_and(|s| s == "settings") {
                    std::env::set_var("LP_SETTINGS_CHECK", "1");
                }
                if args.get(3).is_some_and(|s| s == "search") {
                    std::env::set_var("LP_SEARCH_CHECK", "1");
                }
                if args.get(3).is_some_and(|s| s == "folder" || s == "motion") {
                    if args.get(3).is_some_and(|s| s == "motion") {
                        std::env::set_var("LP_MOTION_CHECK", "1");
                    }
                    lp_refresh();
                    let mut m = state().lock().unwrap();
                    let ids: Vec<_> = m.items.iter().take(3).map(|i| i.id.clone()).collect();
                    if ids.len() == 3 {
                        m.group(&ids[0], &ids[1]);
                        let folder = m
                            .items
                            .iter()
                            .find(|i| i.apps.len() > 1)
                            .unwrap()
                            .id
                            .clone();
                        m.group(&ids[2], &folder);
                        m.rename(&folder, "工具");
                        std::env::set_var("LP_PREVIEW_FOLDER", folder);
                    }
                }
            }
        }
        unsafe { lp_run() }
    }
}
fn main() {
    #[cfg(target_os = "macos")]
    mac::run();
    #[cfg(not(target_os = "macos"))]
    eprintln!("Launchpad2 requires macOS 11 or later.");
}
