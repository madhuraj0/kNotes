import sys
from pathlib import Path
import uvicorn

# Add current directory to path
backend_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(backend_dir))

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
