#!/usr/bin/env bash
set -euo pipefail

# This hook runs MWP verification before destructive actions.

# CRUSH_TOOL_NAME is provided by Crush.
# CRUSH_TOOL_INPUT_FILE_PATH is provided if it's a file tool.

if [[ "$CRUSH_TOOL_NAME" == "edit" || "$CRUSH_TOOL_NAME" == "multiedit" || "$CRUSH_TOOL_NAME" == "write" ]]; then
    TARGET_DIR="."
    if [[ -n "${CRUSH_TOOL_INPUT_FILE_PATH:-}" ]]; then
        TARGET_DIR=$(dirname "$CRUSH_TOOL_INPUT_FILE_PATH")
    fi
    
    if ! bash .mwp/mwp-verify.sh "$TARGET_DIR"; then
        echo "MWP Guard: Verification failed. Path is read-only or context missing." >&2
        exit 1
    fi
fi

exit 0 # Allow
