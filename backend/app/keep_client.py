import json
import logging
import os
import re
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import gkeepapi
from gkeepapi.node import ColorValue, List as KeepList, Note as KeepNote, TopLevelNode

from app import config
from app.models import ChecklistItem, NoteCreateRequest, NoteResponse, NoteUpdateRequest, StatusResponse

logger = logging.getLogger("knotes.keep")

COLOR_MAP: Dict[str, ColorValue] = {
    "White": ColorValue.White,
    "Red": ColorValue.Red,
    "Orange": ColorValue.Orange,
    "Yellow": ColorValue.Yellow,
    "Green": ColorValue.Green,
    "Teal": ColorValue.Teal,
    "Blue": ColorValue.Blue,
    "DarkBlue": ColorValue.DarkBlue,
    "Purple": ColorValue.Purple,
    "Pink": ColorValue.Pink,
    "Brown": ColorValue.Brown,
    "Gray": ColorValue.Gray,
}

REVERSE_COLOR_MAP: Dict[ColorValue, str] = {v: k for k, v in COLOR_MAP.items()}


class KeepManager:
    """Manages Google Keep synchronization, local offline caching, and note CRUD."""

    def __init__(self) -> None:
        self.lock = threading.RLock()
        self.keep = gkeepapi.Keep()
        self.authenticated = False
        self.email: Optional[str] = None
        self.master_token: Optional[str] = None
        self.sync_status = "offline"
        self.last_synced: Optional[str] = None
        self._init_storage()
        self._start_periodic_sync()

    def _start_periodic_sync(self) -> None:
        """Run periodic background sync every 60 seconds when online."""
        def loop():
            import time
            while True:
                time.sleep(60)
                if self.authenticated and self.sync_status != "syncing":
                    try:
                        self.sync()
                    except Exception as e:
                        logger.warning("Periodic background sync: %s", e)
        t = threading.Thread(target=loop, daemon=True, name="KeepAutoSync")
        t.start()

    def _init_storage(self) -> None:
        """Initialize local cache directory and state."""
        config.ensure_secure_dir()

        # 1. Restore local notes cache if available
        has_local_cache = False
        if config.STATE_FILE.exists():
            try:
                with open(config.STATE_FILE, "r", encoding="utf-8") as f:
                    state = json.load(f)
                self.keep.restore(state)
                has_local_cache = True
                logger.info("Restored local state from %s", config.STATE_FILE)
            except Exception as e:
                logger.warning("Failed to restore local state: %s", e)

        # 2. If no local cache exists, seed welcome notes for instant high-fidelity experience
        if not has_local_cache or len(list(self.keep.all())) == 0:
            self._seed_welcome_notes()
            self._save_state_to_disk()

        # 3. Attempt to resume existing session if session.json exists
        self._attempt_auto_resume()

    def _seed_welcome_notes(self) -> None:
        """Seed rich Notes style welcome notes."""
        welcome_note = self.keep.createNote(
            "Welcome to KNotes ",
            "KNotes brings the iconic Notes experience to Google Keep on macOS.\n\n"
            "✨ Features:\n"
            "• Native macOS UI with sidebar, search, and vibrant glass design\n"
            "• Bidirectional cloud sync with Google Keep via gkeepapi\n"
            "• Full offline support — read and write notes anytime\n"
            "• Checklists, tags/labels, and Apple-curated color themes\n"
            "• Fast search and native keyboard shortcuts (⌘N for new note)\n\n"
            "To connect your Google Keep account, click the Account status at the bottom of the sidebar "
            "or use the Settings sheet.",
        )
        welcome_note.pinned = True
        welcome_note.color = ColorValue.Yellow

        lbl_work = self.keep.createLabel("Work")
        lbl_personal = self.keep.createLabel("Personal")
        welcome_note.labels.add(lbl_work)

        quick_start = self.keep.createList(
            "Quick Start Checklist 📋",
            [
                ("Explore the native 3-column macOS interface", True),
                ("Create your first note or checklist (⌘N)", True),
                ("Try changing note colors from the toolbar palette", False),
                ("Add a custom tag / label", False),
                ("Sign in to Google Keep in Account Settings", False),
            ],
        )
        quick_start.pinned = True
        quick_start.color = ColorValue.Teal
        quick_start.labels.add(lbl_personal)

        ideas_note = self.keep.createNote(
            "Project Ideas 💡",
            "• Build a native menu bar quick-capture extension\n"
            "• Add drag and drop reordering for checklist items\n"
            "• Rich markdown formatting preview\n"
            "• Siri Shortcuts and Raycast integration",
        )
        ideas_note.color = ColorValue.Purple
        ideas_note.labels.add(lbl_work)

    def _attempt_auto_resume(self) -> None:
        """Attempt to restore authentication session from disk."""
        if not config.SESSION_FILE.exists():
            return

        try:
            with open(config.SESSION_FILE, "r", encoding="utf-8") as f:
                session_data = json.load(f)

            email = session_data.get("email")
            master_token = session_data.get("master_token")

            if email and master_token:
                self.email = email
                self.master_token = master_token
                # Try authenticating in background or mark authenticated
                try:
                    state = self.keep.dump()
                    self.keep.authenticate(email, master_token, state=state, sync=True)
                    self.authenticated = True
                    self.sync_status = "synced"
                    self.last_synced = datetime.now(timezone.utc).isoformat()
                    self._save_state_to_disk()
                    logger.info("Auto-resumed Google Keep session for user")
                except Exception as auth_err:
                    logger.warning("Session resume sync failed (working offline): %s", auth_err)
                    self.authenticated = True
                    self.sync_status = "offline"
        except Exception as e:
            logger.warning("Error reading session file: %s", e)

    def _save_state_to_disk(self) -> None:
        """Serialize current keep state to disk with 0600 permissions."""
        with self.lock:
            try:
                state = self.keep.dump()
                tmp_file = config.STATE_FILE.with_suffix(".tmp")
                with open(tmp_file, "w", encoding="utf-8") as f:
                    json.dump(state, f)
                try:
                    os.chmod(tmp_file, 0o600)
                except OSError:
                    pass
                tmp_file.replace(config.STATE_FILE)
            except Exception as e:
                logger.error("Failed to save state to disk: %s", e)

    def _save_session(self, email: str, master_token: str) -> None:
        """Persist session credentials with restricted permissions (0600)."""
        config.ensure_secure_dir()
        tmp_file = config.SESSION_FILE.with_suffix(".tmp")
        data = {
            "email": email,
            "master_token": master_token,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
        with open(tmp_file, "w", encoding="utf-8") as f:
            json.dump(data, f)
        try:
            os.chmod(tmp_file, 0o600)
        except OSError:
            pass
        tmp_file.replace(config.SESSION_FILE)

    def _clear_session(self) -> None:
        """Remove session file on logout."""
        if config.SESSION_FILE.exists():
            try:
                config.SESSION_FILE.unlink()
            except OSError:
                pass

    def login(
        self,
        email: str,
        password: Optional[str] = None,
        master_token: Optional[str] = None,
    ) -> Tuple[bool, str]:
        """Authenticate with Google Keep using App Password or Master Token."""
        with self.lock:
            try:
                state = self.keep.dump()
                clean_email = email.strip()
                token_to_use = master_token.strip() if master_token else None
                if not token_to_use and password and (password.startswith("oauth2_4/") or password.startswith("oauth2rt_") or password.startswith("aas_et/")):
                    token_to_use = password.strip()

                if token_to_use:
                    if token_to_use.startswith("oauth2_4/"):
                        import gpsoauth, uuid
                        device_id = f"{uuid.getnode():x}"
                        exchange_res = gpsoauth.exchange_token(clean_email, token_to_use, device_id)
                        if "Token" not in exchange_res:
                            err = exchange_res.get("Error", "Unknown exchange error")
                            return False, f"OAuth Token exchange failed: {err}. Please ensure you copied the complete oauth_token cookie."
                        token_to_use = exchange_res["Token"]

                    self.keep.authenticate(clean_email, token_to_use, state=state, sync=True)
                    token = token_to_use
                elif password:
                    clean_pw = password.strip().replace(" ", "")
                    try:
                        self.keep.login(clean_email, clean_pw, state=state, sync=True)
                        token = self.keep.getMasterToken()
                    except gkeepapi.exception.LoginException as le:
                        if "BadAuthentication" in str(le):
                            return False, (
                                "Google has discontinued password and App Password authentication for the unofficial Keep API. "
                                "Please use the 'Google Master Token' method instead (click 'Use Master Token' in KNotes or run scripts/get_master_token.py)."
                            )
                        raise
                else:
                    return False, "Password or master token is required."

                self.email = email
                self.master_token = token
                self.authenticated = True
                self.sync_status = "synced"
                self.last_synced = datetime.now(timezone.utc).isoformat()

                self._save_session(email, token)
                self._save_state_to_disk()
                return True, "Successfully authenticated with Google Keep."
            except gkeepapi.exception.LoginException as le:
                logger.warning("Google Keep login failed: %s", str(le))
                return False, f"Login failed: {str(le)}. If 2FA is enabled, please use a Google App Password."
            except Exception as e:
                logger.error("Unexpected login error: %s", e)
                return False, "An error occurred during authentication. Please check your credentials."

    def logout(self) -> None:
        """Log out from Google Keep and revert to local mode."""
        with self.lock:
            self.authenticated = False
            self.email = None
            self.master_token = None
            self.sync_status = "offline"
            self._clear_session()

    def sync(self) -> Tuple[bool, str]:
        """Trigger sync with Google Keep."""
        with self.lock:
            if not self.authenticated:
                return True, "Working in local mode (not connected to Google Keep)."

            self.sync_status = "syncing"
            try:
                self.keep.sync()
                self.sync_status = "synced"
                self.last_synced = datetime.now(timezone.utc).isoformat()
                self._save_state_to_disk()
                return True, "Successfully synced with Google Keep."
            except Exception as e:
                self.sync_status = "error"
                logger.error("Sync failed: %s", e)
                return False, f"Sync error: {str(e)}"

    def get_status(self) -> StatusResponse:
        """Get current system status and counts."""
        with self.lock:
            all_notes = list(self.keep.all())
            active_notes = [n for n in all_notes if not n.trashed and not n.archived]
            pinned_notes = [n for n in active_notes if n.pinned]
            archived_notes = [n for n in all_notes if n.archived and not n.trashed]
            trash_notes = [n for n in all_notes if n.trashed]
            quick_notes = [n for n in active_notes if any(lbl.name.lower() == "quick notes" for lbl in n.labels.all())]

            masked_email = None
            if self.email:
                parts = self.email.split("@")
                if len(parts) == 2 and len(parts[0]) > 2:
                    masked_email = f"{parts[0][:2]}***@{parts[1]}"
                else:
                    masked_email = self.email

            return StatusResponse(
                authenticated=self.authenticated,
                email=self.email or masked_email,
                sync_status=self.sync_status,
                last_synced=self.last_synced,
                total_notes=len(active_notes),
                pinned_notes=len(pinned_notes),
                archived_notes=len(archived_notes),
                trash_notes=len(trash_notes),
                quick_notes=len(quick_notes),
            )

    def _node_to_response(self, node: TopLevelNode) -> NoteResponse:
        """Convert a gkeepapi TopLevelNode to a NoteResponse model."""
        is_list = isinstance(node, KeepList)
        items: List[ChecklistItem] = []

        if is_list:
            for item in getattr(node, "items", []):
                items.append(
                    ChecklistItem(
                        id=str(item.id) if item.id else None,
                        text=item.text or "",
                        checked=bool(item.checked),
                    )
                )

        labels = [l.name for l in node.labels.all()]
        color_name = "White"
        if hasattr(node, "color") and node.color is not None:
            if hasattr(node.color, "name"):
                color_name = node.color.name
            elif node.color in REVERSE_COLOR_MAP:
                color_name = REVERSE_COLOR_MAP[node.color]

        collaborators: List[str] = []
        if hasattr(node, "collaborators"):
            try:
                for c in node.collaborators.all():
                    if isinstance(c, str):
                        collaborators.append(c)
                    elif hasattr(c, "email") and c.email:
                        collaborators.append(c.email)
            except Exception:
                pass

        created_str = None
        updated_str = None
        if hasattr(node, "timestamps"):
            if node.timestamps.created:
                created_str = node.timestamps.created.isoformat()
            if node.timestamps.updated:
                updated_str = node.timestamps.updated.isoformat()

        return NoteResponse(
            id=node.id,
            title=node.title or "",
            text=node.text or "",
            is_list=is_list,
            items=items,
            color=color_name,
            pinned=bool(node.pinned),
            archived=bool(node.archived),
            trashed=bool(node.trashed),
            labels=labels,
            collaborators=collaborators,
            created=created_str,
            updated=updated_str,
        )

    def list_notes(
        self,
        folder: str = "all",
        label: Optional[str] = None,
        query: Optional[str] = None,
    ) -> List[NoteResponse]:
        """List and filter notes according to folder, label, and search query."""
        with self.lock:
            all_nodes = list(self.keep.all())

            filtered: List[TopLevelNode] = []
            for n in all_nodes:
                # 1. Folder filtering
                if folder == "trash":
                    if not n.trashed:
                        continue
                elif folder == "archived":
                    if n.trashed or not n.archived:
                        continue
                elif folder == "pinned":
                    if n.trashed or n.archived or not n.pinned:
                        continue
                elif folder == "quick":
                    if n.trashed or n.archived:
                        continue
                    if not any(lbl.name.lower() == "quick notes" for lbl in n.labels.all()):
                        continue
                elif folder == "all":
                    if n.trashed or n.archived:
                        continue

                # 2. Label filtering
                if label:
                    node_label_names = [lbl.name.lower() for lbl in n.labels.all()]
                    if label.lower() not in node_label_names:
                        continue

                # 3. Query search (case-insensitive across title, text, and list items)
                if query:
                    q = query.lower()
                    title_match = q in (n.title or "").lower()
                    text_match = q in (n.text or "").lower()
                    item_match = False
                    if isinstance(n, KeepList):
                        item_match = any(q in (it.text or "").lower() for it in n.items)
                    label_match = any(q in lbl.name.lower() for lbl in n.labels.all())

                    if not (title_match or text_match or item_match or label_match):
                        continue

                filtered.append(n)

            # Sort: Pinned first, then by updated timestamp descending
            def sort_key(node: TopLevelNode):
                ts = (
                    node.timestamps.updated.timestamp()
                    if hasattr(node, "timestamps") and node.timestamps.updated
                    else 0
                )
                return (1 if node.pinned else 0, ts)

            filtered.sort(key=sort_key, reverse=True)
            return [self._node_to_response(n) for n in filtered]

    def get_note(self, note_id: str) -> Optional[NoteResponse]:
        """Fetch a single note by ID."""
        with self.lock:
            node = self.keep.get(note_id)
            if not node:
                return None
            return self._node_to_response(node)

    def create_note(self, req: NoteCreateRequest) -> NoteResponse:
        """Create a new note or list."""
        with self.lock:
            if req.is_list:
                items_tuples = [(it.text, it.checked) for it in req.items]
                node = self.keep.createList(req.title or "", items_tuples)
            else:
                node = self.keep.createNote(req.title or "", req.text or "")

            if req.color in COLOR_MAP:
                node.color = COLOR_MAP[req.color]

            node.pinned = req.pinned
            if req.archived:
                node.archived = True

            if req.collaborators:
                for col_email in req.collaborators:
                    try:
                        node.collaborators.add(col_email)
                    except Exception as e:
                        logger.warning("Could not add collaborator %s: %s", col_email, e)

            # Assign labels
            for lbl_name in req.labels:
                lbl = self.keep.findLabel(lbl_name)
                if not lbl:
                    lbl = self.keep.createLabel(lbl_name)
                node.labels.add(lbl)

            self._save_state_to_disk()

            # Background sync if connected
            if self.authenticated:
                threading.Thread(target=self._safe_bg_sync, daemon=True).start()

            return self._node_to_response(node)

    def update_note(self, note_id: str, req: NoteUpdateRequest) -> Optional[NoteResponse]:
        """Update an existing note."""
        with self.lock:
            node = self.keep.get(note_id)
            if not node:
                return None

            if req.title is not None:
                node.title = req.title

            if req.color is not None and req.color in COLOR_MAP:
                node.color = COLOR_MAP[req.color]

            if req.pinned is not None:
                node.pinned = req.pinned

            if req.archived is not None:
                node.archived = req.archived

            if req.collaborators is not None:
                try:
                    for c in list(node.collaborators.all()):
                        node.collaborators.remove(c)
                    for col_email in req.collaborators:
                        node.collaborators.add(col_email)
                except Exception as e:
                    logger.warning("Could not update collaborators: %s", e)

            if req.trashed is not None:
                if req.trashed and not node.trashed:
                    node.trash()
                elif not req.trashed and node.trashed:
                    node.untrash()

            # Handle list vs text conversion or content update
            if req.is_list is not None and req.is_list != isinstance(node, KeepList):
                # Conversion between Note and List
                title = node.title
                pinned = node.pinned
                archived = node.archived
                color = node.color
                labels = list(node.labels.all())

                if req.is_list:
                    # Note -> List
                    items_tuples = []
                    if req.items:
                        items_tuples = [(it.text, it.checked) for it in req.items]
                    elif node.text:
                        lines = [l.strip() for l in node.text.split("\n") if l.strip()]
                        items_tuples = [(l, False) for l in lines]
                    new_node = self.keep.createList(title, items_tuples)
                else:
                    # List -> Note
                    text = req.text if req.text is not None else ""
                    if not text and isinstance(node, KeepList):
                        text = "\n".join([f"- {it.text}" for it in node.items])
                    new_node = self.keep.createNote(title, text)

                new_node.pinned = pinned
                new_node.archived = archived
                new_node.color = color
                for lbl in labels:
                    new_node.labels.add(lbl)

                node.delete()
                node = new_node
            else:
                # Same type update
                if isinstance(node, KeepList):
                    if req.items is not None:
                        # Clear existing items and repopulate preserving order
                        for item in list(node.items):
                            node.remove(item)
                        base_sort = 10000000000
                        for i, it in enumerate(req.items):
                            node.add(it.text, it.checked, sort=base_sort - i * 1000)
                else:
                    if req.text is not None:
                        node.text = req.text

            # Update labels if provided
            if req.labels is not None:
                for existing_lbl in list(node.labels.all()):
                    node.labels.remove(existing_lbl)
                for lbl_name in req.labels:
                    lbl = self.keep.findLabel(lbl_name)
                    if not lbl:
                        lbl = self.keep.createLabel(lbl_name)
                    node.labels.add(lbl)

            self._save_state_to_disk()

            if self.authenticated:
                threading.Thread(target=self._safe_bg_sync, daemon=True).start()

            return self._node_to_response(node)

    def delete_note(self, note_id: str) -> bool:
        """Trash a note, or permanently delete it if already in trash."""
        with self.lock:
            node = self.keep.get(note_id)
            if not node:
                return False

            if node.trashed:
                node.delete()
            else:
                node.trash()

            self._save_state_to_disk()

            if self.authenticated:
                threading.Thread(target=self._safe_bg_sync, daemon=True).start()

            return True

    def untrash_note(self, note_id: str) -> Optional[NoteResponse]:
        """Restore a note from trash."""
        with self.lock:
            node = self.keep.get(note_id)
            if not node:
                return None
            node.untrash()
            self._save_state_to_disk()

            if self.authenticated:
                threading.Thread(target=self._safe_bg_sync, daemon=True).start()

            return self._node_to_response(node)

    def list_labels(self) -> List[Dict[str, str]]:
        """List all available labels."""
        with self.lock:
            return [{"id": lbl.id, "name": lbl.name} for lbl in self.keep.labels()]

    def create_label(self, name: str) -> Dict[str, str]:
        """Create a new label."""
        with self.lock:
            existing = self.keep.findLabel(name)
            if existing:
                return {"id": existing.id, "name": existing.name}
            lbl = self.keep.createLabel(name)
            self._save_state_to_disk()
            if self.authenticated:
                threading.Thread(target=self._safe_bg_sync, daemon=True).start()
            return {"id": lbl.id, "name": lbl.name}

    def delete_label(self, label_id: str) -> bool:
        """Delete an existing label."""
        with self.lock:
            lbl = self.keep.getLabel(label_id)
            if not lbl:
                return False
            self.keep.deleteLabel(lbl)
            self._save_state_to_disk()
            if self.authenticated:
                threading.Thread(target=self._safe_bg_sync, daemon=True).start()
            return True

    def _safe_bg_sync(self) -> None:
        """Helper to run sync in background thread safely without exceptions crashing."""
        try:
            self.sync()
        except Exception as e:
            logger.error("Background sync error: %s", e)
