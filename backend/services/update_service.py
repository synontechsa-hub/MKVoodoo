import json
import urllib.request
from typing import Optional

from backend.core.exceptions import MKVoodooError
from backend.version import VERSION

UPDATE_URL = "https://api.github.com/repos/synontechsa-hub/mkvoodoo/releases/latest"


class UpdateService:
    """Service for checking and applying application updates."""

    def __init__(self, current_version: str = VERSION) -> None:
        self.current_version = current_version

    def check_for_update(self) -> dict:
        """Check if a new version is available."""
        headers = {"User-Agent": "MKVoodoo-App"}
        req = urllib.request.Request(UPDATE_URL, headers=headers)

        try:
            with urllib.request.urlopen(req, timeout=10) as response:
                if response.status != 200:
                    raise MKVoodooError(f"Update server returned status {response.status}")

                data = json.loads(response.read().decode("utf-8"))
                latest_version = data.get("tag_name", "").replace("v", "")

                if self._is_newer(latest_version, self.current_version):
                    return {
                        "update_available": True,
                        "version": latest_version,
                        "url": data.get("html_url"),
                        "notes": data.get("body"),
                        "installer_url": self._get_installer_url(data)
                    }

                return {"update_available": False}
        except Exception as e:
            raise MKVoodooError(f"Failed to check for updates: {e}")

    def _is_newer(self, latest: str, current: str) -> bool:
        """Simple version comparison."""
        try:
            l_parts = [int(p) for p in latest.split(".")]
            c_parts = [int(p) for p in current.split(".")]
            return l_parts > c_parts
        except Exception:
            return latest != current

    def _get_installer_url(self, release_data: dict) -> Optional[str]:
        """Find the .exe installer in release assets."""
        assets = release_data.get("assets", [])
        for asset in assets:
            if asset.get("name", "").endswith(".exe"):
                download_url: Optional[str] = asset.get("browser_download_url")
                return download_url
        return None
