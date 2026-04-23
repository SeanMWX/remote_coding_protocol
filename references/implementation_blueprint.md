# Remote Coding Implementation Blueprint

## What This Repo Should Be

Treat this repository as the root of an OpenClaw skill project, not as a generic web app or a loose collection of scripts.

The minimum runtime contract is:

- `SKILL.md`
- `references/`
- optional `scripts/`

Repo-local support files such as `README.md`, `.gitignore`, tests, and planning notes are useful, but they are not the runtime contract that OpenClaw loads.

## Preferred Architecture

Use this shape first:

```text
Feishu DM or topic
  -> OpenClaw Feishu channel
  -> OpenClaw routing and session binding
  -> Codex execution via ACP session or Codex harness
  -> Git branch workspace
  -> reply back to the same Feishu conversation
  -> local machine fetch, test, review, merge
```

Keep the original product goal:

- mobile phone is the task entry point
- OpenClaw host is the always-on execution side
- GitHub is the sync boundary
- the local machine stays responsible for final validation

## What To Change From The Original Draft

The original design is directionally right, but two implementation choices should change for v1:

1. Do not build a webhook-first Feishu bridge if OpenClaw already provides a Feishu channel.
2. Do not hand-roll a separate Codex session framework before trying OpenClaw ACP or the bundled Codex runtime.

This matters because OpenClaw already provides:

- Feishu inbound and outbound message routing
- reply threading and chunking
- session ownership on the gateway
- background task tracking for ACP sessions
- Codex-oriented runtime paths

That means the MVP can be smaller, safer, and closer to the platform instead of reimplementing the platform.

## Recommended Runtime Choices

### Feishu

Use the built-in Feishu channel as the default ingress and egress layer.

Prefer:

- direct messages for personal coding requests
- topic threads when you want one conversation to map to one coding task

Only fall back to custom webhook integration if you hit a concrete limitation that the built-in channel cannot solve.

### Codex

Use one of these two paths:

1. `ACP Agents`
   Use when you want persistent Codex sessions, thread binding, background task tracking, or explicit `/acp ...` controls from chat.
2. `codex` harness or `codex-cli` backend
   Use when you want one-shot execution or a simpler path without persistent ACP orchestration.

For your target workflow, ACP is the better fit once you want "continue the previous task" from Feishu.

## Task Model

Represent user requests with three modes.

### `analysis`

Use for repo reading, architecture explanation, call-chain inspection, or training-entry analysis.

Expected behavior:

- no code changes by default
- no new branch unless explicitly requested
- reply with concise findings and suggested next action

### `modify`

Use for code changes.

Expected behavior:

- choose an allowed repo
- checkout a safe base branch
- create a task branch such as `codex/fix-login-timeout`
- run Codex in the isolated workspace
- run minimal allowed verification
- commit and push
- reply with branch, commit, summary, and local test hint

### `follow_up`

Use for "continue the previous task", "add tests to that branch", or "also fix the error handling".

Expected behavior:

- require an explicit branch, task id, or bound ACP conversation
- keep scope narrow
- avoid re-reading or reworking unrelated parts of the repo

## Git And Workspace Safety

Treat Git safety as a product requirement, not a nice-to-have.

Required rules:

- never modify `main` or `dev` directly
- never let two unrelated tasks share one dirty worktree
- prefer one isolated workspace per task
- keep repo access on an allowlist
- keep test commands on an allowlist
- keep dangerous shell access out of the chat surface

## What To Implement In This Repo First

Do not jump straight to a full service. Build in this order:

1. `SKILL.md`
   Define the workflow, task classes, safety rules, and preferred runtime choices.
2. `references/`
   Store architecture notes, task contracts, and examples without bloating `SKILL.md`.
3. `scripts/`
   Add only the deterministic helpers that are truly repeated, such as branch-name generation, result summarization, or config validation.
4. tests
   Verify any helper scripts and output-shape guarantees.

## Concrete MVP Plan

### Phase 1: Skill Definition

Deliver:

- a clean root `SKILL.md`
- one architecture reference
- one task-contract reference if needed

Goal:

- make the repo a valid skill root
- stop mixing runtime contract with copied helper repos

### Phase 2: OpenClaw Configuration

Configure on the server:

- Feishu channel
- Codex runtime path
- agent binding
- repo allowlist

Goal:

- prove that a Feishu message can reach the OpenClaw agent and return a reply

### Phase 3: Branch-Safe Coding Workflow

Add deterministic helpers only where they reduce risk:

- branch naming helper
- result summarizer
- repo and branch policy validator

Goal:

- support `modify` requests end to end

### Phase 4: Follow-Up Sessions

Add:

- ACP binding strategy
- follow-up task rules
- task or branch lookup

Goal:

- support "continue the previous task" from Feishu without losing context

## Suggested Message Output Contract

Return compact structured summaries that fit chat:

```text
任务: 修复登录 timeout
状态: 成功
仓库: repo-a
分支: codex/fix-login-timeout
提交: abc1234
修改文件:
- app/auth.py
- tests/test_auth.py

摘要:
1. 修复 timeout 配置未生效
2. 补充异常路径处理

建议本地执行:
git fetch origin
git checkout codex/fix-login-timeout
pytest tests/test_auth.py
```

## Immediate Next Step

Keep the next step narrow:

- finish the skill structure first
- then write the OpenClaw config shape
- then decide whether v1 uses ACP, Codex harness, or `codex-cli` backend as the primary execution path
