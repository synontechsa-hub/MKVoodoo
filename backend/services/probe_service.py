import subprocess
import json
from pathlib import Path
from typing import List, Dict, Any, Optional
import static_ffmpeg

class ProbeService:
    """Service for probing media files using ffprobe."""

    def __init__(self):
        _, self._ffprobe = static_ffmpeg.run.get_or_fetch_platform_executables_else_raise()

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
            return json.loads(result.stdout)
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
