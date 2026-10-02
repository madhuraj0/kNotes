import logging
from typing import List, Optional
from fastapi import FastAPI, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.keep_client import KeepManager
from app.models import (
    LabelCreateRequest,
    LabelResponse,
    LoginRequest,
    NoteCreateRequest,
    NoteResponse,
    NoteUpdateRequest,
    StatusResponse,
)

# Configure secure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("knotes.api")

app = FastAPI(
    title="KNotes Google Keep API",
    description="Local native backend for KNotes Notes clone on macOS",
    version="1.0.0",
)

# CORS restricted to local origin
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://127.0.0.1",
        "http://localhost:*",
        "http://127.0.0.1:*",
    ],
    allow_origin_regex=r"^http://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

manager = KeepManager()


@app.get("/api/status", response_model=StatusResponse)
def get_status() -> StatusResponse:
    """Return backend status, sync status, and note counts."""
    return manager.get_status()


@app.post("/api/auth/login")
def login(req: LoginRequest):
    """Authenticate with Google Keep using App Password or Master Token."""
    success, message = manager.login(
        email=req.email,
        password=req.password,
        master_token=req.master_token,
    )
    if not success:
        return JSONResponse(
            status_code=status.HTTP_401_UNAUTHORIZED,
            content={"success": False, "message": message},
        )
    return {"success": True, "message": message}


@app.post("/api/auth/logout")
def logout():
    """Disconnect Google Keep account and revert to local mode."""
    manager.logout()
    return {"success": True, "message": "Successfully logged out."}


@app.post("/api/sync")
def trigger_sync():
    """Manually trigger synchronization with Google Keep."""
    success, message = manager.sync()
    if not success:
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={"success": False, "message": message},
        )
    return {"success": True, "message": message}


@app.get("/api/notes", response_model=List[NoteResponse])
def get_notes(
    folder: str = Query("all", description="Folder: all, quick, pinned, archived, trash"),
    label: Optional[str] = Query(None, description="Filter by label name"),
    query: Optional[str] = Query(None, description="Search query"),
) -> List[NoteResponse]:
    """Retrieve notes with folder, label, or text search filtering."""
    return manager.list_notes(folder=folder, label=label, query=query)


@app.post("/api/notes", response_model=NoteResponse, status_code=status.HTTP_201_CREATED)
def create_note(req: NoteCreateRequest) -> NoteResponse:
    """Create a new note or checklist."""
    return manager.create_note(req)


@app.get("/api/notes/{note_id}", response_model=NoteResponse)
def get_note(note_id: str) -> NoteResponse:
    """Get single note details."""
    note = manager.get_note(note_id)
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    return note


@app.put("/api/notes/{note_id}", response_model=NoteResponse)
def update_note(note_id: str, req: NoteUpdateRequest) -> NoteResponse:
    """Update note content, title, tags, color, or pinned state."""
    note = manager.update_note(note_id, req)
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    return note


@app.delete("/api/notes/{note_id}")
def delete_note(note_id: str):
    """Move note to trash, or permanently remove if already in trash."""
    success = manager.delete_note(note_id)
    if not success:
        raise HTTPException(status_code=404, detail="Note not found")
    return {"success": True, "message": "Note deleted"}


@app.post("/api/notes/{note_id}/untrash", response_model=NoteResponse)
def untrash_note(note_id: str) -> NoteResponse:
    """Restore a deleted note from trash."""
    note = manager.untrash_note(note_id)
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    return note


@app.get("/api/labels", response_model=List[LabelResponse])
def get_labels() -> List[LabelResponse]:
    """List all available labels."""
    labels = manager.list_labels()
    return [LabelResponse(**l) for l in labels]


@app.post("/api/labels", response_model=LabelResponse, status_code=status.HTTP_201_CREATED)
def create_label(req: LabelCreateRequest) -> LabelResponse:
    """Create a new label."""
    if not req.name.strip():
        raise HTTPException(status_code=400, detail="Label name cannot be empty")
    created = manager.create_label(req.name.strip())
    return LabelResponse(**created)


@app.delete("/api/labels/{label_id}")
def delete_label(label_id: str):
    """Delete a label."""
    success = manager.delete_label(label_id)
    if not success:
        raise HTTPException(status_code=404, detail="Label not found")
    return {"success": True, "message": "Label deleted"}
