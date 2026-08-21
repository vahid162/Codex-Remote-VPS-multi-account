---
name: codex-remote-vps-multi-account
description: Manage and troubleshoot Codex Desktop SSH Remote connections across multiple VPS hosts and multiple ChatGPT/API auth profiles. Use when switching remote Codex accounts, diagnosing misleading usage-limit errors, clearing stale model selections after account changes, refreshing remote app-server processes, or validating that each VPS is using the intended credential without forcing a model.
---

# Codex Remote VPS Multi-Account

Use this skill for a Windows Codex Desktop setup that connects to one or more Linux VPS hosts over SSH and needs fast switching between multiple ChatGPT or API authentication profiles.

## Core principle

Keep **authentication selection** and **model selection** separate.

The auth manager may:

1. save the current live credential back to its profile,
2. install the target profile credential into the live Codex home,
3. update the active-profile marker,
4. remove a model selection that belonged to the previous account,
5. restart the Remote Codex `app-server` so the new account state is loaded.

The auth manager must **never map an account to a specific model**.

Do not encode rules such as:

```text
account A -> Sol
account B -> Terra
```

The correct behavior is:

```text
switch account
    -> clear stale model pin
    -> refresh remote app-server
    -> Codex discovers models allowed for the new account
    -> user selects any available model in the Codex Desktop UI
```

## Safety rules

Treat these as secrets and never ask the user to paste them into chat, logs, issues, or commits:

- `auth.json`
- access tokens
- refresh tokens
- API keys
- device-login secrets
- private SSH keys

When inspecting auth state, print only non-secret metadata such as:

- `AUTH_MODE=chatgpt` or `AUTH_MODE=apikey`
- whether a refresh token exists
- a masked API-key suffix if Codex itself prints one
- hashes/fingerprints derived from non-secret identity claims when necessary

Do not copy one live ChatGPT `auth.json` from one concurrently active VPS to another. Each VPS should obtain and maintain its own ChatGPT login state so refresh-token rotation remains independent.

For configuration changes, use backup + syntax/preflight + atomic replacement where possible.

## Expected architecture

A typical deployment is:

```text
Windows Codex Desktop
        |
        | SSH
        v
Master VPS ---------------------> Other VPS hosts
  |                                  |
  | ~/.codex/auth.json               | ~/.codex/auth.json
  | ~/.codex/config.toml             | ~/.codex/config.toml
  | ~/.codex-auth/profiles/*         | ~/.codex-auth/profiles/*
  | ~/.codex-auth-manager/*          | ~/.codex-auth-manager/*
  | Codex app-server                 | Codex app-server
```

The Windows helper talks to the master VPS. The master invokes a local helper on itself and over SSH on the other VPS hosts.

A portable profile layout is:

```text
~/.codex-auth/profiles/
├── chatgpt-current/
│   └── auth.json
├── chatgpt-account2/
│   └── auth.json
└── api-main/
    └── auth.json
```

The live credential remains:

```text
~/.codex/auth.json
```

The active profile marker is typically:

```text
~/.codex-auth-manager/active-profile
```

## Workflow

### 1. Start with read-only inspection

Before changing anything, establish:

- SSH host aliases and connectivity,
- remote `whoami` and `$HOME`,
- `codex --version`,
- `codex login status`,
- current active profile,
- current model-related lines in `~/.codex/config.toml`,
- running Codex Remote `app-server` processes.

Prefer Base64-wrapped scripts when PowerShell -> SSH -> Bash quoting becomes complex.

A useful read-only remote check is:

```bash
hostname
codex --version
codex login status
cat "$HOME/.codex-auth-manager/active-profile" 2>/dev/null || true
grep -nE '^[[:space:]]*(model|model_reasoning_effort|model_provider)[[:space:]]*=' \
  "$HOME/.codex/config.toml" 2>/dev/null || echo NO_FORCED_MODEL
pgrep -a -u "$(id -u)" -f '[c]odex.*app-server' || echo NO_APP_SERVER
```

### 2. Validate the target auth profile before switching

Confirm the target profile exists on every VPS and inspect only safe metadata.

For ChatGPT profiles, require:

- `auth_mode == chatgpt`
- token structure present
- refresh token present when expected

For API profiles, require:

- `auth_mode == apikey`
- an API-key field present

Do not expose the secret value.

### 3. Switch credentials atomically

The local switch routine should follow this order:

1. Read the current active profile.
2. If the target is already active, save the live credential back to that profile and exit without clearing the user's current model selection.
3. If changing profiles, save the live credential into the current profile first.
4. Copy the target profile credential to a temporary file under `~/.codex/` with mode `600`.
5. Atomically rename the temporary file to `~/.codex/auth.json`.
6. Remove stale account-specific model selection from `~/.codex/config.toml`:
   - `model = ...`
   - `model_reasoning_effort = ...`
7. Update `active-profile` with mode `600`.
8. Restart the user's Codex Remote `app-server` processes.
9. Print `codex login status`.

Important: only clear model selection when the account actually changes. If the user re-selects the already-active profile, preserve the model they selected in the UI.

A safe model-clear operation is:

```bash
CFG="$HOME/.codex/config.toml"
if [ -f "$CFG" ]; then
  sed -i \
    -e '/^[[:space:]]*model[[:space:]]*=/d' \
    -e '/^[[:space:]]*model_reasoning_effort[[:space:]]*=/d' \
    "$CFG"
fi
```

Restart only the current user's Remote Codex app-server processes:

```bash
pkill -TERM -u "$(id -u)" -f '[c]odex.*app-server' 2>/dev/null || true
```

Expect Codex Desktop Remote sessions to disconnect briefly and require reconnect.

### 4. Let Codex discover model entitlement

After reconnecting the Remote project, do not write a model into `config.toml` on behalf of the user.

Open the Codex Desktop model selector and let Codex show the models available to the newly active account. The user chooses the desired model there.

If the account exposes a stronger model, it should appear naturally. If the account only exposes a smaller set, do not attempt to bypass that entitlement by forcing another model ID.

### 5. Validate the remote data path

Test both layers:

#### Direct VPS CLI

```bash
codex exec --ephemeral --skip-git-repo-check \
  'Reply with exactly: VPS_DIRECT_OK'
```

A successful result proves the remote credential, backend access, and CLI path are functional.

#### Codex Desktop Remote

Open a new Remote chat for each VPS and request an exact marker such as:

```text
Reply exactly with: DESKTOP_REMOTE_OK
```

A successful response proves the Desktop -> SSH -> remote app-server -> OpenAI path is functional.

## Troubleshooting decision tree

### UI says `You've hit your usage limit`

Do not assume the message identifies the true backend cause.

Run a direct remote CLI request and classify the actual error.

### Direct CLI returns `model is not supported when using Codex with a ChatGPT account`

Check `~/.codex/config.toml` for a model pinned by a previous account.

If the account was recently switched:

1. clear `model` and `model_reasoning_effort`,
2. restart the Remote app-server,
3. reconnect Desktop,
4. choose a model from the UI.

Do not hard-code a replacement model in the auth manager.

### Direct CLI works but Codex Desktop Remote fails

Treat this as a Remote app-server/session problem.

Inspect:

```bash
pgrep -a -u "$(id -u)" -f '[c]odex.*app-server'
```

Then, with Desktop closed when practical, restart the app-server and reconnect.

### API profile returns HTTP 401 / `invalid_api_key`

This is an API credential problem, not a ChatGPT usage-limit problem.

Do not modify VPS routing or model selection to compensate. Validate the key independently against the OpenAI API without exposing it. Replace the API profile only after a valid key is confirmed.

### ChatGPT profile works in a temporary `CODEX_HOME` but not in normal Remote mode

Compare the normal `~/.codex/config.toml` and running app-server state. A temporary profile may succeed because it bypasses a stale model pin in the normal Codex home.

### Account identity is uncertain

When necessary, compare privacy-preserving fingerprints derived from non-secret identity claims in the token rather than printing account IDs or JWTs. The purpose is only to verify that two profiles are distinct and that the same named profile corresponds to the same intended identity on multiple VPS hosts.

## Backups and rollback

Before patching auth-manager code, save a timestamped copy and run a syntax check before replacing the live script.

Example pattern:

```bash
FILE="$HOME/.codex-auth-manager/bin/codex-auth-local"
STAMP="$(date +%Y%m%d-%H%M%S)"
cp -a "$FILE" "$FILE.bak-$STAMP"
```

For shell scripts:

```bash
bash -n candidate-script
```

If a patch causes problems, restore the most recent known-good backup, verify the hash/syntax, and restart the Remote app-server.

## Success criteria

Consider the workflow complete only when all of the following are true:

- the requested profile is active on every intended VPS,
- `codex login status` reports the expected auth mode,
- no model from the previous account is forced after an actual account switch,
- Codex Desktop Remote reconnects successfully,
- the model selector reflects the newly active account's available models,
- the user can choose a model in the UI,
- a direct VPS `codex exec` request succeeds,
- a Codex Desktop Remote request succeeds.

## Interaction style

For risky or state-changing operations:

1. explain the current hypothesis briefly,
2. run read-only checks first,
3. show the expected result,
4. make one controlled change at a time,
5. verify immediately,
6. keep a rollback path.

Do not keep changing unrelated layers once the failing layer has been isolated.

For detailed commands and the validated failure modes, read `references/runbook.md`.
