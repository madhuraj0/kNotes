from typing import List, Optional
from pydantic import BaseModel, Field

class ChecklistItem(BaseModel):
    id: Optional[str] = None
    text: str = ""
    checked: bool = False

class NoteResponse(BaseModel):
    id: str
    title: str = ""
    text: str = ""
    is_list: bool = False
    items: List[ChecklistItem] = Field(default_factory=list)
    color: str = "White"
    pinned: bool = False
    archived: bool = False
    trashed: bool = False
    labels: List[str] = Field(default_factory=list)
    collaborators: List[str] = Field(default_factory=list)
    created: Optional[str] = None
    updated: Optional[str] = None

class NoteCreateRequest(BaseModel):
    title: str = ""
    text: str = ""
    is_list: bool = False
    items: List[ChecklistItem] = Field(default_factory=list)
    color: str = "White"
    pinned: bool = False
    archived: bool = False
    labels: List[str] = Field(default_factory=list)
    collaborators: List[str] = Field(default_factory=list)

class NoteUpdateRequest(BaseModel):
    title: Optional[str] = None
    text: Optional[str] = None
    is_list: Optional[bool] = None
    items: Optional[List[ChecklistItem]] = None
    color: Optional[str] = None
    pinned: Optional[bool] = None
    archived: Optional[bool] = None
    trashed: Optional[bool] = None
    labels: Optional[List[str]] = None
    collaborators: Optional[List[str]] = None

class LabelResponse(BaseModel):
    id: str
    name: str

class LabelCreateRequest(BaseModel):
    name: str

class LoginRequest(BaseModel):
    email: str
    password: Optional[str] = None
    master_token: Optional[str] = None

class StatusResponse(BaseModel):
    authenticated: bool
    email: Optional[str] = None
    sync_status: str
    last_synced: Optional[str] = None
    total_notes: int = 0
    pinned_notes: int = 0
    archived_notes: int = 0
    trash_notes: int = 0
    quick_notes: int = 0
