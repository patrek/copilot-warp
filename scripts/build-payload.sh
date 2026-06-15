#!/bin/bash
# Builds a structured JSON notification payload for warp://cli-agent.
#
# Usage: source this file, then call build_payload with event-specific fields.
#
#   source "$(dirname "${BASH_SOURCE[0]}")/build-payload.sh"
#   BODY=$(build_payload "$INPUT" "stop" --arg summary "$MSG")
#
# The function extracts common fields from the hook's stdin JSON (passed as $1),
# then merges any extra jq args you pass. Copilot CLI hook payloads use
# camelCase (sessionId, cwd); we also accept snake_case as a fallback.

PLUGIN_CURRENT_PROTOCOL_VERSION=1

# Negotiate the protocol version with Warp: min(plugin, warp-declared), default 1.
negotiate_protocol_version() {
    local warp_version="${WARP_CLI_AGENT_PROTOCOL_VERSION:-1}"
    if [ "$warp_version" -lt "$PLUGIN_CURRENT_PROTOCOL_VERSION" ] 2>/dev/null; then
        echo "$warp_version"
    else
        echo "$PLUGIN_CURRENT_PROTOCOL_VERSION"
    fi
}

build_payload() {
    local input="$1"
    local event="$2"
    shift 2

    local protocol_version
    protocol_version=$(negotiate_protocol_version)

    local session_id cwd project
    session_id=$(echo "$input" | jq -r '.sessionId // .session_id // empty' 2>/dev/null)
    cwd=$(echo "$input" | jq -r '.cwd // empty' 2>/dev/null)
    project=""
    [ -n "$cwd" ] && project=$(basename "$cwd")

    jq -nc \
        --argjson v "$protocol_version" \
        --arg agent "copilot" \
        --arg event "$event" \
        --arg session_id "$session_id" \
        --arg cwd "$cwd" \
        --arg project "$project" \
        "$@" \
        '{v:$v, agent:$agent, event:$event, session_id:$session_id, cwd:$cwd, project:$project} + $ARGS.named'
}