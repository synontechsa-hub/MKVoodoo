# MKVoodoo 🪄📽️

**MKVoodoo** is a powerful, offline batch video transcoder designed for media enthusiasts. It combines a sleek Flutter-based UI with a high-performance Python backend to provide a seamless transcoding experience with full hardware acceleration support.

![Version](https://img.shields.io/badge/version-1.0.0-blueviolet)
![License](https://img.shields.io/badge/license-MIT-green)

---

## ✨ Features

*   **🚀 Hardware Acceleration**: Automatic detection and support for **NVIDIA NVENC** and **Intel QuickSync (QSV)** for lightning-fast encoding.
*   **🧵 Parallel Processing**: Run multiple conversion jobs simultaneously (configurable in settings).
*   **🧠 Smart Naming**: Automatically parses filenames to detect Seasons and Episodes, applying customizable naming templates.
*   **📂 Queue Management**: Add files or entire folders to a persistent queue. Resume interrupted jobs and track conversion history.
*   **🎧 Track Control**: Select specific audio and subtitle tracks or keep them all. Auto-conversion of audio to high-quality AAC.
*   **💾 Storage Aware**: Real-time disk space monitoring to ensure you never run out of room during a batch.
*   **📦 Portable Backend**: The backend is compiled into a standalone executable using Nuitka, ensuring no Python installation is required for the end user.

---

## 🛠️ Project Structure

*   `/frontend`: Flutter application (the "magic" UI).
*   `/backend`: Python core logic and FFmpeg orchestration.
*   `/main.dist`: Compiled standalone backend executable.
*   `mkvoodoo.iss`: Inno Setup script for generating the Windows installer.

---

## 🚀 Getting Started (Development)

### Prerequisites
*   **Flutter SDK** (^3.11.4)
*   **Python** (3.13 or 3.14)
*   **FFmpeg** (Included in `backend/bin/`)

### Setup
1.  **Backend**:
    ```bash
    python -m venv .venv
    source .venv/bin/activate  # or .venv\Scripts\activate
    pip install -r requirements.txt
    ```
2.  **Frontend**:
    ```bash
    cd frontend
    flutter pub get
    ```

### Building for Release
1.  **Compile Backend**:
    ```bash
    python -m nuitka --standalone --enable-plugin=tk-inter --output-filename=mkvoodoo_backend.exe backend/main.py
    ```
2.  **Build UI**:
    ```bash
    cd frontend
    flutter build windows --release
    ```
3.  **Create Installer**:
    Run `mkvoodoo.iss` through Inno Setup Compiler (F9).

---

## 📜 License
This project is licensed under the MIT License - see the `LICENSE.txt` file for details.

---
*Created with ❤️ by SynonTech*
