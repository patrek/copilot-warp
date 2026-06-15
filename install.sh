#!/bin/bash
# Installs the Copilot CLI -> Warp notification hook into the current user's
# Copilot configuration (~/.copilot/hooks/warp.json), pointing at the scripts in
# this repository. Re-running is safe; it overwrites the previous install.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="${COPILOT_HOME:-$HOME/.copilot}/hooks"
TARGET="$HOOKS_DIR/warp.json"

command -v jq >/dev/null 2>&1 || { echo "error: jq is required (e.g. 'brew install jq' / 'sudo apt install jq')." >&2; exit 1; }

chmod +x "$REPO_DIR"/scripts/*.sh

mkdir -p "$HOOKS_DIR"
sed "s|__INSTALL_DIR__|$REPO_DIR|g" "$REPO_DIR/hooks/hooks.json" > "$TARGET"

echo "Installed Copilot -> Warp notification hook:"
echo "  config:  $TARGET"
echo "  scripts: $REPO_DIR/scripts"
echo
echo "Restart your Copilot CLI session inside Warp to activate it."