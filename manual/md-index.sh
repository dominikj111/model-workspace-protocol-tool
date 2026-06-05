#!/usr/bin/env bash
# Wrapper for md-index.py
# Uses python3 from the environment.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: python3 not found in PATH" >&2
    exit 1
fi

python3 "$SCRIPT_DIR/md-index.py" "$@"
