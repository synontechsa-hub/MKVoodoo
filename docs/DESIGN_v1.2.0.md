# MKVoodoo v1.2.0 Design Document

## Working Title
Precision Clipper

## Objective
MKVoodoo v1.2.0 will add a focused, frame-accurate clip extraction workflow for local videos and supported online video URLs.

The feature is intentionally not a video editor. Its purpose is to let a user identify an exact start frame and exact end frame, preview that selection, and export only the selected section as a new video file.

## Product Principle
The Clipper should solve one job extremely well:

> Open a video, choose the exact frames you want, and export that clip.

No text overlays, transitions, filters, colour grading, multi-track editing, effects, or timeline composition are planned for v1.2.0.

## Primary Use Cases

1. Open an existing local video file and extract an exact frame range.
2. Paste a supported YouTube or media URL, download the source through the existing yt-dlp integration, and open it directly in the Clipper.
3. Create short clips for social media, looping content, reactions, gaming footage, memes, references, and other downstream editing workflows.
4. Export a precise clip without opening a full nonlinear editor such as DaVinci Resolve or another heavyweight editing package.

## Scope

### Inputs

The Clipper should support two entry paths:

- Local video file
- Supported online video URL using the existing MKVoodoo downloader

For URL input, MKVoodoo should:

1. Fetch source metadata.
2. Download the source video using the existing DownloadService.
3. Open the completed source automatically in the Clipper.
4. Allow the user to keep or remove the downloaded source after export in a later refinement if desired.

### Core Clipper Workflow

1. Load source video.
2. Display video preview.
3. Scrub to the approximate start location.
4. Step backward or forward frame-by-frame.
5. Mark the exact start frame using Set In.
6. Scrub to the approximate end location.
7. Step backward or forward frame-by-frame.
8. Mark the exact end frame using Set Out.
9. Preview the selected range.
10. Optionally loop the selected range for verification.
11. Export only the selected range.

## UI Requirements

The Clipper view should remain minimal and focused.

### Required Elements

- Video preview area
- Timeline / scrubber
- Current timestamp
- Current frame number where reliable
- Previous frame button
- Next frame button
- Set In button
- Set Out button
- Start marker display
- End marker display
- Selected duration display
- Play / pause control
- Loop Selection toggle or button
- Export Clip button

### Recommended Keyboard Shortcuts

- Space: Play / Pause
- Left Arrow: Step backward
- Right Arrow: Step forward
- I: Set In
- O: Set Out

Keyboard behavior should favour precise single-frame navigation when paused.

## Frame Accuracy

Frame accuracy is the defining requirement of this feature.

MKVoodoo must not rely only on approximate timestamp seeking or nearest-keyframe cuts when Precise Export is selected.

### Constant Frame Rate Sources

For CFR sources, the UI may expose both:

- Human-readable timestamp
- Frame number

Frame number calculations may be derived from source frame rate when the stream metadata is reliable.

### Variable Frame Rate Sources

For VFR content, presentation timestamps must remain the source of truth internally.

The UI may still expose useful frame navigation where supported, but export boundaries must be based on accurate stream timing rather than assuming:

`frame_number / fps = timestamp`

## Export Design

### Required Containers

- MP4
- MKV

### Default Export

The default should prioritise compatibility and simplicity:

- Container: MP4
- Video: H.264
- Audio: AAC
- Hardware acceleration: Auto where appropriate

### MKV Export

MKV should be available as a secondary output container for users who prefer greater stream flexibility.

### Precise Export

Precise Export is the default v1.2.0 behavior.

The selected range should be re-encoded as required so that the exported clip begins and ends at the exact boundaries selected by the user, rather than being constrained to source keyframes.

### Future Fast Export

A future Fast Cut mode may use stream copying where safe and useful.

This mode is explicitly secondary because stream-copy cuts can be limited by keyframe placement and therefore may not preserve exact selected frame boundaries.

## Backend Architecture

The implementation should reuse the existing MKVoodoo platform rather than duplicate functionality.

Relevant existing components include:

- Flutter frontend
- FFmpeg
- FFprobe
- DownloadService / yt-dlp integration
- ConverterService
- ProbeService
- HardwareService
- Existing executable path resolution
- Existing error handling and diagnostics

### Proposed New Service

Add a dedicated clipping service, for example:

`backend/services/clip_service.py`

Responsibilities may include:

- Probe source timing and frame-rate metadata
- Validate In / Out boundaries
- Build precise FFmpeg clipping commands
- Select export container and codec preset
- Integrate existing hardware acceleration where appropriate
- Report export progress
- Return verified output path
- Preserve useful FFmpeg diagnostics on failure

The Clipper should not duplicate general transcoding logic already owned by ConverterService where that logic can be reused cleanly.

## Frontend Architecture

Add a dedicated Clipper screen or tab within the existing Flutter application.

The Clipper should support:

- Opening a local source file directly
- Receiving a completed file from the Downloader workflow
- Accurate paused seeking and frame stepping
- In / Out state management
- Selection preview
- Export configuration
- Export progress and error state

A useful integration point should be added to the Downloader:

**Download complete -> Open in Clipper**

## Non-Goals for v1.2.0

The following are explicitly out of scope:

- Multiple video tracks
- Multiple clip sequences on one timeline
- Transitions
- Titles or captions
- Text overlays
- Filters
- Colour grading
- Speed changes
- Cropping or reframing
- Audio mixing
- Audio waveform editing
- Effects
- Keyframe animation
- Project files
- Full timeline editing

These features belong in dedicated editing software and would dilute the purpose of MKVoodoo's Clipper.

## Error Handling

The Clipper should provide actionable errors for at least:

- Unsupported or unreadable source
- Missing video stream
- Invalid In / Out order
- Zero-length selection
- Export destination unavailable
- Insufficient disk space
- FFmpeg export failure
- Downloader failure for URL-based sources
- Missing required executable

As with the current downloader, useful final diagnostic output should be retained and surfaced instead of returning low-level process errors alone.

## Success Criteria

v1.2.0 is successful if a user can:

1. Open a local video or paste a supported URL.
2. Reach the Clipper without using external editing software.
3. Navigate precisely to the desired start and end frames.
4. Preview and loop the selected section.
5. Export the exact selected clip as MP4 or MKV.
6. Complete the workflow without needing to understand FFmpeg, codecs, GOPs, or keyframes.

## Suggested Release Positioning

MKVoodoo v1.2.0 evolves the app from a converter and downloader into a focused media preparation utility.

A simple user-facing workflow is:

**Download. Clip. Convert. Done.**

The Clipper should remain fast, local-first, simple, and precise.
