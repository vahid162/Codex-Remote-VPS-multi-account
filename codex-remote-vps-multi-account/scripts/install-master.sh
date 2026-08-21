#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INITIAL_PROFILE=""
REMOTES=()
REPLACE_HOSTS=0

usage() {
    cat <<'USAGE'
Usage: install-master.sh [--initial-profile NAME] [--remote SSH_ALIAS ...] [--replace-hosts]

Installs both local and central auth-manager helpers on the master VPS.
Remote aliases are written to ~/.codex-auth-manager/hosts. Each alias must
already work non-interactively from the master using SSH host-key checking.
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --initial-profile) INITIAL_PROFILE="${2:-}"; shift 2 ;;
        --remote) REMOTES+=("${2:-}"); shift 2 ;;
        --replace-hosts) REPLACE_HOSTS=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
    esac
done

args=()
[ -n "$INITIAL_PROFILE" ] && args+=(--initial-profile "$INITIAL_PROFILE")
"$SCRIPT_DIR/install-node.sh" "${args[@]}"

BASE="$HOME/.codex-auth-manager"
SOURCE="$SCRIPT_DIR/codex-auth"
[ -f "$SOURCE" ] || { echo "ERROR=central_helper_source_not_found"; exit 12; }
bash -n "$SOURCE"
install -m 700 "$SOURCE" "$BASE/bin/codex-auth"

HOSTS_FILE="$BASE/hosts"
if [ "$REPLACE_HOSTS" -eq 1 ] || [ ! -f "$HOSTS_FILE" ]; then
    : > "$HOSTS_FILE"
fi

for h in "${REMOTES[@]}"; do
    [ -n "$h" ] || continue
    if ! grep -Fxq "$h" "$HOSTS_FILE" 2>/dev/null; then
        printf '%s\n' "$h" >> "$HOSTS_FILE"
    fi
done
chmod 600 "$HOSTS_FILE"

echo "CENTRAL_HELPER_INSTALLED=$BASE/bin/codex-auth"
echo "HOSTS_FILE=$HOSTS_FILE"
if [ -s "$HOSTS_FILE" ]; then
    echo "=== REMOTES ==="
    cat "$HOSTS_FILE"
fi
