"""Local thumbnail extraction for MKVoodoo's Clipper."""

from __future__ import annotations

import re
import subprocess
from pathlib import Path
from uuid import uuid4

from backend.models.clip import ThumbnailCandidate
from backend.utils.paths import get_ffmpeg_path


class ThumbnailService:
    """Extract exact still frames and lightweight candidate sets with FFmpeg."""

    _FORMATS = {"jpg": "mjpeg", "png": "png"}

    def __init__(self) -> None:
        self._ffmpeg = str(get_ffmpeg_path())

    def generate_candidates(
        self, source: str | Path, in_us: int, end_us: int, cache_dir: str | Path, count: int = 4
    ) -> list[ThumbnailCandidate]:
        """Generate evenly distributed, exact-frame PNG previews inside a selection."""
        source_path = Path(source)
        cache_path = Path(cache_dir)
        if not source_path.is_file():
            raise FileNotFoundError(f"Thumbnail source does not exist: {source_path}")
        if in_us < 0 or end_us <= in_us:
            raise ValueError("Thumbnail selection must have a positive duration.")
        if count < 1:
            raise ValueError("At least one thumbnail candidate is required.")

        cache_path.mkdir(parents=True, exist_ok=True)
        session_path = cache_path / f"selection_{in_us}_{end_us}_{uuid4().hex}"
        session_path.mkdir()
        duration_us = end_us - in_us
        sample_count = max(count * 3, 12)
        candidates: list[ThumbnailCandidate] = []
        for index in range(sample_count):
            fraction = 0.1 + (0.8 * index / max(1, sample_count - 1))
            timestamp_us = in_us + round(duration_us * fraction)
            path = session_path / f"candidate_{index:02d}_{timestamp_us}.png"
            try:
                self.extract_frame(source_path, timestamp_us, path, "png")
            except ValueError as exc:
                if str(exc) != "FFmpeg did not produce a thumbnail image.":
                    raise
                continue
            score = self._score_candidate(path, fraction)
            if score is not None:
                candidates.append(ThumbnailCandidate(timestamp_us, str(path), score))
            else:
                path.unlink(missing_ok=True)

        candidates.sort(key=lambda candidate: candidate.score, reverse=True)
        return candidates[:count]

    def extract_frame(
        self, source: str | Path, timestamp_us: int, output: str | Path, image_format: str
    ) -> Path:
        """Decode and save one exact presentation timestamp as JPG or PNG."""
        source_path, output_path = Path(source), Path(output)
        normalized_format = image_format.lower().lstrip(".")
        if not source_path.is_file():
            raise FileNotFoundError(f"Thumbnail source does not exist: {source_path}")
        if timestamp_us < 0:
            raise ValueError("Thumbnail timestamp cannot be negative.")
        if normalized_format not in self._FORMATS:
            raise ValueError("Thumbnail format must be JPG or PNG.")
        if output_path.suffix.lower() not in {".jpg", ".jpeg", ".png"}:
            raise ValueError("Thumbnail output must have a JPG or PNG extension.")
        expected_suffixes = {"jpg": {".jpg", ".jpeg"}, "png": {".png"}}
        if output_path.suffix.lower() not in expected_suffixes[normalized_format]:
            raise ValueError("Thumbnail output extension must match the requested format.")
        if output_path.exists():
            raise FileExistsError(f"Thumbnail output already exists: {output_path}")

        output_path.parent.mkdir(parents=True, exist_ok=True)
        temporary = output_path.with_name(f"{output_path.stem}.partial{output_path.suffix}")
        if temporary.exists():
            temporary.unlink()
        try:
            self._run(
                [
                    self._ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", str(source_path),
                    "-ss", f"{timestamp_us / 1_000_000:.6f}", "-frames:v", "1",
                    "-c:v", self._FORMATS[normalized_format], str(temporary),
                ],
            )
            if not temporary.is_file() or temporary.stat().st_size == 0:
                raise ValueError("FFmpeg did not produce a thumbnail image.")
            temporary.replace(output_path)
        except Exception:
            if temporary.exists():
                temporary.unlink()
            raise
        return output_path

    def _score_candidate(self, image_path: Path, temporal_fraction: float) -> float | None:
        """Score a frame using local luma statistics; reject unusable images."""
        result = self._run(
            [
                self._ffmpeg, "-hide_banner", "-i", str(image_path),
                "-vf", "signalstats,metadata=print", "-frames:v", "1", "-f", "null", "-",
            ],
            capture_output=True,
        )
        diagnostics = result.stderr
        average = self._metadata_value(diagnostics, "YAVG")
        low = self._metadata_value(diagnostics, "YLOW")
        high = self._metadata_value(diagnostics, "YHIGH")
        if average is None or low is None or high is None:
            return 0.0
        contrast = high - low
        if average < 16 or contrast < 12:
            return None
        brightness_score = 1.0 - min(1.0, abs(average - 128) / 128)
        contrast_score = min(1.0, contrast / 128)
        temporal_score = 1.0 - abs(temporal_fraction - 0.5)
        return round((contrast_score * 0.5) + (brightness_score * 0.35) + (temporal_score * 0.15), 4)

    @staticmethod
    def _metadata_value(diagnostics: str, name: str) -> float | None:
        match = re.search(rf"lavfi\.signalstats\.{name}=([0-9.]+)", diagnostics)
        return float(match.group(1)) if match else None

    def _run(self, args: list[str], *, capture_output: bool = False) -> subprocess.CompletedProcess[str]:
        """Run FFmpeg behind a small seam for platform-safe integration tests."""
        return subprocess.run(args, check=True, capture_output=capture_output, text=capture_output)
