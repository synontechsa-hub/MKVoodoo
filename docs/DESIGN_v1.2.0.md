# MKVoodoo v1.2.0 Design Document

## Working Title
Precision Clipper

## Objective
MKVoodoo v1.2.0 will add a focused, frame-accurate clip extraction workflow for local videos and supported online video URLs, plus lightweight thumbnail generation for the selected clip.

The feature is intentionally not a video editor. Its purpose is to let a user identify an exact start frame and exact end frame, preview that selection, export only the selected section as a new video file, and optionally choose or generate a still thumbnail from that clip.

## Product Principle
The Clipper should solve one job extremely well:

> Open a video, choose the exact frames you want, and export that clip.

Thumbnail generation is a companion workflow, not a separate editor.

No text overlays, transitions, filters, colour grading, multi-track editing, effects, or timeline composition are planned for v1.2.0.

## Primary Use Cases

1. Open an existing local video file and extract an exact frame range.
2. Paste a supported YouTube or media URL, download the source through the existing yt-dlp integration, and open it directly in the Clipper.
3. Create short clips for social media, looping content, reactions, gaming footage, memes, references, and other downstream editing workflows.
4. Export a precise clip without opening a full nonlinear editor such as DaVinci Resolve or another heavyweight editing package.
5. Automatically generate several useful thumbnail candidates from the selected clip.
6. Manually scrub to an exact frame and save that frame as the thumbnail.

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
12. Optionally generate or manually select a thumbnail from the selected clip.

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
- Generate Thumbnails button
- Save Current Frame / Use This Frame control for manual thumbnail selection

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

## Thumbnail Generation

Thumbnail generation is part of v1.2.0 and should operate on the active Clipper selection.

The user should have two paths:

- Automatic thumbnail suggestions
- Manual thumbnail selection

### Automatic Thumbnail Generation

MKVoodoo should generate a small set of thumbnail candidates from the selected clip, with a target of four candidates in the default UI.

The first implementation should remain lightweight and local. It does not need an AI model.

A practical v1 approach is:

1. Sample a reasonable spread of frames from the selected range.
2. Avoid relying heavily on the very first and final frames, which may contain fades, cut boundaries, or transitional content.
3. Reject obviously poor candidates such as near-black frames, very low-contrast frames, or severely blurred frames where practical.
4. Avoid returning several near-identical candidate frames where practical.
5. Rank the remaining candidates using simple image-quality signals such as sharpness, brightness, and contrast.
6. Present the best four candidates to the user.

The user can then select one candidate and save it as an image.

Automatic selection should be treated as a convenience feature, not as a claim that MKVoodoo understands the most narratively important moment in the video.

### Manual Thumbnail Selection

The user must always be able to override automatic suggestions.

Manual thumbnail selection should reuse the existing Clipper preview, timeline, timestamp display, and frame-step controls.

Workflow:

1. Scrub anywhere within the selected clip.
2. Step frame-by-frame to the exact desired image.
3. Select **Use This Frame** or **Save Current Frame**.
4. Export that frame as an image.

This allows the user to choose a specific expression, action moment, explosion, title card, composition, or other frame that an automatic quality score may not prefer.

### Thumbnail Output

Required image formats:

- JPG
- PNG

The exported image should preserve the source frame resolution by default.

Future versions may add platform presets, resizing, cropping, text overlays, or thumbnail composition tools, but these are not required for v1.2.0.

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

### Proposed New Clipping Service

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

### Proposed Thumbnail Service

Thumbnail functionality may live in a dedicated service such as:

`backend/services/thumbnail_service.py`

or be kept with ClipService if the implementation remains small and cohesive.

Responsibilities may include:

- Extract a frame at an exact presentation timestamp
- Sample candidate frames across the selected range
- Score candidates using lightweight image-quality heuristics
- Reject unusable or near-duplicate candidates where practical
- Export selected frames as JPG or PNG
- Return verified output paths

FFmpeg should remain the primary frame-extraction mechanism unless another dependency provides a clear benefit without materially increasing package complexity.

## Frontend Architecture

Add a dedicated Clipper screen or tab within the existing Flutter application.

The Clipper should support:

- Opening a local source file directly
- Receiving a completed file from the Downloader workflow
- Accurate paused seeking and frame stepping
- In / Out state management
- Selection preview
- Thumbnail candidate generation
- Manual thumbnail selection from the current frame
- Thumbnail candidate selection and save flow
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
- AI-based semantic thumbnail selection
- Thumbnail text/layout design
- YouTube-style thumbnail composition tools

These features belong in dedicated editing or design software and would dilute the purpose of MKVoodoo's Clipper.

## Error Handling

The Clipper should provide actionable errors for at least:

- Unsupported or unreadable source
- Missing video stream
- Invalid In / Out order
- Zero-length selection
- Export destination unavailable
- Insufficient disk space
- FFmpeg export failure
- Thumbnail extraction failure
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
6. Generate several useful thumbnail candidates from the selected clip.
7. Manually select any exact frame from the clip as a thumbnail.
8. Save the chosen thumbnail as JPG or PNG.
9. Complete the workflow without needing to understand FFmpeg, codecs, GOPs, keyframes, or external image-extraction tools.

## Suggested Release Positioning

MKVoodoo v1.2.0 evolves the app from a converter and downloader into a focused media preparation utility.

A simple user-facing workflow is:

**Download. Clip. Thumbnail. Convert. Done.**

The Clipper should remain fast, local-first, simple, and precise.
