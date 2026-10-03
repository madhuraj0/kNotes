import os
import sys
from pathlib import Path

# Add backend directory to sys.path
backend_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(backend_dir))

# Automatically resolve and inject virtualenv site-packages
home = Path.home()
candidate_site_packages = [
    home / ".knotes" / "venv" / "lib" / f"python{sys.version_info.major}.{sys.version_info.minor}" / "site-packages",
    backend_dir.parent / ".venv" / "lib" / f"python{sys.version_info.major}.{sys.version_info.minor}" / "site-packages",
    backend_dir / ".venv" / "lib" / f"python{sys.version_info.major}.{sys.version_info.minor}" / "site-packages",
]

for sp in candidate_site_packages:
    if sp.exists() and str(sp) not in sys.path:
        sys.path.insert(0, str(sp))

import uvicorn
from app import config

if __name__ == "__main__":
    print(f"Starting KNotes backend on {config.HOST}:{config.PORT}...")
    uvicorn.run(
        "app.main:app",
        host=config.HOST,
        port=config.PORT,
        log_level="info",
        reload=False,
    )
