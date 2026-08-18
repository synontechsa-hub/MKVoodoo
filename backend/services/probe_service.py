import json
import subprocess
from pathlib import Path
from typing import Any, Dict, List

from backend.models.clip import ClipFrame, ClipMediaInfo
from backend.utils.paths import get_ffprobe_path

class ProbeService:
    """Service for probing media files using ffprobe."""

    def __init__(self) -> None:
        self._ffprobe = str(get_ffprobe_path())

    def probe_file(self, file_path: str | Path) -> Dict[str, Any]:
        """Probe a file and return its stream information."""
        try:
            result = subprocess.run(
                [
                    self._ffprobe,
                    "-v", "quiet",
                    "-print_format", "json",
                    "-show_streams",
                    "-show_format",
                    str(file_path)
                ],
                capture_output=True,
                text=True,
                check=True,
                encoding="utf-8",
                errors="replace"
            )
            parsed: Dict[str, Any] = json.loads(result.stdout)
            return parsed
        except Exception as exc:
            return {"error": str(exc), "streams": []}

    def get_tracks(self, file_path: str | Path) -> Dict[str, List[Dict[str, Any]]]:
        """Return categorized audio and subtitle tracks."""
        data = self.probe_file(file_path)
        streams = data.get("streams", [])

        audio = []
        subtitles = []

        for s in streams:
            codec_type = s.get("codec_type")
            index = s.get("index")
            lang = s.get("tags", {}).get("language", "und")
            title = s.get("tags", {}).get("title", f"Track {index}")

            track_info = {
                "index": index,
                "codec": s.get("codec_name"),
                "language": lang,
                "title": title,
                "channels": s.get("channels") if codec_type == "audio" else None
            }

            if codec_type == "audio":
                audio.append(track_info)
            elif codec_type == "subtitle":
                subtitles.append(track_info)

        return {
            "audio": audio,
            "subtitles": subtitles
        }

    def get_clip_media_info(self, file_path: str | Path) -> ClipMediaInfo:
        """Return the primary-video facts required by the Clipper."""
        source = Path(file_path)
        data = self.probe_file(source)
        if data.get("error"):
            raise ValueError(f"Unable to probe source media: {data['error']}")

        video_stream = next(
            (stream for stream in data.get("streams", []) if stream.get("codec_type") == "video"),
            None,
        )
        if video_stream is None:
            raise ValueError("The source does not contain a video stream.")

        duration_us = self._seconds_to_us(
            video_stream.get("duration") or data.get("format", {}).get("duration")
        )
        if duration_us is None or duration_us <= 0:
            raise ValueError("The source does not report a usable video duration.")

        average_rate = video_stream.get("avg_frame_rate")
        real_rate = video_stream.get("r_frame_rate")
        is_vfr, reason = self._classify_frame_rate(average_rate, real_rate)
        frame_count = self._as_positive_int(video_stream.get("nb_frames"))

        return ClipMediaInfo(
            source=str(source),
            duration_us=duration_us,
            video_stream_index=int(video_stream.get("index", 0)),
            width=int(video_stream.get("width", 0)),
            height=int(video_stream.get("height", 0)),
            codec=video_stream.get("codec_name"),
            time_base=video_stream.get("time_base"),
            average_frame_rate=average_rate,
            real_frame_rate=real_rate,
            frame_count=frame_count,
            is_variable_frame_rate=is_vfr,
            frame_rate_reason=reason,
        )

    def get_nearby_frames(
        self,
        file_path: str | Path,
        around_us: int,
        before: int = 1,
        after: int = 1,
    ) -> List[ClipFrame]:
        """Return a bounded timestamp window around a requested position.

        FFprobe presentation timestamps, not player seeking, are the source of
        truth for the Clipper's frame boundaries. The bounded interval avoids
        loading every frame from long recordings.
        """
        if around_us < 0:
            raise ValueError("The frame position cannot be negative.")
        if before < 0 or after < 0:
            raise ValueError("Frame window sizes cannot be negative.")

        info = self.get_clip_media_info(file_path)
        window_us = max(1_000_000, (before + after + 2) * 250_000)
        start_us = max(0, around_us - window_us)
        interval_seconds = (window_us * 2) / 1_000_000
        start_seconds = start_us / 1_000_000

        result = subprocess.run(
            [
                self._ffprobe,
                "-v", "error",
                "-select_streams", "v:0",
                "-read_intervals", f"{start_seconds:.6f}%+{interval_seconds:.6f}",
                "-show_frames",
                "-show_entries", "frame=best_effort_timestamp_time,pkt_duration_time,key_frame",
                "-of", "json",
                str(file_path),
            ],
            capture_output=True,
            text=True,
            check=True,
            encoding="utf-8",
            errors="replace",
        )
        payload: Dict[str, Any] = json.loads(result.stdout)
        frames = [
            ClipFrame(
                pts_us=pts_us,
                duration_us=self._seconds_to_us(frame.get("pkt_duration_time")),
                key_frame=bool(frame.get("key_frame", 0)),
            )
            for frame in payload.get("frames", [])
            if (pts_us := self._seconds_to_us(frame.get("best_effort_timestamp_time"))) is not None
        ]
        frames.sort(key=lambda frame: frame.pts_us)

        lower = [frame for frame in frames if frame.pts_us <= around_us]
        upper = [frame for frame in frames if frame.pts_us > around_us]
        return lower[-(before + 1):] + upper[:after]

    @staticmethod
    def _seconds_to_us(value: Any) -> int | None:
        try:
            return int(round(float(value) * 1_000_000))
        except (TypeError, ValueError):
            return None

    @staticmethod
    def _as_positive_int(value: Any) -> int | None:
        try:
            parsed = int(value)
            return parsed if parsed >= 0 else None
        except (TypeError, ValueError):
            return None

    @staticmethod
    def _classify_frame_rate(
        average_rate: str | None, real_rate: str | None
    ) -> tuple[bool, str]:
        if not average_rate or not real_rate or average_rate == "0/0" or real_rate == "0/0":
            return True, "Frame-rate metadata is incomplete; presentation timestamps are required."
        if average_rate != real_rate:
            return True, "Average and real frame-rate metadata differ."
        return False, "Average and real frame-rate metadata agree."
