---
name: remote_coding_protocol
description: Build and operate an OpenClaw-based remote coding workflow with Feishu/Lark, Codex, and GitHub. Use when implementing or refining a 云端编程 + 手机飞书发消息 + Git 分支同步 + 结果回传 system for branch-isolated coding on a remote host.
---

# Remote Coding Protocol

Treat this repo root as the skill root. Keep runtime-facing material in `SKILL.md`, `references/`, and later `scripts/`. Treat `README.md`, `.gitignore`, and `openclaw_codex_feishu_design.md` as repo-local maintenance or planning docs, not the runtime contract.

## Prefer OpenClaw Built-ins First

Prefer the built-in Feishu channel for message ingress and replies. Do not start from a custom webhook service unless the built-in channel cannot satisfy a concrete requirement.

Prefer OpenClaw ACP sessions or the bundled Codex harness for Codex execution. Do not introduce a separate `codex_runner.py` wrapper first if OpenClaw session binding, background tasks, and Codex runtime controls already cover the use case.

Use GitHub branches as the only code sync boundary between remote work and the local machine.

## Model Requests As Three Task Modes

Classify each request as one of these modes:

- `analysis`: inspect code, explain findings, and return a summary without modifying code
- `modify`: create a task branch, apply code changes, commit, push, and return branch plus validation hints
- `follow_up`: continue an existing task by explicit branch or task id, keep scope tight, and preserve prior context

## Enforce Safety Rails

Never let chat-originated input become arbitrary shell execution.

Allow only:

- repo allowlist selection
- base branch checkout and pull
- one task branch per modifying request
- Codex or ACP execution inside the checked-out workspace
- optional predefined test commands
- optional PR creation

Do not modify `main` or `dev` directly. Do not reuse a dirty shared worktree across unrelated tasks. Prefer one isolated workspace per task.

## Return Compact Chat Results

Return Feishu-friendly summaries with:

- status
- repo
- base branch or task branch
- commit or PR link when relevant
- changed files count or list
- short summary
- suggested local verification commands

Chunk replies only when one message is too long for the channel.

## Read Before Changing Architecture

Read `{baseDir}/references/implementation_blueprint.md` before changing routing, session behavior, or the execution model.

Read `{baseDir}/references/openclaw_minimax_codex_acp.md` and `{baseDir}/references/openclaw_minimax_codex_acp.example.json5` when implementing the recommended v1 deployment that uses MiniMax for normal chat and Codex ACP for coding sessions.
