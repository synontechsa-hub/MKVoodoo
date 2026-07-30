from __future__ import annotations
from typing import Dict, Any

class ServiceContainer:
    """Registry for backend services to ensure singletons and clean ownership."""

    def __init__(self):
        self._instances: Dict[str, Any] = {}

    def get_config_service(self):
        from backend.services.config_service import ConfigService
        if "config" not in self._instances:
            self._instances["config"] = ConfigService()
        return self._instances["config"]

    def get_hardware_service(self):
        from backend.services.hardware_service import HardwareService
        if "hardware" not in self._instances:
            self._instances["hardware"] = HardwareService()
        return self._instances["hardware"]

    def get_probe_service(self):
        from backend.services.probe_service import ProbeService
        if "probe" not in self._instances:
            self._instances["probe"] = ProbeService()
        return self._instances["probe"]

    def get_scanner_service(self):
        from backend.services.scanner_service import ScannerService
        if "scanner" not in self._instances:
            self._instances["scanner"] = ScannerService(probe_service=self.get_probe_service())
        return self._instances["scanner"]

    def get_naming_service(self):
        from backend.services.naming_service import NamingService
        if "naming" not in self._instances:
            cfg = self.get_config_service().load()
            self._instances["naming"] = NamingService(template=cfg.naming_template)
        return self._instances["naming"]

    def get_metadata_service(self):
        from backend.services.metadata_service import MetadataService
        if "metadata" not in self._instances:
            cfg = self.get_config_service().load()
            self._instances["metadata"] = MetadataService(api_key=cfg.tmdb_api_key)
        return self._instances["metadata"]

    def get_download_service(self):
        from backend.services.download_service import DownloadService
        if "download" not in self._instances:
            self._instances["download"] = DownloadService()
        return self._instances["download"]

    def get_queue_service(self):
        from backend.services.queue_service import QueueService
        if "queue" not in self._instances:
            cfg = self.get_config_service().load()
            self._instances["queue"] = QueueService(cfg.queue_file)
        return self._instances["queue"]

    def get_logger(self):
        from backend.utils.logger import SynLogger
        if "logger" not in self._instances:
            cfg = self.get_config_service().load()
            self._instances["logger"] = SynLogger(cfg.log_dir)
        return self._instances["logger"]

    def get_converter_service(self):
        from backend.services.converter_service import ConverterService
        from backend.core.engine import FFmpegEngine
        if "converter" not in self._instances:
            hw = self.get_hardware_service()
            engine = FFmpegEngine(hw._ffmpeg)
            self._instances["converter"] = ConverterService(engine, self.get_logger())
        return self._instances["converter"]
        
    def get_update_service(self):
        from backend.services.update_service import UpdateService
        if "update" not in self._instances:
            self._instances["update"] = UpdateService()
        return self._instances["update"]

# Global singleton instance
container = ServiceContainer()
