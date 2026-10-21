# 2026-10-21 本轮核验

命令：`bash godot_project/run_tests.sh`

```text
=== test_calendar_ui.gd ===
WARNING: PASS test_calendar_ui: birthday form, overlapping calendar, effect browsing and reset
=== test_companion.gd ===
WARNING: PASS test_companion: weather chains, interruption, care, sleep, persistence, 16 scenarios, WMO
=== test_companion_scene.gd ===
WARNING: PASS test_companion_scene: layouts, 4 panels, care dispatch, particles, rain/night integration
=== test_event_source.gd ===
WARNING: PASS test_event_source: local fallback, invalid response, cache, revision rollback
=== test_events.gd ===
WARNING: PASS test_events: dates, remote validation, weather priority, cooldown, expiry
=== test_year_program.gd ===
WARNING: PASS test_year_program: 731 daily programs, 200 recipes, lunar leap/eve, moving festivals, memorial conflicts, weather layering
```

线上清单、证书及 APK 哈希核对详见 [交接记录](weather-pet-main.md)。Android 与特效渲染的历史检查未在本轮重跑。
