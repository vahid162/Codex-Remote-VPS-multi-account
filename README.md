# Codex Remote VPS Multi-Account Skill

A reusable skill for managing and troubleshooting **Codex Desktop SSH Remote connections** across multiple VPS hosts and multiple ChatGPT/API authentication profiles.

The core rule of this project is simple:

> **Authentication switching and model selection are separate concerns.**

The auth manager may switch the active account, clear a stale model pin left by the previous account, and restart the Remote `app-server`. It must **not** assign `Sol`, `Terra`, or any other model to an account. Codex should discover the models allowed for the newly active account, and the user chooses the model from the Codex Desktop UI.

## What this skill covers

- Multiple VPS hosts used through Codex Desktop SSH Remote connections.
- Multiple ChatGPT profiles with independent credentials on every VPS.
- Optional API-key profiles.
- Central account switching from Windows through a master VPS.
- Safe handling of `~/.codex/auth.json` and per-profile snapshots.
- Clearing stale `model` / `model_reasoning_effort` settings only when the account actually changes.
- Restarting the Remote Codex `app-server` after an account change.
- Separating real backend errors from misleading UI messages such as `You've hit your usage limit`.
- Read-only diagnosis, backups, verification, and rollback.

## Repository layout

```text
codex-remote-vps-multi-account/
├── SKILL.md
└── references/
    └── runbook.md
```

`SKILL.md` contains the reusable agent workflow. `references/runbook.md` contains the detailed operational and troubleshooting procedures.

## Installation

Install or copy the `codex-remote-vps-multi-account` directory as a Codex/ChatGPT skill, or point your skill installer at this GitHub repository.

OpenAI describes a skill as a directory centered on a `SKILL.md` file, optionally with supporting resources. See:

- https://openai.com/academy/skills/
- https://help.openai.com/en/articles/20001066

## Safety

Never commit or paste any of the following into this repository, an issue, a chat, or a log:

- `auth.json`
- API keys
- access tokens
- refresh tokens
- device-login secrets
- private SSH keys

Only masked identifiers, hashes, status output, and non-secret configuration should be shared during troubleshooting.

## Validated scenario

This workflow was developed against a Windows Codex Desktop client using two Ubuntu VPS hosts. The important behavior is generic: Codex Desktop starts a Codex `app-server` on the remote host over SSH, and the remote host's active Codex credentials and configuration determine the Remote session state.

A successful baseline looks like:

```text
codex login status
Logged in using ChatGPT

codex exec --ephemeral --skip-git-repo-check 'Reply with exactly: VPS_DIRECT_OK'
...
VPS_DIRECT_OK
```

After an account change, the expected lifecycle is:

```text
switch auth
    -> clear stale model selection
    -> restart remote app-server
    -> reconnect Codex Desktop Remote
    -> Codex discovers models allowed for the new account
    -> user selects a model in the UI
```
