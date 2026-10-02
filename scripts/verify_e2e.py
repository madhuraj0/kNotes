import subprocess
import time
import urllib.request
import json
import sys

def check_backend_running(port=8765):
    try:
        req = urllib.request.Request(f"http://127.0.0.1:{port}/api/status")
        with urllib.request.urlopen(req, timeout=2) as response:
            if response.status == 200:
                data = json.loads(response.read().decode("utf-8"))
                return True, data
    except Exception:
        pass
    return False, None

def test_api_workflow(port=8765):
    base_url = f"http://127.0.0.1:{port}/api"
    print("--> 1. Testing GET /api/status...")
    alive, status = check_backend_running(port)
    assert alive, "Backend is not responding!"
    print(f"    Backend alive: {status}")

    print("--> 2. Testing POST /api/notes (creating e2e note)...")
    create_payload = json.dumps({
        "title": "E2E Verification Note",
        "text": "Native macOS KNotes integration test verifying backend and app sync.",
        "color": "Teal",
        "pinned": True,
        "labels": ["Test"]
    }).encode("utf-8")
    req = urllib.request.Request(f"{base_url}/notes", data=create_payload, headers={"Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req) as resp:
        assert resp.status == 201
        created = json.loads(resp.read().decode("utf-8"))
        note_id = created["id"]
        print(f"    Note created: id={note_id}, title={created['title']}")

    print("--> 3. Testing GET /api/notes with search query...")
    req = urllib.request.Request(f"{base_url}/notes?query=Verification")
    with urllib.request.urlopen(req) as resp:
        results = json.loads(resp.read().decode("utf-8"))
        assert any(n["id"] == note_id for n in results)
        print(f"    Search returned {len(results)} matching notes.")

    print("--> 4. Testing PUT /api/notes/{id} (checklist conversion)...")
    update_payload = json.dumps({
        "is_list": True,
        "items": [
            {"text": "Task A - verified", "checked": True},
            {"text": "Task B - pending", "checked": False}
        ]
    }).encode("utf-8")
    req = urllib.request.Request(f"{base_url}/notes/{note_id}", data=update_payload, headers={"Content-Type": "application/json"}, method="PUT")
    with urllib.request.urlopen(req) as resp:
        assert resp.status == 200
        updated = json.loads(resp.read().decode("utf-8"))
        assert updated["is_list"] is True
        assert len(updated["items"]) == 2
        print("    Checklist update successful.")

    print("--> 5. Testing DELETE /api/notes/{id}...")
    req = urllib.request.Request(f"{base_url}/notes/{note_id}", method="DELETE")
    with urllib.request.urlopen(req) as resp:
        assert resp.status == 200
        print("    Note successfully deleted.")

    print("\n✓ All API workflows verified successfully!")

def main():
    print("==========================================")
    print("  KNotes End-to-End Test Runner           ")
    print("==========================================")

    # Check if backend running, if not start it
    alive, _ = check_backend_running()
    proc = None
    if not alive:
        print("Starting backend subprocess...")
        proc = subprocess.Popen([
            "./.venv/bin/python3",
            "backend/run.py"
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(10):
            time.sleep(0.5)
            alive, _ = check_backend_running()
            if alive:
                break
        assert alive, "Backend failed to launch!"

    try:
        test_api_workflow()
    finally:
        if proc:
            proc.terminate()
            proc.wait()

if __name__ == "__main__":
    main()
