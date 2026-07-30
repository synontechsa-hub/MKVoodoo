import pytest
import json
from unittest.mock import MagicMock, patch
from backend.services.metadata_service import MetadataService
from backend.core.exceptions import MKVoodooError

@pytest.fixture
def metadata_service():
    # Key must be > 10 chars to pass is_authenticated check
    return MetadataService(api_key="test-api-key-valid-length")

def test_is_authenticated(metadata_service):
    assert metadata_service.is_authenticated is True
    
    empty_svc = MetadataService(api_key="")
    assert empty_svc.is_authenticated is False
    
    short_svc = MetadataService(api_key="short")
    assert short_svc.is_authenticated is False

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

def test_search_content_unauthenticated():
    svc = MetadataService(api_key="")
    with pytest.raises(MKVoodooError, match="TMDB API Key is missing"):
        svc.search_content("test")

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
