"""Precise, re-encoded video clip export for MKVoodoo's Clipper."""

from __future__ import annotations

from pathlib import Path

from backend.core.engine import FFmpegEngine
from backend.models.clip import ClipExportResult
from backend.models.hardware import EncoderInfo
from backend.services.probe_service import ProbeService


class ClipService:
    """Export primary-video/default-audio clips using presentation timestamps."""

    _SUPPORTED_CONTAINERS = {"mp4", "mkv"}

    def __init__(self, engine: FFmpegEngine, probe_service: ProbeService) -> None:
        self._engine = engine
        self._probe_service = probe_service

    def export(self, source: str | Path, output: str | Path, in_us: int, out_us: int,
               container: str, encoder: EncoderInfo) -> ClipExportResult:
        source_path, output_path = Path(source), Path(output)
        container = container.lower().lstrip(".")
        self._validate_request(source_path, output_path, in_us, out_us, container)
        info = self._probe_service.get_clip_media_info(source_path)
        end_us = self._resolve_exclusive_end(source_path, out_us, info.duration_us)
        if end_us <= in_us:
            raise ValueError("The selected clip must contain at least one frame.")
        output_path.parent.mkdir(parents=True, exist_ok=True)
        temporary = output_path.with_name(f"{output_path.stem}.partial{output_path.suffix}")
        if temporary.exists():
            temporary.unlink()
        has_audio = bool(self._probe_service.get_tracks(source_path)["audio"])
        try:
            args = self._build_ffmpeg_args(
                source_path, temporary, in_us, end_us, container, encoder, has_audio
            )
            self._engine.run(args)
            if self._probe_service.get_clip_media_info(temporary).duration_us <= 0:
                raise ValueError("FFmpeg produced an empty clip.")
            temporary.replace(output_path)
        except Exception:
            if temporary.exists():
                temporary.unlink()
            raise
        return ClipExportResult(str(output_path), in_us, end_us, encoder.video_encoder)

    def _resolve_exclusive_end(self, source: Path, out_us: int, duration_us: int) -> int:
        frames = self._probe_service.get_nearby_frames(source, out_us, before=0, after=1)
        return next((frame.pts_us for frame in frames if frame.pts_us > out_us), duration_us)

    @staticmethod
    def _validate_request(source: Path, output: Path, in_us: int, out_us: int, container: str) -> None:
        if not source.is_file():
            raise FileNotFoundError(f"Clip source does not exist: {source}")
        if output.exists():
            raise FileExistsError(f"Clip output already exists: {output}")
        if in_us < 0 or out_us < 0:
            raise ValueError("Clip boundaries cannot be negative.")
        if out_us < in_us:
            raise ValueError("The Out frame must not be before the In frame.")
        if container not in ClipService._SUPPORTED_CONTAINERS:
            raise ValueError("Clip container must be MP4 or MKV.")
        if output.suffix.lower() != f".{container}":
            raise ValueError(f"Output extension must be .{container}.")

    @staticmethod
    def _build_ffmpeg_args(source: Path, output: Path, in_us: int, end_us: int, container: str,
                           encoder: EncoderInfo, has_audio: bool) -> list[str]:
        start, end = in_us / 1_000_000, end_us / 1_000_000
        video_filter = f"trim=start={start:.6f}:end={end:.6f},setpts=PTS-STARTPTS,format=yuv420p"
        args = ["-hide_banner", "-y", "-i", str(source), "-map", "0:v:0", "-vf", video_filter,
                "-c:v", encoder.video_encoder]
        if encoder.video_encoder == "libx264":
            args += ["-crf", "20", "-preset", "medium"]
        if has_audio:
            audio_filter = f"atrim=start={start:.6f}:end={end:.6f},asetpts=PTS-STARTPTS"
            args += ["-map", "0:a:0", "-af", audio_filter, "-c:a", "aac", "-b:a", "192k"]
        if container == "mp4":
            args += ["-movflags", "+faststart"]
        return args + ["-f", "mp4" if container == "mp4" else "matroska", str(output)]
