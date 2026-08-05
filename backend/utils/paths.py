import sys
import os
from pathlib import Path

def _get_base_path() -> Path:
    """Get the base path of the application, handling Nuitka/frozen state."""
    # Nuitka and other compilers set sys.frozen or __compiled__
    if hasattr(sys, "frozen") or "__compiled__" in globals():
        return Path(sys.executable).parent.resolve()
    
    # If running from source (dev)
    return Path(__file__).parent.parent.resolve()

def _get_user_data_dir() -> Path:
    """Get the directory for user-writable data (config, queue, logs)."""
    if os.name == "nt":
        # Windows: %APPDATA%/MKVoodoo
        base = Path(os.environ.get("APPDATA", str(Path.home() / "AppData" / "Roaming")))
    else:
        # Linux/macOS: ~/.mkvoodoo
        base = Path.home()
        
    path = (base / "MKVoodoo").resolve()
    path.mkdir(parents=True, exist_ok=True)
    return path

def _default_output_dir() -> Path:
    return (Path.home() / "Videos" / "MKVoodoo_Output").resolve()

def _default_log_dir() -> Path:
    return _get_user_data_dir() / "logs"

def _default_queue_file() -> Path:
    return _get_user_data_dir() / "mkvoodoo_queue.json"

def _default_config_file() -> Path:
    return _get_user_data_dir() / "mkvoodoo_config.json"

def _get_downloads_dir() -> Path:
    path = _get_user_data_dir() / "downloads"
    path.mkdir(parents=True, exist_ok=True)
    return path

import shutil

def get_ffmpeg_path() -> Path:
    # Always look for the bundled binary in the expected relative location first
    bundled = _get_base_path() / "backend" / "bin" / "ffmpeg.exe"
    if bundled.exists():
        return bundled
    dev_path = _get_base_path().parent / "backend" / "bin" / "ffmpeg.exe"
    if dev_path.exists():
        return dev_path
    sys_path = shutil.which("ffmpeg")
    if sys_path:
        return Path(sys_path)
    return bundled

def get_ffprobe_path() -> Path:
    bundled = _get_base_path() / "backend" / "bin" / "ffprobe.exe"
    if bundled.exists():
        return bundled
    dev_path = _get_base_path().parent / "backend" / "bin" / "ffprobe.exe"
    if dev_path.exists():
        return dev_path
    sys_path = shutil.which("ffprobe")
    if sys_path:
        return Path(sys_path)
    return bundled

def get_ytdlp_path() -> Path:
    bundled = _get_base_path() / "backend" / "bin" / "yt-dlp.exe"
    if bundled.exists():
        return bundled
    dev_path = _get_base_path().parent / "backend" / "bin" / "yt-dlp.exe"
    if dev_path.exists():
        return dev_path
    sys_path = shutil.which("yt-dlp")
    if sys_path:
        return Path(sys_path)
    return bundled
