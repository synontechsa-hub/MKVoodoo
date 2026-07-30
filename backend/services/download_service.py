import subprocess
import json
import os
import re
from pathlib import Path
from typing import Dict, Any, Optional, Callable
from backend.utils.paths import get_ytdlp_path, _get_downloads_dir
from backend.core.exceptions import MKVoodooError

class DownloadService:
    """Service for downloading videos using yt-dlp."""

    def __init__(self):
        self._ytdlp = str(get_ytdlp_path())

    def fetch_metadata(self, url: str) -> Dict[str, Any]:
        """Fetch video metadata without downloading."""
        try:
            result = subprocess.run(
                [
                    self._ytdlp,
                    "--quiet",
                    "--print-json",
                    "--skip-download",
                    "--no-playlist",
                    url
                ],
                capture_output=True,
                text=True,
                check=True,
                encoding="utf-8",
                errors="replace"
            )
            return json.loads(result.stdout)
        except subprocess.CalledProcessError as e:
            raise MKVoodooError(f"Failed to fetch metadata: {e.stderr}")
        except Exception as e:
            raise MKVoodooError(f"Unexpected error fetching metadata: {e}")

    def download_video(
        self,
        url: str,
        output_path: Optional[Path] = None,
        on_progress: Optional[Callable[[float], None]] = None,
        audio_only: bool = False,
        audio_format: str = "mp3"
    ) -> Path:
        """Download video or extract audio to the downloads directory."""
        if not output_path:
            downloads_dir = _get_downloads_dir()
            ext = audio_format if audio_only else "mp4"
            output_template = str(downloads_dir / f"%(title).200s.{ext}")
        else:
            output_template = str(output_path)

        cmd = [
            self._ytdlp,
            "--newline",
            "--no-playlist",
            "--restrict-filenames",
            "--add-metadata",
            "--embed-thumbnail",
            "--print", "after_move:filepath",
        ]

        if audio_only:
            cmd += [
                "--extract-audio",
                "--audio-format", audio_format,
                "--audio-quality", "0", # Best
            ]
        else:
            cmd += [
                "--format", "bestvideo[height<=1080]+bestaudio/best[height<=1080]/best",
                "--merge-output-format", "mp4",
            ]

        cmd += ["--output", output_template, url]

        try:
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                universal_newlines=True,
                encoding="utf-8",
                errors="replace",
                creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
            )

            final_path = None
            for line in process.stdout:
                line = line.strip()
                if not line:
                    continue

                # 1. Parse deterministic path from --print after_move:filepath
                # This line will only contain the path because of --print
                if line.startswith(str(_get_downloads_dir())) or (output_path and line.startswith(str(output_path.parent))):
                    final_path = Path(line)
                    continue

                # 2. Parse progress: [download]  10.5% of 100.00MiB at 1.50MiB/s ETA 01:00
                progress_match = re.search(r"\[download\]\s+(\d+\.\d+)%", line)
                if progress_match and on_progress:
                    on_progress(float(progress_match.group(1)))

            process.wait()
            
            if process.returncode != 0:
                raise MKVoodooError(f"Download failed with exit code {process.returncode}")

            if not final_path or not final_path.exists():
                raise MKVoodooError("Download finished but could not verify output file path.")

            return final_path.absolute()

        except Exception as e:
            raise MKVoodooError(f"Download error: {e}")

    def update_downloader(self) -> str:
        """Update yt-dlp to the latest version."""
        try:
            result = subprocess.run(
                [self._ytdlp, "-U"],
                capture_output=True,
                text=True,
                check=True,
                encoding="utf-8"
            )
            return result.stdout
        except subprocess.CalledProcessError as e:
            raise MKVoodooError(f"Failed to update downloader: {e.stderr}")
        except Exception as e:
            raise MKVoodooError(f"Unexpected error updating downloader: {e}")
