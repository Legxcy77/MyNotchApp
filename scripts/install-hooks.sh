#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ZSHRC="$HOME/.zshrc"
SOURCE_LINE="source \"$REPO_DIR/scripts/notch.zsh\""

touch "$ZSHRC"
if ! grep -Fq "scripts/notch.zsh" "$ZSHRC"; then
  printf "\n# MyNotchApp terminal & error lens hooks\n%s\n" "$SOURCE_LINE" >> "$ZSHRC"
  echo "Added notch.zsh to $ZSHRC"
else
  echo "notch.zsh already present in $ZSHRC"
fi

chmod +x "$REPO_DIR/scripts/notch" "$REPO_DIR/scripts/hooks/"*.sh 2>/dev/null || true
echo "Hooks ready. Open a new terminal tab or run: source ~/.zshrc"

