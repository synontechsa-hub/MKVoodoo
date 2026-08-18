# MKVoodoo v1.2.0 — Pre-Release Audit & Codex Handoff

**Status:** HOLD — do not publish/rebuild the final public release until the items in this document are reviewed.

**Audit date:** 2026-08-18

**Target:** MKVoodoo v1.2.0 — *Precision Clipper*

## Purpose

This document replaces the earlier v1.2.0 design and implementation-plan documents. The feature implementation is substantially complete. This is now a release-hardening task.

Gemini 3.7 Flash performed an audit and implementation pass after Codex ran out of usage during its own final review. The Gemini changes are largely sound, but the final release should wait for a fresh Codex review and manual verification.

---

## Current Repository State

Two copies currently exist:

1. Development source:
   - `_Development/MKVoodoo/MKVoodoo_v.1.2.0`
2. Public/release repository:
   - `synontechsa-hub/MKVoodoo`

Important: v1.2.0 source changes are already present in the public/release repository. The final installer/release should therefore be treated as **not yet approved**, even though the public source already reports v1.2.0.

The important Flutter application source was found synchronized between Development and Release during the 2026-08-18 audit.

---

# Gemini Audit Findings and Implemented Changes

## 1. Clipper playback UI state

### Original issue

The Precision Clipper play button always displayed the play icon because the controller tracked playback position but not the player's playing/paused stream.

### Gemini implementation

- Subscribe to `player.stream.playing`.
- Expose controller playback state.
- Render play/pause icon according to the real player state.

### Status

Implemented. Requires manual UI verification.

---

## 2. YouTube download → Precision Clipper handoff

### Original issue

Video downloads still followed the old v1.1.1 workflow: automatically entering the conversion queue and deleting the downloaded source after conversion.

This no longer matched the v1.2.0 Precision Clipper workflow.

### Gemini implementation

- Added top-level navigation state via `NavigationController`.
- Video downloads now navigate to the Clipper and load the downloaded source.
- Audio-only downloads remain direct downloads and are not sent to the Clipper.

### Status

Implemented. Requires end-to-end manual verification.

---

## 3. Thumbnail temporary-directory cleanup

### Original issue

Repeated thumbnail-candidate generation created additional `mkvoodoo-clipper-*` system temp folders without cleaning previous candidate folders during the session.

### Gemini implementation

- Track generated thumbnail temp directories.
- Clean previous candidate folders when regenerating candidates.
- Clean remaining candidate temp data when the Clipper controller is disposed.

### Status

Implemented. Requires repeated-generation manual verification.

---

## 4. Dangerous global FFmpeg termination

### Original issue

Windows cancellation used:

```text
taskkill /F /IM ffmpeg.exe /T
```

This could terminate **every FFmpeg process on the user's computer**, including FFmpeg processes belonging to other applications.

### Gemini implementation

Cancellation now targets the relevant process PID tree instead of killing all `ffmpeg.exe` processes globally.

Expected Windows pattern:

```text
taskkill /F /T /PID <pid>
```

### Status

Implemented and materially safer.

### Release requirement

Codex must review process cancellation carefully before final release.

---

## 5. Shared `_activeProcess` collision

### Original issue

`BackendBridge` previously stored one shared `_activeProcess`. Starting another backend operation could overwrite the process reference for an already-running operation, making cancellation unreliable.

### Gemini implementation

Process tracking was changed to support multiple active processes rather than one singleton process reference.

### Status

Implemented, but requires a focused Codex review for lifecycle races.

### Specific race Codex must check

If active processes are keyed by an operation identifier, verify that completion of an older process cannot remove the tracking entry for a newer process using the same identifier.

Potential sequence:

```text
Process A starts under operation ID X
→ map[X] = A

A is cancelled / begins exiting
→ tracking changes

Process B starts under operation ID X
→ map[X] = B

A's delayed cleanup executes
→ blindly removes map[X]

Result: B continues running but is no longer tracked.
```

Cleanup should verify process identity before removing a map entry, conceptually:

```dart
if (_activeProcesses[operationId] == process) {
  _activeProcesses.remove(operationId);
}
```

Codex should inspect the actual implementation and use the appropriate equivalent rather than blindly applying this sample.

---

## 6. yt-dlp argument hardening

### Original issue

User-supplied URLs were passed to yt-dlp as arguments without an explicit option terminator. A value beginning with `--` could potentially be interpreted as an yt-dlp option rather than a target URL.

This was not shell command injection because `shell=True` was not being used, but it was still unnecessary argument-injection exposure.

### Gemini implementation

Added the standard `--` argument terminator before user-controlled URL arguments in relevant metadata/download commands.

### Status

Implemented.

---

## 7. Python code hygiene

Gemini removed unused imports and cleaned formatting issues identified during its Flake8 review.

Affected areas included service and utility modules such as hardware, metadata, naming, update, debug, and logger code.

### Status

Implemented. Final lint suite still required before release.

---

# Audit Findings Still Requiring Work

## P0 — Release metadata still says Development

`backend/version.py` currently reports:

```python
VERSION = "1.2.0"
RELEASE_DATE = "Development"
CODENAME = "Precision Clipper"
```

Before final v1.2.0 release, replace the development marker with the actual release date.

Expected release date for the currently prepared release is:

```text
2026-08-18
```

If the actual release occurs on a later date, use the real release date instead.

### Release blocker

Yes.

---

## P0 — Final process lifecycle review

Codex must inspect the multi-process tracking implementation and verify:

- process handles cannot overwrite unrelated operations;
- old process cleanup cannot unregister a newer process;
- cancellation kills only the intended process tree;
- cancellation works correctly on Windows;
- no unrelated FFmpeg process is killed;
- completed/cancelled processes are removed from tracking;
- no orphaned child process remains after cancellation where reasonably preventable.

### Release blocker

Yes, until reviewed and manually exercised.

---

## P1 — CHANGELOG is incomplete

The v1.2.0 changelog currently documents the main Precision Clipper feature work but should also record the later hardening work, including:

- targeted PID-based process cancellation;
- concurrent process tracking improvements;
- Clipper play/pause state synchronization;
- thumbnail temp-directory cleanup;
- YouTube video download → Clipper handoff;
- yt-dlp argument hardening;
- backend lint/code-hygiene cleanup where appropriate.

### Release blocker

Release-hygiene blocker. Update before publishing the final release.

---

## P1 — Generated/development junk in public repository

The public repository was observed to contain generated/development artifacts including items such as:

- `backend/__pycache__/`
- `.idea/`
- `frontend/.metadata`
- `main.dist/`

Review the complete repository before deletion because some build output may currently be intentionally used by the installer/build workflow.

At minimum:

- remove Python bytecode/cache files from source control;
- ensure `.gitignore` prevents regeneration;
- remove IDE-specific metadata that is not intentionally shared;
- decide deliberately whether compiled distribution output belongs in the public source repository.

Do not delete required installer/build inputs blindly.

### Release blocker

Not a functional blocker, but should be cleaned before declaring the public repository release-ready.

---

## P2 — yt-dlp self-update under Program Files

The downloader updater still uses an in-place yt-dlp update (`yt-dlp -U`).

If MKVoodoo is installed beneath `C:\Program Files\MKVoodoo`, a normal non-elevated process may not have permission to overwrite the bundled executable.

### Recommendation

Do not hold v1.2.0 solely for this unless testing reveals a user-facing regression.

For v1.2.1/v1.3, consider one of:

- storing the updateable downloader binary in a user-writable application-data directory;
- downloading updates through MKVoodoo's own updater logic;
- disabling in-place self-update for protected installations and providing a clear update path.

---

## P3 — TMDB API key storage

TMDB API configuration is stored in plaintext application configuration.

For a desktop client this is not unusual, but Windows DPAPI / Credential Manager would provide stronger local secret storage.

### Recommendation

Future hardening only. Do not block v1.2.0 unless the stored credential becomes materially sensitive or privileged.

---

# Precision Clipper Technical Audit Notes

The Clipper implementation appears structurally sound based on source review.

Positive points observed:

- presentation timestamps are used for frame navigation rather than assuming constant frame rate;
- Out-frame handling resolves to the next presentation timestamp so the selected Out frame can be included;
- clipping re-encodes rather than relying only on keyframe-aligned stream copy;
- export uses a partial output before final placement;
- failed exports remove partial output;
- destination overwrite is prevented;
- output duration is checked before accepting the result.

No source-level issue was found that justifies declaring the Precision Clipper fundamentally broken.

However, source review cannot prove frame-accurate real-world output. Manual CFR and VFR tests remain mandatory.

---

# Required Codex Review After Usage Reset

When Codex becomes available again, give it this document and instruct it to perform a **differential release audit**, not a redesign.

Codex should:

1. Read this document first.
2. Review Gemini's actual changes rather than assuming this summary is correct.
3. Inspect `BackendBridge` process tracking and cancellation for race conditions.
4. Verify the old global `taskkill /IM ffmpeg.exe` behavior is completely gone.
5. Verify targeted PID cancellation cannot kill unrelated processes.
6. Verify process-map cleanup cannot remove a newer process entry.
7. Review Precision Clipper export boundaries and error handling.
8. Verify YouTube video download → Clipper navigation/handoff.
9. Verify audio-only downloads still behave correctly.
10. Verify thumbnail temp cleanup.
11. Fix release metadata.
12. Update the changelog.
13. Review and clean generated repository artifacts safely.
14. Run all automated checks.
15. Report remaining findings before changing unrelated architecture.

Do **not** ask Codex to rewrite working subsystems simply because it would implement them differently.

---

# Automated Verification Required

Run from the v1.2.0 project root as appropriate.

## Python

```powershell
python -m pytest
python -m mypy backend
python -m flake8 backend --max-line-length=120 --exclude=__pycache__
```

## Flutter

```powershell
Push-Location frontend
flutter analyze
flutter test
Pop-Location
```

All release-relevant failures must be investigated. Do not suppress a failure merely to obtain a green command.

---

# Mandatory Manual Verification

Automated tests are not enough for media/process behavior.

## A. Normal conversion smoke test

- Add a known-good local video.
- Convert it using a common preset.
- Verify output opens and plays.
- Verify source deletion behavior matches the selected option.

## B. CFR Precision Clipper test

Use a known constant-frame-rate video.

- Load video in Clipper.
- Play/pause and verify icon state.
- Set exact In frame.
- Set exact Out frame.
- Export MP4.
- Export MKV if supported by the selected workflow.
- Verify the desired first and final frames are present.
- Verify output duration is plausible.

## C. VFR Precision Clipper test

Use a known variable-frame-rate source.

- Repeat precise In/Out selection.
- Export clip.
- Verify boundaries visually.
- Verify no obvious A/V sync regression.

## D. Thumbnail test

- Generate thumbnail candidates.
- Generate them again several times.
- Verify old temporary candidate directories are cleaned.
- Export a manually selected still frame.
- Close/dispose Clipper and verify session temp cleanup.

## E. YouTube video workflow

- Download a permitted/test video source.
- Verify video download completes.
- Verify MKVoodoo automatically navigates to Precision Clipper.
- Verify the downloaded file is loaded.
- Verify it is **not** automatically destructively transcoded/deleted through the old queue workflow.

## F. Audio-only workflow

- Perform an audio-only download.
- Verify it saves normally.
- Verify MKVoodoo does not incorrectly open it in the video Clipper.

## G. Cancellation / concurrency safety

This is mandatory because of the prior global FFmpeg kill bug.

- Start an MKVoodoo operation that spawns a backend/FFmpeg process.
- Start a second independent operation where the UI permits it.
- Cancel one operation.
- Verify only the intended operation stops.
- Verify the second operation continues where expected.
- Verify MKVoodoo remains responsive.
- Verify no unrelated FFmpeg process on the computer is terminated.
- Verify no stale process entry prevents subsequent operations.

Where practical, run an unrelated FFmpeg-using application/process during this test to prove MKVoodoo no longer kills it globally.

---

# Release Repository Cleanup Checklist

Before final release:

- [ ] `backend/version.py` has the actual release date.
- [ ] `CHANGELOG.md` includes the final Gemini/Codex hardening changes.
- [ ] `__pycache__` and Python bytecode are not tracked.
- [ ] `.gitignore` covers generated Python cache files.
- [ ] IDE metadata is reviewed/removed where appropriate.
- [ ] compiled/build artifacts are intentionally included or intentionally excluded.
- [ ] README version references are correct.
- [ ] Flutter package version is correct.
- [ ] installer version is correct.
- [ ] installer icon/branding is correct.
- [ ] release notes match actual behavior.

---

# Installer / Checksum Rules

The Inno Setup script currently targets MKVoodoo v1.2.0 and uses the application icon.

After **all** code and metadata changes are complete:

1. Build the production Flutter application.
2. Build/package the Python backend as required.
3. Build a **new** Inno Setup installer.
4. Install it on Windows as a normal user where possible.
5. Run the mandatory smoke tests against the installed build.
6. Generate a fresh SHA-256 for the exact final installer binary.
7. Replace any checksum generated for an earlier build.
8. Only then publish/attach the installer as the v1.2.0 release asset.

Never reuse an old checksum after rebuilding the installer.

---

# Release Gate

MKVoodoo v1.2.0 may ship when all of the following are true:

- [ ] Codex has reviewed Gemini's process-management changes.
- [ ] Process lifecycle race concerns are resolved or proven safe.
- [ ] Release date metadata is final.
- [ ] Changelog is final.
- [ ] Repository hygiene is acceptable.
- [ ] Python tests pass.
- [ ] Mypy passes.
- [ ] Flake8 passes.
- [ ] Flutter analyze passes.
- [ ] Flutter tests pass.
- [ ] Normal conversion smoke test passes.
- [ ] CFR Clipper test passes.
- [ ] VFR Clipper test passes.
- [ ] Thumbnail cleanup test passes.
- [ ] YouTube → Clipper handoff passes.
- [ ] Audio-only download behavior passes.
- [ ] Cancellation/concurrency safety test passes.
- [ ] Final installer builds successfully.
- [ ] Installed production build passes smoke testing.
- [ ] Final installer SHA-256 is regenerated.

Until those gates are satisfied, treat v1.2.0 as **release candidate / development state**, even if the source version already reports 1.2.0.

---

# Scope Control

The next pass is **release hardening**, not feature development.

Do not add new features while resolving this document.

Do not redesign the UI.

Do not replace working architecture merely for stylistic preference.

Do not promote additional changes into the release until the existing v1.2.0 behavior is verified.

The objective is simple:

> Stabilize what exists, prove it works, clean the release, and ship v1.2.0 safely.
