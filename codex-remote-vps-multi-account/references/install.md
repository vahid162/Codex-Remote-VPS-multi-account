# Installation and Deployment

This guide installs the reusable multi-VPS auth manager from a clean system.

The deployment has three layers:

```text
Windows helper
    -> master VPS: codex-auth
        -> master VPS: codex-auth-local
        -> remote VPS(s): codex-auth-local
```

The manager switches authentication only. On a real account change it clears the previous account's saved `model` and `model_reasoning_effort`, restarts the Remote Codex app-server, and lets Codex Desktop rediscover the models available to the new account. It never maps an account to a model.

## Prerequisites

On every Linux VPS:

- a normal non-root user for Codex Remote work,
- Codex CLI installed and reachable as `codex`,
- Python 3,
- OpenSSH client,
- a working independent Codex login for the first profile.

On Windows:

- Codex Desktop,
- OpenSSH client (`ssh.exe`),
- PowerShell,
- SSH aliases for the master VPS and any VPS opened directly from Codex Desktop.

Do not disable SSH host-key checking to make setup easier.

## 1. Install the local helper on every VPS

Clone this repository on each VPS or copy the `codex-remote-vps-multi-account/scripts` directory to it.

If the VPS is already logged into the first ChatGPT account and you want to preserve it as `chatgpt-current`:

```bash
cd Codex-Remote-VPS-multi-account/codex-remote-vps-multi-account
bash scripts/install-node.sh --initial-profile chatgpt-current
```

This creates:

```text
~/.codex-auth/profiles/chatgpt-current/auth.json
~/.codex-auth-manager/active-profile
~/.codex-auth-manager/bin/codex-auth-local
```

Run this independently on every VPS. Do not copy one VPS's ChatGPT `auth.json` to another VPS.

If you do not want to snapshot the current live credential yet:

```bash
bash scripts/install-node.sh
```

## 2. Configure master-to-remote SSH

Choose one VPS as the auth master. From that VPS, each remote VPS must be reachable using an SSH alias without interactive password entry.

Example master `~/.ssh/config`:

```sshconfig
Host vps-two
    HostName 203.0.113.20
    User codexops
    Port 60030
    IdentityFile ~/.ssh/codex_auth_master_ed25519
    IdentitiesOnly yes
    StrictHostKeyChecking yes
```

Verify before installing the central manager:

```bash
ssh -o BatchMode=yes vps-two 'hostname; whoami'
```

The host key must already be verified in `known_hosts`.

## 3. Install the central manager on the master VPS

On the chosen master VPS:

```bash
cd Codex-Remote-VPS-multi-account/codex-remote-vps-multi-account
bash scripts/install-master.sh \
  --remote vps-two
```

For more remotes, repeat `--remote`:

```bash
bash scripts/install-master.sh \
  --remote vps-two \
  --remote vps-three
```

If the master has not yet been installed as a node and its current live auth should become the initial profile:

```bash
bash scripts/install-master.sh \
  --initial-profile chatgpt-current \
  --remote vps-two
```

Remote aliases are stored in:

```text
~/.codex-auth-manager/hosts
```

The master itself is not listed there; it is handled locally.

Check the deployment:

```bash
~/.codex-auth-manager/bin/codex-auth status
~/.codex-auth-manager/bin/codex-auth list
```

## 4. Install the Windows helper

Clone the repository on Windows, then from PowerShell:

```powershell
cd .\Codex-Remote-VPS-multi-account\codex-remote-vps-multi-account\windows
.\install-windows.ps1 -MasterAlias webmaster
```

`webmaster` in this example is the Windows SSH alias that connects to the master VPS.

The installer creates, by default:

```text
$HOME\bin\codex-auth.ps1
$HOME\bin\codex-auth.cmd
$HOME\bin\codex-auth.config.json
```

It also adds `$HOME\bin` to the user PATH unless `-SkipPathUpdate` is specified.

Open a new PowerShell window and test:

```powershell
codex-auth status
codex-auth list
```

## 5. Add another ChatGPT account

From Windows:

```powershell
codex-auth add-chatgpt chatgpt-account2
```

The workflow performs a separate device login on the master and every remote VPS. Complete each device flow with the intended ChatGPT account.

The same logical profile name should correspond to the same intended account on every VPS, but each VPS keeps its own independently issued/refreshable credential.

## 6. Switch accounts

```powershell
codex-auth use chatgpt-current
```

or:

```powershell
codex-auth use chatgpt-account2
```

On a real profile change the helper performs this lifecycle on every VPS:

```text
save refreshed credential for old profile
    -> install target auth.json atomically
    -> clear stale model + model_reasoning_effort
    -> update active-profile
    -> terminate current user's Codex app-server
    -> Codex Desktop reconnects
    -> user chooses any model available in the UI
```

Selecting the already-active profile does not clear the current model selection or restart the app-server.

## 7. API-key profiles

The local helper includes `create-api` for controlled per-VPS provisioning, but the central Windows workflow intentionally does not fan out an API secret automatically in this version.

Before installing an API key into profiles, validate that the key itself works against the OpenAI API. A 401 `invalid_api_key` is a credential problem, not a Remote Codex usage-limit problem.

Provision API credentials independently and securely on each VPS under the same logical profile name, then `codex-auth use PROFILE` can switch to it like any other profile.

Never put API keys in command history, repository files, issue text, or chat messages.

## 8. Verification

After a switch:

```powershell
codex-auth status
```

Then reconnect each Remote project in Codex Desktop and verify the model selector reflects the active account.

For direct remote verification:

```bash
codex login status
codex exec --ephemeral --skip-git-repo-check \
  'Reply with exactly: VPS_DIRECT_OK'
```

For Desktop Remote verification, create a new chat and request:

```text
Reply exactly with: DESKTOP_REMOTE_OK
```

## 9. Rollback

The installers do not overwrite profile secrets from another host. Before manual edits to manager scripts, create a timestamped backup.

If a new helper version causes trouble:

1. restore the last known-good `codex-auth-local` or `codex-auth`,
2. run `bash -n` on the restored script,
3. confirm `codex login status`,
4. confirm `active-profile`,
5. restart the user's Codex Remote app-server,
6. reconnect and run direct + Desktop tests.

Do not delete working profile credentials as the first rollback step.
