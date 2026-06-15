#!/bin/bash
# Hook script for the Copilot CLI `notification` event.
#
# Copilot consolidates agent lifecycle signals into a single notification event
# carrying a `notification_type`. We map each type onto the Warp cli-agent event
# vocabulary and send a structured notification.
#
# Incoming stdin payload (Copilot CLI notification hook):
#   {
#     "sessionId": string,
#     "timestamp": number,
#     "cwd": string,
#     "hook_event_name": "Notification",
#     "message": string,
#     "title"?: string,
#     "notification_type": "shell_completed" | "shell_detached_completed"
#                        | "agent_completed" | "agent_idle"
#                        | "permission_prompt" | "elicitation_dialog"
#   }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/should-use-structured.sh"

# Nothing to do if this Warp build can't render structured notifications.
should_use_structured || exit 0

source "$SCRIPT_DIR/build-payload.sh"

INPUT=$(cat)

NOTIF_TYPE=$(echo "$INPUT" | jq -r '.notification_type // "unknown"' 2>/dev/null)
MSG=$(echo "$INPUT" | jq -r '.message // empty' 2>/dev/null)
TITLE=$(echo "$INPUT" | jq -r '.title // empty' 2>/dev/null)
[ -z "$MSG" ] && MSG="Input needed"

# Map Copilot notification types onto Warp cli-agent event names.
case "$NOTIF_TYPE" in
    agent_completed)                         EVENT="stop" ;;
    agent_idle|elicitation_dialog)           EVENT="idle_prompt" ;;
    permission_prompt)                       EVENT="permission_request" ;;
    shell_completed|shell_detached_completed) EVENT="post_tool_use" ;;
    *)                                       EVENT="$NOTIF_TYPE" ;;
esac

BODY=$(build_payload "$INPUT" "$EVENT" \
    --arg summary "$MSG" \
    --arg title "$TITLE")

"$SCRIPT_DIR/warp-notify.sh" "warp://cli-agent" "$BODY"