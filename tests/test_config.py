import json

from backend.models.config import DEFAULT_NAMING_TEMPLATE
from backend.services.config_service import ConfigService


def test_migrates_test_sentinel_naming_template(tmp_path):
    config_path = tmp_path / "mkvoodoo_config.json"
    config_path.write_text(
        json.dumps({"version": 1, "naming_template": "PROD_{title}"}),
        encoding="utf-8",
    )

    config = ConfigService(config_path).load()

    assert config.version == 2
    assert config.naming_template == DEFAULT_NAMING_TEMPLATE
    persisted = json.loads(config_path.read_text(encoding="utf-8"))
    assert persisted["version"] == 2
    assert persisted["naming_template"] == DEFAULT_NAMING_TEMPLATE


def test_preserves_custom_naming_template_during_migration(tmp_path):
    config_path = tmp_path / "mkvoodoo_config.json"
    config_path.write_text(
        json.dumps({"version": 1, "naming_template": "Archive - {title}"}),
        encoding="utf-8",
    )

    config = ConfigService(config_path).load()

    assert config.version == 2
    assert config.naming_template == "Archive - {title}"
