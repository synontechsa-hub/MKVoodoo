from pathlib import Path

def _default_output_dir() -> Path:
    return Path.cwd() / "MKVoodoo_Output"

def _default_log_dir() -> Path:
    return Path.cwd() / "logs"

def _default_queue_file() -> Path:
    return Path.cwd() / "mkvoodoo_queue.json"

def _default_config_file() -> Path:
    return Path.cwd() / "mkvoodoo_config.json"

def get_ffmpeg_path() -> Path:
    return Path(__file__).parent.parent / "bin" / "ffmpeg.exe"

def get_ffprobe_path() -> Path:
    return Path(__file__).parent.parent / "bin" / "ffprobe.exe"
