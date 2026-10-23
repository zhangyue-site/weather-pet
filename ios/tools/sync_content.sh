#!/bin/bash
# Copies the shared calendar/festival content from the Godot project into the iOS package.
# Run after editing godot_project/companion/content/*.json; ContentParityTests fails until you do.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cp "$ROOT"/godot_project/companion/content/{daily,effects,events,lunar_calendar,server}.json \
   "$ROOT"/ios/CompanionCore/Sources/CompanionCore/Content/
echo "content synced"
