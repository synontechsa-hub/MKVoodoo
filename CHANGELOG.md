# Changelog — MKVoodoo

All notable changes to the MKVoodoo project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.1] — 2026-08-13 (*Voodoo Master*)

### 🐛 Fixed
- **YouTube Downloader Packaging**: Bundled the official `yt-dlp.exe` Windows executable (2026.07.04), which was referenced by the application and installer but absent from v1.0.3.
- **Actionable Downloader Errors**: Missing downloader installations now report the expected path and recommend reinstalling instead of returning a low-level process-launch error.
- **Download Diagnostics**: Failed downloads now retain the final `yt-dlp` diagnostic line so common YouTube-side failures can be understood from the UI.

### ⚙️ Release Maintenance
- Synchronized the release version as `1.1.1` across the Python package, backend manifest, Flutter package, README, and Inno Setup installer.

---

## [1.1.0] — 2026-08-05 (*Voodoo Master*)

### 🚀 Added
- **Windows Installer Integration**: Added `mkvoodoo.iss` Inno Setup configuration for generating standalone executable installers (`MKVoodoo_v1.0.3_Setup.exe`).
- **YouTube / Media Downloader**: Added YouTube video/audio downloader tab powered by `yt-dlp` with format selection (MP3, FLAC, M4A, MP4) and direct batch queue ingestion.
- **Robust Executable Path Resolution**: Added automatic `shutil.which` system path fallback discovery for `ffmpeg.exe`, `ffprobe.exe`, and `yt-dlp.exe` in `backend/utils/paths.py`.
- **Dynamic Service Container**: Added `reset()` method to `ServiceContainer` allowing registered service singletons to reload upon global configuration changes.

### 🐛 Fixed
- **Windows Process Signal Crash**: Fixed runtime `AttributeError` on Windows by replacing `signal.SIGKILL` with cross-platform `getattr(signal, "SIGKILL", signal.SIGTERM)` in `backend/core/engine.py`.
- **Integration Test Suite**: Fixed test failures in `test_integration.py` by mocking `os.path.exists`/`os.path.isdir` during scanner tests and invoking container resets for config updates.
- **Hypothesis Test Import**: Added `pytest.importorskip("hypothesis")` in `test_naming_property.py` to allow test collection to pass cleanly when hypothesis is optional.
- **Documentation Filename References**: Updated configuration references in `PRIVACY.md` to `mkvoodoo_config.json` and `mkvoodoo_queue.json`.

### ⚡ Refactored & Improved
- **100% Python Type Safety**: Fixed 55 Mypy static type errors across all 35 backend Python files.
- **Flutter UI Modernization**: Resolved 7 Flutter analyzer deprecation warnings (`activeColor` -> `activeThumbColor`, `value` -> `initialValue` in `DropdownButtonFormField`).
- **Version Manifest Synchronization**: Unified `1.0.3` version string across `README.md`, `frontend/pubspec.yaml`, `backend/version.py`, `mkvoodoo.iss`, and `PRIVACY.md`.

---

## [1.0.2] — 2026-07-15
- Initial queue persistence and track selection controls.
- Parallel transcoding engine support and UI dashboard metrics.

## [1.0.0] — 2026-06-01
- Initial release of MKVoodoo batch video transcoder with Flutter UI and Nuitka Python backend.
