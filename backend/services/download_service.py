import subprocess
import json
import os
import re
from pathlib import Path
from typing import Dict, Any, Optional, Callable
from backend.utils.paths import get_ffmpeg_path, get_ytdlp_path, _get_downloads_dir
from backend.core.exceptions import MKVoodooError


class DownloadService:
    """Service for downloading videos using yt-dlp."""

    def __init__(self) -> None:
        ytdlp_path = get_ytdlp_path()
        if not ytdlp_path.is_file():
            raise MKVoodooError(
                "The YouTube downloader is unavailable. Expected yt-dlp.exe at "
                f"'{ytdlp_path}'. Reinstall MKVoodoo or restore the bundled downloader."
            )
        self._ytdlp = str(ytdlp_path)
        # yt-dlp needs both ffmpeg and ffprobe for video merging and audio
        # extraction. Point it at the bundled binary directory instead of
        # relying on the user's PATH.
        self._ffmpeg_location = str(get_ffmpeg_path().parent)

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
                    "--",
                    url
                ],
                capture_output=True,
                text=True,
                check=True,
                encoding="utf-8",
                errors="replace",
                stdin=subprocess.DEVNULL,
            )
            parsed: Dict[str, Any] = json.loads(result.stdout)
            return parsed
        except subprocess.CalledProcessError as e:
            details = (e.stderr or e.stdout or str(e)).strip()
            raise MKVoodooError(f"Failed to fetch metadata: {details}")
        except Exception as e:
            raise MKVoodooError(f"Unexpected error fetching metadata: {e}")

    def download_video(
        self,
        url: str,
        output_path: Optional[Path] = None,
        on_progress: Optional[Callable[[float], None]] = None,
        audio_only: bool = False,
        audio_format: str = "mp3",
        video_quality: str = "1080",
    ) -> Path:
        """Download video or extract audio to the downloads directory."""
        if not output_path:
            downloads_dir = _get_downloads_dir()
            ext = audio_format if audio_only else "mp4"
            output_template = str(downloads_dir / f"%(title).200s.{ext}")
        else:
            output_template = str(output_path)

        if video_quality not in {"1080", "720", "480", "360"}:
            raise MKVoodooError("Video quality must be 1080p, 720p, 480p, or 360p.")

        cmd = [
            self._ytdlp,
            "--newline",
            "--no-playlist",
            "--restrict-filenames",
            # The Android client supplies a usable progressive fallback when
            # YouTube enables SABR-only adaptive streams for web clients.
            "--extractor-args", "youtube:player_client=android",
            "--socket-timeout", "30",
            "--retries", "3",
            "--fragment-retries", "3",
            "--add-metadata",
            "--embed-thumbnail",
            "--print", "after_move:filepath",
            "--ffmpeg-location", self._ffmpeg_location,
        ]

        if audio_only:
            cmd += [
                "--extract-audio",
                "--audio-format", audio_format,
                "--audio-quality", "0",  # Best
            ]
        else:
            format_selector = (
                f"bestvideo[height<={video_quality}]+bestaudio/"
                f"best[height<={video_quality}]/best"
            )
            cmd += [
                "--format", format_selector,
                "--merge-output-format", "mp4",
            ]

        cmd += ["--output", output_template, "--", url]

        try:
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                stdin=subprocess.DEVNULL,
                universal_newlines=True,
                encoding="utf-8",
                errors="replace",
                creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
            )

            final_path = None
            recent_output = []
            if process.stdout:
                for line in process.stdout:
                    line = line.strip()
                    if not line:
                        continue

                    recent_output.append(line)
                    if len(recent_output) > 10:
                        recent_output.pop(0)

                    # 1. Parse deterministic path from --print after_move:filepath
                    # This line will only contain the path because of --print
                    in_downloads_dir = line.startswith(str(_get_downloads_dir()))
                    in_requested_dir = output_path and line.startswith(
                        str(output_path.parent)
                    )
                    if in_downloads_dir or in_requested_dir:
                        final_path = Path(line)
                        continue

                    # 2. Parse progress: [download]  10.5% of 100.00MiB at 1.50MiB/s ETA 01:00
                    progress_match = re.search(r"\[download\]\s+(\d+\.\d+)%", line)
                    if progress_match and on_progress:
                        on_progress(float(progress_match.group(1)))

            process.wait()

            if process.returncode != 0:
                details = recent_output[-1] if recent_output else "No diagnostic output was returned."
                raise MKVoodooError(
                    f"Download failed with exit code {process.returncode}: {details}"
                )

            if not final_path or not final_path.exists():
                raise MKVoodooError("Download finished but could not verify output file path.")

            return final_path.absolute()

        except MKVoodooError:
            raise
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
