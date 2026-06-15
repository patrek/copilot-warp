#!/bin/bash
# Determines whether the current Warp build supports structured CLI agent notifications.
#
# Warp advertises support through two environment variables that it injects into
# the shell of every pane:
#   - WARP_CLI_AGENT_PROTOCOL_VERSION : the cli-agent notification protocol version
#   - WARP_CLIENT_VERSION             : the running Warp client build
#
# Some early Warp builds set WARP_CLI_AGENT_PROTOCOL_VERSION without actually
# being able to render structured notifications, so we additionally gate on the
# client version being newer than the last known broken release per channel.
#
# Usage:
#   source "$SCRIPT_DIR/should-use-structured.sh"
#   if should_use_structured; then ...; fi
#
# Returns 0 (true) when structured notifications are safe to use, 1 (false) otherwise.

LAST_BROKEN_DEV=""
LAST_BROKEN_STABLE="v0.2026.03.25.08.24.stable_05"
LAST_BROKEN_PREVIEW="v0.2026.03.25.08.24.preview_05"

should_use_structured() {
    [ -z "${WARP_CLI_AGENT_PROTOCOL_VERSION:-}" ] && return 1
    [ -z "${WARP_CLIENT_VERSION:-}" ] && return 1

    local threshold=""
    case "$WARP_CLIENT_VERSION" in
        *dev*)     threshold="$LAST_BROKEN_DEV" ;;
        *stable*)  threshold="$LAST_BROKEN_STABLE" ;;
        *preview*) threshold="$LAST_BROKEN_PREVIEW" ;;
    esac

    if [ -n "$threshold" ] && [[ ! "$WARP_CLIENT_VERSION" > "$threshold" ]]; then
        return 1
    fi

    return 0
}