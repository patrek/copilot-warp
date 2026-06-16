#!/bin/bash
# Warp notification utility using OSC escape sequences.
# Usage: warp-notify.sh <title> <body>
#
# For structured Warp notifications, title should be "warp://cli-agent" and
# body should be a JSON string matching the cli-agent notification schema.
#
# Copilot CLI runs notification hooks without a controlling terminal (stdin is a
# pipe and there is no /dev/tty), and — unlike Claude Code — it offers no
# `terminalSequence` hook-output field to inject escape sequences. So we locate
# the agent's PTY (the terminal Warp scans for OSC sequences) by walking up the
# process tree and write the OSC 777 sequence there directly. Nothing is written
# to stdout, which Copilot CLI reserves for hook control JSON.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/should-use-structured.sh"

# Only emit when we've confirmed the Warp build can render structured notifications.
if ! should_use_structured; then
    exit 0
fi

TITLE="${1:-Notification}"
BODY="${2:-}"

# The hook runs without a controlling terminal (no /dev/tty), so we cannot write
# there. Instead, walk up the process tree to find the agent's PTY (the terminal
# Warp scans for OSC sequences) by inspecting each ancestor's stdio fds.
find_agent_pty() {
    local pid="$PPID" hops=0 fd target stat rest
    while [ -n "$pid" ] && [ "$pid" != "0" ] && [ "$pid" != "1" ] && [ "$hops" -lt 12 ]; do
        for fd in 1 0 2; do
            target=$(readlink "/proc/$pid/fd/$fd" 2>/dev/null)
            case "$target" in
                /dev/pts/*) echo "$target"; return 0 ;;
            esac
        done
        # /proc/<pid>/stat is: "pid (comm) state ppid ...". comm may contain
        # spaces/parens, so read the fields after the final ')'.
        stat=$(cat "/proc/$pid/stat" 2>/dev/null) || return 1
        rest=${stat##*) }
        pid=$(echo "$rest" | awk '{print $2}')
        hops=$((hops + 1))
    done
    return 1
}

PTY=$(find_agent_pty)

# OSC 777 format: \033]777;notify;<title>;<body>\007
SEQ_TARGET="${PTY:-/dev/tty}"
printf '\033]777;notify;%s;%s\007' "$TITLE" "$BODY" > "$SEQ_TARGET" 2>/dev/null || true