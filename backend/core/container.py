from __future__ import annotations

from typing import TYPE_CHECKING, Any, Dict, cast

if TYPE_CHECKING:
    from backend.services.clip_service import ClipService
    from backend.services.config_service import ConfigService
    from backend.services.converter_service import ConverterService
    from backend.services.download_service import DownloadService
    from backend.services.hardware_service import HardwareService
    from backend.services.metadata_service import MetadataService
    from backend.services.naming_service import NamingService
    from backend.services.probe_service import ProbeService
    from backend.services.queue_service import QueueService
    from backend.services.scanner_service import ScannerService
    from backend.services.thumbnail_service import ThumbnailService
    from backend.services.update_service import UpdateService
    from backend.utils.logger import SynLogger


class ServiceContainer:
    """Registry for backend services to ensure singletons and clean ownership."""

    def __init__(self) -> None:
        self._instances: Dict[str, Any] = {}

    def reset(self) -> None:
        """Clear cached service singletons."""
        self._instances.clear()

    def get_config_service(self) -> ConfigService:
        from backend.services.config_service import ConfigService
        if "config" not in self._instances:
            self._instances["config"] = ConfigService()
        return cast("ConfigService", self._instances["config"])

    def get_hardware_service(self) -> HardwareService:
        from backend.services.hardware_service import HardwareService
        if "hardware" not in self._instances:
            self._instances["hardware"] = HardwareService()
        return cast("HardwareService", self._instances["hardware"])

    def get_probe_service(self) -> ProbeService:
        from backend.services.probe_service import ProbeService
        if "probe" not in self._instances:
            self._instances["probe"] = ProbeService()
        return cast("ProbeService", self._instances["probe"])

    def get_scanner_service(self) -> ScannerService:
        from backend.services.scanner_service import ScannerService
        if "scanner" not in self._instances:
            self._instances["scanner"] = ScannerService(probe_service=self.get_probe_service())
        return cast("ScannerService", self._instances["scanner"])

    def get_naming_service(self) -> NamingService:
        from backend.services.naming_service import NamingService
        if "naming" not in self._instances:
            cfg = self.get_config_service().load()
            self._instances["naming"] = NamingService(template=cfg.naming_template)
        return cast("NamingService", self._instances["naming"])

    def get_metadata_service(self) -> MetadataService:
        from backend.services.metadata_service import MetadataService
        if "metadata" not in self._instances:
            cfg = self.get_config_service().load()
            self._instances["metadata"] = MetadataService(api_key=cfg.tmdb_api_key)
        return cast("MetadataService", self._instances["metadata"])

    def get_download_service(self) -> DownloadService:
        from backend.services.download_service import DownloadService
        if "download" not in self._instances:
            self._instances["download"] = DownloadService()
        return cast("DownloadService", self._instances["download"])

    def get_queue_service(self) -> QueueService:
        from backend.services.queue_service import QueueService
        if "queue" not in self._instances:
            cfg = self.get_config_service().load()
            self._instances["queue"] = QueueService(cfg.queue_file)
        return cast("QueueService", self._instances["queue"])

    def get_logger(self) -> SynLogger:
        from backend.utils.logger import SynLogger
        if "logger" not in self._instances:
            cfg = self.get_config_service().load()
            self._instances["logger"] = SynLogger(cfg.log_dir)
        return cast("SynLogger", self._instances["logger"])

    def get_converter_service(self) -> ConverterService:
        from backend.core.engine import FFmpegEngine
        from backend.services.converter_service import ConverterService
        if "converter" not in self._instances:
            hw = self.get_hardware_service()
            engine = FFmpegEngine(hw._ffmpeg)
            self._instances["converter"] = ConverterService(engine, self.get_logger())
        return cast("ConverterService", self._instances["converter"])

    def get_clip_service(self) -> "ClipService":
        from backend.core.engine import FFmpegEngine
        from backend.services.clip_service import ClipService
        if "clip" not in self._instances:
            hardware = self.get_hardware_service()
            self._instances["clip"] = ClipService(FFmpegEngine(hardware._ffmpeg), self.get_probe_service())
        return cast("ClipService", self._instances["clip"])

    def get_thumbnail_service(self) -> "ThumbnailService":
        from backend.services.thumbnail_service import ThumbnailService
        if "thumbnail" not in self._instances:
            self._instances["thumbnail"] = ThumbnailService()
        return cast("ThumbnailService", self._instances["thumbnail"])

    def get_update_service(self) -> UpdateService:
        from backend.services.update_service import UpdateService
        if "update" not in self._instances:
            self._instances["update"] = UpdateService()
        return cast("UpdateService", self._instances["update"])


# Global singleton instance
container = ServiceContainer()
