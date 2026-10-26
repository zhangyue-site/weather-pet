# 项目开发交接

- 当前 Godot 工程入口为 `godot_project/project.godot`，核心代码在 `godot_project/companion/`。
- 开始或继续开发前先读 `docs/handoff/weather-pet-main.md`，核对工作区和远端分支，不把旧测试记录当本轮验收。
- 用户默认采用 `dida-dev-handoff` 技能；环境中存在此技能时读取并遵循，在实施前、关键改动、测试、阻塞及交还前先保存仓库交接，再同步滴答。缺少该环境时保留本地待同步记录。
- 以稳定键 `weather-pet-main` 沿用同一交接任务；私人 ID 与同步绑定放在被忽略的 `.local/handoff/`，不写入共享文档。
- 用户已于2026-10-25选定Android现有Godot小院为跨端基准。GitHub默认分支为 `codex/weather-companion-handoff`，iOS与Android共用Godot场景；`flutter-rive-v3`保留为历史开发线，不再作为iOS构建入口。
- 上传源码不等于发布 APK。APK、签名、邮箱授权码与服务器凭据不得提交；同版本不同哈希必须先核对再发布。
