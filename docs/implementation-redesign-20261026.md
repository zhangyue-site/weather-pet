# Shared Godot courtyard implementation plan

> Execute in the current chat with superpowers:executing-plans. Review the plan and final change with subagents; keep file ownership isolated.

**Goal:** Implement the approved four-screen design on the shared Godot project, attach visible effects to real scene events, and exercise both platform builds.

**Architecture:** Keep existing world, actor, fish, native location and Android updater. Rework shared main UI with a focused UI helper where useful. Add an effect scene director with finite event lifetimes and context rules, consumed by calendar_effects. Preserve real simulation state across previews.

**Tech stack:** Godot 4.4.1, GDScript, existing iOS Objective-C++ bridge, Android patched package workflow, Xcode simulator and Android test device.

## 1. Source and baseline

- [ ] Clone current `codex/weather-companion-handoff` at `7c9d19c7ca98766bc54519d4b8e663a244780d8b` into dedicated checkout, create implementation branch, read AGENTS and handoff.
- [ ] Save approved design and pending handoff in repo; no private credentials or task bindings.
- [ ] Run existing `godot_project/run_tests.sh` with pinned engine and save baseline.

## 2. Behavioral regression tests before implementation

- [ ] Add `godot_project/tests/test_scene_effects.gd`: real weather context, limited festival duration, interaction impulse lifetime, night/solemn/reduced behavior, cancellation and no stacking.
- [ ] Add `godot_project/tests/test_redesign_flow.gd`: two home actions, city selection, care panel, notebook tabs, settings/exploration, close/back/focus, persistent quiet exit, draft protection, and preview restore.
- [ ] Confirm tests fail on the missing behavior. Existing tests remain meaningful; update navigation assertions only where approved design changes them.

## 3. Effects and preview isolation

- [ ] Create `companion/scene_effects.gd` for season/weather/date/interaction effect selection with bounded life and count; modify `calendar_effects.gd` to render the director's recipes and use local elapsed event time.
- [ ] Attach successful care actions, festival/date transitions and weather callbacks in main; scene restoration cancels old effects.
- [ ] Preserve live world and fish memory while previewing; previews cannot modify journal, discovery, bond, or nightly consumption. Restoring today returns to latest actual weather, selected city and real date.
- [ ] Keep weather particles in effects.gd, avoid duplicate rain/snow layers; reduced motion removes large movement and persistent flash while retaining visible static feedback.
- [ ] Run new effect tests and existing world/fish/duet/calendar suites.

## 4. Shared UI

- [ ] Modify `companion/main.gd`, optionally add `companion/courtyard_ui.gd`: top city chip/settings, stable weather block, date chip, slim contextual caption, two-action dock; preserve original art.
- [ ] Care: 2x2 actions, visible close, immediate scene feedback; no duplicate journal/gallery entries.
- [ ] Notebook: full-page diary/anniversary segmented view, existing saved records and validated dates, draft exit protection.
- [ ] Settings: grouped low-frequency rows; city access only at home; exploration carries preview label and one return-to-today action.
- [ ] Layout from available viewport and safe area, wrap long statuses, visible keyboard focus, modal focus return, background click blocking, platform back handling.
- [ ] Run new flow tests and full suite; capture actual screenshots at phone/tablet sizes and compare to approved design.

## 5. Build and actual runtime checks

- [ ] Bump unused shared version/build consistently only after checking existing releases; use latest verified Android baseline retaining native libs/DEX/weather/updater.
- [ ] Extend package tool to include new scripts/remaps, verify untouched native and source hashes; compile bytecode for Godot 4.4.1. Sign through existing protected server tools.
- [ ] Export shared PCK for iOS, build existing native plugin with matching engine and headers. Use existing cloud workflow/server signing when necessary, never Flutter.
- [ ] Android: install test package on available suitable device/emulator, tap home/care/notebook/settings/exploration, capture rain/snow/wind/festival/interaction and return-to-live evidence, inspect logcat.
- [ ] iOS: simulator actual app launch and interaction checks; synthetic location explicitly marked. Physical iPhone check only if device available; report availability truthfully.
- [ ] Verify both packages contain current shared scripts and art; fresh test output and screen recordings, not historical reports.

## 6. Review and delivery

- [ ] Review spec compliance then code correctness; fix material findings and rerun affected checks.
- [ ] Update `docs/handoff/weather-pet-main.md` and current release report with exact commits/hashes, test levels, screenshots/recordings, package locations and unverified items.
- [ ] Preserve app data, keep internal-only testing; no App Store review or production Android OTA switch in this scope.
- [ ] Commit reviewed changes and make test artifacts accessible; no third-party messages without authorization. Missing dida-dev-handoff environment remains pending local synchronization.

## Review additions

- Weather/location states: loading, failed/retry preserving selected city, cancel leaves city unchanged, expired cache, no data, explicit preview status.
- Device/application reduced motion, battery saver and sustained slow frames all feed one conservative effect policy. Test supported platform readings and document unavailable native signals.
- Runtime matrix on both platforms: drizzle, heavy rain, snow, wind, fog, four seasons/day-night, birthday+solemn priority, weather conflict, cross-date exit, successful/failed/cooldown care, each retained gallery entry and return-to-live. Save actual captures rather than counting configuration references.
- Tests use isolated user storage. Before upgrading an existing test installation, back up readable app data and verify journal/anniversary/bond/fish memory/settings migration. Never uninstall an existing production app just to get testing to pass; use separate test bundle if matching signing or backup cannot be guaranteed.
- Touch role hit regions, modal background blocking/close/focus, and all save/discard/continue-edit draft exits explicitly.
