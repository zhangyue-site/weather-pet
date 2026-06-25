# 天气小人 v3 · 轻量引擎选型

## 当前问题 (Godot 4.6)
- APK 体积 50MB（一个天气宠物 app 不该这么大）
- 3D 模型加载慢，材质兼容问题多
- 布局系统复杂（viewport/stretch/坐标系问题反复出现）
- 免费 3D 模型资源少，自定义困难

## 选型对比

| 方案 | 体积 | 动画资源 | 开发效率 | 桌面宠物适合度 | 推荐度 |
|------|------|----------|----------|----------------|--------|
| **Flutter + Rive** | 5-10MB | ⭐⭐⭐⭐⭐ Rive 免费素材库 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | **🏆 首选** |
| React Native + Lottie | 8-15MB | ⭐⭐⭐⭐⭐ LottieFiles 海量免费 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 备选 |
| Android 原生 + Lottie | 3-8MB | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | 轻量首选 |
| HTML5 Canvas/Web | 1-3MB | ⭐⭐⭐⭐ SVG/Lottie | ⭐⭐⭐⭐ | ⭐⭐⭐ | 极轻量 |
| Defold (Lua) | 8-12MB | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | |
| Cocos Creator | 10-15MB | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | |

## 🏆 方案 A: Flutter + Rive (推荐)

### 优势
- **APK 仅 5-10MB**（Godot 的 1/5）
- **Rive 免费素材库**: https://rive.app/community — 数千个免费交互动画
- **Rive 编辑器免费**: 可以自制角色动画，支持骨骼绑定+状态机
- **Flutter 渲染引擎**: Skia/Impeller，2D 渲染性能极佳
- **桌面宠物实现简单**: Flutter 可以做悬浮窗+系统级覆盖
- **和风天气 API 调用**: http/dio 包，几行代码搞定

### 免费素材来源
- **Rive Community**: https://rive.app/community — 动物/人物/天气图标，可编辑
- **LottieFiles**: https://lottiefiles.com — 可导入 Flutter
- **OpenGameArt**: https://opengameart.org — 2D 精灵图
- **Kenney**: https://kenney.nl — 高质量免费素材

### 技术栈
```yaml
# pubspec.yaml
dependencies:
  flutter:
  rive: ^0.13.0          # Rive 动画渲染
  http: ^1.0.0           # 天气 API
  geolocator: ^10.0.0    # GPS 定位
  shared_preferences:    # 持久化
  workmanager:           # 后台定时刷新
```

### 架构
```
lib/
├── main.dart            # 入口 + 悬浮窗
├── models/
│   └── weather.dart     # 天气数据模型
├── services/
│   ├── weather_api.dart # 和风天气 API
│   └── location.dart    # GPS 定位
├── ui/
│   ├── pet_widget.dart  # Rive 动画宠物
│   ├── hud_widget.dart  # 天气/时间 HUD
│   └── settings.dart    # 设置面板
└── assets/
    └── pet.riv          # Rive 动画文件
```

## 方案 B: Android 原生 + Lottie

### 优势
- **最小体积 3-8MB**
- **LottieFiles 海量免费动画**: https://lottiefiles.com
- **原生性能最佳**
- **桌面宠物用 WindowManager 悬浮窗**

### 适合场景
- 只做 Android
- 追求极致轻量
- 团队熟悉 Kotlin

## 方案 C: HTML5 + Canvas

### 优势
- **极轻量 1-3MB**
- **Web 技术栈，开发快**
- **可以用 Capacitor/Cordova 打包 APK**
- **SVG 动画 + CSS 动画资源丰富**

### 适合场景
- 快速原型
- 需要同时支持 Web + App

## 决策建议

| 如果你... | 选择 |
|-----------|------|
| 想要最好的开发体验 + 丰富素材 | **Flutter + Rive** |
| 只做 Android + 追求极致轻量 | Android 原生 + Lottie |
| 想快速原型验证 | HTML5 + Canvas |
| 已经熟悉 Godot + 只需修 bug | 继续 Godot |

## 下一步

确认方案后我会：
1. 创建新项目结构
2. 集成天气 API
3. 导入/创建角色动画
4. 实现桌面宠物悬浮窗
5. 打包测试
