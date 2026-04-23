# remote_coding_protocol

This repository is the root of an OpenClaw skill project for remote coding with Feishu/Lark, Codex, and GitHub.

Current runtime-facing files:

- `SKILL.md`
- `references/implementation_blueprint.md`
- `references/openclaw_minimax_codex_acp.md`
- `references/openclaw_minimax_codex_acp.example.json5`
- `references/quick_start.md`

Repo-local planning and maintenance files:

- `openclaw_codex_feishu_design.md`
- `.gitignore`
- `LICENSE`

Notes:

- `skill_creator/` is treated as an external local reference and is ignored by git.
- The recommended v1 path is OpenClaw Feishu channel + Codex ACP or Codex harness, not a custom webhook-first service.
