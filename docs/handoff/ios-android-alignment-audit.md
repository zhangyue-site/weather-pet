# 小院天气｜Android 与 iOS 使用同一小院

> 进行中 · 2026-10-25 · Codex
>
> 已接通同一 Godot 主场景、资源和 iOS 平台桥接；正在验证 iOS 原生启动及最终打包。尚未声称真机验收或 App Store 更新。

## 目标与实现

以当前 Android Godot 小院为基准，替换旧 iOS Flutter 猫咪界面。两端共用阿晴、大肥鱼、106套动作、日历、个人纪念日、双人互动及背景微动。保留 Flutter 历史分支。

iOS 仅增加 CoreLocation 权限、坐标和城市/区县解析、请求超时与取消、低电量状态，以及安全区和前后台适配。原生回调不访问 Godot 对象，通过带请求编号的队列在 Godot 线程轮询；旧请求不能覆盖新位置。iOS 更新文案使用 App Store/TestFlight。

## 本轮验证

- [x] 原有16组Godot回归通过。
- [x] iOS桥接测试：请求编号、坐标/区县、取消后过期回调、权限失败、省电状态。
- [x] 原生插件 device arm64、simulator arm64 编译；增加 simulator x86_64 以匹配官方4.4.1模板。
- [x] 专用导出插件修复 `.gdignore` 下 WebP 资源漏包；12659帧及清单、许可逐文件哈希核对通过。
- [x] 当前受控源码凭据扫描无规则命中；证书、描述文件、私有发行配置及构建产物排除。
- [ ] iOS 模拟器启动与真机定位、功耗验收。
- [ ] GitHub 源码提交、读回后生成最终签名包。

## 构建与公开范围

`tools/build_ios_plugin.py` 编译系统桥接，`tools/build_ios.py` 导出、核验资源并构建；签名显式使用仓库外证书和描述文件。iOS bundle identifier 沿用 `com.weatherpet.weatherPet`，版本1.4.3，build213。

原创代码MIT；第三方资源分别保留MIT/OFL等许可，详见根目录 `THIRD_PARTY_NOTICES.md`。GitHub原先已公开，近期Android提交只含代码缺少鱼帧，本轮补齐可独立克隆的资源和构建步骤。

## 已发现与处理

1. 普通导出会忽略fish目录：使用EditorExportPlugin按manifest逐帧加入，不导入上万张纹理。
2. 官方4.4.1模拟器库为x86_64：插件同时生成arm64/x86_64模拟器库；模拟器构建使用x86_64。
3. 新模拟器SDK没有MetalFX：仅模拟器导出项目移除无用弱链接，device保留。
4. 本机已有Android设备探测会拖住iOS导出退出：iOS构建用隔离的portable编辑器配置，不改全局设置或ADB服务。

## 接手入口

共享工程 `godot_project/project.godot`；平台桥接 `native/ios/CompanionIOS.mm` 与 `companion/ios_platform.gd`；构建与验证方法见README。历史211候选与原有工作区修改不冒记为本轮新实现。未自动切换Android正式OTA，未上传App Store。
