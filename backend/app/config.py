import os
from pathlib import Path

HOST = "127.0.0.1"
PORT = int(os.environ.get("KNOTES_PORT", "8765"))

DATA_DIR = Path(os.environ.get("KNOTES_DATA_DIR", str(Path.home() / ".knotes")))
SESSION_FILE = DATA_DIR / "session.json"
STATE_FILE = DATA_DIR / "state.json"

def ensure_secure_dir() -> None:
    """Ensure data directory exists with restricted user-only permissions (0700)."""
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    try:
        os.chmod(DATA_DIR, 0o700)
    except OSError:
        pass
