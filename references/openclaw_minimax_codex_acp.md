# OpenClaw MiniMax + Codex ACP Draft

## Goal

Use one OpenClaw deployment with this split:

- default conversation, routing, and light task parsing on `MiniMax`
- real coding work on `Codex` through `ACP`
- Feishu as the mobile entry and reply surface

This keeps the day-to-day chat path cheap and simple while preserving a stronger coding runtime when you actually need repository work.

## Recommended v1 Shape

Use [openclaw_minimax_codex_acp.example.json5]({baseDir}/references/openclaw_minimax_codex_acp.example.json5) as the base config.

The logic is:

1. All normal Feishu messages route to agent `main`
2. Agent `main` uses `minimax/MiniMax-M2.7`
3. When you want coding, you explicitly start a Codex ACP session
4. The bound DM or topic then talks directly to the Codex ACP session

This is safer than making every message run on Codex, and simpler than replacing Feishu routing with a custom webhook service.

## Why This Split Works

### `main` agent

Use `MiniMax` for:

- normal chat
- quick summaries
- deciding whether the request is analysis or coding
- lightweight instructions before entering coding mode

### `codex` agent

Use `ACP` + `Codex` for:

- repository edits
- branch work
- follow-up coding in the same conversation
- longer-running code tasks that need a persistent runtime

## Feishu Usage Model

### Normal chat

In Feishu DM or group, send ordinary messages:

```text
帮我看一下这个 repo 的训练入口
```

This goes to the `main` agent on `MiniMax`.

### Enter coding mode

In a Feishu DM or topic conversation, send:

```text
/acp spawn codex --thread here
```

What this does:

- OpenClaw starts a Codex ACP session
- the current DM or topic becomes bound to that session
- follow-up messages in that same DM or topic go to Codex directly

After that, you can send coding tasks such as:

```text
在 repo-a 里从 main 开一个分支修复登录 timeout，并把摘要回给我
```

### Check or stop the coding session

Useful commands:

```text
/acp status
/acp close
```

## Why I Prefer ACP Here

ACP is a better fit than `codex harness` for your target workflow because you want:

- explicit "now enter coding mode"
- a persistent coding session in the same Feishu conversation
- follow-up turns like "继续上一个任务"
- background-task style control and session ownership on OpenClaw

`codex harness` is better when you want the whole agent turn itself to be natively executed by Codex. That is a different shape: simpler for Codex-first deployments, less aligned with your "MiniMax for normal chat, Codex only for coding" split.

## What You Must Fill In

Before use, replace these placeholders in the example config:

- `MINIMAX_API_KEY`
- `cli_xxx_replace_me`
- `replace_me`
- `oc_replace_with_group_chat_id`
- `ou_replace_with_allowed_user_open_id`
- `/srv/openclaw/...` paths

## Suggested Server Paths

Use a structure like:

```text
/srv/openclaw/workspace/main
/srv/openclaw/workspaces/default
/srv/openclaw/workspaces/repo-a
/srv/openclaw/workspaces/repo-b
```

Then set `cwd` or `bindings[].acp.cwd` per repo-specific coding conversation.

## Safer v1 Operating Rules

Keep v1 narrow:

- default all ordinary Feishu messages to `MiniMax`
- only enter Codex by explicit `/acp spawn codex --thread here`
- prefer DMs first
- only allow specific Feishu groups or topics
- require `@mention` in groups
- keep ACP write permissions enabled, but only on a trusted host

## Setup Checklist

1. Configure MiniMax auth
   Run either `openclaw onboard --auth-choice minimax-global-api` or the matching regional option.

2. Configure Feishu channel
   Add the Feishu account, then verify the bot can receive DMs.

3. Enable ACP baseline
   Make sure `acp.enabled=true` and `plugins.entries.acpx.enabled=true`.

4. Check ACP runtime health
   Run `/acp doctor`.

5. Validate the config
   Run `openclaw config validate`.

6. Restart the gateway
   Run `openclaw gateway restart`.

7. Test in Feishu
   First send a normal DM.
   Then send `/acp spawn codex --thread here`.
   Then send a small coding task.

## Optional Later Upgrade

If you later want an entire agent to run natively on Codex instead of only using ACP for coding conversations, switch to `codex harness`.

That path is not the recommended v1 here because it makes Codex the primary execution brain for those agent turns, while your current design goal is:

- normal OpenClaw conversation on MiniMax
- coding only when explicitly escalated
