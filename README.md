# remote_coding_protocol

This repository is the root of an OpenClaw skill project for remote coding with Feishu/Lark, MiniMax, Codex, and GitHub.

## What It Does

The intended v1 flow is:

1. Feishu messages enter through the OpenClaw Feishu channel
2. normal chat routes to the `main` agent on MiniMax
3. coding work escalates explicitly with `/acp spawn codex --thread here`
4. Codex runs through OpenClaw ACP in an isolated workspace
5. GitHub stays the sync boundary and the local machine keeps final review and merge

## Automated Install

The main installer is:

- [scripts/setup.sh](scripts/setup.sh)

Run it on the OpenClaw host:

```bash
bash ~/.openclaw/skills/remote_coding_protocol/scripts/setup.sh
```

What it does:

- checks `openclaw`, `codex`, and `python3`
- verifies `codex login status`
- stores operator secrets in `~/.openclaw/.env`
- incrementally configures MiniMax, Feishu, ACP, and the `codex` agent
- validates config and restarts the gateway

What it does not do:

- install OpenClaw itself
- install Codex itself
- force vendor-side sandbox bypass flags for restricted container hosts

## Key Files

Runtime-facing files:

- [SKILL.md](SKILL.md)
- [scripts/setup.sh](scripts/setup.sh)
- [references/implementation_blueprint.md](references/implementation_blueprint.md)
- [references/openclaw_minimax_codex_acp.md](references/openclaw_minimax_codex_acp.md)
- [references/openclaw_minimax_codex_acp.example.json5](references/openclaw_minimax_codex_acp.example.json5)
- [references/quick_start.md](references/quick_start.md)
- [references/deployment_notes.md](references/deployment_notes.md)
- [references/repo_policy.md](references/repo_policy.md)
- [references/task_contract.md](references/task_contract.md)

Repo-local planning and maintenance files:

- [openclaw_codex_feishu_design.md](openclaw_codex_feishu_design.md)
- `.gitignore`
- `LICENSE`

## Validation

After install, the basic validation flow is:

1. send a normal Feishu message to confirm `main` is alive
2. run `/acp doctor`
3. run `/acp spawn codex --thread here`
4. send a small coding or analysis request in that bound conversation

## Notes

- `skill_creator/` is treated as an external local reference and is ignored by git.
- The recommended v1 path is OpenClaw Feishu channel + Codex ACP, not a custom webhook-first service.
- Secrets should live in the host `~/.openclaw/.env`, not in repo files or checked-in config.
