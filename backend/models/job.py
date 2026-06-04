from dataclasses import dataclass
from enum import Enum
from typing import Optional

class JobStatus(str, Enum):
    PENDING     = "pending"
    IN_PROGRESS = "in_progress"
    DONE        = "done"
    FAILED      = "failed"
    SKIPPED     = "skipped"

@dataclass
class Job:
    """Represents one file conversion task."""
    id: str
    source: str
    output: str
    preset: str
    status: JobStatus = JobStatus.PENDING
    error: Optional[str] = None
    attempts: int = 0

    # Track Selection (indices from ffprobe, or None for all)
    audio_tracks: Optional[list[int]] = None
    subtitle_tracks: Optional[list[int]] = None

    # Quality Overrides
    audio_bitrate: Optional[str] = None # e.g. "128k", "192k", "256k"

    # Extra flags
    keep_all_audio: bool = True
    keep_all_subtitles: bool = True
