#!/bin/bash
# Wrapper script to capture LSP server logs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/nuxt-lsp-server.log"

echo "[$(date)] Starting Nuxt DX Tools LSP Server" >> "$LOG_FILE"
node "$SCRIPT_DIR/dist/server.js" --stdio 2>> "$LOG_FILE"
