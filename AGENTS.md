# AGENTS.md - bilibili_down Low-Token Rules

Applies to `D:\Project\bilibili_down`. Keep this file short: it is a runtime rule sheet, not project documentation.
Store durable architecture notes in `docs/technical-architecture.md`; do not add temporary project notes here.

## Priority Order

1. Read only context needed for the current request; do not reopen files or repeat checks whose result is already known in the same task.
2. Query `memory` only when work depends on earlier decisions, stable preferences, module history, or a repeated failure:
   - `Rule:` / `Decision:` for cross-cutting constraints.
   - `Module:<name-or-path>` before unfamiliar module edits.
   - `Gotcha:` when a confusing error repeats.
   - Skip memory for self-contained edits; do not write logs, obvious facts, guesses, or temporary state to memory.
3. Do not use CodeGraph merely because `.codegraph/` exists. Prefer `rg` and targeted file reads for ordinary work; use CodeGraph only when the task genuinely needs architecture, caller, dependency, or impact analysis and direct search is insufficient.
4. Read the smallest useful slice. Avoid full files, generated files, build output, binary directories, and lockfiles unless required.
5. Use `headroom` only for genuinely large output. Use `planner` only for multi-module work, explicit planning, or complex reports; skip both for small edits.
6. Keep changes scoped, verify proportionally, and auto-commit completed requested work unless the user says not to commit or the task remains incomplete.

## Commands

- Reply in Chinese; on Windows prefer PowerShell.
- Prefer `rg` / `rg --files`; use `rtk` for noisy Git, build, test, or log output when available and when exact raw output is not needed.
- Batch independent reads/checks when useful, but do not produce large combined output.
- Do not read `.dart_tool`, `build`, `.codegraph/codegraph.db`, native binaries, generated `*.g.dart`, or `pubspec.lock` unless the task requires them.
- Do not revert user changes. Do not branch, push, reset, or perform destructive operations unless explicitly requested.

## Project

- Flutter Bilibili downloader targeting Android, iOS, Windows, macOS, and Linux.
- Follow `docs/technical-architecture.md` for runtime architecture, and match existing UI code for responsive behavior.
- Match existing Riverpod, `go_router`, Drift, download-engine, and media-merger boundaries before adding abstractions.
- Do not edit `lib/core/database/app_database.g.dart` manually; update Drift sources and regenerate only when schema changes.
- Keep platform packaging architecture-specific; never bundle every `native_bins` target into one package.

## Editing and Comments

- Use `apply_patch` for manual edits; keep diffs focused and preserve user data and download recovery behavior.
- All destructive UI actions require confirmation.
- 所有可点击控件在桌面端和 Web 端悬停时必须使用 `SystemMouseCursors.click`；禁用控件使用 `SystemMouseCursors.forbidden`。新增交互控件必须优先复用 `core/widgets` 公共组件并同步设置鼠标指针。
- 新增或修改的代码必须使用中文注释，不得只写英文注释。
- 变量声明与赋值必须说明数据用途、来源或状态含义。
- 方法、构造函数和回调必须说明职责、输入、输出或生命周期。
- `if`、`switch`、循环、异常分支和外部 API / 文件 / 进程 / 平台调用必须说明业务原因。
- 注释应解释意图和平台限制，避免逐字翻译代码或重复显而易见的信息。

## Verification

- Do not run full builds or Dart tests unless the user asks.
- 未经用户明确允许，禁止为了查看效果执行 build、run、启动应用或模拟器、截图及视觉 QA；即使 Product Design 流程建议预览，也必须先获得用户许可。
- Prefer `dart format <changed files>`, `dart analyze <changed scope>`, and task-specific smoke/config checks.
- Do not rerun unchanged expensive checks in the same task. If verification is skipped or platform-specific behavior cannot be verified locally, say exactly what was not run.

## Git and Response

- Commit messages use an English conventional prefix plus Chinese summary, e.g. `feat: 实现任务恢复`.
- Commit only current-task files; exclude unrelated dirty or generated files.
- If the user also edits a current-task file during the task, include those edits in the same commit by default; do not exclude the user's hunks unless explicitly requested.
- Use a concise subject and Chinese body covering key changes and verification.
- Final response stays concise: outcome first, then changed files, verification, and any real limitation.
