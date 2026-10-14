"""Audio mapping and channel layout regression tests for conversions."""

from unittest.mock import Mock

from backend.models.hardware import EncoderBackend, EncoderInfo
from backend.models.job import Job
from backend.presets import get_preset
from backend.services.converter_service import ConverterService


ENCODER = EncoderInfo(EncoderBackend.CPU, "libx264", "CPU", False)
TRACKS = [
    {"index": 1, "channels": 6},
    {"index": 2, "channels": 2},
    {"index": 3, "channels": 1},
]


def make_service() -> tuple[ConverterService, Mock]:
    probe = Mock()
    probe.get_tracks.return_value = {"audio": TRACKS}
    return ConverterService(Mock(), Mock(), probe), probe


def make_job(**overrides: object) -> Job:
    return Job(id="audio-test", source="source.mkv", output="output.mkv",
               preset="720p_medium", **overrides)


def test_only_multichannel_aac_tracks_are_downmixed() -> None:
    service, _ = make_service()
    args = service._build_ffmpeg_args(make_job(), get_preset("720p_medium"), ENCODER)

    assert [args[i + 1] for i, value in enumerate(args) if value == "-map"][:2] == [
        "0:V:0?", "0:a?",
    ]
    assert "-ac:a:0" in args
    assert args[args.index("-ac:a:0") + 1] == "2"
    assert "-ac:a:1" not in args
    assert "-ac:a:2" not in args


def test_selected_track_order_controls_output_audio_index() -> None:
    service, _ = make_service()
    job = make_job(keep_all_audio=False, audio_tracks=[2, 1])
    args = service._build_ffmpeg_args(job, get_preset("720p_medium"), ENCODER)

    assert [args[i + 1] for i, value in enumerate(args) if value == "-map"][:3] == [
        "0:V:0?", "0:2", "0:1",
    ]
    assert "-ac:a:0" not in args
    assert args[args.index("-ac:a:1") + 1] == "2"


def test_audio_copy_keeps_original_channel_layout() -> None:
    service, probe = make_service()
    args = service._build_ffmpeg_args(
        make_job(audio_bitrate="copy"), get_preset("720p_medium"), ENCODER
    )

    assert args[args.index("-c:a") + 1] == "copy"
    assert not any(arg.startswith("-ac:a:") for arg in args)
    probe.get_tracks.assert_not_called()
