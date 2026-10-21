# 项目开发交接

- 当前 Godot 工程入口为 `godot_project/project.godot`，核心代码在 `godot_project/companion/`。
- 开始或继续开发前先读 `docs/handoff/weather-pet-main.md`，核对工作区和远端分支，不把旧测试记录当本轮验收。
- 用户默认采用 `/Users/yuezhang/.codex/skills/dida-dev-handoff/SKILL.md`；环境中存在此技能时读取并遵循，在实施前、关键改动、测试、阻塞及交还前先保存仓库交接，再同步滴答。缺少该环境时保留本地待同步记录。
- 以稳定键 `weather-pet-main` 沿用同一交接任务；私人 ID 与同步绑定放在被忽略的 `.local/handoff/`，不写入共享文档。
- GitHub 默认分支 `flutter-rive-v3` 是另一条开发线。本分支保留当前 Godot 成果，未获得明确指令前不要覆盖或合并默认分支。
- 上传源码不等于发布 APK。APK、签名、邮箱授权码与服务器凭据不得提交；同版本不同哈希必须先核对再发布。
