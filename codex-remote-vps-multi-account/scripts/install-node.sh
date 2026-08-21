#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR/codex-auth-local"
INITIAL_PROFILE=""

usage() {
    cat <<'USAGE'
Usage: install-node.sh [--initial-profile NAME]

Installs codex-auth-local on one Linux VPS. It does not copy secrets from
another VPS. With --initial-profile, the current ~/.codex/auth.json is safely
snapshotted as that profile and marked active on this VPS.
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --initial-profile) INITIAL_PROFILE="${2:-}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
    esac
done

command -v codex >/dev/null || { echo "ERROR=codex_not_found"; exit 10; }
command -v python3 >/dev/null || { echo "ERROR=python3_not_found"; exit 11; }
[ -f "$SOURCE" ] || { echo "ERROR=source_helper_not_found"; exit 12; }
bash -n "$SOURCE"

BASE="$HOME/.codex-auth-manager"
PROFILES="$HOME/.codex-auth/profiles"
mkdir -p "$BASE/bin" "$PROFILES" "$HOME/.codex"
chmod 700 "$BASE" "$BASE/bin" "$HOME/.codex-auth" "$PROFILES" "$HOME/.codex" 2>/dev/null || true

install -m 700 "$SOURCE" "$BASE/bin/codex-auth-local"

echo "LOCAL_HELPER_INSTALLED=$BASE/bin/codex-auth-local"

if [ -n "$INITIAL_PROFILE" ]; then
    [[ "$INITIAL_PROFILE" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "ERROR=INVALID_PROFILE"; exit 20; }
    [ -f "$HOME/.codex/auth.json" ] || { echo "ERROR=LIVE_AUTH_NOT_FOUND"; exit 21; }
    [ ! -e "$PROFILES/$INITIAL_PROFILE" ] || { echo "ERROR=PROFILE_EXISTS"; exit 22; }
    mkdir -p "$PROFILES/$INITIAL_PROFILE"
    chmod 700 "$PROFILES/$INITIAL_PROFILE"
    install -m 600 "$HOME/.codex/auth.json" "$PROFILES/$INITIAL_PROFILE/auth.json"
    printf '%s\n' "$INITIAL_PROFILE" > "$BASE/active-profile"
    chmod 600 "$BASE/active-profile"
    echo "INITIAL_PROFILE=$INITIAL_PROFILE"
fi

"$BASE/bin/codex-auth-local" status
