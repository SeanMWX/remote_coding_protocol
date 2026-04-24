---
name: remote_coding_protocol
description: Build and operate an OpenClaw-based remote coding workflow with Feishu/Lark, Codex, and GitHub. Use when implementing or refining a 云端编程 + 手机飞书发消息 + Git 分支同步 + 结果回传 system for branch-isolated coding on a remote host.
---

# Remote Coding Protocol

Treat this repo root as the skill root. Keep runtime-facing material in `SKILL.md`, `references/`, and later `scripts/`. Treat `README.md`, `.gitignore`, and `openclaw_codex_feishu_design.md` as repo-local maintenance or planning docs, not the runtime contract.

## 🚀 Quick Start / Installation

When the user says something like:
- "帮我初始化 remote_coding_protocol"
- "remote_coding_protocol install"
- "remote_coding_protocol setup"
- "启动 remote_coding_protocol"
- "remote coding protocol 初始化"

Run the setup script:
```bash
bash ~/.openclaw/skills/remote_coding_protocol/scripts/setup.sh
```

The setup script will:
1. Check and install `bubblewrap` if needed
2. Verify Codex is logged in (if not, prompt user to run `codex login`)
3. Ask for GitHub Token if not already configured
4. Generate and write `openclaw.json` with ACP + Codex configuration
5. Validate and restart the Gateway

**Note**: This script only runs when explicitly requested. It will NOT run automatically on startup or when just mentioned casually.

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

---

## 🧪 Practical Deployment Notes (Tested)

This section documents issues discovered and solutions found during actual deployment on an Ubuntu server in a container/VM environment.

### 1. bubblewrap Installation

Codex CLI's sandbox requires `bubblewrap` to create user namespaces. Install it first:

```bash
sudo apt-get install -y bubblewrap
```

**Without bubblewrap**, Codex will fail with:
- `bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted`
- Commands fail even for basic `ls` or file creation

### 2. Sandbox Limitation in Container/VM Environments

**Problem**: Even with bubblewrap installed, container/VM environments often restrict user namespace creation, causing Codex sandbox to fail.

**Symptom**: Codex exits immediately with sandbox errors for all commands.

**Solution**: Use `--dangerously-bypass-approvals-and-sandbox` flag to skip sandboxing.

In `openclaw.json`, configure the acpx plugin with:
```json
"plugins": {
  "entries": {
    "acpx": {
      "enabled": true,
      "config": {
        "permissionMode": "approve-all",
        "nonInteractivePermissions": "fail"
      }
    }
  }
}
```

This makes Codex run without sandbox in ACP sessions. **Only use on trusted servers.**

### 3. Codex Credentials Auto-Sync

OpenClaw automatically syncs Codex credentials from `~/.codex/auth.json`. No additional configuration needed.

To verify Codex is logged in:
```bash
codex login status
```

The auth file contains `auth_mode` (e.g., "chatgpt" for ChatGPT Pro) and token information.

### 4. Workspace Path Note

**Do NOT use `/srv/openclaw`** if you don't have permission. Use the user's home directory instead:

```
/home/{user}/.openclaw/workspaces/
```

In the working deployment:
```json
"agents": {
  "list": [
    {
      "id": "codex",
      "workspace": "/home/{user}/.openclaw/workspaces/codex-test",
      "runtime": {
        "type": "acp",
        "acp": {
          "agent": "codex",
          "backend": "acpx",
          "mode": "persistent",
          "cwd": "/home/{user}/.openclaw/workspaces/codex-test"
        }
      }
    }
  ]
}
```

### 5. Working openclaw.json Template

```json
{
  "env": {
    "GITHUB_TOKEN": "ghp_xxxxxxxxxxxx"
  },
  "acp": {
    "enabled": true,
    "dispatch": { "enabled": true },
    "backend": "acpx",
    "defaultAgent": "codex",
    "allowedAgents": ["codex"]
  },
  "agents": {
    "defaults": {
      "workspace": "/home/{user}/.openclaw/workspace"
    },
    "list": [
      {
        "id": "main",
        "default": true,
        "name": "Feishu Main",
        "workspace": "/home/{user}/.openclaw/workspace",
        "model": { "primary": "minimax/MiniMax-M2.7" }
      },
      {
        "id": "codex",
        "name": "Codex Worker",
        "workspace": "/home/{user}/.openclaw/workspaces/codex-test",
        "model": { "primary": "minimax/MiniMax-M2.7" },
        "runtime": {
          "type": "acp",
          "acp": {
            "agent": "codex",
            "backend": "acpx",
            "mode": "persistent",
            "cwd": "/home/{user}/.openclaw/workspaces/codex-test"
          }
        }
      }
    ]
  },
  "bindings": [
    {
      "type": "route",
      "agentId": "main",
      "match": { "channel": "feishu", "accountId": "main" }
    },
    {
      "type": "acp",
      "agentId": "codex",
      "match": {
        "channel": "feishu",
        "accountId": "main",
        "peer": { "kind": "direct", "id": "ou_{feishu_user_id}" }
      },
      "acp": {
        "label": "codex-feishu-dm",
        "cwd": "/home/{user}/.openclaw/workspaces/codex-test"
      }
    }
  ],
  "plugins": {
    "entries": {
      "feishu": { "enabled": true, "config": {} },
      "acpx": {
        "enabled": true,
        "config": {
          "permissionMode": "approve-all",
          "nonInteractivePermissions": "fail"
        }
      }
    }
  }
}
```

### 6. Validation Commands

After configuration, validate and restart:

```bash
openclaw config validate   # Must show: Config valid
openclaw gateway restart   # Restart to load new config
openclaw gateway status    # Verify running
```

Check logs for:
- `acpx runtime backend ready` ✅
- `synced openai-codex credentials from external cli` ✅

### 7. ACP Session Management

ACP sessions are stored in:
```
~/.openclaw/agents/codex/sessions/sessions.json
```

| Command | Description |
|---------|-------------|
| `/acp spawn codex` | Start a new Codex ACP session |
| `/acp spawn codex --thread here` | Rebind current DM to a new session |
| `/acp status` | Check current session (must be in ACP session first) |
| `/acp close` | Close current ACP session |

**To clear stale sessions**: Edit `~/.openclaw/agents/codex/sessions/sessions.json` and remove old entries, then restart gateway.

### 8. Testing Codex Manually

Before using via ACP, test Codex CLI directly:

```bash
cd /home/{user}/.openclaw/workspaces/codex-test
codex exec --dangerously-bypass-approvals-and-sandbox "创建 fib.py，实现斐波那契函数"
```

If successful, ACP should work the same way.
