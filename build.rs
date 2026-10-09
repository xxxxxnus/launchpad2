use std::{env, path::PathBuf, process::Command};
fn main() {
    println!("cargo:rerun-if-changed=native/Launcher.m");
    println!("cargo:rerun-if-changed=native/Scene.inc");
    println!("cargo:rerun-if-changed=native/Animation.h");
    println!("cargo:rerun-if-changed=native/Gesture.m");
    println!("cargo:rerun-if-changed=native/Settings.inc");
    println!("cargo:rerun-if-changed=native/Search.h");
    if env::var("CARGO_CFG_TARGET_OS").unwrap() != "macos" {
        return;
    }
    println!("cargo:rustc-link-arg=-mmacosx-version-min=11.0");
    let out = PathBuf::from(env::var_os("OUT_DIR").unwrap());
    let arch = if env::var("CARGO_CFG_TARGET_ARCH").unwrap() == "aarch64" {
        "arm64"
    } else {
        "x86_64"
    };
    for source in ["Launcher", "Gesture"] {
        let status = Command::new("clang")
            .args([
                "-fobjc-arc",
                "-O2",
                "-arch",
                arch,
                "-mmacosx-version-min=11.0",
                "-c",
                &format!("native/{source}.m"),
                "-o",
            ])
            .arg(out.join(format!("{source}.o")))
            .status()
            .expect("Install Xcode Command Line Tools");
        assert!(status.success(), "Native bridge failed to compile");
    }
    let _ = std::fs::remove_file(out.join("liblauncher.a"));
    assert!(Command::new("ar")
        .arg("rcs")
        .arg(out.join("liblauncher.a"))
        .arg(out.join("Launcher.o"))
        .arg(out.join("Gesture.o"))
        .status()
        .unwrap()
        .success());
    println!("cargo:rustc-link-search=native={}", out.display());
    println!("cargo:rustc-link-lib=static=launcher");
    for framework in ["AppKit", "QuartzCore", "Carbon"] {
        println!("cargo:rustc-link-lib=framework={framework}");
    }
}
