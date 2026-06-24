# Connections — 天气APK小人

> The **edges** in the call graph. obs-code captured **1643** call edges in this project.
> Wiki splits them into three views: who is central, where layers connect, and what the longest live wires look like.

## Hubs — high fan-in symbols

These are the symbols **most things call into**. Changing them changes the most behavior. Treat them as the core API surface.

- **`append`** (function) — called by **83** sites
  `天气APK小人/zuqiuxiaojiang/src/cn_football_agent/memory_store.py:59`
- **`current_state`** (function) — called by **77** sites
  `天气APK小人/zuqiuxiaojiang/src/cn_football_agent/engine.py:177`
- **`animT`** (method) — called by **63** sites
  `天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/util/TimeUtil.kt:84`
- **`drawStanding`** (method) — called by **38** sites
  `天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/wallpaper/renderer/GrokletRenderer.kt:226`
- **`wrap`** (function) — called by **35** sites
  `天气APK小人/zuqiuxiaojiang/src/cn_football_agent/cli.py:75`
- **`next_fixture`** (function) — called by **34** sites
  `天气APK小人/zuqiuxiaojiang/src/cn_football_agent/models.py:108`
- **`dims`** (method) — called by **25** sites
  `天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/wallpaper/renderer/GrokletRenderer.kt:49`
- **`bootstrap`** (function) — called by **23** sites
  `天气APK小人/zuqiuxiaojiang/src/cn_football_agent/engine.py:89`
- **`gry`** (function) — called by **23** sites
  `天气APK小人/zuqiuxiaojiang/src/cn_football_agent/cli.py:95`
- **`save_world_state`** (function) — called by **23** sites
  `天气APK小人/zuqiuxiaojiang/src/cn_football_agent/storage.py:47`
- **`advance_to_next_decision`** (function) — called by **20** sites
  `天气APK小人/zuqiuxiaojiang/src/cn_football_agent/engine.py:248`
- **`_emit`** (function) — called by **17** sites
  `天气APK小人/zuqiuxiaojiang/src/cn_football_agent/tui.py:620`

## Bridges — cross-layer calls

These are the calls that cross a layer boundary (controller→service, service→data, …). They are the load-bearing wires between abstractions; bugs here usually become integration bugs.

### other → data (82 calls)
  - `run` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/agent_loop.py:72) → `append` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/memory_store.py:59)
  - `_build_system` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/agent_loop.py:134) → `build_context` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/memory_store.py:96)
  - `_messages_to_prompt` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/agent_loop.py:172) → `append` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/memory_store.py:59)

### other → presentation (77 calls)
  - `run` (天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/wallpaper/engine/WallpaperEngine.kt:45) → `drawFrame` (天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/ui/WallpaperPreviewView.kt:171)
  - `onTouch` (天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/wallpaper/engine/WallpaperEngine.kt:73) → `drawFrame` (天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/ui/WallpaperPreviewView.kt:171)
  - `main` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/cli.py:2146) → `run_tui` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/tui.py:1065)

### test → other (75 calls)
  - `test_new_game_custom_profile_persists_manager_identity` (天气APK小人/zuqiuxiaojiang/tests/test_engine.py:44) → `bootstrap` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/engine.py:89)
  - `test_new_game_custom_profile_persists_manager_identity` (天气APK小人/zuqiuxiaojiang/tests/test_engine.py:44) → `current_state` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/engine.py:177)
  - `test_advance_to_next_decision_returns_turn_summary` (天气APK小人/zuqiuxiaojiang/tests/test_engine.py:59) → `bootstrap` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/engine.py:89)

### other → utility (67 calls)
  - `onCreate` (天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/WeatherWallpaperApplication.kt:16) → `preload` (天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/wallpaper/renderer/LottieWeatherHelper.kt:23)
  - `render` (天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/wallpaper/engine/WallpaperEngine.kt:89) → `getTimeOfDay` (天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/util/TimeUtil.kt:9)
  - `drawMountainWaterScene` (天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/wallpaper/renderer/BackgroundRenderer.kt:207) → `animT` (天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/util/TimeUtil.kt:84)

### other → model (36 calls)
  - `_print_match_result` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/cli.py:506) → `next_fixture` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/models.py:108)
  - `_maybe_trigger_match` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/cli.py:719) → `next_fixture` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/models.py:108)
  - `_match_flow` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/cli.py:974) → `next_fixture` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/models.py:108)

### presentation → other (28 calls)
  - `handleToggle` (天气APK小人/small-screen-animation/src/components/immersive-toggle.tsx:10) → `bind` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/tools.py:257)
  - `_redraw` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/tui.py:146) → `current_state` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/engine.py:177)
  - `_redraw` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/tui.py:146) → `trust_warning_message` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/engine.py:647)

### presentation → data (8 calls)
  - `add_tool_call` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/tui.py:140) → `append` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/memory_store.py:59)
  - `_redraw` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/tui.py:146) → `append` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/memory_store.py:59)
  - `write_tool_call` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/tui.py:342) → `append` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/memory_store.py:59)

### service → other (6 calls)
  - `onDestroy` (天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/WeatherWallpaperService.kt:82) → `destroy` (天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/wallpaper/engine/WallpaperEngine.kt:68)
  - `fetchWeather` (天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/WeatherWallpaperService.kt:89) → `getLastLocation` (天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/location/LocationProvider.kt:16)
  - `fetchWeather` (天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/WeatherWallpaperService.kt:89) → `getCurrentLocation` (天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/location/LocationProvider.kt:26)

## Main paths — representative call chains

Greedy walks starting from "calls out but is not called" symbols (top-level entries), each stepping to the highest-fan-out neighbor. Limited to depth 6. These are not exhaustive — they are the *kind* of chains that exist.

**Path 1** (5 hops)
  `_flow_match_day` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/weekly_loop.py:432)
  → `_flow_lineup` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/weekly_loop.py:590)
  → `_flow_lineup_adjust` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/weekly_loop.py:643)
  → `append` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/memory_store.py:59)
  → `_path` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/memory_store.py:53)

**Path 2** (7 hops)
  `main` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/cli.py:2146)
  → `advance_to_next_decision` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/engine.py:248)
  → `_hydrate_turn_modules_from_llm` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/engine.py:1686)
  → `build_turn_modules_prompt` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/prompt_presets.py:9)
  → `build_match_context` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/match_module.py:44)
  → `is_match_week` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/match_module.py:6)
  → `next_fixture` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/models.py:108)

**Path 3** (7 hops)
  `onCreate` (天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/settings/WallpaperSettingsActivity.kt:65)
  → `loadWeather` (天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/settings/WallpaperSettingsActivity.kt:329)
  → `updateLottie` (天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/settings/WallpaperSettingsActivity.kt:317)
  → `getTimeOfDay` (天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/util/TimeUtil.kt:9)
  → `estimateSunriseMin` (天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/util/TimeUtil.kt:42)
  → `estimateSunsetMin` (天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/util/TimeUtil.kt:53)
  → `getSunFraction` (天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/util/TimeUtil.kt:64)

**Path 4** (7 hops)
  `_flow_choice` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/weekly_loop.py:868)
  → `play_command` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/engine.py:1436)
  → `advance_to_next_decision` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/engine.py:248)
  → `_hydrate_turn_modules_from_llm` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/engine.py:1686)
  → `build_turn_modules_prompt` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/prompt_presets.py:9)
  → `build_match_context` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/match_module.py:44)
  → `is_match_week` (天气APK小人/zuqiuxiaojiang/src/cn_football_agent/match_module.py:6)

**Path 5** (7 hops)
  `start` (天气APK小人/godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:142)
  → `updateTime` (天气APK小人/godot_project/plugin/src/main/java/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:105)
  → `checkFestival` (天气APK小人/godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:160)
  → `sendWeather` (天气APK小人/godot_project/plugin/src/main/java/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:122)
  → `sendTouch` (天气APK小人/godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:175)
  → `pushBatterySnapshot` (天气APK小人/godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:180)
  → `safeEmitSignal` (天气APK小人/godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:196)

---

_Need a specific symbol's full callers/callees? Call `obs_impact` with its name._
_Need the call chain for a feature? Call `obs_feature_map`._
_Numbers above are derived from `calls` edges only; `imports` / `defines` / `extends` edges are not counted here._
