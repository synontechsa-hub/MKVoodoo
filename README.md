# MKVoodoo 🪄📽️

**MKVoodoo** is a powerful, offline-first batch video transcoder and media management suite designed for anime and video enthusiasts. It pairs a modern Flutter desktop user interface with a high-performance Python core and FFmpeg engine for seamless hardware-accelerated encoding.

![Version](https://img.shields.io/badge/version-1.1.0-blueviolet)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Windows-blue)

---

## ✨ Key Features in v1.1.0

*   **🚀 Hardware Acceleration**: Automatic discovery and fail-safe selection for **NVIDIA NVENC** (`h264_nvenc`) and **Intel QuickSync** (`h264_qsv`), with automatic fallback to high-quality CPU encoding (`libx264`).
*   **📥 Integrated YouTube & Media Downloader**: Download videos or extract audio (MP3, FLAC, M4A, MP4) directly from YouTube and supported web sources via `yt-dlp`, with 1-click batch queue ingestion.
*   **🧵 Parallel Transcoding Engine**: Run up to 8 conversion jobs concurrently with thread-safe queue management and real-time progress callbacks.
*   **🧠 Smart Naming & Directory Mirroring**: Automatically parses Season and Episode numbers, retains folder structures, and applies customizable output template formats (e.g. `S{Season}E{Episode} - {Title}.mkv`).
*   **🎧 Multi-Stream Preservation**: Preserves all original audio and subtitle streams (soft subs) without forced burn-in, with customizable per-track strategy controls.
*   **💾 Disk Space & Safety Monitoring**: Real-time storage checks prevent disk-full crashes, and input files are treated as immutable (no in-place overwrite).
*   **📦 Standalone Portable Binary**: Pre-compiled standalone backend via Nuitka and packaged using Inno Setup installer (`MKVoodoo_v1.1.0_Setup.exe`).

---

## 🛠️ Project Structure

*   `/frontend`: Flutter desktop UI application.
*   `/backend`: Python backend services, FFmpeg engine orchestration, and CLI handlers.
*   `/main.dist`: Nuitka pre-compiled backend binary environment.
*   `mkvoodoo.iss`: Inno Setup compiler script for building the Windows setup executable.
*   `CHANGELOG.md`: Chronological log of features, fixes, and release notes.

---

## 🚀 Installation & Usage

### 📥 End-User Setup
Download and run the pre-built Windows installer:
- **`MKVoodoo_v1.1.0_Setup.exe`**

### 💻 Developer Setup & Build

#### Prerequisites
*   **Flutter SDK** (^3.11.4)
*   **Python** (3.13 or 3.14)
*   **FFmpeg / FFprobe** (Included in `backend/bin/`)

#### 1. Setup Backend Environment
```powershell
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

#### 2. Run Tests & Quality Checks
```powershell
# Run Pytest suite
python -m pytest

# Run Mypy static type checking
python -m mypy backend/

# Run Flake8 linter
python -m flake8 backend/ --max-line-length=120
```

#### 3. Compile Standalone Release Build
```powershell
# Compile standalone Python backend
python -m nuitka --standalone --enable-plugin=tk-inter --output-filename=mkvoodoo_backend.exe backend/main.py

# Build Flutter release runner
cd frontend
flutter build windows --release
cd ..

# Build Inno Setup Installer
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" mkvoodoo.iss
```

---

## 📜 License
This project is licensed under the MIT License - see the [LICENSE.txt](file:///d:/Coding/Synontech/MKVoodoo/LICENSE.txt) file for details.

---
*Created with ❤️ by SynonTech*
