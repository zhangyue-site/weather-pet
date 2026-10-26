#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"

if [ ! -x "$GODOT_BIN" ]; then
  echo "Godot not found at $GODOT_BIN" >&2
  exit 1
fi

export GODOT_BIN
exec python3 "$PROJECT_DIR/../tools/run_regressions.py"
