#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
task_temp="$(mktemp -d)"
trap 'rm -rf "$task_temp"' EXIT
clang -fobjc-arc -O2 scripts/generate-icon.m -framework AppKit -o "$task_temp/generate-icon"
"$task_temp/generate-icon" "$task_temp/base.png"
mkdir "$task_temp/AppIcon.iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$task_temp/base.png" --out "$task_temp/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$task_temp/base.png" --out "$task_temp/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$task_temp/AppIcon.iconset" -o resources/AppIcon.icns
