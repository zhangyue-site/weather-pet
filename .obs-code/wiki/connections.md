---
tags: [obs-code, connections, call-graph, hub, bridge]
created: 2026-06-25
source: obs-code
project: weather-pet
---
# Connections — weather-pet

> 调用图核心视图。阅读顺序：[[project.md]] → [[architecture.md]] → 本文
> obs-code 捕获了 **107** 条调用边。

## Hubs — 高频被调用符号

这些符号被最多地方调用，改动它们影响最大。视为核心 API 表面。

- **`fetchWeatherAndCity`** (method) — called by **4** sites
  `weather-pet/godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:301`
- **`fetchWeatherAndCity`** (method) — called by **4** sites
  `weather-pet/godot_project/plugin/src/main/java/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:301`
- **`refreshWeather`** (method) — called by **4** sites
  `weather-pet/godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:136`
- **`refreshWeather`** (method) — called by **4** sites
  `weather-pet/godot_project/plugin/src/main/java/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:136`
- **`requestLocationPermission`** (method) — called by **3** sites
  `weather-pet/godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:220`
- **`requestLocationPermission`** (method) — called by **3** sites
  `weather-pet/godot_project/plugin/src/main/java/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:220`
- **`checkFestival`** (method) — called by **2** sites
  `weather-pet/godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:200`
- **`checkFestival`** (method) — called by **2** sites
  `weather-pet/godot_project/plugin/src/main/java/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:200`
- **`draw_cloud`** (function) — called by **2** sites
  `weather-pet/godot_project/scripts/make_icon.py:73`
- **`draw_pet`** (function) — called by **2** sites
  `weather-pet/godot_project/scripts/make_icon.py:89`
- **`draw_sun`** (function) — called by **2** sites
  `weather-pet/godot_project/scripts/make_icon.py:49`
- **`emitLocation`** (method) — called by **2** sites
  `weather-pet/godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:291`

## Bridges — 跨层调用

跨越架构层边界的调用（controller→service, service→data…）。这些是抽象之间的承重线，bug 通常变成集成 bug。

_(no cross-layer calls detected — either single-layer codebase or layer heuristics did not match)_

## Main paths — 主要调用链

从顶层入口开始的贪心遍历，每步走到最高 fan-out 的邻居。限制深度 6。不是穷举——是存在的*那种*链路。

**Path 1** (4 hops)
  `main` (weather-pet/godot_project/scripts/make_icon.py:255)
  → `make_icon` (weather-pet/godot_project/scripts/make_icon.py:206)
  → `gradient_bg` (weather-pet/godot_project/scripts/make_icon.py:32)
  → `lerp_color` (weather-pet/godot_project/scripts/make_icon.py:28)

**Path 2** (7 hops)
  `onReceive` (weather-pet/godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:52)
  → `getPluginName` (weather-pet/godot_project/plugin/src/main/java/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:73)
  → `getPluginSignals` (weather-pet/godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:75)
  → `onMainCreate` (weather-pet/godot_project/plugin/src/main/java/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:86)
  → `registerReceivers` (weather-pet/godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:98)
  → `scheduleWeatherRefresh` (weather-pet/godot_project/plugin/src/main/java/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:110)
  → `start` (weather-pet/godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:125)

**Path 3** (7 hops)
  `onReceive` (weather-pet/godot_project/plugin/src/main/java/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:52)
  → `getPluginName` (weather-pet/godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:73)
  → `getPluginSignals` (weather-pet/godot_project/plugin/src/main/java/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:75)
  → `onMainCreate` (weather-pet/godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:86)
  → `registerReceivers` (weather-pet/godot_project/plugin/src/main/java/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:98)
  → `scheduleWeatherRefresh` (weather-pet/godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:110)
  → `start` (weather-pet/godot_project/plugin/src/main/java/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:125)

---

- [[project.md]] — 项目概览
- [[architecture.md]] — 架构分层
- [[terms.md]] — 中英术语映射
- 需要特定符号的完整调用者/被调者？调用 `obs_impact`
- 需要功能的调用链？调用 `obs_feature_map`
- 上述数字仅统计 `calls` 边；`imports` / `defines` / `extends` 边未计入。
