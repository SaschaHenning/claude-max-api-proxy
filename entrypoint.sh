#!/bin/sh
set -e

PORT="${PORT:-3456}"
HOST="${HOST:-0.0.0.0}"

echo "============================================"
echo " Claude Max API Proxy (Docker)"
echo "============================================"
echo ""

# Check Claude CLI
if ! command -v claude >/dev/null 2>&1; then
  echo "ERROR: Claude CLI not found in PATH"
  exit 1
fi

CLAUDE_VERSION=$(claude --version 2>/dev/null || echo "unknown")
echo "Claude CLI version: $CLAUDE_VERSION"
echo "Listening on:       $HOST:$PORT"
echo ""

exec node dist/server/standalone.js "$PORT"
