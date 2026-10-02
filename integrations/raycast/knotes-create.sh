#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Create KNotes Note
# @raycast.mode compact
# @raycast.packageName KNotes
#
# Optional parameters:
# @raycast.icon ✍️
# @raycast.argument1 { "type": "text", "placeholder": "Note Title" }
# @raycast.argument2 { "type": "text", "placeholder": "Note Body", "optional": true }

TITLE="$1"
CONTENT="${2:-}"

payload=$(python3 -c "
import json
print(json.dumps({
    'title': '''$TITLE''',
    'text': '''$CONTENT''',
    'labels': ['Quick Notes']
}))
")

res=$(curl -s -X POST "http://127.0.0.1:8765/api/notes" -H "Content-Type: application/json" -d "$payload")
echo "✓ Note created in KNotes & Google Keep!"
