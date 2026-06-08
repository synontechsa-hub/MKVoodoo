import sys
import os
from pathlib import Path

def _get_base_path() -> Path:
    """Get the base path of the application, handling Nuitka/frozen state."""
    # Nuitka and other compilers set sys.frozen or __compiled__
    if hasattr(sys, "frozen") or "__compiled__" in globals():
        return Path(sys.executable).parent
    
    # If running from source (dev)
    return Path(__file__).parent.parent

def _get_user_data_dir() -> Path:
    """Get the directory for user-writable data (config, queue, logs)."""
    if os.name == "nt":
        # Windows: %APPDATA%/MKVoodoo
        base = Path(os.environ.get("APPDATA", str(Path.home() / "AppData" / "Roaming")))
    else:
        # Linux/macOS: ~/.mkvoodoo
        base = Path.home()
        
    path = base / "MKVoodoo"
    path.mkdir(parents=True, exist_ok=True)
    return path

def _default_output_dir() -> Path:
    return Path.home() / "Videos" / "MKVoodoo_Output"

def _default_log_dir() -> Path:
    return _get_user_data_dir() / "logs"

def _default_queue_file() -> Path:
    return _get_user_data_dir() / "mkvoodoo_queue.json"

def _default_config_file() -> Path:
    return _get_user_data_dir() / "mkvoodoo_config.json"

def get_ffmpeg_path() -> Path:
    # Always look for the bundled binary in the expected relative location first
    bundled = _get_base_path() / "backend" / "bin" / "ffmpeg.exe"
    if bundled.exists():
        return bundled
    # Fallback for dev environment structures
    return _get_base_path().parent / "backend" / "bin" / "ffmpeg.exe"

def get_ffprobe_path() -> Path:
    bundled = _get_base_path() / "backend" / "bin" / "ffprobe.exe"
    if bundled.exists():
        return bundled
    return _get_base_path().parent / "backend" / "bin" / "ffprobe.exe"
