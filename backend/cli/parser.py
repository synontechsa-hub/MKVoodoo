import argparse


def build_parser() -> argparse.ArgumentParser:
    """Define the CLI structure for MKVoodoo."""
    parser = argparse.ArgumentParser(
        prog="mkvoodoo",
        description="MKVoodoo — Offline batch video transcoder",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    # -- config --
    p_config = sub.add_parser("config", help="Read or update global configuration")
    p_config.add_argument("--get", action="store_true", help="Get current config as JSON")
    p_config.add_argument("--set", help="Update config with a JSON string")

    # -- queue --
    p_queue = sub.add_parser("queue", help="Manage the job queue")
    p_queue.add_argument("--resume", action="store_true", help="Process pending jobs in the queue")
    p_queue.add_argument("--clear-done", action="store_true", help="Remove completed/skipped jobs")
    p_queue.add_argument("--clear-all", action="store_true", help="Remove all non-pending jobs")
    p_queue.add_argument("--reset-failed", action="store_true", help="Reset failed jobs to pending")
    p_queue.add_argument("--remove", help="Remove jobs by comma-separated IDs")
    p_queue.add_argument("--add", nargs="+", help="Add specific files to the queue")
    p_queue.add_argument("--jobs", help="Add jobs from a JSON string")
    p_queue.add_argument("--to", help="Output directory for added files")

    # -- scan --
    p_scan = sub.add_parser("scan", help="Scan directories/files and list video files")
    p_scan.add_argument("--input", "-i", nargs="+", required=True, help="Input items to scan")
    p_scan.add_argument("--output", "-o", help="Output directory (for safety check only)")
    p_scan.add_argument("--json", action="store_true", help="Output results as JSON")

    # -- convert --
    p_conv = sub.add_parser("convert", help="Convert video files")
    p_conv.add_argument("--input", "-i", required=True, help="Input directory")
    p_conv.add_argument("--output", "-o", help="Output root directory")
    p_conv.add_argument("--preset", "-p", help="Preset name")
    p_conv.add_argument("--encoder", "-e", help="Force a specific FFmpeg encoder")
    p_conv.add_argument("--template", "-t", help="Custom naming template")
    p_conv.add_argument("--no-review", action="store_true", help="Skip review mode")

    # -- status --
    p_stat = sub.add_parser("status", help="Show queue status")
    p_stat.add_argument("--queue", "-q", help="Path to queue file")
    p_stat.add_argument("--json", action="store_true", help="Output status as JSON")

    # -- presets --
    sub.add_parser("presets", help="List available presets")

    # -- encoders --
    sub.add_parser("encoders", help="List available hardware backends")

    # -- probe --
    p_probe = sub.add_parser("probe", help="Probe a media file for streams")
    p_probe.add_argument("--input", "-i", required=True, help="Input file to probe")
    p_probe.add_argument("--clip-info", action="store_true", help="Return Clipper media metadata as JSON")
    p_probe.add_argument("--around-us", type=int, help="Return neighbouring video frames around this timestamp")
    p_probe.add_argument("--before", type=int, default=1, help="Frames to return before the requested timestamp")
    p_probe.add_argument("--after", type=int, default=1, help="Frames to return after the requested timestamp")

    p_clip = sub.add_parser("clip", help="Precise video clip export")
    p_clip.add_argument("--input", "-i", required=True, help="Source video")
    p_clip.add_argument("--output", "-o", required=True, help="New MP4 or MKV output path")
    p_clip.add_argument("--in-us", type=int, required=True, help="Inclusive In frame presentation timestamp")
    p_clip.add_argument("--out-us", type=int, required=True, help="Inclusive Out frame presentation timestamp")
    p_clip.add_argument("--container", choices=("mp4", "mkv"), default="mp4")

    p_thumbnail = sub.add_parser("thumbnail", help="Extract Clipper thumbnail previews")
    p_thumbnail.add_argument("--input", "-i", required=True, help="Source video")
    p_thumbnail.add_argument("--timestamp-us", type=int, help="Exact frame presentation timestamp")
    p_thumbnail.add_argument("--output", "-o", help="JPG or PNG output path for an exact frame")
    p_thumbnail.add_argument("--format", choices=("jpg", "png"), default="png")
    p_thumbnail.add_argument("--in-us", type=int, help="Selection start for candidate generation")
    p_thumbnail.add_argument("--end-us", type=int, help="Selection end for candidate generation")
    p_thumbnail.add_argument("--cache-dir", help="Cache directory for generated candidates")
    p_thumbnail.add_argument("--count", type=int, default=4, help="Number of ranked candidates to return")

    # -- youtube --
    p_yt = sub.add_parser("youtube", help="YouTube download tools")
    p_yt.add_argument("--info", help="Fetch video metadata from URL")
    p_yt.add_argument("--download", help="Download video from URL")
    p_yt.add_argument("--audio-only", action="store_true", help="Extract audio only")
    p_yt.add_argument("--format", default="mp3", help="Audio format (mp3, flac, m4a)")

    # -- metadata --
    p_meta = sub.add_parser("metadata", help="Fetch movie/TV show metadata")
    p_meta.add_argument("--search", help="Search for content title")
    p_meta.add_argument("--tv", action="store_true", help="Search for TV show instead of movie")

    # -- updates --
    sub.add_parser("check-update", help="Check for application updates")
    sub.add_parser("update-downloader", help="Update the yt-dlp binary")

    # -- debug --
    sub.add_parser("debug", help="Print system debug information for bug reports")

    return parser
