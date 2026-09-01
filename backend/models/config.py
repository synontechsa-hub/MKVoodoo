from dataclasses import dataclass, field
from typing import Literal

from backend.utils.paths import _default_log_dir, _default_output_dir, _default_queue_file

PresetName = Literal["720p_mobile", "480p_saver"]
DEFAULT_NAMING_TEMPLATE = "S{S:02d}E{E:02d} - {title}"


@dataclass
class MKVoodooConfig:
    """User-editable global configuration."""
    version: int = 2

    # --- Output ---
    output_dir: str = field(default_factory=lambda: str(_default_output_dir()))

    # --- Conversion ---
    default_preset: PresetName = "720p_mobile"
    default_audio_bitrate: str = "128k"

    # --- Naming ---
    naming_template: str = DEFAULT_NAMING_TEMPLATE

    # --- Behaviour ---
    review_before_convert: bool = True
    skip_existing: bool = True
    max_retries: int = 1
    parallel_jobs: int = 2
    show_notifications: bool = True
    update_check_enabled: bool = True
    auto_update_downloader: bool = False

    # --- Hardware ---
    force_encoder: str | None = None

    # --- Web Services ---
    tmdb_api_key: str = ""

    # --- Logging & Queue ---
    log_dir: str = field(default_factory=lambda: str(_default_log_dir()))
    queue_file: str = field(default_factory=lambda: str(_default_queue_file()))
