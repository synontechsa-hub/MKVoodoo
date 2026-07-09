"""
MKVoodoo Hardware Verification Suite
Usage: python scripts/verify_hardware.py
"""

import subprocess
import os
import sys
import time
from pathlib import Path

# Add project root to sys.path
sys.path.append(str(Path(__file__).parent.parent))

from backend.utils.paths import get_ffmpeg_path
from backend.services.hardware_service import HardwareService
from backend.models.hardware import EncoderBackend

def run_stress_test(ffmpeg: str, encoder: str, label: str):
    print(f"Testing {label} ({encoder})...", end=" ", flush=True)
    
    # Create a 5-second test dummy video using color source
    output = f"test_{encoder}.mkv"
    cmd = [
        ffmpeg, "-y", "-hide_banner", "-loglevel", "error",
        "-f", "lavfi", "-i", "color=c=blue:s=1280x720:d=5",
        "-c:v", encoder,
        "-t", "5",
        output
    ]
    
    start = time.monotonic()
    try:
        subprocess.run(cmd, check=True, capture_output=True)
        elapsed = time.monotonic() - start
        print(f"✅ SUCCESS ({elapsed:.1f}s)")
    except subprocess.CalledProcessError as e:
        print(f"❌ FAILED")
        print(f"Error output: {e.stderr.decode('utf-8')}")
    finally:
        if os.path.exists(output):
            os.remove(output)

def main():
    print("━" * 60)
    print("  MKVoodoo Hardware Verification Suite")
    print("━" * 60)
    
    hw_svc = HardwareService()
    ffmpeg = str(get_ffmpeg_path())
    
    print(f"FFmpeg Path: {ffmpeg}")
    print(f"Detected Encoders:")
    
    backends = hw_svc.get_available_backends()
    for b in backends:
        print(f"  - {b.label} [{b.video_encoder}]")
        
    print("\nStarting stress tests...\n")
    
    # 1. CPU Test (Mandatory)
    run_stress_test(ffmpeg, "libx264", "CPU (Software)")
    
    # 2. NVIDIA Test
    if any(b.backend == EncoderBackend.NVENC for b in backends):
        run_stress_test(ffmpeg, "h264_nvenc", "NVIDIA NVENC")
        
    # 3. Intel Test
    if any(b.backend == EncoderBackend.QSV for b in backends):
        run_stress_test(ffmpeg, "h264_qsv", "Intel QuickSync")

    print("\n━" * 60)
    print("  Verification Complete")
    print("━" * 60)

if __name__ == "__main__":
    main()
