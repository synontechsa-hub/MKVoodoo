import pytest
from backend.core.container import container
from backend.models.scan import ScanResult
from pathlib import Path
from unittest.mock import patch, MagicMock

def test_full_scan_to_proposal_flow():
    """Integration test: Scanner -> Naming -> Proposal through Container."""
    scanner = container.get_scanner_service()
    naming = container.get_naming_service()
    
    with patch("os.path.exists", return_value=True), \
         patch("os.path.isdir", return_value=True), \
         patch("os.walk") as mock_walk:
        mock_walk.return_value = [
            ("D:/Media/Show/Season 1", [], ["S01E01.mp4", "S01E02.mp4"])
        ]
        
        # Mock probe service to avoid actual ffprobe calls
        with patch.object(container.get_probe_service(), "get_tracks", return_value={"audio": [], "subtitles": []}):
            results = scanner.scan("D:/Media/Show")
            assert len(results) == 2
            
            proposals = naming.build_proposals(results, Path("D:/Output"))
            
            assert len(proposals) == 2
            assert proposals[0].season == 1
            assert proposals[0].episode == 1
            assert "S01E01" in proposals[0].output_filename

def test_config_affects_naming_service():
    """Verify that changing global config updates the Naming Service behavior."""
    container.reset()
    cfg_svc = container.get_config_service()
    
    # Update config state
    config = cfg_svc.load()
    config.naming_template = "PROD_{title}"
    cfg_svc.save(config)
    
    # Reset container instances to reflect new config upon re-fetch
    container.reset()
    new_naming = container.get_naming_service()
    
    assert new_naming.template == "PROD_{title}"
