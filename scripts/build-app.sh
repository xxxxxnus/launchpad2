#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:-native}"
version="$(sed -n 's/^version = "\([^"]*\)"/\1/p' Cargo.toml | head -n 1)"
test -n "$version"
case "$mode" in
  native) cargo build --locked --release; binary=target/release/launchpad2 ;;
  arm64) cargo build --locked --release --target aarch64-apple-darwin; binary=target/aarch64-apple-darwin/release/launchpad2 ;;
  universal)
    cargo build --locked --release --target aarch64-apple-darwin
    cargo build --locked --release --target x86_64-apple-darwin
    mkdir -p target/universal
    lipo -create target/aarch64-apple-darwin/release/launchpad2 target/x86_64-apple-darwin/release/launchpad2 -output target/universal/launchpad2
    binary=target/universal/launchpad2 ;;
  *) echo "Usage: $0 [native|arm64|universal]" >&2; exit 2 ;;
esac
bundle=dist/Launchpad2.app
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp "$binary" "$bundle/Contents/MacOS/launchpad2"
cp resources/Info.plist "$bundle/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$bundle/Contents/Info.plist"
cp resources/AppIcon.icns "$bundle/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$bundle"
codesign --verify --deep --strict "$bundle"
plutil -lint "$bundle/Contents/Info.plist"
archive="dist/Launchpad2-${version}-${mode}.zip"
ditto -c -k --keepParent "$bundle" "$archive"
du -h "$bundle/Contents/MacOS/launchpad2" "$archive"
echo "Built $bundle"
