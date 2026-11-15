#!/usr/bin/env zsh
set -euo pipefail

# Codex CLI passes a JSON payload as $1 on `notify`.
payload="${1:-{}}"
NOTCH_CLI="${0:A:h:h}/notch"
[[ -x "$NOTCH_CLI" ]] || exit 0

parsed=$(python3 -c '
import json, sys, os
try:
    d = json.loads(sys.argv[1])
except Exception:
    d = {}
session = str(d.get("thread-id") or d.get("session_id") or "default")
cwd = str(d.get("cwd") or os.getcwd())
ev_type = str(d.get("type") or "agent-turn-complete")
state = "waiting" if "approval" in ev_type or "input" in ev_type else "done"
title = str(d.get("last-assistant-message") or ev_type)[:48]
print(session)
print(state)
print(title)
print(cwd)
' "$payload")

lines=("${(@f)parsed}")
"$NOTCH_CLI" activity codex "${lines[1]}" "${lines[2]}" "${lines[3]}" "${lines[4]}" >/dev/null 2>&1 || true
