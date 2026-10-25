# 小院天气 · 阿晴和大肥鱼

用真实天气、昼夜、节日和日常互动驱动的小院。Android 与 iOS 使用同一套 **Godot 4.4.1 场景与资源**：阿晴、大肥鱼、天气行为、全年日历、个人纪念日、双人互动、背景微动和减少动态设置共用源码。

## 运行

使用 Godot 4.4.1 打开 `godot_project/project.godot`。主场景是 `companion/main.tscn`。首次运行可手选城市；天气暂不可用时可体验场景。大肥鱼按需解码，缓存最多40帧/24MiB，完整动作帧随本分支提供。

```bash
GODOT_BIN=/path/to/Godot bash godot_project/run_tests.sh
```

## iOS 构建

需要 macOS、Xcode、Python 3/SCons、官方 Godot 4.4.1 编辑器及 iOS 导出模板，以及同版本 Godot 源码。原生插件只提供 CoreLocation、城市区县解析和省电状态；画面与行为全部来自共享 Godot 场景。

```bash
python3 tools/build_ios_plugin.py --godot-source /path/to/godot-4.4.1-stable
python3 tools/build_ios.py --godot /path/to/Godot
# 模拟器版本
python3 tools/build_ios.py --godot /path/to/Godot --simulator --output builds/ios-simulator
```

官方 Godot 4.4.1 模拟器模板只含 x86_64 库；新 Apple Silicon iOS runtime 需要 arm64。可用同版本源码构建测试引擎，然后传入 `--simulator-engine /path/to/libgodot.ios.template_release.arm64.simulator.a`：

```bash
# 在 Godot 4.4.1 源码目录执行（只影响模拟器验证，不替换 device 模板）
scons platform=ios target=template_release ios_simulator=yes arch=arm64 disable_3d=yes vulkan=no metal=no modules_enabled_by_default=no module_gdscript_enabled=yes module_text_server_adv_enabled=yes module_freetype_enabled=yes module_webp_enabled=yes module_mbedtls_enabled=yes module_regex_enabled=yes optimize=size debug_symbols=no -j4
```

默认生成未签名 IPA。使用自己的证书和匹配的描述文件签名：

```bash
python3 tools/build_ios.py --identity 'Apple Distribution: ...' --profile /private/path/AppStore.mobileprovision
```

描述文件、私钥和签名证书不随源码分发。App Store 分发签名包需通过 App Store Connect/TestFlight 使用。包名沿用 `com.weatherpet.weatherPet`；自行分发时请修改 iOS 导出预设中的 bundle identifier。预设中的团队值只是未签名导出占位符。

导出插件会把 `.gdignore` 下按需解码的 WebP 帧加入资源包；`tools/verify_pack.py` 会核对清单中所有帧、许可和哈希，缺帧直接阻止打包。不要只复制 GDScript 或绕过导出插件。

## Android 构建

现有构建入口是 `godot_project/build_companion.py`（Godot 4.4.1、JDK17、Android SDK 和 Gradle）。发布构建必须使用维护者自己的既有签名，不把调试包当作可覆盖正式包。`tools/build_interaction_test.py` 是历史固定APK补丁工具，并非公开源码构建的必要依赖。

## 平台差异

- Android：原生定位与 APK OTA。
- iOS：仅使用应用期间定位，允许系统近似定位；拒绝权限或超时后手选城市。通过 App Store/TestFlight 更新，不下载安装 APK。
- 两端：Open-Meteo 天气、日历、角色与双人互动、本地纪念日和陪伴记录、背景省电降级。

无定位权限也能使用。定位坐标用于天气和系统地名查询，个人纪念日及陪伴记录保存在设备本地。场景体验使用示例天气，页面明确标记。

## 开源与许可

原创代码使用 [MIT](LICENSE)；大肥鱼 MIT、字体 OFL、农历生成依赖等许可见 [第三方说明](THIRD_PARTY_NOTICES.md)，应用设置内也可查看。天气数据来源 Open-Meteo。旧 Flutter/Rive 分支保留作历史参考，不参与当前构建。

[跨端交接](docs/handoff/ios-android-alignment-audit.md) · [开发交接](docs/handoff/weather-pet-main.md) · [每日内容](docs/calendar/每日内容.csv)
