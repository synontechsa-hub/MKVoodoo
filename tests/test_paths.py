from pathlib import Path
from unittest.mock import patch

from backend.utils.paths import get_javascript_runtime


def test_javascript_runtime_prefers_bundled_deno(tmp_path):
    backend_root = tmp_path / "backend"
    bundled = backend_root / "bin" / "deno.exe"
    bundled.parent.mkdir(parents=True)
    bundled.touch()

    with patch("backend.utils.paths._get_base_path", return_value=backend_root), patch(
        "backend.utils.paths.shutil.which", return_value="C:/Program Files/nodejs/node.exe"
    ):
        runtime = get_javascript_runtime()

    assert runtime == ("deno", bundled)


def test_javascript_runtime_falls_back_to_system_node(tmp_path):
    with patch("backend.utils.paths._get_base_path", return_value=tmp_path), patch(
        "backend.utils.paths.shutil.which",
        side_effect=lambda name: "C:/Program Files/nodejs/node.exe" if name == "node" else None,
    ):
        runtime = get_javascript_runtime()

    assert runtime == ("node", Path("C:/Program Files/nodejs/node.exe"))
