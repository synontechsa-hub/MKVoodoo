import urllib.request
import urllib.parse
import json
from typing import Dict, Any, List, Optional
from backend.core.exceptions import MKVoodooError

TMDB_API_BASE = "https://api.themoviedb.org/3"

class MetadataService:
    """Service for fetching movie and TV show metadata from TMDB."""

    def __init__(self, api_key: str = ""):
        self.api_key = api_key

    @property
    def is_authenticated(self) -> bool:
        """Check if a valid-looking API key is present."""
        return bool(self.api_key and len(self.api_key) > 10)

    def search_content(self, query: str, is_tv: bool = False) -> List[Dict[str, Any]]:
        """Search for a movie or TV show."""
        if not self.is_authenticated:
            raise MKVoodooError("TMDB API Key is missing or invalid. Please check Settings.")

        search_type = "tv" if is_tv else "movie"
        encoded_query = urllib.parse.quote(query)
        url = f"{TMDB_API_BASE}/search/{search_type}?api_key={self.api_key}&query={encoded_query}"
        
        try:
            with urllib.request.urlopen(url, timeout=10) as response:
                data = json.loads(response.read().decode("utf-8"))
                return data.get("results", [])
        except Exception as e:
            raise MKVoodooError(f"TMDB Search failed: {e}")

    def get_details(self, content_id: int, is_tv: bool = False) -> Dict[str, Any]:
        """Get detailed info including poster path."""
        if not self.is_authenticated:
            raise MKVoodooError("TMDB API Key is missing or invalid.")

        search_type = "tv" if is_tv else "movie"
        url = f"{TMDB_API_BASE}/{search_type}/{content_id}?api_key={self.api_key}"
        
        try:
            with urllib.request.urlopen(url, timeout=10) as response:
                return json.loads(response.read().decode("utf-8"))
        except Exception as e:
            raise MKVoodooError(f"TMDB Details fetch failed: {e}")

    def get_poster_url(self, poster_path: str, size: str = "w500") -> str:
        """Construct a full URL for a TMDB poster."""
        if not poster_path:
            return ""
        return f"https://image.tmdb.org/t/p/{size}{poster_path}"
