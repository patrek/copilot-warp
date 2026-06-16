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
[ -z "$MSG" ] && MSG="Input needed"

# Map Copilot notification types onto Warp cli-agent events and emit the fields
# Warp renders for each event. (The `stop` event displays `query`/`response`;
# the other events display `summary`.)
case "$NOTIF_TYPE" in
    agent_completed)
        BODY=$(build_payload "$INPUT" "stop" \
            --arg query "$MSG" \
            --arg response "$MSG" \
            --arg transcript_path "")
        ;;
    agent_idle|elicitation_dialog)
        BODY=$(build_payload "$INPUT" "idle_prompt" --arg summary "$MSG")
        ;;
    permission_prompt)
        BODY=$(build_payload "$INPUT" "permission_request" --arg summary "$MSG")
        ;;
    shell_completed|shell_detached_completed)
        BODY=$(build_payload "$INPUT" "post_tool_use" --arg summary "$MSG")
        ;;
    *)
        BODY=$(build_payload "$INPUT" "$NOTIF_TYPE" --arg summary "$MSG")
        ;;
esac

"$SCRIPT_DIR/warp-notify.sh" "warp://cli-agent" "$BODY"