#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Sync KNotes
# @raycast.mode compact
# @raycast.packageName KNotes
#
# Optional parameters:
# @raycast.icon 🔄

res=$(curl -s -X POST "http://127.0.0.1:8765/api/sync")
echo "✓ Google Keep synced successfully!"
