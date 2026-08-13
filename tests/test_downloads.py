import pytest
import os
from unittest.mock import MagicMock, patch
from pathlib import Path
from backend.services.download_service import DownloadService
from backend.core.exceptions import MKVoodooError

@pytest.fixture
def download_service():
    with patch(
        "backend.services.download_service.get_ytdlp_path",
        return_value=Path(__file__),
    ):
        return DownloadService()

def test_missing_downloader_has_actionable_error():
    missing = Path("D:/missing/yt-dlp.exe")
    with patch("backend.services.download_service.get_ytdlp_path", return_value=missing):
        with pytest.raises(MKVoodooError, match="Reinstall MKVoodoo"):
            DownloadService()

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
    # Use os.path.join to ensure slashes match the OS expectations for startswith
    downloads_dir = Path("D:/Downloads").absolute()
    mock_dest = downloads_dir / "Test Video.mp4"
    
    with patch("backend.services.download_service._get_downloads_dir", return_value=downloads_dir):
        mock_stdout = [
            "[download]   5.0% of 10.00MiB at 1.00MiB/s ETA 00:10\n",
            f"{mock_dest}\n", # The deterministic path line with correct OS slashes
            "[download]  10.0% of 10.00MiB at 1.00MiB/s ETA 00:09\n",
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

@patch("subprocess.Popen")
def test_download_audio_only_flags(mock_popen, download_service):
    downloads_dir = Path("D:/Downloads").absolute()
    mock_dest = downloads_dir / "test.mp3"
    
    with patch("backend.services.download_service._get_downloads_dir", return_value=downloads_dir):
        process_mock = MagicMock()
        process_mock.stdout = iter([f"{mock_dest}\n"])
        process_mock.returncode = 0
        mock_popen.return_value = process_mock
        
        with patch("pathlib.Path.exists", return_value=True):
            download_service.download_video("url", audio_only=True, audio_format="flac")
            
            # Check if correct flags were passed to Popen
            args, kwargs = mock_popen.call_args
            cmd = args[0]
            assert "--extract-audio" in cmd
            assert "--audio-format" in cmd
            assert "flac" in cmd
            assert "--print" in cmd
            assert "after_move:filepath" in cmd

@patch("subprocess.Popen")
def test_download_failure_includes_ytdlp_diagnostic(mock_popen, download_service):
    process_mock = MagicMock()
    process_mock.stdout = iter(["ERROR: Sign in to confirm you are not a bot\n"])
    process_mock.returncode = 1
    mock_popen.return_value = process_mock

    with pytest.raises(MKVoodooError, match="Sign in to confirm"):
        download_service.download_video("https://youtube.com/watch?v=123")
