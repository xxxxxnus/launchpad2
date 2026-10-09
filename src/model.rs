use std::{
    collections::{HashMap, HashSet},
    fs,
    path::{Path, PathBuf},
};
#[derive(Clone, Debug, PartialEq)]
pub struct App {
    pub id: String,
    pub name: String,
    pub path: String,
}
#[derive(Clone, Debug, PartialEq)]
pub struct Item {
    pub id: String,
    pub name: String,
    pub apps: Vec<String>,
}
#[derive(Default)]
pub struct Model {
    pub apps: HashMap<String, App>,
    pub items: Vec<Item>,
    pub hidden: HashSet<String>,
    pub revision: u64,
    undo: Vec<(Vec<Item>, HashSet<String>)>,
    redo: Vec<(Vec<Item>, HashSet<String>)>,
}
pub fn encode(s: &str) -> String {
    s.as_bytes().iter().map(|b| format!("{b:02x}")).collect()
}
pub fn decode(s: &str) -> Option<String> {
    if !s.len().is_multiple_of(2) || !s.is_ascii() {
        return None;
    }
    String::from_utf8(
        (0..s.len())
            .step_by(2)
            .map(|i| u8::from_str_radix(&s[i..i + 2], 16))
            .collect::<Result<Vec<_>, _>>()
            .ok()?,
    )
    .ok()
}
impl Model {
    pub fn checkpoint(&mut self) {
        self.undo.push((self.items.clone(), self.hidden.clone()));
        if self.undo.len() > 32 {
            self.undo.remove(0);
        }
        self.redo.clear();
    }
    pub fn undo(&mut self) {
        if let Some((items, hidden)) = self.undo.pop() {
            self.redo.push((self.items.clone(), self.hidden.clone()));
            self.items = items;
            self.hidden = hidden;
            self.normalize();
        }
    }
    pub fn redo(&mut self) {
        if let Some((items, hidden)) = self.redo.pop() {
            self.undo.push((self.items.clone(), self.hidden.clone()));
            self.items = items;
            self.hidden = hidden;
            self.normalize();
        }
    }
    pub fn reconcile(&mut self, apps: Vec<App>) {
        self.apps = apps.into_iter().map(|a| (a.id.clone(), a)).collect();
        let mut seen = HashSet::new();
        for item in &mut self.items {
            item.apps.retain(|id| {
                self.apps.contains_key(id) && !self.hidden.contains(id) && seen.insert(id.clone())
            });
        }
        self.items.retain(|i| !i.apps.is_empty());
        for item in &mut self.items {
            if item.apps.len() == 1 {
                let a = &self.apps[&item.apps[0]];
                *item = Item {
                    id: a.id.clone(),
                    name: a.name.clone(),
                    apps: vec![a.id.clone()],
                };
            }
        }
        let mut new: Vec<_> = self
            .apps
            .values()
            .filter(|a| !seen.contains(&a.id) && !self.hidden.contains(&a.id))
            .cloned()
            .collect();
        new.sort_by(|a, b| {
            a.name
                .to_lowercase()
                .cmp(&b.name.to_lowercase())
                .then_with(|| a.id.cmp(&b.id))
        });
        self.items.extend(new.into_iter().map(|a| Item {
            id: a.id.clone(),
            name: a.name,
            apps: vec![a.id],
        }));
    }
    pub fn search(&self, query: &str) -> Vec<Item> {
        let q = query.to_lowercase();
        let mut hits: Vec<_> = self
            .apps
            .values()
            .filter(|a| !self.hidden.contains(&a.id))
            .filter_map(|a| {
                let name = a.name.to_lowercase();
                let score = if name.starts_with(&q) {
                    0
                } else if name.contains(&q) {
                    1
                } else {
                    let mut chars = name.chars();
                    if !q.chars().all(|c| chars.by_ref().any(|n| n == c)) {
                        return None;
                    }
                    2
                };
                Some((score, a))
            })
            .collect();
        hits.sort_by(|(s, a), (t, b)| {
            s.cmp(t)
                .then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase()))
                .then_with(|| a.id.cmp(&b.id))
        });
        hits.into_iter()
            .map(|(_, a)| Item {
                id: a.id.clone(),
                name: a.name.clone(),
                apps: vec![a.id.clone()],
            })
            .collect()
    }
    pub fn reorder(&mut self, source: &str, target: usize) {
        if let Some(i) = self.items.iter().position(|i| i.id == source) {
            let item = self.items.remove(i);
            self.items.insert(target.min(self.items.len()), item);
        }
    }
    pub fn group(&mut self, source: &str, target: &str) {
        if source == target {
            return;
        }
        let Some(s) = self.items.iter().position(|i| i.id == source) else {
            return;
        };
        if !self.items.iter().any(|i| i.id == target) {
            return;
        }
        let item = self.items.remove(s);
        let t = self.items.iter_mut().find(|i| i.id == target).unwrap();
        if t.apps.len() == 1 {
            self.revision += 1;
            let time = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_nanos();
            t.id = format!("folder:{time}:{}", self.revision);
            t.name = "文件夹".into();
        }
        t.apps.extend(item.apps);
    }
    pub fn extract(&mut self, app: &str, target: usize) {
        let Some(a) = self.apps.get(app).cloned() else {
            return;
        };
        for item in &mut self.items {
            item.apps.retain(|id| id != app);
        }
        self.items.retain(|i| !i.apps.is_empty());
        self.items.insert(
            target.min(self.items.len()),
            Item {
                id: a.id.clone(),
                name: a.name,
                apps: vec![a.id],
            },
        );
        self.normalize();
    }
    pub fn reorder_child(&mut self, folder: &str, source: &str, target: usize) {
        if let Some(item) = self.items.iter_mut().find(|i| i.id == folder) {
            if let Some(index) = item.apps.iter().position(|id| id == source) {
                let app = item.apps.remove(index);
                item.apps.insert(target.min(item.apps.len()), app);
            }
        }
    }
    fn normalize(&mut self) {
        let apps = self.apps.values().cloned().collect();
        self.reconcile(apps);
    }
    pub fn hide(&mut self, id: &str) {
        self.hidden.insert(id.into());
        self.normalize();
    }
    pub fn restore(&mut self) {
        self.hidden.clear();
        self.normalize();
    }
    pub fn rename(&mut self, id: &str, name: &str) {
        if let Some(i) = self
            .items
            .iter_mut()
            .find(|i| i.id == id && i.apps.len() > 1)
        {
            let n = name.trim();
            if !n.is_empty() {
                i.name = n.chars().take(80).collect();
            }
        }
    }
    pub fn save(&self, path: &Path) -> std::io::Result<()> {
        let mut s = String::from("Launchpad2-v1\n");
        let mut hidden: Vec<_> = self.hidden.iter().collect();
        hidden.sort();
        for id in hidden {
            s.push_str(&format!("H\t{}\n", encode(id)));
        }
        for i in &self.items {
            s.push_str(&format!(
                "I\t{}\t{}\t{}\n",
                encode(&i.id),
                encode(&i.name),
                i.apps
                    .iter()
                    .map(|a| encode(a))
                    .collect::<Vec<_>>()
                    .join(",")
            ));
        }
        if let Some(p) = path.parent() {
            fs::create_dir_all(p)?;
        }
        let temp = path.with_extension("tmp");
        fs::write(&temp, s)?;
        fs::rename(temp, path)
    }
    pub fn load(path: &Path) -> Self {
        let mut m = Self::default();
        let Ok(s) = fs::read_to_string(path) else {
            return m;
        };
        if !s.starts_with("Launchpad2-v1\n") {
            return m;
        }
        for line in s.lines().skip(1) {
            let f: Vec<_> = line.split('\t').collect();
            match f.as_slice() {
                ["H", id] => {
                    if let Some(id) = decode(id) {
                        m.hidden.insert(id);
                    }
                }
                ["I", id, name, apps] => {
                    if let (Some(id), Some(name), Some(apps)) = (
                        decode(id),
                        decode(name),
                        apps.split(',').map(decode).collect::<Option<Vec<_>>>(),
                    ) {
                        m.items.push(Item { id, name, apps });
                    }
                }
                _ => {}
            }
        }
        m
    }
}
pub fn bundles(root: &Path, depth: usize, out: &mut Vec<PathBuf>) {
    if depth == 0 {
        return;
    }
    let Ok(entries) = fs::read_dir(root) else {
        return;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().is_some_and(|e| e == "app") {
            out.push(path);
        } else if entry
            .file_type()
            .is_ok_and(|t| t.is_dir() && !t.is_symlink())
        {
            bundles(&path, depth - 1, out);
        }
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    fn model() -> Model {
        let mut m = Model::default();
        m.reconcile(
            [("a", "Safari"), ("b", "System Settings"), ("c", "日历")]
                .into_iter()
                .map(|(id, name)| App {
                    id: id.into(),
                    name: name.into(),
                    path: format!("/{id}.app"),
                })
                .collect(),
        );
        m
    }
    #[test]
    fn group_extract_and_rename() {
        let mut m = model();
        m.group("a", "b");
        let f = m
            .items
            .iter()
            .find(|i| i.apps.len() == 2)
            .unwrap()
            .id
            .clone();
        m.rename(&f, "工具");
        assert_eq!(m.items.iter().find(|i| i.id == f).unwrap().name, "工具");
        m.extract("a", 0);
        assert_eq!(m.items[0].id, "a");
        assert!(m.items.iter().all(|i| i.apps.len() == 1));
    }
    #[test]
    fn search_in_folders_and_unicode() {
        let mut m = model();
        m.group("a", "b");
        assert_eq!(m.search("sfr")[0].id, "a");
        assert_eq!(m.search("日")[0].id, "c");
    }
    #[test]
    fn missing_and_new_apps() {
        let mut m = model();
        m.group("a", "b");
        m.reconcile(vec![App {
            id: "b".into(),
            name: "Settings".into(),
            path: "/b.app".into(),
        }]);
        assert_eq!(m.items.len(), 1);
        assert_eq!(m.items[0].id, "b");
    }
    #[test]
    fn hide_restore() {
        let mut m = model();
        m.hide("a");
        assert!(m.search("Safari").is_empty());
        m.restore();
        assert_eq!(m.search("Safari").len(), 1);
    }
    #[test]
    fn persistence() {
        let mut m = model();
        m.group("a", "b");
        m.hide("c");
        let p = std::env::temp_dir().join(format!("launchpad-test-{}", std::process::id()));
        m.save(&p).unwrap();
        let mut n = Model::load(&p);
        n.reconcile(m.apps.values().cloned().collect());
        assert_eq!(m.items, n.items);
        assert_eq!(m.hidden, n.hidden);
        fs::remove_file(p).unwrap();
    }
    #[test]
    fn malformed_encoding() {
        assert_eq!(decode("é"), None);
        assert_eq!(decode("ff"), None);
        assert_eq!(decode(&encode("名字\t\n")), Some("名字\t\n".into()));
    }
    #[test]
    fn reorder_folder_children() {
        let mut m = model();
        m.group("a", "b");
        let id = m
            .items
            .iter()
            .find(|i| i.apps.len() > 1)
            .unwrap()
            .id
            .clone();
        m.reorder_child(&id, "a", 0);
        assert_eq!(
            m.items.iter().find(|i| i.id == id).unwrap().apps,
            vec!["a", "b"]
        );
    }
    #[test]
    fn duplicate_and_self_drop() {
        let mut m = model();
        let before = m.items.clone();
        m.group("a", "a");
        m.group("missing", "b");
        assert_eq!(m.items, before);
        m.items.push(m.items[0].clone());
        m.reconcile(m.apps.values().cloned().collect());
        assert_eq!(m.items.len(), 3);
    }
    #[test]
    fn undo_redo_layout_and_hidden_state() {
        let mut m = model();
        let original = m.items.clone();
        m.checkpoint();
        m.group("a", "b");
        let grouped = m.items.clone();
        m.checkpoint();
        m.hide("c");
        m.undo();
        assert_eq!(m.items, grouped);
        assert!(m.hidden.is_empty());
        m.undo();
        assert_eq!(m.items, original);
        m.redo();
        assert_eq!(m.items, grouped);
        m.redo();
        assert!(m.hidden.contains("c"));
        m.undo();
        m.checkpoint();
        m.rename(
            &grouped.iter().find(|i| i.apps.len() > 1).unwrap().id,
            "新名字",
        );
        let edited = m.items.clone();
        m.redo();
        assert_eq!(m.items, edited);
    }
    #[test]
    fn undo_after_uninstall_cannot_resurrect_missing_app() {
        let mut m = model();
        m.checkpoint();
        m.group("a", "b");
        m.reconcile(vec![m.apps["b"].clone()]);
        m.undo();
        assert_eq!(m.items.len(), 1);
        assert_eq!(m.items[0].id, "b");
    }
}
