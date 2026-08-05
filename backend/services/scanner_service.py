import os
from pathlib import Path
from typing import List, Optional, Any
from backend.models.scan import ScanResult
from backend.core.exceptions import ScannerError
from backend.services.probe_service import ProbeService

SUPPORTED_EXTENSIONS = frozenset({".mkv", ".mp4", ".webm"})

class ScannerService:
    """Service for discovering video files in the filesystem."""

    def __init__(self, probe_service: Optional[ProbeService] = None):
        self.probe_service = probe_service

    def scan(self, root: str | Path, output_dir: Optional[str | Path] = None) -> List[ScanResult]:
        """Recursively scan root for supported video files."""
        root_path = Path(root).resolve()
        
        if root_path.is_file():
            if root_path.suffix.lower() in SUPPORTED_EXTENSIONS:
                return [self._build_result(root_path, Path(root_path.name))]
            return []

        self._validate(root_path, output_dir)

        results: List[ScanResult] = []
        try:
            for dirpath, _dirnames, filenames in os.walk(root_path):
                for filename in filenames:
                    ext = Path(filename).suffix.lower()
                    if ext in SUPPORTED_EXTENSIONS:
                        abs_path = Path(dirpath) / filename
                        rel_path = abs_path.relative_to(root_path)
                        results.append(self._build_result(abs_path, rel_path))
        except Exception as exc:
            raise ScannerError(f"Directory scan failed: {exc}")

        results.sort(key=lambda r: str(r.relative_path))
        return results

    def _build_result(self, abs_path: Path, rel_path: Path) -> ScanResult:
        tracks: dict[str, list[dict[str, Any]]] = {"audio": [], "subtitles": []}
        if self.probe_service:
            try:
                tracks = self.probe_service.get_tracks(abs_path)
            except Exception:
                pass # Silently fail probing during scan
        return ScanResult(source_path=abs_path, relative_path=rel_path, tracks=tracks)

    def scan_multiple(self, roots: List[str | Path], output_dir: Optional[str | Path] = None) -> List[ScanResult]:
        """Scan multiple roots and merge results."""
        all_results: List[ScanResult] = []
        for r in roots:
            all_results.extend(self.scan(r, output_dir=output_dir))

        # Unique by absolute path
        seen = set()
        unique: List[ScanResult] = []
        for res in all_results:
            abs_p = str(res.source_path.resolve())
            if abs_p not in seen:
                seen.add(abs_p)
                unique.append(res)

        unique.sort(key=lambda item: str(item.relative_path))
        return unique

    def _validate(self, root: Path, output_dir: Optional[str | Path]) -> None:
        """Validate input/output directory constraints."""
        if not root.exists():
            raise FileNotFoundError(f"Input directory does not exist: {root}")
        if not root.is_dir():
            raise NotADirectoryError(f"Input path is not a directory: {root}")
            
        if output_dir is not None:
            output_resolved = Path(output_dir).resolve()
            if root == output_resolved:
                raise ValueError("Input and output directories must not be the same path.")
            
            try:
                output_resolved.relative_to(root)
                raise ValueError("Output directory must not be inside the input directory.")
            except ValueError as exc:
                if "must not be inside" in str(exc):
                    raise
                # Related to paths being unrelated — this is good.
                pass
