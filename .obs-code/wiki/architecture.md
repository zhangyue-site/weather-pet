---
tags: [obs-code, architecture, layers]
created: 2026-06-25
source: obs-code
project: weather-pet
---
# Architecture

> 自动检测的架构分层。阅读顺序：[[project.md]] → 本文 → [[connections.md]]

## 分层

### presentation (1 files)

- `weather-pet/godot_project/plugin/build.gradle.kts`

## 检测到的模式

- Hooks

## 入口点

- `weather-pet/godot_project/scripts/make_icon.py` — function `main`
- `weather-pet/godot_project/scripts/make_skin.py` — function `main`

---

- [[project.md]] — 项目概览
- [[connections.md]] — 调用图和跨层桥接
- 需要特定功能的阅读顺序？调用 `obs_feature_map`
- 需要评估改动影响？调用 `obs_impact`
