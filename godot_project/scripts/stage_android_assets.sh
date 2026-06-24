#!/bin/zsh
set -euo pipefail
export PATH="/bin:/usr/bin:/usr/sbin:/sbin"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS_DIR="$ROOT_DIR/android/assets"
RUNTIME_DIRS=(
  "scripts"
  "scenes"
  "addons"
  ".godot"
)
RUNTIME_FILES=(
  "project.godot"
  "main.tscn"
  "icon.png"
  "icon.png.import"
)

/bin/mkdir -p "$ASSETS_DIR"

for path in "${RUNTIME_FILES[@]}"; do
  /bin/cp "$ROOT_DIR/$path" "$ASSETS_DIR/$path"
done

for dir_name in "${RUNTIME_DIRS[@]}"; do
  /bin/mkdir -p "$ASSETS_DIR/$dir_name"
  /bin/cp -R "$ROOT_DIR/$dir_name/." "$ASSETS_DIR/$dir_name/"
done

/usr/bin/find "$ASSETS_DIR/.godot/editor" -mindepth 1 -delete 2>/dev/null || true
/usr/bin/find "$ASSETS_DIR" -name '*.uid' -delete
/usr/bin/find "$ASSETS_DIR" -name '*.bak' -delete
