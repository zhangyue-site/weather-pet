# 小院天气｜Android 与 iOS 共用 Godot 小院

> 已交付源码与签名包 · 2026-10-25 · Codex
>
> iOS 已接入 Android 的同一 Godot 场景。公开源码可独立构建；签名包已生成，尚未上传 App Store/TestFlight，真机验收未完成。

## 实现

- 共用阿晴、大肥鱼、106套动作、日历、个人纪念日、双人互动、背景微动及减少动态设置。
- iOS增加CoreLocation、仅使用期间定位、城市/区县解析、超时和取消、省电状态、安全区及前后台恢复。
- 原生回调不接触Godot对象，通过带请求编号的事件队列在Godot线程轮询；过期请求不会覆盖新位置。
- iOS通过App Store/TestFlight更新；Android保留APK OTA。未改Android正式OTA条目。
- 原创代码MIT，第三方分别保留MIT/OFL等许可，设置内可查看。默认分支已切换到本Godot分支，旧Flutter分支保留。

## 验证

| 检查 | 结果 | 范围与限制 |
| --- | --- | --- |
| Godot回归 | 17组通过 | 含原有双人互动、日历、资源缓存、定位标签及新增iOS事件隔离 |
| 原生插件 | 编译通过 | device arm64，simulator arm64/x86_64 |
| 资源完整性 | 通过 | 12659帧、清单、许可逐文件哈希一致，PCK SHA256 `874f72d041342dca0c42a42fdbe43378b9b49c0f691d4f8dd8a1dacc8b1ecfe9` |
| GitHub干净构建 | 通过 | Actions [40207737101](https://github.com/zhangyue-site/weather-pet/actions/runs/40207737101)，公开源码拉取、测试、unsigned IPA及artifact上传成功 |
| iOS模拟器 | 通过 | 同版本源码编译arm64测试引擎，18张天气/节日场景截图；模拟GPS触发系统城市/区县解析 |
| iOS device包 | 构建及签名验证通过 | 官方4.4.1 device模板，严格codesign验证通过；不是实机安装验收 |
| 实际天气/定位权限分支/功耗/流畅度 | 真机未验证 | 模拟器天气网络曾不可用，不把体验场景数据当真实天气 |

模拟器使用iOS26.5、Apple Software Renderer和Dummy音频驱动：CoreSimulator的真实音频RemoteIO曾RPC超时，不能冒称音频或GPU性能通过。模拟器测试引擎仅用于验证，最终device包仍用官方模板。

## 构建交付

- 源码：[5146cf6](https://github.com/zhangyue-site/weather-pet/commit/5146cf6950f6fdf2549c0ced03a7afd3a237c439)（后续提交仅补构建说明、资源UID与验证记录）。
- 版本1.4.3，build213，bundle `com.weatherpet.weatherPet`，Apple分发签名。
- IPA：235148149字节，SHA256 `cd69cf7c060c1ba5a8f0488e4a27290fdc5a3e36c767db109d53868c53227ac5`。
- 真实签名证书SHA256 `64d558fd26467d195d1d71d9b9006b331665482419154519331b5b4f45d0e019`。
- 产物和106私有备份已独立核对哈希；私人路径、描述文件及签名材料不进入公开源码。
- AppStore分发签名包需要通过AppStore Connect/TestFlight使用；本轮没有执行上传或提审。

## 构建入口与注意

`tools/build_ios_plugin.py` 编译系统桥接；`tools/build_ios.py` 导出、核验资源、构建与可选签名。方法见README。

1. `.gdignore`会导致普通导出漏鱼帧；专用EditorExportPlugin按manifest逐帧加入，`verify_pack.py`阻止缺帧交付。
2. 官方4.4.1模拟器模板只有x86_64；新Apple Silicon runtime用同版本源码编译arm64，并通过`--simulator-engine`传入。模拟器单独去掉不存在的MetalFX弱链接，device保留。
3. iOS构建使用隔离portable编辑器配置，显式关闭Android探测与退出时ADB关闭，不改用户全局编辑器设置。
4. 构建依赖建议放在非云同步目录；本次Documents出现dataless文件阻塞，依赖移至临时目录后完成验证。

## 界面证据

[晴天](../screenshots/ios/clear.png) · [下雨](../screenshots/ios/rain.png) · [节日日历](../screenshots/ios/festival_menu.png)

## 下一步

在有权限的实体iPhone上通过TestFlight/既有分发渠道安装，验收真实天气、定位允许/拒绝、前后台、纪念日持久化、动画功耗。发布商店与提审需对应指令，本轮源码提交和打包不自动执行上架。
