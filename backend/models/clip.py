"""Typed media facts shared by the Clipper backend contract."""

from __future__ import annotations

from dataclasses import asdict, dataclass


@dataclass(frozen=True)
class ClipFrame:
    """A decoded video frame identified by its presentation timestamp."""

    pts_us: int
    duration_us: int | None
    key_frame: bool

    def to_dict(self) -> dict[str, int | bool | None]:
        return asdict(self)


@dataclass(frozen=True)
class ClipMediaInfo:
    """Media facts required for accurate Clipper navigation and export."""

    source: str
    duration_us: int
    video_stream_index: int
    width: int
    height: int
    codec: str | None
    time_base: str | None
    average_frame_rate: str | None
    real_frame_rate: str | None
    frame_count: int | None
    is_variable_frame_rate: bool
    frame_rate_reason: str

    def to_dict(self) -> dict[str, int | str | bool | None]:
        return asdict(self)


@dataclass(frozen=True)
class ClipExportResult:
    """Verified result of a precise clip export."""

    output: str
    start_us: int
    end_us: int
    encoder: str

    def to_dict(self) -> dict[str, int | str]:
        return asdict(self)


@dataclass(frozen=True)
class ThumbnailCandidate:
    """A locally generated thumbnail frame from a Clipper selection."""

    timestamp_us: int
    path: str
    score: float

    def to_dict(self) -> dict[str, int | str | float]:
        return asdict(self)
