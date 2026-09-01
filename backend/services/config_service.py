import json
from dataclasses import asdict
from pathlib import Path

from backend.core.exceptions import ConfigError
from backend.models.config import DEFAULT_NAMING_TEMPLATE, MKVoodooConfig
from backend.utils.paths import _default_config_file


class ConfigService:
    """Service for managing application configuration."""

    def __init__(self, config_path: Path | None = None):
        self._path = config_path or _default_config_file()

    def load(self) -> MKVoodooConfig:
        """Load config from JSON file, or return defaults if file doesn't exist."""
        if self._path.exists():
            try:
                with open(self._path, encoding="utf-8") as f:
                    data = json.load(f)

                # Filter unknown fields to avoid errors on schema changes
                known = {k for k in MKVoodooConfig.__dataclass_fields__}
                filtered = {k: v for k, v in data.items() if k in known}
                config = MKVoodooConfig(**filtered)
                self._migrate(config)
                return config
            except (json.JSONDecodeError, TypeError):
                # Fall back to defaults but keep the file
                return MKVoodooConfig()
        return MKVoodooConfig()

    def _migrate(self, config: MKVoodooConfig) -> None:
        """Repair known legacy state and persist the current config schema."""
        if config.version >= 2:
            return

        # An early integration test wrote this sentinel into real user config
        # before the test suite gained application-data isolation.
        if config.naming_template == "PROD_{title}":
            config.naming_template = DEFAULT_NAMING_TEMPLATE

        config.version = 2
        self.save(config)

    def save(self, cfg: MKVoodooConfig) -> None:
        """Persist config to JSON file."""
        try:
            self._path.parent.mkdir(parents=True, exist_ok=True)
            with open(self._path, "w", encoding="utf-8") as f:
                json.dump(asdict(cfg), f, indent=2)
        except Exception as exc:
            raise ConfigError(f"Failed to save configuration to {self._path}: {exc}")

    def update_from_json(self, json_str: str) -> MKVoodooConfig:
        """Update current config with values from a JSON string."""
        try:
            updates = json.loads(json_str)
            cfg = self.load()
            for k, v in updates.items():
                if hasattr(cfg, k):
                    setattr(cfg, k, v)
            self.save(cfg)
            return cfg
        except json.JSONDecodeError:
            raise ConfigError("Invalid JSON provided for configuration update.")
        except Exception as exc:
            raise ConfigError(f"Configuration update failed: {exc}")
