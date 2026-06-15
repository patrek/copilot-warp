#!/bin/bash
# Warp notification utility using OSC escape sequences.
# Usage: warp-notify.sh <title> <body>
#
# For structured Warp notifications, title should be "warp://cli-agent" and
# body should be a JSON string matching the cli-agent notification schema.
#
# Unlike Claude Code, Copilot CLI has no `terminalSequence` hook-output field,
# and a hook's stdout is reserved for control JSON. We therefore write the OSC
# sequence directly to the controlling terminal (/dev/tty) and emit nothing on
# stdout.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/should-use-structured.sh"

# Only emit when we've confirmed the Warp build can render structured notifications.
if ! should_use_structured; then
    exit 0
fi

TITLE="${1:-Notification}"
BODY="${2:-}"

# OSC 777 format: \033]777;notify;<title>;<body>\007
SEQ=$(printf '\033]777;notify;%s;%s\007' "$TITLE" "$BODY")
printf '%s' "$SEQ" > /dev/tty 2>/dev/null || true