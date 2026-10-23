# 小院天气 · iOS 与 Apple Watch（原生 SwiftUI）

这是 Android 版「小院天气 · 阿晴」（Godot 4.4，分支 `codex/weather-companion-handoff`）的原生移植。iPhone 版功能对等；Apple Watch 版取了其中一部分。行为、文案、数据和美术都直接取自 Godot 工程。逻辑按 GDScript 逐个函数移植，不依赖 Godot、Flutter 或任何第三方 SDK。

## 结构

```
ios/
├── project.yml                 XcodeGen 配置（改后运行 `xcodegen` 重新生成工程）
├── WeatherPet.xcodeproj        已生成，可直接用 Xcode 打开
├── CompanionCore/              Swift Package，两端共用
│   ├── Sources/CompanionCore/  纯逻辑：world.gd / events.gd / calendar_data.gd / weather_source.gd /
│   │                           event_source.gd / main.gd 的移植，外加 CoreLocation 定位
│   ├── Sources/CompanionScene/ SwiftUI Canvas 渲染：背景、阿晴、天气粒子、200 套节日特效
│   └── Tests/                  Godot 六组测试的移植，以及与 Godot 内容一致性的检查
├── App/                        iPhone 应用（主界面 + 8 个面板）
├── Watch/                      Apple Watch 应用
├── Shared/                     iPhone ↔ Watch 设置同步、启动参数
└── tools/
    ├── prepare_assets.swift    精灵图集抠色切帧、背景压缩、图标生成
    └── sync_content.sh         从 godot_project 同步节日/农历/每日内容
```

## 与 Godot 版的对应

| Godot / Android | iOS |
| --- | --- |
| `world.gd` 状态机（雨天取伞、雷声、睡觉、陪伴冷却、湿度、精力、心情） | `CompanionWorld`，常量和时序一致 |
| `events.gd` 校验与匹配（公历、农历、闰月、除夕、第 N 个星期、节气；哀思压制庆祝） | `Events`，同样拒绝未知动作、效果和非法日期 |
| `event_source.gd` 服务器活动（只走 HTTPS、不跟随重定向、上限 128 KiB、拒绝旧 revision、每 6 小时刷新） | `EventSource` |
| `weather_source.gd` Open-Meteo（先显示缓存、15 分钟刷新、当地日出日落相位） | `WeatherService`、`WeatherClock` |
| `CompanionLocation.kt` 一次性前台定位 + 逆地理编码 | `DeviceLocation`（CoreLocation，iOS 26 起改用 MapKit 逆地理编码） |
| `actor.gd` + `chroma.gdshader` | 图集在构建前抠色切帧（`prepare_assets.swift`，算法与 shader 相同），运行时按帧绘制并叠加色调 |
| `effects.gd`、`calendar_effects.gd` | `SceneRenderer`、`Motif`（同样是 20 类图形 × 10 种运动） |
| Kotlin OTA（APK 下载安装） | **iOS 不适用**：应用版本走 App Store / TestFlight；节日日历仍从服务器自动更新 |

坐标系：画面统一换算成 Godot 的 540 单位逻辑宽度，所以位置、速度、粒子尺寸的常量都能原样沿用。

## Apple Watch 的取舍

- 保留：小院动画（轻点阿晴打招呼，轻点头部摸头，轻点地面让他走过去）、实时天气与定位、今日天气/农历/节日、五种陪伴、陪伴日记、16 种天气体验与自动漫游、城市选择、节日目录预览、减少动态效果。
- 简化：天气粒子减半，帧率 30。抬腕常亮时显示静态画面，降低亮度。
- 不做：纪念日编辑（在 iPhone 上设置，通过 WatchConnectivity 同步过来）、任意日期预览、200 特效图鉴、安静观赏模式。
- 两端同步的设置：城市、是否自动定位、个人纪念日。陪伴次数、日记、精力各自保存。
- 手表可以独立运行（`WKRunsIndependentlyOfCompanionApp`），自己定位、自己拉天气。

## 构建与测试

需要 Xcode 26 或更高版本（本机是 Xcode 27.1）。最低系统为 iOS 17 / watchOS 10。

```bash
cd ios/CompanionCore && swift test          # 核心逻辑测试
cd ios && xcodebuild -scheme WeatherPet -destination 'generic/platform=iOS Simulator' build      # 连带编译手表
cd ios && xcodebuild -scheme WeatherPetWatch -destination 'generic/platform=watchOS Simulator' build
```

调试用的启动参数会让应用进入演示模式，且不写存档：

```bash
xcrun simctl launch booted com.weatherpet.weatherPet -demo rain -sheet weather
xcrun simctl launch booted com.weatherpet.weatherPet -previewDate 2026-02-17
xcrun simctl launch booted com.weatherpet.weatherPet -festival national_day
xcrun simctl launch booted com.weatherpet.weatherPet -effect lantern_drift
```

可用参数：`-demo <场景id>`、`-sheet weather|care|festivals|settings`、`-previewDate YYYY-MM-DD`、`-festival <活动id>`、`-effect <特效id>`、`-quiet YES`。

## 真机前要做的

1. 在 `project.yml` 的 `DEVELOPMENT_TEAM` 填上团队 ID（或在 Xcode 的 Signing 里选），然后运行 `xcodegen`。
2. 包名沿用之前 iOS 版的 `com.weatherpet.weatherPet`，手表为 `com.weatherpet.weatherPet.watchkitapp`。版本号与 Android 对齐：1.2.1（103）。
3. 修改 Godot 的美术或内容后，运行 `xcrun swift ios/tools/prepare_assets.swift "$PWD"` 和 `ios/tools/sync_content.sh`。
