import pytest
from unittest.mock import MagicMock, patch
from pathlib import Path
from backend.services.download_service import DownloadService
from backend.core.exceptions import MKVoodooError

@pytest.fixture
def download_service():
    with patch("backend.services.download_service.get_ytdlp_path", return_value="yt-dlp"):
        return DownloadService()

def test_fetch_metadata_success(download_service):
    mock_json = '{"title": "Test Video", "thumbnail": "url", "duration": 120}'
    
    with patch("subprocess.run") as mock_run:
        mock_run.return_value = MagicMock(stdout=mock_json, returncode=0)
        
        meta = download_service.fetch_metadata("https://youtube.com/watch?v=123")
        
        assert meta["title"] == "Test Video"
        assert meta["duration"] == 120
        mock_run.assert_called_once()

def test_fetch_metadata_failure(download_service):
    with patch("subprocess.run") as mock_run:
        mock_run.side_effect = Exception("Process error")
        
        with pytest.raises(MKVoodooError, match="Unexpected error fetching metadata"):
            download_service.fetch_metadata("invalid-url")

@patch("subprocess.Popen")
def test_download_video_parsing(mock_popen, download_service):
    # Simulate yt-dlp output lines
    mock_stdout = [
        "[download]   5.0% of 10.00MiB at 1.00MiB/s ETA 00:10\n",
        "[download]  10.0% of 10.00MiB at 1.00MiB/s ETA 00:09\n",
        "[download] Destination: D:/Downloads/Test Video.mp4\n"
    ]
    
    process_mock = MagicMock()
    process_mock.stdout = iter(mock_stdout)
    process_mock.returncode = 0
    mock_popen.return_value = process_mock
    
    # Mock Path.exists to return true for our fake destination
    with patch("pathlib.Path.exists", return_value=True):
        progress_calls = []
        def on_progress(p): progress_calls.append(p)
        
        path = download_service.download_video("url", on_progress=on_progress)
        
        assert "Test Video.mp4" in str(path)
        assert 5.0 in progress_calls
        assert 10.0 in progress_calls
