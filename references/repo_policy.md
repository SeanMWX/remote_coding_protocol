# Repo Policy

## Purpose

This file defines the repository safety rules for the remote coding workflow.

Use it whenever the system is about to modify code, create branches, or push to GitHub.

## Allowed Repos

Use an explicit allowlist.

Do not let arbitrary Feishu input select an unrestricted filesystem path or random Git repository.

Recommended shape:

```text
repo-a -> /srv/repos/repo-a
repo-b -> /srv/repos/repo-b
repo-c -> /srv/repos/repo-c
```

If the operator has not defined the allowlist yet, stop and ask for it before enabling unattended modify tasks.

## Branch Rules

Never modify `main`, `master`, `dev`, or any long-lived shared branch directly.

For modify tasks, create one task branch per request.

Recommended naming:

```text
codex/fix-login-timeout
codex/refactor-config-loader
codex/add-health-check
```

Branch naming rules:

- lowercase only
- hyphen-separated summary
- one task per branch
- no branch reuse across unrelated requests

## Workspace Isolation

Use one isolated workspace per task or per repo-specific ACP session.

Recommended paths:

```text
~/.openclaw/workspaces/repo-a/task-20260424-001
~/.openclaw/workspaces/repo-a/task-20260424-002
```

Do not run two unrelated coding tasks in the same dirty workspace.

## GitHub Token Scope

Use the smallest token scope that still allows:

- clone or fetch
- push branch
- optional PR creation

Do not use an admin-scoped token for ordinary coding tasks.

If the token is only needed by helper scripts, keep it in `~/.openclaw/.env`, not in `openclaw.json`.

## Test Command Policy

Allow only predefined test commands.

Examples:

- `pytest`
- `pytest tests/test_auth.py`
- `npm test -- login`
- `pnpm test`

Do not expose arbitrary shell execution through chat.

## Commit Policy

Use explicit commit messages for machine-made changes.

Recommended format:

```text
codex: fix login timeout
codex: add config loader tests
```

## Local Validation Boundary

The remote system is responsible for:

- analysis
- branch creation
- code changes
- minimal validation
- push

The local developer remains responsible for:

- full test suites
- risky migrations
- manual review
- final merge
