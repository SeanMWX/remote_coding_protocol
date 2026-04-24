# Deployment Notes

## Purpose

This file holds host-specific deployment guidance that should not live in `SKILL.md`.

Use it when the operator is actively deploying on a real server and needs environment-specific caveats.

## Bubblewrap

Codex sandboxing may depend on `bubblewrap` on Linux hosts.

Install it when missing:

```bash
sudo apt-get install -y bubblewrap
```

This is a host-preparation step, not a guarantee that sandboxing will work.

## Container And VM Limits

Some containerized or restricted VM hosts block unprivileged user namespace creation.

Typical symptom:

- Codex sandbox startup fails before normal command execution

Important distinction:

- `plugins.entries.acpx.config.permissionMode=approve-all` controls ACPX approval behavior
- it does **not** automatically prove that Codex vendor-side sandbox bypass is configured

Do not claim that ACPX approval settings alone solve Codex sandbox failures.

## Secrets

Prefer storing operator secrets in `~/.openclaw/.env`.

For this repo, the setup script writes values such as:

- `MINIMAX_API_KEY`
- `FEISHU_APP_SECRET`
- optional `GITHUB_TOKEN`

Do not write plaintext long-lived secrets into `~/.openclaw/openclaw.json`.

## Codex Credentials

OpenClaw can reuse Codex credentials already present on the host in `~/.codex/`.

Validate with:

```bash
codex login status
```

## Workspace Paths

If `/srv/openclaw` is not writable, use a home-directory state path such as:

```text
~/.openclaw/workspace
~/.openclaw/workspaces/remote-coding
```

## Recommended Feishu Flow

Default v1 behavior:

1. Feishu routes normal messages to `main`
2. `main` uses MiniMax
3. The operator explicitly enters coding mode with `/acp spawn codex --thread here`

Do not hard-bind a DM directly to Codex unless the operator explicitly asks for that workflow.

## Validation Commands

After setup:

```bash
openclaw config validate
openclaw gateway restart
openclaw gateway status
openclaw logs --follow
```

Useful ACP commands in Feishu:

```text
/acp doctor
/acp spawn codex --thread here
/acp status
/acp close
```
