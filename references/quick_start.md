# Quick Start

## Short Answer

No, the whole project is not finished.

What is finished now:

- the skill root structure
- the architecture direction
- the OpenClaw config draft for `MiniMax` + `Feishu` + `Codex ACP`

What is not finished yet:

- your actual server deployment
- your real Feishu app credentials
- your real OpenClaw runtime validation
- repo-specific automation such as branch policy, allowlists, and task templates

For the first MVP, you do **not** need to write much custom code.

That is intentional.

The fastest path is:

1. use OpenClaw built-ins for Feishu + ACP + Codex
2. prove the end-to-end path works
3. only then add custom scripts for repo rules and automation

## What To Start With

Start with this exact goal:

```text
手机发一条飞书消息
-> OpenClaw 收到
-> 你在飞书里显式进入 Codex ACP 会话
-> Codex 回消息
```

Do not start with custom webhook code.
Do not start with a full `task_parser.py`.
Do not start with Git automation.

First prove the transport and runtime path.

## Phase 1: Make OpenClaw Run

On your server, install and verify:

- OpenClaw
- Codex / Codex app-server auth
- network access for MiniMax and Feishu

Then check:

```bash
openclaw --version
openclaw gateway status
```

If `openclaw` is not found, stop and fix installation first.

## Phase 2: Configure MiniMax

Use one of the official onboarding paths:

```bash
openclaw onboard --auth-choice minimax-global-api
```

Or the matching regional variant if you use the China endpoint.

Then verify the provider:

```bash
openclaw models list --provider minimax
openclaw models status
```

Your target state:

- `minimax/MiniMax-M2.7` is visible
- auth is healthy

## Phase 3: Configure Feishu

Create the Feishu or Lark app first.

Then add the channel:

```bash
openclaw channels add
```

Choose `Feishu`, then fill:

- `appId`
- `appSecret`

After that, check:

```bash
openclaw channels status
openclaw gateway restart
openclaw logs --follow
```

Your target state:

- the gateway is up
- Feishu account is connected
- the bot can receive a DM

## Phase 4: Apply This Repo's Config Draft

Take this file as the base:

- [openclaw_minimax_codex_acp.example.json5]({baseDir}/references/openclaw_minimax_codex_acp.example.json5)

Copy its contents into your real OpenClaw config file:

```text
~/.openclaw/openclaw.json
```

Then replace all placeholders:

- `MINIMAX_API_KEY`
- Feishu `appId`
- Feishu `appSecret`
- allowed group ids
- allowed user ids
- workspace paths

Then validate:

```bash
openclaw config validate
openclaw gateway restart
```

## Phase 5: Test The No-Code MVP

### Test normal chat

Send a normal Feishu DM:

```text
你好，帮我总结一下你现在能做什么
```

Expected:

- OpenClaw replies through the `main` agent
- the default model path is MiniMax

### Test coding mode

In the same Feishu DM or topic, send:

```text
/acp doctor
```

Expected:

- ACP backend health information appears

Then send:

```text
/acp spawn codex --thread here
```

Expected:

- a Codex ACP session is created
- the conversation is now bound to Codex

Then send:

```text
帮我先分析一下当前仓库目录结构，不改代码
```

Expected:

- Codex replies in the same conversation

At this point, your MVP transport path is working.

## When You Actually Need Coding

You need custom coding only after the basic path works.

That work usually starts here:

### 1. Repo policy

You want:

- repo allowlist
- branch naming rules
- task workspace isolation
- safe test command allowlist

This usually becomes small helper scripts or structured references.

### 2. Repeatable task contract

You want users to say:

```text
在 repo-a 从 main 开分支修复登录 timeout
```

and have the system always turn that into the same internal workflow.

That is where you add:

- task contract docs
- branch generator helpers
- summary formatter helpers

### 3. Automatic Git workflow

You want:

- checkout base branch
- create task branch
- run Codex
- commit
- push
- optional PR

That is the point where custom scripts become worth it.

## Recommended Order After MVP

After the no-code MVP works, do this next:

1. add repo allowlist and branch policy
2. add workspace isolation rules
3. add a task contract document
4. add helper scripts only for repeated safe actions

## Practical Reading Order

Read these files in this order:

1. [implementation_blueprint.md]({baseDir}/references/implementation_blueprint.md)
2. [openclaw_minimax_codex_acp.md]({baseDir}/references/openclaw_minimax_codex_acp.md)
3. [openclaw_minimax_codex_acp.example.json5]({baseDir}/references/openclaw_minimax_codex_acp.example.json5)
4. this file

## If You Want Me To Continue

The next sensible implementation step is not another architecture note.

It is one of these:

1. write `task_contract.md`
2. write `repo_policy.md`
3. write the first helper script for branch naming and safe workspace selection
