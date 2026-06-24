# Connections — godot_project

> The **edges** in the call graph. obs-code captured **53** call edges in this project.
> Wiki splits them into three views: who is central, where layers connect, and what the longest live wires look like.

## Hubs — high fan-in symbols

These are the symbols **most things call into**. Changing them changes the most behavior. Treat them as the core API surface.

- **`safeEmitSignal`** (method) — called by **6** sites
  `godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:196`
- **`checkFestival`** (method) — called by **4** sites
  `godot_project/plugin/src/main/java/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:111`
- **`sendWeather`** (method) — called by **4** sites
  `godot_project/plugin/src/main/java/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:122`
- **`pushBatterySnapshot`** (method) — called by **3** sites
  `godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:180`
- **`updateTime`** (method) — called by **3** sites
  `godot_project/plugin/src/main/java/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:105`
- **`checkFestival`** (method) — called by **2** sites
  `godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:160`
- **`init`** (method) — called by **2** sites
  `godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:221`
- **`init`** (method) — called by **2** sites
  `godot_project/plugin/src/main/java/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:146`
- **`registerReceivers`** (method) — called by **2** sites
  `godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:90`
- **`registerReceivers`** (method) — called by **2** sites
  `godot_project/plugin/src/main/java/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:72`
- **`scheduleWeatherRefresh`** (method) — called by **2** sites
  `godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:125`
- **`sendWeather`** (method) — called by **2** sites
  `godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:170`

## Bridges — cross-layer calls

These are the calls that cross a layer boundary (controller→service, service→data, …). They are the load-bearing wires between abstractions; bugs here usually become integration bugs.

_(no cross-layer calls detected — either single-layer codebase or layer heuristics did not match)_

## Main paths — representative call chains

Greedy walks starting from "calls out but is not called" symbols (top-level entries), each stepping to the highest-fan-out neighbor. Limited to depth 6. These are not exhaustive — they are the *kind* of chains that exist.

**Path 1** (7 hops)
  `onReceive` (godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:32)
  → `onMainCreate` (godot_project/plugin/src/main/java/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:49)
  → `registerReceivers` (godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:90)
  → `onGodotMainLoopStarted` (godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:111)
  → `registerReceivers` (godot_project/plugin/src/main/java/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:72)
  → `scheduleWeatherRefresh` (godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:125)
  → `start` (godot_project/plugin/src/main/java/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:96)

**Path 2** (7 hops)
  `onReceive` (godot_project/plugin/src/main/java/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:25)
  → `onMainCreate` (godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:64)
  → `onMainDestroy` (godot_project/plugin/src/main/java/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:55)
  → `getPluginName` (godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:78)
  → `getPluginSignals` (godot_project/plugin/src/main/java/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:62)
  → `registerReceivers` (godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:90)
  → `onGodotMainLoopStarted` (godot_project/android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt:111)

---

_Need a specific symbol's full callers/callees? Call `obs_impact` with its name._
_Need the call chain for a feature? Call `obs_feature_map`._
_Numbers above are derived from `calls` edges only; `imports` / `defines` / `extends` edges are not counted here._
