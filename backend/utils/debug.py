import platform
import sys
import json
from pathlib import Path
from backend.services.hardware_service import HardwareService
from backend.services.config_service import ConfigService

def get_debug_info() -> str:
    """Gather system and app info for bug reporting."""
    hw = HardwareService()
    cfg = ConfigService().load()
    
    # Get best encoder info
    try:
        best = hw.detect_best_encoder(force=cfg.force_encoder)
        gpu_info = f"{best.label} ({best.video_encoder})"
    except Exception as e:
        gpu_info = f"Detection Error: {e}"

    info = [
        "--- MKVoodoo Debug Report ---",
        f"Version: 1.0.0",
        f"Platform: {platform.system()} {platform.release()} ({platform.architecture()[0]})",
        f"Python: {sys.version.split(' ')[0]}",
        f"Encoder: {gpu_info}",
        f"Parallel Jobs: {cfg.parallel_jobs}",
        f"Output Path: {cfg.output_dir}",
        "----------------------------"
    ]
    return "\n".join(info)

if __name__ == "__main__":
    # If run directly, just print the info
    print(get_debug_info())
