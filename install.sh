#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
TARGET="$CLAUDE_DIR/statusline-command.sh"

# Copy script
cp "$SCRIPT_DIR/statusline-command.sh" "$TARGET"
chmod +x "$TARGET"
echo "✓ Installed $TARGET"

# Patch settings.json
if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

# Use jq to merge statusLine config
updated=$(jq '. + {
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}' "$SETTINGS")

echo "$updated" > "$SETTINGS"
echo "✓ Updated $SETTINGS"
echo ""
echo "Done. Restart Claude Code to see the status bar."
