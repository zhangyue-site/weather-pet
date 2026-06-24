# Agent Brief — godot_project

This repo has been indexed by **obs-code**. Read this file first when you arrive.

## How to orient yourself (in 30 seconds)

1. `project.md`       — what this codebase is, scale, languages, key files
2. `architecture.md`  — layers, patterns, entry points (the skeleton)
3. `connections.md`   — hubs, cross-layer bridges, main call chains (the wiring)
4. `manifest.json`    — index stats & freshness timestamp

You can read those files directly with your file tools — no MCP call needed.
Skeleton + wiring together = the complete map. Read `architecture.md` for *where things live*, then `connections.md` for *how they reach each other*.

## When to call which obs-code MCP tool

| Situation | Tool | Why |
|---|---|---|
| "Where is symbol X defined?" | `obs_find` | name → file:line |
| "What breaks if I change X?" | `obs_impact` | BFS callers + callees (summary by default; pass `format: "full"` / `include_source: true` to widen) |
| "I want to add feature Y" (natural language) | `obs_plan` | requirement → file list with abs paths |
| "Help me understand login flow / feature Z" | `obs_feature_map` | feature → reading chain by phase |
| "Where are the HTTP routes?" | `obs_routes` | route table + call chains |
| "What's the project shape?" | (read `project.md`) or `llm_wiki_generator` | overview |
| "Show me unused functions" | `obs_deadcode` | zero-caller non-exported functions |
| Code has changed significantly | `obs_index` | re-index, refreshes this wiki |

## Hard rules

- Respond to the user in Chinese by default. Keep code identifiers, file paths, API names, and command names in their original form.
- When another AI participates in explanation, planning, or risk analysis, instruct it to produce concise Chinese output unless the user asks otherwise.
- **Do NOT** ask the user to re-index unless code has clearly changed since `manifest.json.generatedAt`.
- **Do NOT** call `obs_index` repeatedly in one session — it is expensive.
- **Do NOT** call `llm_wiki_generator` if `project.md` / `architecture.md` already answers the user's question.
- **Prefer** `obs_plan` over manual `obs_find` + `obs_impact` chains when the user states a natural-language requirement.

## Freshness

- **Last indexed:** 2026-06-21 15:56:56
- **Stats:** 56 nodes, 55 edges, 4 files
- **Project root:** `/Users/yuezhang/Developer/mycode/天气APK小人/godot_project`
