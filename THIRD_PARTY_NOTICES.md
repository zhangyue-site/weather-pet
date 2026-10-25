# 第三方许可与服务

项目原创代码使用根目录 MIT 许可。第三方内容继续使用各自许可，根目录许可不替代它们。

| 内容 | 来源与许可 | 仓库内许可 |
| --- | --- | --- |
| 大肥鱼动作与兼容动作帧 | [PC2005-cloud/dsh-pet](https://github.com/PC2005-cloud/dsh-pet)，固定提交 `b292803d694e8820d6f1fc88101dec7a0b87cadc`，MIT | `godot_project/companion/fish/LICENSE-upstream.txt` |
| 中文字体 Noto Sans SC | Google / Adobe，SIL Open Font License 1.1 | `godot_project/companion/fonts/OFL.txt` |
| 农历数据生成依赖 lunar-python | [6tail/lunar-python](https://github.com/6tail/lunar-python)，MIT | `docs/calendar/LICENSE-lunar-python.txt` |
| Godot Engine（构建时获取） | [godotengine/godot](https://github.com/godotengine/godot)，MIT及第三方组件许可 | 使用对应发行版的版权与许可；应用内包含 Godot 的许可入口 |

天气数据来自 [Open-Meteo](https://open-meteo.com/)，使用需遵守其服务条款及数据署名要求。iOS 地名解析使用系统 CoreLocation / CLGeocoder，Android 使用系统地名解析。定位仅用于天气与地名查询；个人纪念日保存在设备沙盒中。

原 Flutter/Rive 开发线不是当前 Godot 构建依赖。本分支的公开许可不扩大到其他分支中未经核实的第三方资源。
