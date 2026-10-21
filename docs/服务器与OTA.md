# 服务器与 OTA

## 已核实的服务器

2026-10-01 在腾讯云控制台核实：124.222.88.195，上海轻量应用服务器，4 核 / 4 GB / 70 GB，运行中。到期时间 **2029-08-07 14:04:42**（控制台显示时间）。没有进行续费或账单操作。

## 已上线地址

复用指向此服务器的 `zz.zhangyue.site`，独立目录 `/www/wwwroot/zz.zhangyue.site/weather-companion`。

- `events.json`：公共节日安排下发。
- `latest.json`：APK 版本、大小、哈希、下载地址、适用 SDK/架构与说明。
- `releases/WeatherCompanion-版本号.apk`：已签名安装包。
- 私人生日、纪念日、定位、陪伴记录不上传。

## 证书来源与部署

2026-10-01 在新服务器 `106.52.123.149` 找到现有任务：每日 09:00 运行 `/www/wwwroot/tools/ssl_recovery_from_qq_mail.py`，从 QQ 邮箱接收证书；配置 `MODE=after_expire`，只在证书到期时检查邮件。

该服务器已有 `*.zhangyue.site` / `zhangyue.site` 证书，有效期 2026-08-24 至 2026-11-22 23:59:59 UTC（北京时间 11 月 23 日 07:59:59）。证书与私钥公钥匹配，证书链经正常 TLS 验证。

已将此现有证书部署到 `124.222.88.195` 的 `zz.zhangyue.site`，无需申请新证书或接受新协议。旧文件备份在原服务器 `/root/weather-ota-cert-backup-20261001-155120`，nginx 配置检查及公网 HTTPS 均通过。私钥仅保留在服务器证书目录，没有写入项目或 APK。

新服务器定时任务原先只更新新服务器的 5 个站点；本次没有修改其调度，也没有声称它会自动同步到旧服务器。旧服务器后续仍需在证书到期前同步有效证书。

## APK 内流程

设置 → 应用更新 → 检查更新 → 查看说明和大小 → 下载更新 → 安装更新。首次安装更新需要在 Android 系统页允许本应用安装未知来源应用；返回后点继续安装。用户可取消，不会后台静默安装。

仅信任指定 HTTPS 主机和目录，拒绝重定向。下载上限 150 MB，检查剩余空间、声明大小、SHA-256、包名、版本号和当前安装应用的签名。相同版本或旧版本不会提示升级。下载失败删除不完整文件，保留当前应用；安装失败可重试。

用户明确点击下载才传输 APK。私人数据位于 Android 原应用沙箱，同包名同签名升级会保留；不要卸载后重装来“升级”。

## 构建与发布

```bash
python3 godot_project/build_companion.py
python3 tools/publish_release.py             # 仅生成可审核的 builds/latest.json
python3 tools/publish_release.py --deploy    # 有效 HTTPS 后才允许发布
```

后续发布必须递增版本码并保持同一签名：

```bash
WEATHER_VERSION_CODE=104 WEATHER_VERSION_NAME=1.2.2 python3 godot_project/build_companion.py
```

当前沿用本机原有 Android 调试签名以兼容之前安装的 APK，属于内测分发；不要删除或替换 `~/.android/debug.keystore`。正式商用签名与渠道发布需单独迁移设计，不能直接换钥后声称可以 OTA 覆盖安装。

发布先上传版本化 APK 并核对哈希，再原子替换清单，避免客户端读到半成品。发布脚本会用正常 TLS 再下载核对线上 APK。密钥从不上传服务器。
