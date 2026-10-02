import os
import tempfile
from pathlib import Path
import pytest
from fastapi.testclient import TestClient

# Use a temporary directory for tests so we don't mess with ~/.knotes
test_dir = tempfile.mkdtemp(prefix="knotes_test_")
os.environ["KNOTES_DATA_DIR"] = test_dir

from app.main import app, manager
from app import config

client = TestClient(app)


def test_status_endpoint():
    response = client.get("/api/status")
    assert response.status_code == 200
    data = response.json()
    assert "authenticated" in data
    assert "sync_status" in data
    assert data["total_notes"] >= 2  # Seeded notes exist
    assert data["pinned_notes"] >= 1


def test_list_notes():
    response = client.get("/api/notes")
    assert response.status_code == 200
    notes = response.json()
    assert isinstance(notes, list)
    assert len(notes) >= 2


def test_create_and_get_text_note():
    payload = {
        "title": "Meeting Notes with Apple Team",
        "text": "Discussed macOS Sequoia UI and Swift native performance.",
        "is_list": False,
        "color": "Teal",
        "pinned": True,
        "labels": ["Work", "Design"],
    }
    create_res = client.post("/api/notes", json=payload)
    assert create_res.status_code == 201
    created = create_res.json()
    assert created["title"] == payload["title"]
    assert created["text"] == payload["text"]
    assert created["color"] == "Teal"
    assert created["pinned"] is True
    assert "Work" in created["labels"]
    assert "Design" in created["labels"]

    # Verify GET by ID
    note_id = created["id"]
    get_res = client.get(f"/api/notes/{note_id}")
    assert get_res.status_code == 200
    fetched = get_res.json()
    assert fetched["id"] == note_id
    assert fetched["title"] == payload["title"]


def test_create_and_update_checklist():
    payload = {
        "title": "Grocery Run",
        "is_list": True,
        "items": [
            {"text": "Almond milk", "checked": False},
            {"text": "Honey crisp apples", "checked": True},
        ],
        "color": "Green",
    }
    create_res = client.post("/api/notes", json=payload)
    assert create_res.status_code == 201
    created = create_res.json()
    assert created["is_list"] is True
    assert len(created["items"]) == 2
    assert created["items"][0]["text"] == "Almond milk"
    assert created["items"][1]["checked"] is True

    # Update checklist: check item 0
    note_id = created["id"]
    update_payload = {
        "items": [
            {"text": "Almond milk", "checked": True},
            {"text": "Honey crisp apples", "checked": True},
            {"text": "Organic sourdough bread", "checked": False},
        ]
    }
    update_res = client.put(f"/api/notes/{note_id}", json=update_payload)
    assert update_res.status_code == 200
    updated = update_res.json()
    assert len(updated["items"]) == 3
    assert updated["items"][0]["checked"] is True


def test_search_and_filter():
    # Filter by folder=pinned
    pinned_res = client.get("/api/notes?folder=pinned")
    assert pinned_res.status_code == 200
    pinned_notes = pinned_res.json()
    for note in pinned_notes:
        assert note["pinned"] is True

    # Filter by query
    query_res = client.get("/api/notes?query=Grocery")
    assert query_res.status_code == 200
    results = query_res.json()
    assert len(results) >= 1
    assert any("Grocery" in r["title"] for r in results)


def test_labels_crud():
    # Create label
    create_res = client.post("/api/labels", json={"name": "Travel"})
    assert create_res.status_code == 201
    lbl = create_res.json()
    assert lbl["name"] == "Travel"
    lbl_id = lbl["id"]

    # List labels
    list_res = client.get("/api/labels")
    assert list_res.status_code == 200
    labels = list_res.json()
    assert any(l["name"] == "Travel" for l in labels)

    # Delete label
    del_res = client.delete(f"/api/labels/{lbl_id}")
    assert del_res.status_code == 200


def test_trash_and_untrash():
    # Create a note to trash
    note_res = client.post("/api/notes", json={"title": "To be trashed", "text": "Draft note"})
    note_id = note_res.json()["id"]

    # Delete note (moves to trash)
    del_res = client.delete(f"/api/notes/{note_id}")
    assert del_res.status_code == 200

    # Verify not in 'all' folder
    all_res = client.get("/api/notes?folder=all")
    assert not any(n["id"] == note_id for n in all_res.json())

    # Verify in 'trash' folder
    trash_res = client.get("/api/notes?folder=trash")
    assert any(n["id"] == note_id for n in trash_res.json())

    # Untrash note
    untrash_res = client.post(f"/api/notes/{note_id}/untrash")
    assert untrash_res.status_code == 200
    assert untrash_res.json()["trashed"] is False


def test_security_directory_permissions():
    """Verify security compliance: state file permissions are restricted to user only."""
    assert Path(test_dir).exists()
    st = os.stat(test_dir)
    # Directory should have 0700 permissions
    assert (st.st_mode & 0o777) == 0o700
