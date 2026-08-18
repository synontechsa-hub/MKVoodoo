# MKVoodoo v1.2.0 Implementation Plan

## Status

- Target version: `1.2.0`
- Working title: **Precision Clipper**
- Authoritative product design: [`DESIGN_v1.2.0.md`](DESIGN_v1.2.0.md)
- Implementation root: `D:\Coding\Synontech\_Development\MKVoodoo\MKVoodoo_v.1.2.0`
- Release repository: `D:\Coding\Synontech\MKVoodoo`
- Release-repository policy: **out of scope; do not edit, copy into, build from, or version-bump the release repository during development**

## Goal

Deliver a focused local-first Clipper that lets a user open a local video or a supported downloaded video, select an exact inclusive start and end frame, preview the selection, export it as MP4 or MKV, and save an automatic or manually selected thumbnail as JPG or PNG.

The feature is complete only when exact-boundary behavior is verified with generated media fixtures, not merely when the UI appears to seek to the requested position.

## Delivery Principles

1. FFprobe owns media facts and presentation timestamps.
2. FFmpeg owns precise export, frame extraction, and thumbnail analysis.
3. The Flutter player provides responsive preview and controls but is not the source of truth for VFR boundaries.
4. Canonical timestamps cross the backend/frontend boundary as integer microseconds, avoiding floating-point drift.
5. Existing downloader, path resolution, hardware detection, error handling, and process-progress conventions are reused.
6. No source file is overwritten or modified.
7. A partially written export is never presented as a successful result.
8. The smallest coherent implementation is preferred over editor-like expansion.

## Approved Scope From the Design

### Included

- Local file input.
- Supported URL input through the existing `DownloadService` and yt-dlp integration.
- Video preview, play/pause, scrub, frame stepping, Set In, Set Out, duration, and loop-selection controls.
- Precise re-encoded export to MP4 or MKV.
- Four automatic thumbnail suggestions by default.
- Manual current-frame thumbnail export.
- JPG and PNG thumbnail output at source-frame resolution.
- Actionable errors and retained FFmpeg/yt-dlp diagnostics.

### Excluded

- Multiple clips or tracks on a timeline.
- Stream-copy Fast Cut mode.
- Transitions, titles, captions, overlays, effects, filters, grading, speed changes, cropping, reframing, audio mixing, waveform editing, or project files.
- AI or semantic thumbnail selection.
- Thumbnail composition, text, layout, or social-platform presets.
- Changes to the release repository.

## Architecture

### Canonical Boundary Model

The backend will represent a selected frame with:

- `pts_us`: presentation timestamp in integer microseconds.
- `duration_us`: frame duration where known.
- `ordinal`: optional display ordinal within a bounded frame window.
- `key_frame`: informational only; precise export does not depend on keyframe placement.

The UI may show a frame number for reliable CFR media. For VFR media, the timestamp remains authoritative and a displayed frame number must be labelled as informational when it cannot be derived reliably.

Boundary semantics:

- **In** is inclusive.
- **Out** is inclusive.
- FFmpeg trimming uses an exclusive end boundary, so the backend converts the selected Out frame to the presentation timestamp of the following frame.
- If the selected Out frame is the final frame, the probed source duration is used as the exclusive end.
- A valid selection requires `exclusive_end_us > in_pts_us`.

This rule must be tested explicitly because it prevents the selected final frame from being silently omitted.

### Probe and Frame Navigation

Extend `ProbeService` rather than creating a second general probe implementation.

Add clip-oriented probe results containing:

- source path and file size;
- duration and start time;
- primary video stream index;
- width, height, pixel format, codec, and rotation metadata;
- stream `time_base`;
- `avg_frame_rate` and `r_frame_rate` as rational values;
- optional `nb_frames`;
- CFR/VFR classification with an explicit confidence/reason field;
- audio-stream summary;
- nearby frame presentation timestamps on request.

Frame-step requests should query a bounded interval around the current position instead of loading every frame from a long source into memory. FFprobe `best_effort_timestamp_time` is the preferred frame timestamp when available.

Suggested backend operations:

```text
clip probe --input <path>
clip frames --input <path> --around-us <timestamp> --before <n> --after <n>
clip export --request-json <json>
thumbnail generate --request-json <json>
thumbnail save --request-json <json>
```

CLI output intended for Flutter should be JSON or newline-delimited JSON. Human-readable diagnostics go to stderr or structured error fields so they do not corrupt JSON parsing.

### Clip Service

Add `backend/services/clip_service.py` with responsibility for:

- validating input and output paths;
- validating source media and video-stream presence;
- validating In/Out order and minimum duration;
- resolving the exclusive end boundary;
- selecting MP4 or MKV output policy;
- constructing a precise FFmpeg command;
- running through the existing process-management/progress conventions;
- retaining the useful tail of FFmpeg diagnostics;
- writing to a temporary sibling path;
- probing the completed temporary output;
- atomically promoting the verified file to its final name;
- cleaning incomplete temporary output after cancellation or failure.

Precise export should use decoded/re-encoded boundaries, not output-side keyframe stream copying. Audio must be trimmed and timestamps reset with the video so the result starts at zero and remains synchronized.

Hardware acceleration may be used for encoding when the existing `HardwareService` reports a supported encoder and the exact-boundary integration tests pass for that path. CPU `libx264` remains the correctness fallback.

### Thumbnail Service

Add `backend/services/thumbnail_service.py` rather than growing `ClipService` into two responsibilities.

Default candidate pipeline:

1. Pick 12 sample timestamps distributed from roughly 10% through 90% of the selected range.
2. Extract or analyze the exact frames through the bundled FFmpeg.
3. Reject near-black and very low-contrast frames using `blackframe` and `signalstats` data.
4. Penalize blurred frames using `blurdetect`.
5. Remove exact duplicates by content hash.
6. Suppress near-duplicates using FFmpeg `signature` or scaled-frame `ssim` comparisons.
7. Rank remaining frames by normalized sharpness, brightness, contrast, and temporal spread.
8. Return the best four candidates with timestamp, score components, and temporary preview path.

The bundled FFmpeg 8.0.1 build exposes `blackframe`, `blurdetect`, `signalstats`, `thumbnail`, `signature`, and `ssim`, so the first implementation does not require Pillow, OpenCV, or an ML dependency.

Generated previews belong in an application cache directory and should be cleaned when the source changes, the session closes, or an explicit cleanup runs. A user-selected thumbnail is written to a user-selected final destination through a temporary sibling file and verified before success.

### Flutter Preview

Add a dedicated playback dependency for the preview surface. The proposed dependency set is:

- `media_kit`
- `media_kit_video`
- `media_kit_libs_windows_video`

`media_kit` supports local playback, Windows, seeking, looping, screenshots, and custom controls. Its position is suitable for preview synchronization, but authoritative frame boundaries still come from the backend.

Dependency references:

- <https://pub.dev/packages/media_kit>
- <https://github.com/media-kit/media-kit>

Add:

- `frontend/lib/models/clip_media_info.dart`
- `frontend/lib/models/clip_frame.dart`
- `frontend/lib/models/clip_selection.dart`
- `frontend/lib/models/thumbnail_candidate.dart`
- `frontend/lib/services/clipper_api.dart`
- `frontend/lib/services/backend_clipper_api.dart`
- `frontend/lib/controllers/clipper_controller.dart`
- `frontend/lib/pages/clipper_page.dart`
- focused Clipper widgets under `frontend/lib/widgets/clipper/`

`ClipperApi` is a narrow interface around the relevant `BackendBridge` calls. This keeps controller tests deterministic without refactoring every existing controller or adding a mocking framework.

### Navigation and Downloader Handoff

The current `MainLayout` owns its selected navigation index locally, so another controller cannot reliably open the Clipper. Introduce a small app-navigation controller that owns:

- selected destination;
- optional pending Clipper source path;
- `openClipper(path)`;
- consumption/clearing of the pending source intent.

Add **Clipper** to the navigation rail and indexed stack.

For successful video downloads:

1. Keep the completed source path from the downloader event.
2. Call `openClipper(path)` automatically, matching the design document.
3. Do not auto-delete the downloaded source after clip export.
4. Retain the existing audio-only flow without opening the Clipper.

The existing automatic “add downloaded video to conversion queue” behavior must not happen simultaneously with automatic Clipper navigation. The product decision for v1.2.0 should be one of:

- recommended: open video downloads in the Clipper and offer an explicit secondary “Add to Conversion Queue” action;
- alternative: let the user choose “Open in Clipper” or “Add to Queue” after download.

## Product Decisions Requiring Architect Approval

### Gate A — Preview Dependency

Recommended: approve the three Windows-focused `media_kit` packages listed above.

Reason: the current Flutter application has no playback dependency, and building a native Windows player is outside the feature’s purpose.

### Gate B — Export Stream Policy

The design specifies H.264/AAC but does not define multiple audio, subtitle, attachment, or chapter behavior.

Recommended v1.2.0 policy:

- primary video stream only;
- default audio stream only, re-encoded to AAC;
- no subtitle, attachment, data, or chapter streams;
- preserve basic title/date metadata only when compatible;
- document that the Clipper is a focused social/media-preparation path, separate from the converter’s full-stream-preservation workflow.

Alternative: retain all audio and supported subtitle streams, which increases container-specific mapping, sync, and compatibility work.

### Gate C — Download Completion Behavior

Recommended: video downloads open automatically in the Clipper and are not simultaneously queued for conversion. Audio-only downloads retain the current behavior.

### Gate D — Minimum Supported Platform

Recommended: acceptance and release gating for v1.2.0 targets Windows first, consistent with the current bundled executables and installer. Other generated Flutter platforms must continue to analyze where practical but are not Clipper release blockers unless separately approved.

## Implementation Batches

### Batch 0 — Consolidation and Baseline

Purpose: establish a trustworthy v1.2.0 development baseline before feature code.

Work:

- Confirm `MKVoodoo_v.1.2.0` is the only active development version.
- Remove or regenerate copied caches that retain absolute v1.0.4 paths; do not delete source files.
- Ensure `.gitignore` excludes Python, Flutter, Nuitka, and test caches/build outputs.
- Synchronize development metadata to `1.2.0` in `pyproject.toml`, `backend/version.py`, Flutter `pubspec.yaml`, README badge/text, and installer metadata, without changing the release repository.
- Run the baseline Python and Flutter gates.
- Record any pre-existing failures separately from Clipper work.

Observed baseline on 2026-08-15:

- Python mypy: passes for 35 backend source files.
- Pytest: collection fails because copied bytecode resolves BDD feature paths under removed `MKVoodoo_v.1.0.4`.
- Pytest cache creation also reports access-denied warnings in the copied development directory.
- Flutter analyze/test invocation did not complete within the 120-second planning check and must be rerun after cache consolidation.

Acceptance:

- no test or build command resolves a removed version path;
- baseline results are reproducible from the v1.2.0 root;
- the release repository has no new diff.

### Batch 1 — Media Contracts and Frame Navigation

Work:

- Add backend request/result models for clip probing, frames, selections, exports, and errors.
- Extend `ProbeService` with clip media info and bounded nearby-frame queries.
- Add CLI parser, handler, service-container registration, and JSON bridge methods.
- Add CFR and VFR classification logic.
- Implement inclusive-Out-to-exclusive-end resolution.

Tests:

- rational rate parsing;
- missing/invalid timing metadata;
- CFR classification;
- VFR classification;
- nearby-frame ordering and boundary behavior;
- final-frame Out behavior;
- invalid and zero-length selections;
- paths containing spaces and Unicode.

Acceptance:

- Flutter can request media info and step to authoritative neighboring timestamps without exporting anything.

### Batch 2 — Precise Clip Export

Work:

- Add `ClipService` and container registration.
- Build MP4 and MKV command policies.
- Add JSON/NDJSON progress and cancellation behavior.
- Use verified temporary output and atomic promotion.
- Surface actionable error categories and diagnostic tails.
- Integrate hardware encoder selection behind the CPU-correctness path.

Tests:

- command construction without invoking FFmpeg;
- output collision/no-overwrite rules;
- cancellation cleanup;
- disk/path validation;
- FFmpeg failure diagnostic retention;
- synthetic CFR fixture with known per-frame colours or checksums;
- synthetic VFR fixture with known presentation timestamps;
- first and last output frame match the inclusive selection;
- audio begins at zero and remains within sync tolerance;
- MP4 and MKV output probe successfully.

Acceptance:

- an automated integration test proves that the requested first and last frames are present in the exported clip.

### Batch 3 — Thumbnail Generation

Work:

- Add `ThumbnailService` and candidate/result models.
- Implement candidate sampling, analysis, deduplication, ranking, cache ownership, and cleanup.
- Add manual exact-frame export.
- Add JPG/PNG format and destination validation.

Tests:

- avoid first/final boundary bias;
- reject generated black frames;
- penalize generated blurred frames;
- suppress identical and near-identical candidates;
- stable ranking for a fixed fixture;
- return up to four candidates when fewer good frames exist;
- exact manual frame checksum;
- cache and failure cleanup.

Acceptance:

- automatic generation returns four useful candidates for the standard fixture and manual export matches the chosen frame.

### Batch 4 — Clipper UI

Work:

- Add approved playback packages and initialize them in `main.dart`.
- Add Clipper models, API adapter, controller, page, and widgets.
- Add navigation destination.
- Implement local-file open, preview, scrubber, timestamps, frame display, stepping, markers, selected duration, playback, selection loop, export options, progress, cancel, and errors.
- Implement keyboard shortcuts: Space, Left, Right, I, and O.
- Disable invalid actions and preserve selection state during routine widget rebuilds.
- Add thumbnail candidate grid and manual-save flow.

Tests:

- controller state transitions with a fake `ClipperApi`;
- Set In/Out validation;
- frame-step calls use backend-returned timestamps;
- keyboard intent mapping;
- export controls and progress states;
- error and cancellation states;
- thumbnail selection and save flow;
- focused widget tests at supported window sizes.

Acceptance:

- the entire local-file workflow is usable without the downloader and without direct FFmpeg knowledge.

### Batch 5 — Downloader Integration

Work:

- Return/retain the completed video path reliably.
- Add app-level Clipper navigation intent.
- Open completed video downloads in the Clipper according to Gate C.
- Keep audio-only behavior unchanged.
- Make cleanup ownership explicit; never delete a downloaded source merely because a clip exported successfully.

Tests:

- video download completion opens the exact returned path;
- audio-only completion does not open the Clipper;
- failed/cancelled downloads do not navigate;
- spaces and Unicode in downloaded paths survive log/event handling;
- conversion queue behavior matches the approved product choice.

Acceptance:

- URL to downloaded source to precise clip is a continuous in-app workflow.

### Batch 6 — Hardening and Development Candidate

Work:

- Run full Python typing, lint, unit, BDD, and integration suites.
- Run Flutter analyze, unit/widget tests, and Windows build.
- Run manual smoke tests with short/long, CFR/VFR, rotated, silent, multi-audio, corrupt, and unusual-path media.
- Verify cancellation, low disk, destination denial, missing executable, and unsupported-source errors.
- Verify temporary/cache cleanup.
- Update development README and CHANGELOG with accurate behavior and limitations.
- Build only from the v1.2.0 development directory.
- Do not copy or publish anything to the release repository without a separate architect-approved release task.

Acceptance:

- all automated gates pass;
- manual acceptance checklist passes on Windows;
- known limitations are documented;
- the release repository remains untouched.

## Test Fixtures

Generate deterministic fixtures during tests or in an ignored test-artifact directory:

- CFR colour/frame-number sequence, approximately 3 seconds at 10 fps.
- VFR sequence with deliberately varied frame durations.
- video with audio tone markers for sync checks.
- silent video.
- video containing black, blurred, duplicate, and high-detail frames for thumbnail ranking.
- corrupt/truncated input.

Do not commit large binary fixtures when an FFmpeg command can generate them quickly and deterministically.

## Quality Gates

Run from the v1.2.0 development root:

```powershell
python -m mypy backend
python -m flake8 backend --max-line-length=120 --exclude=__pycache__
python -m pytest
Push-Location frontend
flutter analyze
flutter test
flutter build windows --release
Pop-Location
```

Feature-specific integration tests should additionally probe produced media and compare boundary-frame checksums or deterministic visual properties.

## Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| Preview seek lands near, not on, a requested frame | Resolve Set In/Out through backend frame PTS and treat player position as advisory. |
| VFR content breaks `frame / fps` calculations | Never use that formula as the internal boundary representation; use presentation timestamps. |
| Inclusive Out frame is dropped | Convert Out to the next frame PTS and test first/last frame checksums. |
| Hardware encoder changes boundary behavior | Gate each hardware path with the same integration fixtures and retain CPU fallback. |
| Long videos make full frame probing expensive | Query bounded frame windows around the current position. |
| Thumbnail scoring adds heavy dependencies | Use verified filters in the bundled FFmpeg build. |
| Download log parsing loses paths | Prefer structured JSON/NDJSON completion events; test spaces and Unicode. |
| Partial outputs appear successful | Write to a temporary sibling, probe, then atomically promote. |
| Consolidated directories retain stale absolute paths | Make cache cleanup and baseline verification Batch 0. |
| Feature expands into a video editor | Enforce the design document’s explicit non-goals during review. |
| Development work leaks into release | Use absolute dev-root checks and verify the release repository diff after each batch. |

## Definition of Done

MKVoodoo v1.2.0 development is feature-complete when:

1. A local video can be opened in the Clipper.
2. A supported video URL can download and open in the Clipper.
3. CFR and VFR selections use authoritative presentation timestamps.
4. Previous/next controls resolve neighboring frames while paused.
5. In and Out markers use documented inclusive semantics.
6. Selection preview and loop work without mutating boundaries.
7. MP4 and MKV exports contain the verified requested first and last frames.
8. Export audio is synchronized within the agreed test tolerance.
9. Four automatic thumbnail candidates are produced where usable frames exist.
10. Any exact selected frame can be saved as JPG or PNG.
11. Errors and cancellations leave no misleading completed output.
12. Python and Flutter quality gates pass from the v1.2.0 development directory.
13. Documentation states actual behavior and limitations.
14. The release repository has not been modified.

## Recommended Execution Order

Approve Gates A-D, then execute Batches 0 through 6 in order. Batch 3 service work can begin after Batch 1 while Batch 2 is being reviewed, but frontend integration should start only after the media and selection contracts are stable.
