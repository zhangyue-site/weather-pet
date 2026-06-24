# Architecture

> Auto-detected from filename and symbol-name heuristics. Treat as a starting hypothesis, not ground truth.

## Layers

### presentation (11 files)

- `天气APK小人/godot_project/plugin/build.gradle.kts`
- `天气APK小人/small-screen-animation/src/components/core/flip-card.test.tsx`
- `天气APK小人/small-screen-animation/src/components/core/flip-card.tsx`
- `天气APK小人/small-screen-animation/src/components/core/flip-clock.test.tsx`

### config (7 files)

- `天气APK小人/small-screen-animation/postcss.config.mjs`
- `天气APK小人/small-screen-animation/vite.config.ts`
- `天气APK小人/small-screen-animation/vitest.config.ts`
- `天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/settings/WallpaperSettingsActivity.kt`

### utility (5 files)

- `天气APK小人/small-screen-animation/src/lib/types.ts`
- `天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/util/TimeUtil.kt`
- `天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/util/WeatherMapper.kt`
- `天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/wallpaper/renderer/LottieWeatherHelper.kt`

### test (10 files)

- `天气APK小人/small-screen-animation/vitest.setup.ts`
- `天气APK小人/zuqiuxiaojiang/tests/__init__.py`
- `天气APK小人/zuqiuxiaojiang/tests/test_engine.py`
- `天气APK小人/zuqiuxiaojiang/tests/test_fixtures.py`

### service (2 files)

- `天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/WeatherWallpaperService.kt`
- `天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/widget/WidgetAnimationService.kt`

### model (5 files)

- `天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/domain/model/SceneType.kt`
- `天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/domain/model/TimeOfDay.kt`
- `天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/domain/model/WeatherCondition.kt`
- `天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/domain/model/WeatherData.kt`

### controller (1 files)

- `天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/sensor/SensorController.kt`

### data (1 files)

- `天气APK小人/zuqiuxiaojiang/src/cn_football_agent/memory_store.py`

## Detected patterns

- Hooks

## Entry points

- `天气APK小人/weather-figure/app/src/main/kotlin/com/skydiver/weatherlive/ui/WallpaperPreviewView.kt` — function `run`
- `天气APK小人/zuqiuxiaojiang/src/cn_football_agent/agent_loop.py` — function `run`
- `天气APK小人/zuqiuxiaojiang/src/cn_football_agent/cli.py` — function `main`
- `天气APK小人/zuqiuxiaojiang/src/cn_football_agent/engine.py` — function `bootstrap`

---

_Need a specific feature's reading order? Call `obs_feature_map` with the feature name._
_Need to see impact before a change? Call `obs_impact` with the symbol name._
