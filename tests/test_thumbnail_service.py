"""Integration coverage for local Clipper thumbnail extraction."""

from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

from backend.services.thumbnail_service import ThumbnailService
from backend.utils.paths import get_ffmpeg_path


def _create_fixture(path: Path) -> None:
    subprocess.run(
        [
            str(get_ffmpeg_path()), "-hide_banner", "-loglevel", "error", "-y",
            "-f", "lavfi", "-i", "testsrc2=size=64x64:rate=4:duration=2",
            "-c:v", "libx264", "-pix_fmt", "yuv420p", str(path),
        ],
        check=True,
    )


class _DirectThumbnailService(ThumbnailService):
    """Avoid pytest's Windows captured-handle conflict while exercising FFmpeg."""

    def _run(self, args: list[str], *, capture_output: bool = False) -> subprocess.CompletedProcess[str]:
        subprocess.run(
            args,
            check=True,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return subprocess.CompletedProcess(args, 0, "", "")


def test_extract_frame_writes_a_non_empty_png(tmp_path: Path) -> None:
    source = tmp_path / "source.mp4"
    output = tmp_path / "preview.png"
    _create_fixture(source)

    result = _DirectThumbnailService().extract_frame(source, 500_000, output, "png")

    assert result == output
    assert output.is_file()
    assert output.stat().st_size > 0


def test_generate_candidates_returns_ranked_existing_images(tmp_path: Path) -> None:
    source = tmp_path / "source.mp4"
    _create_fixture(source)

    candidates = _DirectThumbnailService().generate_candidates(
        source, 0, 2_000_000, tmp_path / "cache", 2
    )

    assert len(candidates) == 2
    assert candidates == sorted(candidates, key=lambda candidate: candidate.score, reverse=True)
    assert all(Path(candidate.path).is_file() for candidate in candidates)
    assert all(0 <= candidate.timestamp_us <= 2_000_000 for candidate in candidates)


def test_extract_frame_rejects_mismatched_output_extension(tmp_path: Path) -> None:
    source = tmp_path / "source.mp4"
    _create_fixture(source)

    with pytest.raises(ValueError, match="extension must match"):
        _DirectThumbnailService().extract_frame(source, 0, tmp_path / "preview.jpg", "png")


def test_signalstats_metadata_parser_reads_luma_values() -> None:
    diagnostics = "[Parsed_metadata_1] lavfi.signalstats.YAVG=100.25\n"

    assert ThumbnailService._metadata_value(diagnostics, "YAVG") == 100.25
