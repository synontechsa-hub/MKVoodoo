import pytest
from backend.core.container import container
from backend.models.scan import ScanResult
from pathlib import Path
from unittest.mock import patch, MagicMock

def test_full_scan_to_proposal_flow():
    """Integration test: Scanner -> Naming -> Proposal through Container."""
    scanner = container.get_scanner_service()
    naming = container.get_naming_service()
    
    # Mock filesystem discovery
    mock_files = [
        Path("D:/Media/Show/Season 1/S01E01.mp4"),
        Path("D:/Media/Show/Season 1/S01E02.mp4")
    ]
    
    with patch("os.walk") as mock_walk:
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
    cfg_svc = container.get_config_service()
    naming_svc = container.get_naming_service()
    
    # Initial state
    config = cfg_svc.load()
    config.naming_template = "PROD_{title}"
    cfg_svc.save(config)
    
    # Note: Because naming_service is a singleton in our container, 
    # we need to verify if it reflects the config change or if it needs a re-init.
    # In v1.0.3 container.py, naming is instantiated with cfg.naming_template.
    
    # Let's check the container logic
    new_naming = container.get_naming_service()
    # If the container just returns the old instance, the template might be stale.
    # A professional container might have a 'reset' or be truly dynamic.
    
    # For now, we verify the initial load logic
    assert new_naming.template == "PROD_{title}"
