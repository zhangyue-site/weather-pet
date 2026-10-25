#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"

if [ ! -x "$GODOT_BIN" ]; then
  echo "Godot not found at $GODOT_BIN" >&2
  exit 1
fi

cd "$PROJECT_DIR"
FAIL=0
for t in "$PROJECT_DIR"/tests/test_*.gd; do
  name="$(basename "$t")"
  echo "=== $name ==="
  OUT=$("$GODOT_BIN" --headless --quiet --path "$PROJECT_DIR" --script "res://tests/$name" 2>&1) || true
  echo "$OUT" | grep -E "PASS|FAIL|SCRIPT ERROR" || true
  if echo "$OUT" | grep -q "FAIL\|SCRIPT ERROR" || [ -z "$(echo "$OUT" | grep PASS)" ]; then
    echo ">>> FAILED: $name"
    FAIL=1
  fi
done
exit $FAIL
