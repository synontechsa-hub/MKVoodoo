import pytest
import json
from unittest.mock import MagicMock, patch
from backend.services.update_service import UpdateService

@pytest.fixture
def update_service():
    return UpdateService(current_version="1.0.2")

def test_is_newer(update_service):
    assert update_service._is_newer("1.1.0", "1.0.2") is True
    assert update_service._is_newer("1.0.2", "1.0.1") is True
    assert update_service._is_newer("1.0.2", "1.0.2") is False
    assert update_service._is_newer("1.0.2", "1.1.0") is False

@patch("urllib.request.urlopen")
def test_check_for_update_available(mock_urlopen, update_service):
    # Mock GitHub API response
    mock_response = MagicMock()
    mock_response.status = 200
    mock_data = {
        "tag_name": "v1.1.0",
        "html_url": "https://github.com/synontech/mkvoodoo/releases/tag/v1.1.0",
        "body": "New features!",
        "assets": [{"name": "MKVoodoo_Setup.exe", "browser_download_url": "https://download.com/setup.exe"}]
    }
    mock_response.read.return_value = json.dumps(mock_data).encode("utf-8")
    mock_urlopen.return_value.__enter__.return_value = mock_response

    res = update_service.check_for_update()
    
    assert res["update_available"] is True
    assert res["version"] == "1.1.0"
    assert res["installer_url"] == "https://download.com/setup.exe"

@patch("urllib.request.urlopen")
def test_check_for_update_none(mock_urlopen, update_service):
    mock_response = MagicMock()
    mock_response.status = 200
    mock_data = {"tag_name": "v1.0.2"}
    mock_response.read.return_value = json.dumps(mock_data).encode("utf-8")
    mock_urlopen.return_value.__enter__.return_value = mock_response

    res = update_service.check_for_update()
    assert res["update_available"] is False
