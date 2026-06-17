# copilot-warp

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

> ## ⚠️ Known limitation — does not currently populate Warp's notification box
>
> **As of Warp `v0.2026.06` this plugin cannot deliver in-app notifications from
> an interactive Copilot session, due to limitations on Warp's side.** Two
> independent constraints apply:
>
> 1. **Agent allow-list.** Warp's in-app cli-agent notification box only renders
>    a fixed set of agent identifiers (`claude` | `gemini` | `codex`); anything
>    else is dropped as `unknown`. The plugin works around this by masquerading as
>    `codex` (configurable via `COPILOT_WARP_AGENT_ID`).
> 2. **Alt-screen TUI + no Copilot plugin manager (the blocker).** Warp renders
>    the box via its terminal block parser, which is active for *normal-screen*
>    panes, or for *alt-screen* panes where Warp has a per-agent plugin manager
>    (`claude.rs` / `codex.rs` / `gemini.rs` — that is how `claude-code-warp`
>    works in Claude's TUI). Interactive Copilot CLI runs as an **alt-screen
>    TUI** and Warp ships **no `copilot` plugin manager**, so the OSC the hook
>    writes into Copilot's own pane is silently ignored.
>
> The hook still fires correctly and writes a valid payload — verified end to end
> — and the same payload **does** render when delivered to a normal-screen pane.
> But until Warp adds native Copilot recognition (a `copilot` plugin manager) or
> renders cli-agent OSC in alt-screen panes, the in-app box will stay empty from a
> live Copilot session. (Desktop toasts via `notify-send`/DBus still work as an
> out-of-band fallback.) See `STATUS_REPORT.md` for the full investigation.

## How it works

Copilot CLI [hooks](https://docs.github.com/en/copilot/reference/hooks-reference)
fire shell commands at lifecycle points. This integration registers a single
`notification` hook. The script:

1. Reads the hook payload from stdin (`notification_type`, `message`, `title`,
   `sessionId`, `cwd`).
2. Confirms the running Warp build advertises structured-notification support
   (`WARP_CLI_AGENT_PROTOCOL_VERSION` / `WARP_CLIENT_VERSION`).
3. Builds a structured JSON payload tagged with a Warp-recognized agent id.
   Warp's in-app cli-agent notification box only renders a fixed allow-list of
   agent identifiers (`claude` | `gemini` | `codex`); any other value (including
   `copilot`) is dropped as `unknown`. The payload therefore defaults to `codex`
   and is overridable via the `COPILOT_WARP_AGENT_ID` env var.
4. Emits an **OSC 777** escape sequence to the agent's terminal:
   `\033]777;notify;warp://cli-agent;<json>\007`. Warp parses `warp://cli-agent`
   and drives the notification UI.

Unlike Claude Code, Copilot CLI has no `terminalSequence` hook-output field and
reserves stdout for control JSON. Worse, it runs notification hooks **without a
controlling terminal** (`/dev/tty` is unavailable), so the script discovers the
agent's PTY by walking up the process tree — inspecting each ancestor's stdio
file descriptors for a `/dev/pts/*` target — and writes the sequence there.

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

Install it directly from GitHub:

```bash
copilot plugin install patrek/copilot-warp
```

Verify it registered, then restart your Copilot CLI session **inside Warp**:

```bash
copilot plugin list   # shows "warp-notifications"
```

## Development

To hack on the plugin or contribute, clone the repo and install from your local
working copy:

```bash
git clone https://github.com/patrek/copilot-warp.git
copilot plugin install ./copilot-warp
```

After editing the scripts, reinstall to pick up your changes and restart your
Copilot CLI session inside Warp:

```bash
copilot plugin uninstall warp-notifications
copilot plugin install ./copilot-warp
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
scripts/warp-notify.sh        discovers the agent PTY and writes the OSC 777 sequence there
scripts/should-use-structured.sh  gates on Warp build support
```

## Credit

Protocol and script structure adapted from Warp's official
[`claude-code-warp`](https://github.com/warpdotdev/claude-code-warp) (MIT).

## License

MIT