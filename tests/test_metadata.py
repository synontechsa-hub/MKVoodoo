import pytest
import json
from unittest.mock import MagicMock, patch
from backend.services.metadata_service import MetadataService

@pytest.fixture
def metadata_service():
    return MetadataService(api_key="test-key")

@patch("urllib.request.urlopen")
def test_search_content_success(mock_urlopen, metadata_service):
    mock_data = {
        "results": [
            {"id": 1, "title": "Inception", "release_date": "2010-07-16", "poster_path": "/path.jpg"}
        ]
    }
    mock_response = MagicMock()
    mock_response.read.return_value = json.dumps(mock_data).encode("utf-8")
    mock_urlopen.return_value.__enter__.return_value = mock_response
    
    results = metadata_service.search_content("Inception")
    
    assert len(results) == 1
    assert results[0]["title"] == "Inception"
    assert results[0]["id"] == 1
    mock_urlopen.assert_called_once()
    assert "query=Inception" in mock_urlopen.call_args[0][0]

def test_get_poster_url(metadata_service):
    path = "/test.jpg"
    url = metadata_service.get_poster_url(path, size="w500")
    assert url == "https://image.tmdb.org/t/p/w500/test.jpg"
    
    # Test empty path
    assert metadata_service.get_poster_url(None) == ""

@patch("urllib.request.urlopen")
def test_get_details(mock_urlopen, metadata_service):
    mock_data = {"id": 1, "overview": "A dream within a dream"}
    mock_response = MagicMock()
    mock_response.read.return_value = json.dumps(mock_data).encode("utf-8")
    mock_urlopen.return_value.__enter__.return_value = mock_response
    
    details = metadata_service.get_details(1)
    assert details["overview"] == "A dream within a dream"
    assert "/movie/1?" in mock_urlopen.call_args[0][0]
