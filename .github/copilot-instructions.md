# Copilot Instructions

## What This Is

A minimal Copilot CLI **plugin** that connects GitHub Copilot CLI's hook system to Warp's native notification center. When Copilot fires a `notification` hook, `scripts/on-notification.sh` reads the JSON payload from stdin, maps the `notification_type` to a Warp event name, builds a structured JSON body, and emits an **OSC 777** escape sequence to the agent's PTY (the terminal Warp scans for escape sequences).

There is no build system, no dependencies to install, and no tests. `jq` is the only runtime dependency.

## Layout

```
plugin.json                   Plugin manifest; points "hooks" -> hooks.json
hooks.json                    Registers the notification hook (relative script path)
scripts/on-notification.sh    Entry point: reads stdin, maps types, calls build+notify
scripts/build-payload.sh      Sourced library: build_payload() and negotiate_protocol_version()
scripts/should-use-structured.sh  Sourced library: should_use_structured() gate
scripts/warp-notify.sh        Discovers the agent PTY and writes the OSC 777 sequence there
```

## Architecture

The four scripts under `scripts/` form a simple pipeline:

1. **`on-notification.sh`** — hook entry point; sources the other scripts; reads stdin once into `$INPUT`; maps `notification_type` → Warp event; calls `build_payload` and pipes result to `warp-notify.sh`.
2. **`build-payload.sh`** — defines `build_payload()` and `negotiate_protocol_version()`. Sourced (not executed). `build_payload` takes the raw hook JSON as `$1`, the event name as `$2`, and forwards any extra `--arg` / `--argjson` flags to `jq`.
3. **`should-use-structured.sh`** — defines `should_use_structured()`. Sourced everywhere it's needed. Gates on `WARP_CLI_AGENT_PROTOCOL_VERSION` and `WARP_CLIENT_VERSION` env vars.
4. **`warp-notify.sh`** — standalone; accepts `<title> <body>`; emits `\033]777;notify;<title>;<body>\007`. Because Copilot CLI runs hooks **without a controlling terminal** (no `/dev/tty`) and offers no `terminalSequence` hook-output field, it locates the agent's PTY by walking up the process tree (inspecting each ancestor's stdio fds for a `/dev/pts/*` target) and writes the sequence there. Stdout is intentionally silent because Copilot CLI reserves hook stdout for control JSON.

## Key Conventions

- **Scripts are sourced, not executed**, for shared functions (`build-payload.sh`, `should-use-structured.sh`). Always `source` these; never call them as subprocesses.
- **`$INPUT` is read once** in `on-notification.sh` via `INPUT=$(cat)` and passed as a string argument to `build_payload`. Do not re-read stdin in downstream helpers.
- **`hooks.json` uses a relative script path** (`./scripts/on-notification.sh`), resolved against the installed plugin directory. Never hardcode absolute paths. The entry script self-locates its siblings via `SCRIPT_DIR`, so the working directory at hook time does not matter.
- **Version gating** in `should-use-structured.sh` uses lexicographic string comparison (`[[ ! "$WARP_CLIENT_VERSION" > "$threshold" ]]`) on Warp's version strings. Three separate constants (`LAST_BROKEN_DEV`, `LAST_BROKEN_STABLE`, `LAST_BROKEN_PREVIEW`) gate by channel; update all three when bumping thresholds.
- **`warp-notify.sh` re-checks `should_use_structured` independently** — it is safe to invoke standalone, not only via `on-notification.sh`.
- **Protocol version negotiation** takes `min(PLUGIN_CURRENT_PROTOCOL_VERSION, WARP_CLI_AGENT_PROTOCOL_VERSION)`. `PLUGIN_CURRENT_PROTOCOL_VERSION` is defined at the top of `build-payload.sh`.
- **`build_payload` uses `jq -nc … $ARGS.named`** — any extra `--arg`/`--argjson` flags passed by the caller are automatically merged into the top-level JSON object. Use this to add event-specific fields without modifying the function.
- The `agent` field in every payload is set to a Warp-recognized id
  (`${COPILOT_WARP_AGENT_ID:-codex}`; allow-list `claude`|`gemini`|`codex`).
  Warp's cli-agent notification box drops unrecognized ids (e.g. `copilot`) as
  `unknown`, so the value is NOT literally `"copilot"`.

## Incoming Hook Payload Schema

```json
{
  "sessionId": "string",
  "timestamp": "number",
  "cwd": "string",
  "hook_event_name": "Notification",
  "message": "string",
  "title": "string (optional)",
  "notification_type": "shell_completed | shell_detached_completed | agent_completed | agent_idle | permission_prompt | elicitation_dialog"
}
```

`build_payload` accepts both camelCase (`sessionId`) and snake_case (`session_id`) for Copilot CLI forward-compatibility.

## Event Mapping

| Copilot `notification_type`             | Warp event          |
| --------------------------------------- | ------------------- |
| `agent_completed`                       | `stop`              |
| `agent_idle`, `elicitation_dialog`      | `idle_prompt`       |
| `permission_prompt`                     | `permission_request`|
| `shell_completed`, `shell_detached_completed` | `post_tool_use` |
| _(anything else)_                       | passed through as-is |

## Install / Test

```bash
# Install as a plugin from a local clone
copilot plugin install ./copilot-warp
copilot plugin list   # should show "warp-notifications"

# Simulate a hook payload without Copilot
echo '{"sessionId":"test","cwd":"/tmp","notification_type":"agent_completed","message":"Done"}' \
  | WARP_CLI_AGENT_PROTOCOL_VERSION=1 WARP_CLIENT_VERSION=v0.2026.04.01.stable_01 \
    bash scripts/on-notification.sh
```