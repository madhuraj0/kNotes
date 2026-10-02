#!/usr/bin/env python3
import json
import os
import sys
import uuid
import webbrowser
from datetime import datetime, timezone
from pathlib import Path

# Add project root and virtualenv site-packages to sys.path
script_dir = Path(__file__).resolve().parent
project_dir = script_dir.parent
sys.path.insert(0, str(project_dir / "backend"))

# Auto-inject virtualenv site-packages if running with system python
candidate_site_packages = [
    project_dir / ".venv" / "lib" / f"python{sys.version_info.major}.{sys.version_info.minor}" / "site-packages",
    Path.home() / ".knotes" / "venv" / "lib" / f"python{sys.version_info.major}.{sys.version_info.minor}" / "site-packages",
    Path("/Users/madhuraj/Downloads/code/KNotes/.venv/lib/python3.12/site-packages"),
]
for sp in candidate_site_packages:
    if sp.exists() and str(sp) not in sys.path:
        sys.path.insert(0, str(sp))

import gpsoauth
import gkeepapi
from app import config

def main():
    print("=" * 60)
    print("  KNotes Google Keep Master Token Generator & CLI Login   ")
    print("=" * 60)
    print()
    print("Google has discontinued password / App Password login for the")
    print("unofficial Keep API. To connect, Google uses an oauth session token.")
    print()

    email = input("Enter your Google email [default: user@example.com]: ").strip()
    if not email:
        email = "user@example.com"

    print("\nStep 1: Opening Google's Embedded Login in your browser...")
    url = "https://accounts.google.com/EmbeddedSetup"
    print(f"URL: {url}")
    webbrowser.open(url)

    print("\nStep 2: In the browser window that opens:")
    print("  1. Sign in with your Google account (complete 2FA if prompted).")
    print("  2. When the page finishes/hangs on a white or 'Please wait' screen:")
    print("     • Press ⌥ + ⌘ + I (Option + Command + I) to open Developer Tools.")
    print("     • Go to 'Application' (in Chrome/Brave/Edge) or 'Storage' (in Safari/Firefox).")
    print("     • Expand 'Cookies' -> Click 'https://accounts.google.com'.")
    print("     • Find the cookie named 'oauth_token' (starts with oauth2_4/...).")
    print("     • Double-click the Value and Copy it.")
    print()

    token_input = input("Paste the oauth_token (or existing Master Token) here: ").strip()
    if not token_input:
        print("Error: No token provided.")
        sys.exit(1)

    android_id = f"{uuid.getnode():x}"

    master_token = token_input
    if token_input.startswith("oauth2_4/"):
        print("\nExchanging oauth_token for Google Master Token via gpsoauth...")
        res = gpsoauth.exchange_token(email, token_input, android_id)
        if "Token" not in res:
            print(f"\n❌ Exchange failed: {res.get('Error', res)}")
            sys.exit(1)
        master_token = res["Token"]
        print(f"✓ Master token obtained successfully!")

    print("\nTesting Google Keep connection...")
    keep = gkeepapi.Keep()
    try:
        keep.authenticate(email, master_token, sync=True)
        notes = list(keep.all())
        print(f"✓ Authentication SUCCESSFUL!")
        print(f"✓ Found {len(notes)} notes in your Google Keep account.")

        # Save session to ~/.knotes/session.json
        config.ensure_secure_dir()
        session_data = {
            "email": email,
            "master_token": master_token,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
        with open(config.SESSION_FILE, "w", encoding="utf-8") as f:
            json.dump(session_data, f)
        config.SESSION_FILE.chmod(0o600)
        print(f"✓ Saved session to {config.SESSION_FILE} (permissions 0600)")

        # Save Keep state so KNotes loads it immediately
        state = keep.dump()
        with open(config.STATE_FILE, "w", encoding="utf-8") as f:
            json.dump(state, f)
        config.STATE_FILE.chmod(0o600)
        print(f"✓ Saved Keep notes cache to {config.STATE_FILE}")

        print("\n" + "=" * 60)
        print("🎉 All set! Restart or switch to KNotes.app.")
        print("   Your Google Keep notes are now connected and ready!")
        print("=" * 60)

    except Exception as e:
        print(f"\n❌ Authentication failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
