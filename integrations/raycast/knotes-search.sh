#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Search KNotes
# @raycast.mode fullOutput
# @raycast.packageName KNotes
#
# Optional parameters:
# @raycast.icon 📝
# @raycast.argument1 { "type": "text", "placeholder": "Search Query", "optional": true }

QUERY="${1:-}"
curl -s "http://127.0.0.1:8765/api/notes?query=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$QUERY'))")" | python3 -c "
import sys, json

notes = json.load(sys.stdin)
if not notes:
    print('No matching notes found.')
    sys.exit(0)

print(f'# KNotes Results ({len(notes)} notes)\n')
for n in notes:
    title = n.get('title') or '(Untitled)'
    nid = n.get('id')
    labels = ' '.join(['\`#' + l + '\`' for l in n.get('labels', [])])
    text = (n.get('text') or '').replace('\n', ' ')[:80]
    pin = '📌 ' if n.get('pinned') else ''
    print(f'### {pin}[{title}](knotes://note/{nid}) {labels}')
    if text:
        print(f'{text}\n')
"
