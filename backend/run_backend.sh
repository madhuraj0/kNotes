#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$HOME"

# Check possible python locations (prefer ~/.knotes/venv)
if [ -f "$HOME_DIR/.knotes/venv/bin/python3" ]; then
    PY="$HOME_DIR/.knotes/venv/bin/python3"
elif which python3.12 >/dev/null 2>&1; then
    PY="$(which python3.12)"
else
    PY="$(which python3)"
fi

exec "$PY" "$DIR/run.py"
