from __future__ import annotations
import pytest
from pathlib import Path
from backend.services.naming_service import NamingService
from backend.models.scan import ScanResult

@pytest.fixture
def naming_service():
    return NamingService()

# ---------------------------------------------------------------------------
# Season extraction
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("folder,expected", [
    ("Season 1",       1),
    ("Season 2",       2),
    ("Season 01",      1),
    ("S2",             2),
    ("S03",            3),
    ("series 4",       4),
    ("2nd Season",     2),
    ("3rd Season",     3),
])
def test_infer_season(naming_service, folder: str, expected: int) -> None:
    # Build a mock scan result where folder is a parent
    mock_path = Path(f"D:/Media/{folder}/Episode 01.mkv")
    result = ScanResult(source_path=mock_path, relative_path=Path(folder) / "Episode 01.mkv")
    assert naming_service._infer_season(result) == expected


# ---------------------------------------------------------------------------
# Episode extraction
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("stem,expected", [
    ("[SubGroup] Show Name - S01E05 [1080p]",                5),
    ("Show.S02E12.HDTV",                                    12),
    ("[SubGroup] Anime Show - 07 [720p][HEVC]",              7),
    ("Anime Show Episode 03",                                3),
    ("Show Ep.11 BluRay",                                   11),
    ("ShowName_05",                                          5),
    ("[Group] Long Show - 101 [720p]",                     101),
])
def test_extract_episode(naming_service, stem: str, expected: int) -> None:
    assert naming_service._extract_episode(stem) == expected


# ---------------------------------------------------------------------------
# Filename rendering
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("season,episode,title,expected", [
    (1,  3,  "The Dark",   "S01E03 - The Dark.mkv"),
    (2, 12,  "Last Stand", "S02E12 - Last Stand.mkv"),
])
def test_render(naming_service, season: int, episode: int, title: str, expected: str) -> None:
    assert naming_service.render(season, episode, title) == expected


def test_collision_protection(naming_service):
    # Test that build_proposals generates unique paths for identical smart names in SAME folder
    results = [
        ScanResult(source_path=Path("A/Show.S01E01.mkv"), relative_path=Path("Show.S01E01.mkv")),
        ScanResult(source_path=Path("B/Show.S01E01.mkv"), relative_path=Path("Show.S01E01.mkv")),
    ]
    # If both files have the same title "ep1", they might collide
    # In naming_service, title defaults to stem if undetectable
    
    proposals = naming_service.build_proposals(results, Path("D:/Output"))
    
    assert len(proposals) == 2
    assert proposals[0].output_filename != proposals[1].output_filename
    assert "-1.mkv" in proposals[1].output_filename
