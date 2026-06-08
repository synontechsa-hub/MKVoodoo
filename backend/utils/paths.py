import sys
from pathlib import Path

def _get_base_path() -> Path:
    """Get the base path of the application, handling frozen (compiled) state."""
    if hasattr(sys, "frozen"):
        # If compiled with Nuitka or similar, use the executable folder
        return Path(sys.executable).parent
    # If running from source
    return Path(__file__).parent.parent

def _default_output_dir() -> Path:
    return Path.cwd() / "MKVoodoo_Output"

def _default_log_dir() -> Path:
    return Path.cwd() / "logs"

def _default_queue_file() -> Path:
    return Path.cwd() / "mkvoodoo_queue.json"

def _default_config_file() -> Path:
    return Path.cwd() / "mkvoodoo_config.json"

def get_ffmpeg_path() -> Path:
    return _get_base_path() / "backend" / "bin" / "ffmpeg.exe"

def get_ffprobe_path() -> Path:
    return _get_base_path() / "backend" / "bin" / "ffprobe.exe"
