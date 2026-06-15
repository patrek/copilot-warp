# copilot-code-warp

Native [Warp](https://www.warp.dev/) notifications for the **GitHub Copilot CLI** — the
Copilot equivalent of Warp's official [`claude-code-warp`](https://github.com/warpdotdev/claude-code-warp)
plugin.

When Copilot finishes a task, goes idle waiting for input, or asks for a tool
permission, Warp shows a native notification in its notification center and as a
system notification — so you can context-switch while Copilot works and get
pulled back when it needs you.

> **Unofficial.** Warp ships an official integration for Claude Code but not (yet)
> for Copilot CLI. This project reuses Warp's `warp://cli-agent` notification
> protocol via Copilot CLI's hooks system. It depends on Warp environment
> variables and an undocumented protocol that may change.

## How it works

Copilot CLI [hooks](https://docs.github.com/en/copilot/reference/hooks-reference)
fire shell commands at lifecycle points. This integration registers a single
`notification` hook. The script:

1. Reads the hook payload from stdin (`notification_type`, `message`, `title`,
   `sessionId`, `cwd`).
2. Confirms the running Warp build advertises structured-notification support
   (`WARP_CLI_AGENT_PROTOCOL_VERSION` / `WARP_CLIENT_VERSION`).
3. Builds a structured JSON payload tagged `agent: "copilot"`.
4. Emits an **OSC 777** escape sequence to the controlling terminal:
   `\033]777;notify;warp://cli-agent;<json>\007`. Warp parses `warp://cli-agent`
   and drives the notification UI.

Unlike Claude Code, Copilot CLI has no `terminalSequence` hook-output field and
reserves stdout for control JSON, so the sequence is written directly to
`/dev/tty`.

### Event mapping

| Copilot `notification_type`                  | Warp event          |
| -------------------------------------------- | ------------------- |
| `agent_completed`                            | `stop`              |
| `agent_idle`, `elicitation_dialog`           | `idle_prompt`       |
| `permission_prompt`                          | `permission_request`|
| `shell_completed`, `shell_detached_completed`| `post_tool_use`     |
| _(anything else)_                            | passed through      |

## Requirements

- [Warp](https://www.warp.dev/) — a recent build with cli-agent structured
  notifications (newer than `v0.2026.03.25`).
- [GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli)
  with hooks support.
- `jq`.

## Install

This is a [Copilot CLI plugin](https://docs.github.com/en/copilot/concepts/agents/copilot-cli/about-cli-plugins).
Install it from a local clone:

```bash
git clone <this-repo> copilot-code-warp
copilot plugin install ./copilot-code-warp
```

…or directly from GitHub once published:

```bash
copilot plugin install OWNER/copilot-code-warp
```

Verify it registered, then restart your Copilot CLI session **inside Warp**:

```bash
copilot plugin list   # shows "warp-notifications"
```

## Uninstall

```bash
copilot plugin uninstall warp-notifications
```

## Layout

```
plugin.json                   Copilot plugin manifest (points hooks -> hooks.json)
hooks.json                    notification hook registration (relative script path)
scripts/on-notification.sh    notification hook entry point; maps types -> Warp events
scripts/build-payload.sh      builds the warp://cli-agent JSON payload
scripts/warp-notify.sh        emits the OSC 777 sequence to /dev/tty
scripts/should-use-structured.sh  gates on Warp build support
```

## Credit

Protocol and script structure adapted from Warp's official
[`claude-code-warp`](https://github.com/warpdotdev/claude-code-warp) (MIT).

## License

MIT