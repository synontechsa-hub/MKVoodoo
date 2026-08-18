"""Shared test isolation for the MKVoodoo backend suite."""

from __future__ import annotations

from pathlib import Path

import pytest


@pytest.fixture(autouse=True)
def isolate_application_data(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    """Keep config, queue, logs, and downloads inside each test's temp directory."""
    app_data_dir = tmp_path / "mkvoodoo-data"
    monkeypatch.setattr("backend.utils.paths._get_user_data_dir", lambda: app_data_dir)

    from backend.core.container import container

    container.reset()
    yield
    container.reset()
