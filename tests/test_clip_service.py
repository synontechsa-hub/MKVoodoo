"""Integration coverage for precise, frame-boundary clip export."""

from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

from backend.models.hardware import EncoderBackend, EncoderInfo
from backend.models.clip import ClipFrame, ClipMediaInfo
from backend.services.clip_service import ClipService
from backend.utils.paths import get_ffmpeg_path


CPU_ENCODER = EncoderInfo(
    backend=EncoderBackend.CPU,
    video_encoder="libx264",
    label="Standard H.264 (CPU)",
    is_hardware=False,
)


def _create_cfr_fixture(path: Path) -> None:
    subprocess.run(
        [
            str(get_ffmpeg_path()), "-hide_banner", "-loglevel", "error", "-y",
            "-f", "lavfi", "-i", "testsrc2=size=64x64:rate=4:duration=2",
            "-c:v", "libx264", "-pix_fmt", "yuv420p", str(path),
        ],
        check=True,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def _frame_hashes(path: Path) -> list[str]:
    result = subprocess.run(
        [str(get_ffmpeg_path()), "-hide_banner", "-loglevel", "error", "-i", str(path),
         "-map", "0:v:0", "-f", "framemd5", "-"],
        check=True,
        capture_output=True,
        text=True,
        stdin=subprocess.DEVNULL,
    )
    return [line.split(",")[-1].strip() for line in result.stdout.splitlines() if line.startswith("0,")]


def _selection_ssim(source: Path, clip: Path, start_us: int, end_us: int) -> float:
    start, end = start_us / 1_000_000, end_us / 1_000_000
    result = subprocess.run(
        [
            str(get_ffmpeg_path()), "-hide_banner", "-i", str(source), "-i", str(clip),
            "-filter_complex",
            f"[0:v]trim=start={start}:end={end},setpts=PTS-STARTPTS[expected];"
            "[1:v]setpts=PTS-STARTPTS[actual];[expected][actual]ssim",
            "-f", "null", "-",
        ],
        check=True,
        capture_output=True,
        text=True,
        stdin=subprocess.DEVNULL,
    )
    marker = "All:"
    return float(result.stderr.rsplit(marker, 1)[1].split()[0])


class _FixtureProbe:
    """Avoid platform subprocess restrictions while FFmpeg validates output bytes."""

    def get_clip_media_info(self, path: Path) -> ClipMediaInfo:
        return ClipMediaInfo(
            source=str(path), duration_us=2_000_000, video_stream_index=0,
            width=64, height=64, codec="h264", time_base="1/16384",
            average_frame_rate="4/1", real_frame_rate="4/1", frame_count=8,
            is_variable_frame_rate=False, frame_rate_reason="fixture",
        )

    def get_tracks(self, _path: Path) -> dict[str, list[object]]:
        return {"audio": [], "subtitles": []}

    def get_nearby_frames(self, _path: Path, _out_us: int, before: int, after: int) -> list[ClipFrame]:
        assert before == 0 and after == 1
        return [ClipFrame(pts_us=1_250_000, duration_us=250_000, key_frame=False)]


class _DirectEngine:
    """Test adapter that avoids pytest's Windows streaming-handle conflict."""

    def run(self, args: list[str]) -> bool:
        subprocess.run(
            [str(get_ffmpeg_path()), *args],
            check=True,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return True


@pytest.fixture
def clip_service() -> ClipService:
    return ClipService(_DirectEngine(), _FixtureProbe())  # type: ignore[arg-type]


@pytest.mark.parametrize("container", ["mp4", "mkv"])
def test_export_preserves_inclusive_first_and_last_frames(
    clip_service: ClipService, tmp_path: Path, container: str
) -> None:
    source = tmp_path / "source.mp4"
    output = tmp_path / f"clip.{container}"
    _create_cfr_fixture(source)

    result = clip_service.export(source, output, 500_000, 1_000_000, container, CPU_ENCODER)

    assert output.exists()
    assert result.end_us == 1_250_000
    assert len(_frame_hashes(output)) == 3
    assert _selection_ssim(source, output, 500_000, 1_250_000) > 0.99


def test_export_refuses_to_overwrite_existing_output(clip_service: ClipService, tmp_path: Path) -> None:
    source = tmp_path / "source.mp4"
    output = tmp_path / "clip.mp4"
    _create_cfr_fixture(source)
    output.touch()

    with pytest.raises(FileExistsError, match="already exists"):
        clip_service.export(source, output, 0, 250_000, "mp4", CPU_ENCODER)


def test_export_single_frame_clip(tmp_path: Path) -> None:
    source = tmp_path / "source.mp4"
    output = tmp_path / "single_frame.mp4"
    _create_cfr_fixture(source)

    class _SingleFrameProbe(_FixtureProbe):
        def get_nearby_frames(self, _path: Path, _out_us: int, before: int, after: int) -> list[ClipFrame]:
            return [ClipFrame(pts_us=750_000, duration_us=250_000, key_frame=False)]

    service = ClipService(_DirectEngine(), _SingleFrameProbe())  # type: ignore[arg-type]
    result = service.export(source, output, 500_000, 500_000, "mp4", CPU_ENCODER)

    assert output.exists()
    assert result.end_us == 750_000
    assert len(_frame_hashes(output)) == 1


def test_export_final_frame_boundary_uses_source_duration(tmp_path: Path) -> None:
    source = tmp_path / "source.mp4"
    output = tmp_path / "final_frame.mp4"
    _create_cfr_fixture(source)

    class _FinalFrameProbe(_FixtureProbe):
        def get_nearby_frames(self, _path: Path, _out_us: int, before: int, after: int) -> list[ClipFrame]:
            # No following frame exists after the last frame
            return []

    service = ClipService(_DirectEngine(), _FinalFrameProbe())  # type: ignore[arg-type]
    result = service.export(source, output, 1_750_000, 1_750_000, "mp4", CPU_ENCODER)

    assert output.exists()
    assert result.end_us == 2_000_000
    assert len(_frame_hashes(output)) == 1


def test_export_cancellation_cleans_partial_output(tmp_path: Path) -> None:
    source = tmp_path / "source.mp4"
    output = tmp_path / "cancelled.mp4"
    _create_cfr_fixture(source)

    class _FailingEngine:
        def run(self, args: list[str]) -> bool:
            # Simulate partial write then cancellation/interruption
            partial = Path(args[-1])
            partial.write_bytes(b"partial video data in progress")
            raise RuntimeError("Process cancelled by user")

    service = ClipService(_FailingEngine(), _FixtureProbe())  # type: ignore[arg-type]

    with pytest.raises(RuntimeError, match="cancelled"):
        service.export(source, output, 0, 500_000, "mp4", CPU_ENCODER)

    partial = output.with_name(f"{output.stem}.partial{output.suffix}")
    assert not partial.exists()
    assert not output.exists()


def test_export_rejects_reversed_boundaries(clip_service: ClipService, tmp_path: Path) -> None:
    source = tmp_path / "source.mp4"
    _create_cfr_fixture(source)

    with pytest.raises(ValueError, match="Out frame"):
        clip_service.export(source, tmp_path / "clip.mp4", 500_000, 250_000, "mp4", CPU_ENCODER)

