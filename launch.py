import subprocess
import sys
import os
from pathlib import Path


def main():
    root = Path(__file__).parent.resolve()
    frontend_dir = root / "frontend"
    venv_python = root / ".venv" / "Scripts" / "python.exe"

    print("🚀 MKVoodoo v1.0.0 Launcher")
    print("━" * 30)

    # 1. Check Environment
    if not venv_python.exists():
        print("❌ Error: Virtual environment (.venv) not found.")
        print("   Please run 'python -m venv .venv' and install dependencies.")
        sys.exit(1)

    # 2. Check Flutter
    flutter_cmd = "flutter.bat" if os.name == "nt" else "flutter"
    try:
        subprocess.run(
            [flutter_cmd, "--version"],
            capture_output=True,
            check=True,
            shell=(os.name == "nt"),
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("❌ Error: Flutter SDK not found in PATH.")
        print("   If you have Flutter installed, make sure it's added to your System Environment Variables.")
        sys.exit(1)

    # 3. Verify backend is reachable before launching UI
    print("🔍 Checking backend...")
    try:
        result = subprocess.run(
            [str(venv_python), "-m", "backend.main", "--help"],
            cwd=str(root),
            capture_output=True,
            timeout=10,
        )
        if result.returncode == 0:
            print("✅ Environment: OK")
            print("✅ Backend: Ready")
        else:
            print("⚠️  Backend check failed — module may be missing.")
            print("   Try: pip install -e .")
    except Exception as e:
        print(f"⚠️  Backend check error: {e}")

    print("📡 Launching UI...")
    print("━" * 30)

    # 4. Launch UI
    print("📡 Launching UI...")
    print("━" * 30)

    # Path to release executable
    release_exe = frontend_dir / "build" / "windows" / "x64" / "release" / "runner" / "mkvoodoo_ui.exe"
    
    env = os.environ.copy()
    env["MKVOODOO_ROOT"] = str(root)

    if release_exe.exists():
        print("🚀 Mode: RELEASE (Compiled Binary)")
        try:
            subprocess.run([str(release_exe)], cwd=str(root), env=env)
        except Exception as e:
            print(f"❌ Failed to launch release binary: {e}")
    else:
        print("🛠 Mode: DEV (flutter run)")
        print("💡 Tip: Run 'flutter build windows --release' to compile for distribution.")
        try:
            subprocess.run(
                ["flutter", "run", "-d", "windows"],
                cwd=str(frontend_dir),
                shell=True,
                env=env,
            )
        except KeyboardInterrupt:
            print("\n👋 Launcher closed.")


if __name__ == "__main__":
    main()
