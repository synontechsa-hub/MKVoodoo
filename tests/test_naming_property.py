import pytest
from hypothesis import given, strategies as st
from backend.services.naming_service import NamingService

@pytest.fixture
def naming_service():
    return NamingService()

@given(st.text())
def test_extract_episode_never_crashes(naming_service, stem):
    """Naming service should handle ANY string without throwing exceptions."""
    try:
        res = naming_service._extract_episode(stem)
        assert isinstance(res, int)
    except Exception as e:
        pytest.fail(f"Extract episode crashed with input {stem!r}: {e}")

@given(st.text())
def test_extract_title_never_crashes(naming_service, stem):
    """Naming service title extraction should be stable for any input."""
    res = naming_service._extract_title(stem)
    assert res is None or isinstance(res, str)

@given(st.integers(min_value=0, max_value=999), 
       st.integers(min_value=0, max_value=999), 
       st.text(min_size=1))
def test_render_deterministic(naming_service, season, episode, title):
    """Rendering should always produce a valid-looking MKV filename."""
    filename = naming_service.render(season, episode, title)
    assert filename.endswith(".mkv")
    assert f"S{season:02d}" in filename or str(season) in filename
    # Illegal characters should be removed
    for char in '<>:"/\\|?*':
        assert char not in filename
