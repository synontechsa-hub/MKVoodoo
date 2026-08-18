"""Tests for the Clipper-oriented FFprobe contract."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from backend.models.clip import ClipMediaInfo
from backend.services.probe_service import ProbeService


def test_clip_media_info_uses_primary_video_and_reports_cfr() -> None:
    service = ProbeService()
    with patch.object(
        service,
        "probe_file",
        return_value={
            "format": {"duration": "12.5"},
            "streams": [
                {"index": 0, "codec_type": "audio"},
                {
                    "index": 1,
                    "codec_type": "video",
                    "width": 1920,
                    "height": 1080,
                    "codec_name": "h264",
                    "time_base": "1/90000",
                    "avg_frame_rate": "30000/1001",
                    "r_frame_rate": "30000/1001",
                    "nb_frames": "375",
                },
            ],
        },
    ):
        info = service.get_clip_media_info("clip.mp4")

    assert info.video_stream_index == 1
    assert info.duration_us == 12_500_000
    assert info.frame_count == 375
    assert not info.is_variable_frame_rate


def test_clip_media_info_marks_incomplete_rate_metadata_as_vfr() -> None:
    service = ProbeService()
    with patch.object(
        service,
        "probe_file",
        return_value={
            "format": {"duration": "1"},
            "streams": [{"index": 0, "codec_type": "video", "avg_frame_rate": "0/0"}],
        },
    ):
        info = service.get_clip_media_info("clip.mkv")

    assert info.is_variable_frame_rate
    assert "presentation timestamps" in info.frame_rate_reason


def test_clip_media_info_rejects_sources_without_video() -> None:
    service = ProbeService()
    with patch.object(service, "probe_file", return_value={"streams": []}):
        with pytest.raises(ValueError, match="video stream"):
            service.get_clip_media_info("audio.mp3")


def test_nearby_frames_uses_presentation_timestamps_and_returns_window() -> None:
    service = ProbeService()
    info = ClipMediaInfo(
        source="clip.mp4",
        duration_us=5_000_000,
        video_stream_index=1,
        width=1920,
        height=1080,
        codec="h264",
        time_base="1/90000",
        average_frame_rate="30/1",
        real_frame_rate="30/1",
        frame_count=150,
        is_variable_frame_rate=False,
        frame_rate_reason="metadata agrees",
    )
    response = MagicMock(
        stdout=(
            '{"frames": ['
            '{"best_effort_timestamp_time": "0.900", "pkt_duration_time": "0.033", "key_frame": 0},'
            '{"best_effort_timestamp_time": "1.000", "pkt_duration_time": "0.033", "key_frame": 1},'
            '{"best_effort_timestamp_time": "1.050", "pkt_duration_time": "0.033", "key_frame": 0},'
            '{"best_effort_timestamp_time": "1.100", "pkt_duration_time": "0.033", "key_frame": 0}'
            ']}'
        )
    )
    with patch.object(service, "get_clip_media_info", return_value=info), patch(
        "backend.services.probe_service.subprocess.run", return_value=response
    ) as run:
        frames = service.get_nearby_frames("clip.mp4", 1_000_000, before=1, after=1)

    assert [frame.pts_us for frame in frames] == [900_000, 1_000_000, 1_050_000]
    assert frames[1].key_frame
    assert "v:0" in run.call_args.args[0]


def test_nearby_frames_rejects_negative_positions() -> None:
    service = ProbeService()
    with pytest.raises(ValueError, match="cannot be negative"):
        service.get_nearby_frames("clip.mp4", -1)
