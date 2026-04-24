# Task Contract

## Purpose

This file defines the expected task shapes for the remote coding workflow.

Use it when turning Feishu requests into structured actions.

## Task Types

Support exactly three task types.

### `analysis`

Use for:

- architecture explanation
- entrypoint tracing
- call-chain inspection
- config flow analysis

Expected behavior:

- no code changes by default
- no branch required by default
- return concise findings and suggested next action

### `modify`

Use for:

- bug fixes
- focused refactors
- new tests
- small feature additions

Expected behavior:

- choose an allowed repo
- choose a safe base branch
- create a task branch
- run Codex in the selected workspace
- run minimal allowed verification
- commit and push
- return branch, summary, and local test hints

### `follow_up`

Use for:

- continue previous task
- add tests to the same branch
- extend a just-created change

Expected behavior:

- require an explicit branch, task id, or bound ACP session
- preserve existing context
- keep scope narrow

## Recommended Parsed Shape

Normalize chat input into a structure like:

```json
{
  "task_type": "modify",
  "repo": "repo-a",
  "base_branch": "main",
  "work_branch": "codex/fix-login-timeout",
  "prompt": "修复登录 timeout 并补最小测试",
  "need_push": true,
  "need_pr": false
}
```

## Required Inputs

For `modify`:

- repo
- task goal
- base branch when it matters

For `follow_up`:

- existing branch, task id, or bound ACP thread

## Output Contract

Return compact chat-friendly summaries.

Recommended fields:

- status
- task type
- repo
- branch
- commit or PR link when available
- files changed count or list
- short summary
- suggested local verification commands

## Safe Defaults

If the user request is ambiguous:

- default to `analysis`
- do not modify code
- ask for the repo or branch only when needed to proceed safely

## Examples

### Analysis

Input:

```text
帮我分析 repo-a 的训练入口，不改代码
```

Output shape:

```json
{
  "task_type": "analysis",
  "repo": "repo-a",
  "prompt": "分析训练入口，不改代码"
}
```

### Modify

Input:

```text
在 repo-a 从 main 开分支修复登录 timeout
```

Output shape:

```json
{
  "task_type": "modify",
  "repo": "repo-a",
  "base_branch": "main",
  "work_branch": "codex/fix-login-timeout",
  "prompt": "修复登录 timeout"
}
```

### Follow-up

Input:

```text
继续刚才那个分支，再补一版测试
```

Output shape:

```json
{
  "task_type": "follow_up",
  "branch": "codex/fix-login-timeout",
  "prompt": "补一版测试"
}
```
