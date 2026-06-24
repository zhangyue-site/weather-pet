# 天气小人 v2 (Weather Pet)

一个用 **Godot 4.4** 制作的 Android 桌面天气宠物，根据实时定位、天气、时间、节日驱动小人做出不同动作。

## ✨ 功能

- 🌤 **真实天气**：和风天气 API（QWeather），根据 GPS 定位获取当地实时天气
- 📍 **定位**：GPS 实时定位 + 14 个预设城市手动切换
- 🎭 **30+ 种小人状态**：睡觉/吃饭/散步/撑伞/打雪仗/怕雷/发抖/热化/过节…
- 🕐 **昼夜循环**：背景天空/城市灯光随真实时间变化
- 🎉 **节日提醒**：自动识别节日触发庆祝动作
- 🔋 **设备状态**：电量/信号实时显示
- 👆 **触摸交互**：点击挥手、长按趴下、双击转圈
- 🎨 **天气小人图标**：矢量绘制的可爱黄色小人

## 📱 演示模式

无 Android 设备时，PC 上自动进入**演示模式**：轮播各种天气 + 加速过一天，便于预览所有效果。

## 🏗 项目结构

```
godot_project/
├── scripts/          # GDScript 代码
│   ├── main_scene.gd     # 主场景: 背景 + HUD + 触摸交互
│   ├── data_channel.gd   # 数据中枢: 插件/演示双分支
│   ├── pet_fsm.gd        # 小人状态机
│   ├── pet_renderer.gd   # 小人矢量绘制
│   ├── cityscape.gd      # 城市背景
│   ├── weather_fx.gd     # 天气粒子特效
│   └── prop_system.gd    # 道具系统(伞/围巾等)
├── plugin/           # Kotlin 插件源码
│   └── .../WeatherPetPlugin.kt   # GPS定位 + 和风天气API + 系统广播
├── android/          # Godot Android 导出工程
│   ├── src/              # 插件 Kotlin 源码(打包时复制)
│   └── AndroidManifest.xml
├── icon.png          # 天气小人图标
└── build_apk.sh      # 一键打包脚本
```

## 🔧 打包

```bash
cd godot_project
bash build_apk.sh
```

产物：`WeatherPet_signed.apk`

## ⚙️ 和风天气配置

API Key 和 Host 配置在：
`plugin/src/main/java/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt`

```kotlin
private val QWEATHER_KEY: String = "你的KEY"
private val QWEATHER_HOST: String = "你的专属API Host"
```

注册：https://dev.qweather.com/

## 📲 安装

```bash
adb install WeatherPet_signed.apk
```

首次打开需授权**定位权限**以获取当地真实天气。
