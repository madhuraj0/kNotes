import os
import sys
from pathlib import Path

# Add backend directory to sys.path
backend_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(backend_dir))

home = Path.home()
knotes_dir = home / ".knotes"
knotes_dir.mkdir(parents=True, exist_ok=True)
try:
    os.chdir(str(knotes_dir))
except Exception:
    pass

# Automatically resolve and inject isolated virtualenv site-packages if running with system python
if sys.prefix == sys.base_prefix:
    venv_sp = knotes_dir / "venv" / "lib" / f"python{sys.version_info.major}.{sys.version_info.minor}" / "site-packages"
    if venv_sp.exists() and str(venv_sp) not in sys.path:
        sys.path.insert(0, str(venv_sp))

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
