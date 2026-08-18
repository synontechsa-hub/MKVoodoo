import re
from pathlib import Path
from typing import List, Optional

from backend.models.scan import NameProposal, ScanResult

DEFAULT_TEMPLATE = "S{S:02d}E{E:02d} - {title}"


class NamingService:
    """Service for generating and reviewing output filenames."""

    def __init__(self, template: str = DEFAULT_TEMPLATE):
        self.template = template
        self._season_patterns = [
            re.compile(r"season\s*(\d+)", re.IGNORECASE),
            re.compile(r"\bS(\d+)\b", re.IGNORECASE),
            re.compile(r"\bser(?:ies)?\s*(\d+)\b", re.IGNORECASE),
            re.compile(r"(\d+)(?:st|nd|rd|th)\s*season", re.IGNORECASE),
        ]
        self._episode_patterns = [
            re.compile(r"[Ss]\d+[Ee](\d+)"),
            re.compile(r"\bEp(?:isode)?\.?\s*(\d+)\b", re.IGNORECASE),
            re.compile(r"(?:^|[\s\-_])(\d{2,3})(?:\s*[\[\(v\.]|$)"),
        ]

    def build_proposals(
        self,
        results: List[ScanResult],
        output_root: Path,
        container: str = "mkv"
    ) -> List[NameProposal]:
        """Convert scan results into named proposals."""
        proposals: List[NameProposal] = []
        taken_paths: set[Path] = set()

        for result in results:
            stem = result.source_path.stem
            season = self._infer_season(result)
            episode = self._extract_episode(stem)
            title = self._extract_title(stem) or (f"Episode {episode:02d}" if episode else stem)

            # Auto-increment episode if undetectable
            if not episode:
                season_eps = [p for p in proposals if p.season == season]
                ep_num = len(season_eps) + 1
            else:
                ep_num = episode

            filename = self.render(season, ep_num, title, container)
            base_output_path = (output_root / result.relative_path.parent / filename).resolve()

            # Collision Protection
            final_output_path = self._ensure_unique(base_output_path, taken_paths)
            taken_paths.add(final_output_path)

            final_filename = final_output_path.name

            proposals.append(NameProposal(
                scan_result=result,
                season=season,
                episode=ep_num,
                title=title,
                output_filename=final_filename,
                output_path=final_output_path
            ))

        return proposals

    def _ensure_unique(self, path: Path, taken: set[Path]) -> Path:
        """Ensure the output path doesn't collide with others in this batch."""
        if path not in taken:
            return path

        counter = 1
        while True:
            new_name = f"{path.stem}-{counter}{path.suffix}"
            new_path = path.parent / new_name
            if new_path not in taken:
                return new_path
            counter += 1

    def render(self, season: int, episode: int, title: str, container: str = "mkv") -> str:
        """Render a single filename using the current template."""
        try:
            name = self.template.format(S=season, E=episode, title=title)
        except (KeyError, ValueError):
            name = DEFAULT_TEMPLATE.format(S=season, E=episode, title=title)

        name = re.sub(r'[<>:"/\\|?*]', "_", name)
        return f"{name}.{container}"

    def _infer_season(self, result: ScanResult) -> int:
        for parent in result.source_path.parents:
            for pat in self._season_patterns:
                m = pat.search(parent.name)
                if m:
                    return int(m.group(1))
        return 1

    def _extract_episode(self, stem: str) -> int:
        for pat in self._episode_patterns:
            m = pat.search(stem)
            if m:
                return int(m.group(1))
        return 0

    def _extract_title(self, stem: str) -> Optional[str]:
        # Minimal extraction for now, can be expanded later
        text = stem
        # Remove [Tags], (Tags), etc.
        text = re.sub(r"\[.*?\]|\(.*?\)", " ", text)
        text = re.sub(r"[_\-\.]+", " ", text)
        text = re.sub(r"\s+", " ", text).strip()
        return text.title() if len(text) > 2 else None
