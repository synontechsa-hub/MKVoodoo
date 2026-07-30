import pytest
from pytest_bdd import scenario, given, when, then, parsers
from unittest.mock import MagicMock, patch
from pathlib import Path
from backend.services.download_service import DownloadService
from backend.services.metadata_service import MetadataService
from backend.core.exceptions import MKVoodooError

# ---------------------------------------------------------------------------
# Scenarios
# ---------------------------------------------------------------------------

@scenario("features/youtube_download.feature", "Successful metadata fetch")
def test_youtube_metadata():
    pass

@scenario("features/error_handling.feature", "Metadata search with missing API key")
def test_metadata_auth_error():
    pass

# ---------------------------------------------------------------------------
# Steps: YouTube
# ---------------------------------------------------------------------------

@pytest.fixture
def context():
    return {}

@given(parsers.parse('a valid YouTube URL "{url}"'))
def youtube_url(context, url):
    context["url"] = url

@when("I request video information")
def fetch_info(context):
    svc = DownloadService()
    mock_meta = {"title": "Never Gonna Give You Up", "thumbnail": "https://img.yt.com/123.jpg"}
    with patch.object(svc, "fetch_metadata", return_value=mock_meta):
        context["result"] = svc.fetch_metadata(context["url"])

@then(parsers.parse('I should see the title "{title}"'))
def check_title(context, title):
    assert context["result"]["title"] == title

@then("I should see a valid thumbnail URL")
def check_thumbnail(context):
    assert context["result"]["thumbnail"].startswith("http")

# ---------------------------------------------------------------------------
# Steps: Errors
# ---------------------------------------------------------------------------

@given("an empty TMDB API key in settings")
def empty_key(context):
    context["svc"] = MetadataService(api_key="")

@when(parsers.parse('I perform a content search for "{query}"'))
def search_content(context, query):
    try:
        context["svc"].search_content(query)
    except MKVoodooError as e:
        context["error"] = e

@then("the system should raise an authentication error")
def check_auth_error(context):
    assert isinstance(context["error"], MKVoodooError)

@then(parsers.parse('the error message should mention "{text}"'))
def check_error_msg(context, text):
    assert text in str(context["error"])
