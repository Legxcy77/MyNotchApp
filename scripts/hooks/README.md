# Agent Inbox Hooks

Wire your coding agents to `~/MyNotchApp/scripts/notch activity <source> <session> <state> [title] [cwd]`.

## Claude Code (`~/.claude/settings.json`)
Merge the `hooks` block from `claude-settings.json` into `~/.claude/settings.json`.

## Codex CLI (`~/.codex/config.toml`)
Add:
```toml
notify = ["~/MyNotchApp/scripts/hooks/codex-notify.sh"]
```

## Antigravity / Custom Agents
Call `~/MyNotchApp/scripts/notch activity antigravity "<session>" working "Running" "$PWD"` when starting a long task, `waiting` when blocked on user input, and `done` or `failed` on completion.

