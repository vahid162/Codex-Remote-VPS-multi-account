# Runbook: Codex Desktop Remote VPS Multi-Account Authentication

This runbook documents the validated operating model behind the skill. Use it when the short workflow in `SKILL.md` is not enough.

## 1. Problem statement

Codex Desktop can open projects on Linux VPS hosts over SSH. The Desktop client starts a Codex `app-server` on the remote host. If multiple ChatGPT accounts or API credentials are used, the remote host can accidentally retain state from the previous account.

The most important failure observed in this scenario was:

1. Account A selected a model in Codex Desktop.
2. The selected model was written to `~/.codex/config.toml` on the VPS.
3. Authentication was switched to Account B.
4. Account B did not have access to the model left by Account A.
5. The Remote session failed even though Account B's authentication itself was valid.

The durable solution is **not** to assign a fixed model to every account. The solution is to clear stale model selection on a real account change and let Codex rediscover the new account's model entitlement.

## 2. Separation of responsibilities

### Auth manager

Responsible for:

- profile existence and validation,
- credential switching,
- preserving refreshed credentials,
- active-profile tracking,
- clearing stale account-specific model selection after a real profile change,
- restarting the Remote app-server after a real profile change.

Not responsible for:

- deciding which model the account should use,
- mapping account names to Sol/Terra/other models,
- bypassing account/model entitlement.

### Codex Desktop

Responsible for:

- reconnecting to the Remote app-server,
- showing models available to the active account,
- letting the user select a model and reasoning level.

### VPS

Responsible for:

- holding its own live Codex auth state,
- holding its own per-profile auth snapshots,
- running the Remote Codex app-server.

## 3. Recommended paths

```text
~/.codex/
├── auth.json
└── config.toml

~/.codex-auth/
└── profiles/
    ├── chatgpt-current/
    │   └── auth.json
    ├── chatgpt-account2/
    │   └── auth.json
    └── api-main/
        └── auth.json

~/.codex-auth-manager/
├── active-profile
├── hosts
└── bin/
    ├── codex-auth
    └── codex-auth-local
```

Recommended permissions:

```text
~/.codex                         700
~/.codex/auth.json               600
~/.codex-auth                    700
profile directories              700
profile auth.json                600
~/.codex-auth-manager            700
active-profile                   600
hosts                            600
```

Never store secrets in the repository.

## 4. Windows SSH layer

Example SSH config:

```sshconfig
Host vps-one
    HostName example-one.invalid
    User codexops
    Port 60030
    IdentityFile C:/Users/USER/.ssh/codex_vps_one
    IdentitiesOnly yes
    StrictHostKeyChecking yes

Host vps-two
    HostName example-two.invalid
    User codexops
    Port 60030
    IdentityFile C:/Users/USER/.ssh/codex_vps_two
    IdentitiesOnly yes
    StrictHostKeyChecking yes
```

Keep host-key verification enabled. Do not solve connectivity problems by disabling `StrictHostKeyChecking` globally.

## 5. Prefer Base64 for PowerShell -> SSH -> Bash scripts

Complex quoting with PowerShell, SSH, Bash, regexes, and nested quotes is error-prone. Use this transport pattern:

```powershell
$HostsList = @("vps-one", "vps-two")

$RemoteScript = @'
echo "=== HOST ==="
hostname
codex login status
'@

$RemoteScript = $RemoteScript -replace "`r", ""
$B64 = [Convert]::ToBase64String(
    [Text.Encoding]::UTF8.GetBytes($RemoteScript)
)

foreach ($HostName in $HostsList) {
    Write-Host "`n=== $HostName ==="
    ssh $HostName "echo '$B64' | base64 -d | bash"
}
```

Use this pattern whenever shell regexes or quoted prompts start breaking through nested SSH quoting.

## 6. Read-only baseline

Run before modifying auth or config:

```bash
echo "=== HOST ==="
hostname

echo "=== VERSION ==="
codex --version

echo "=== LOGIN ==="
codex login status

echo "=== ACTIVE PROFILE ==="
cat "$HOME/.codex-auth-manager/active-profile" 2>/dev/null || echo UNKNOWN

echo "=== MODEL CONFIG ==="
grep -nE '^[[:space:]]*(model|model_reasoning_effort|model_provider)[[:space:]]*=' \
  "$HOME/.codex/config.toml" 2>/dev/null || echo NO_FORCED_MODEL

echo "=== APP SERVER ==="
pgrep -a -u "$(id -u)" -f '[c]odex.*app-server' || echo NO_APP_SERVER
```

Typical Desktop Remote process:

```text
codex -c features.code_mode_host=true app-server --listen unix://
```

Do not kill processes during baseline inspection.

## 7. Creating a ChatGPT profile on a headless VPS

Use device auth with an isolated temporary `CODEX_HOME` so the active Remote credential is not replaced during profile creation.

Conceptual sequence:

```bash
TEMP="$HOME/.codex-auth/profiles/.PROFILE.new.$$"
mkdir -p "$TEMP"
chmod 700 "$TEMP"
printf '%s\n' 'cli_auth_credentials_store = "file"' > "$TEMP/config.toml"
chmod 600 "$TEMP/config.toml"

CODEX_HOME="$TEMP" codex login --device-auth
```

After the browser/device-code flow succeeds:

1. verify `auth.json` exists,
2. verify safe metadata says `auth_mode=chatgpt`,
3. verify the expected token structure/refresh token exists,
4. set `auth.json` mode to `600`,
5. atomically rename the temporary profile directory to the final profile name.

Do not share the device code after it has been used. Never share the resulting `auth.json`.

For multiple VPS hosts, perform an independent login on each VPS for the same logical profile name.

## 8. Local profile switch semantics

The validated switch routine uses these variables conceptually:

```bash
BASE="$HOME/.codex-auth-manager"
PROFILES="$HOME/.codex-auth/profiles"
ACTIVE="$BASE/active-profile"
AUTH="$HOME/.codex/auth.json"
```

### If target profile is already active

Do this:

```text
save live auth.json back into current profile
report ALREADY_ACTIVE
print codex login status
exit
```

Do **not** clear model selection and do **not** restart app-server merely because the user repeated the same profile selection. The user's current model choice should remain intact.

### If target profile is different

Perform this order:

```text
1. validate target profile
2. save current live auth.json to current profile
3. install target auth.json to ~/.codex/auth.json atomically
4. clear stale model/model_reasoning_effort from ~/.codex/config.toml
5. update active-profile
6. restart current user's Codex app-server
7. print codex login status
```

Atomic credential replacement pattern:

```bash
TMP="$HOME/.codex/auth.json.new"
install -m 600 "$TARGET" "$TMP"
mv -f "$TMP" "$HOME/.codex/auth.json"
```

## 9. Clearing stale model state

Only on a real account change:

```bash
CFG="$HOME/.codex/config.toml"

if [ -f "$CFG" ]; then
    sed -i \
      -e '/^[[:space:]]*model[[:space:]]*=/d' \
      -e '/^[[:space:]]*model_reasoning_effort[[:space:]]*=/d' \
      "$CFG"
fi
```

This is intentionally different from assigning a model.

Correct:

```text
old account model pin -> removed
new account -> Codex discovers entitlement
user -> selects model in UI
```

Incorrect:

```text
if profile=main then model=Sol
if profile=secondary then model=Terra
```

Account capabilities can change over time. The auth manager should not encode entitlement policy.

## 10. Refreshing the Remote app-server

On a real profile change:

```bash
pkill -TERM -u "$(id -u)" -f '[c]odex.*app-server' 2>/dev/null || true
```

Notes:

- target only processes owned by the current remote user,
- expect the Desktop Remote connection to drop briefly,
- reconnect the Remote project after the switch,
- do not use `pkill -9` unless normal termination has failed and you have verified the target process.

## 11. Direct CLI test

This is the primary truth source when the Desktop UI reports a vague error.

```bash
codex login status
codex exec --ephemeral --skip-git-repo-check \
  'Reply with exactly: VPS_DIRECT_OK'
```

Successful example:

```text
Logged in using ChatGPT
...
VPS_DIRECT_OK
```

The exact model shown may differ by account, rollout, Codex version, and UI selection. Do not build the workflow around a specific model name.

## 12. Desktop Remote test

After reconnecting to each VPS in Codex Desktop, create a new chat and request a deterministic marker:

```text
Reply exactly with: DESKTOP_REMOTE_OK
```

If direct CLI and Desktop Remote both succeed, the complete path is functional.

## 13. Error classification

### A. Desktop says usage limit, direct CLI succeeds

Likely layer:

```text
Desktop Remote app-server/session/cache
```

Actions:

1. inspect app-server processes,
2. ensure auth/profile on VPS is correct,
3. restart app-server,
4. reconnect Remote,
5. start a new chat.

### B. Direct CLI says model unsupported for ChatGPT account

Likely layer:

```text
stale model selection in ~/.codex/config.toml
```

Actions:

1. verify active profile,
2. remove `model` and `model_reasoning_effort`,
3. restart app-server,
4. reconnect,
5. choose a model from UI.

Do not substitute a guessed model ID from API documentation.

### C. Direct API profile request returns 401 `invalid_api_key`

Likely layer:

```text
API key invalid/revoked/wrong credential
```

This is not a ChatGPT plan-limit issue.

Validate the new secret against the API independently before installing it into remote profiles. Never paste the secret into chat.

### D. `codex login status` is correct, but model list looks like the previous account

Likely layer:

```text
model pin or stale app-server entitlement state
```

Check:

```bash
grep -nE '^[[:space:]]*(model|model_reasoning_effort)[[:space:]]*=' \
  "$HOME/.codex/config.toml" 2>/dev/null || echo NO_FORCED_MODEL
```

If an actual account change just occurred, clear the stale selection and restart app-server.

### E. Temporary profile works but normal Codex home fails

Compare:

```text
TEMP CODEX_HOME config
vs
~/.codex/config.toml
```

A temporary profile can succeed because it does not inherit a stale model selection from the normal Remote environment.

## 14. Privacy-preserving identity verification

When two ChatGPT profile names may accidentally contain the same account, do not print raw JWTs or account IDs.

A safe diagnostic may:

1. decode only the JWT payload locally,
2. collect stable non-secret identity claim values,
3. hash them,
4. print only a short fingerprint.

Use this only to answer questions such as:

```text
Is chatgpt-current different from chatgpt-account2?
Is chatgpt-account2 the same intended identity on both VPS hosts?
```

Do not persist the decoded token body.

## 15. Backup and patch discipline

Before editing manager scripts:

```bash
FILE="$HOME/.codex-auth-manager/bin/codex-auth-local"
STAMP="$(date +%Y%m%d-%H%M%S)"
cp -a "$FILE" "$FILE.bak-$STAMP"
```

Generate the replacement separately, then:

```bash
bash -n "$NEW"
```

Only after syntax succeeds:

```bash
mv -f "$NEW" "$FILE"
chmod 700 "$FILE"
```

When the same helper is deployed to multiple VPS hosts, compare SHA-256 hashes:

```bash
sha256sum "$HOME/.codex-auth-manager/bin/codex-auth-local"
```

Matching hashes are a useful deployment consistency check.

## 16. Rollback

If profile switching becomes unreliable:

1. stop making additional unrelated changes,
2. identify the last known-good backup,
3. restore the manager script,
4. run `bash -n`,
5. verify `codex login status`,
6. verify the active-profile marker,
7. clear stale model selection only if it belongs to another account,
8. restart app-server,
9. reconnect and run direct + Desktop tests.

Do not delete profile credentials as a first-line rollback action.

## 17. Final operational workflow

Normal daily use should be short:

```powershell
codex-auth use chatgpt-current
```

or:

```powershell
codex-auth use chatgpt-account2
```

Then reconnect the Remote project if needed and choose the desired available model in Codex Desktop.

The user should not have to manually run `sed`, copy `auth.json`, or kill app-server processes during ordinary use. Those operations belong inside the switch workflow or troubleshooting runbook.

## 18. Definition of done

The implementation is stable when:

- one command switches the requested logical profile across all intended VPS hosts,
- refreshed ChatGPT credentials are preserved independently per VPS,
- same-profile selection does not erase the user's current model choice,
- real account changes clear only stale model-selection fields,
- Remote app-server refreshes after a real account change,
- Desktop presents the model set allowed for the active account,
- the user remains free to select any model shown in the UI,
- direct CLI tests pass,
- Desktop Remote tests pass,
- secrets never appear in logs or repository content.
