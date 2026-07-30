import pytest
from backend.core.container import ServiceContainer
from backend.services.config_service import ConfigService
from backend.services.hardware_service import HardwareService

def test_container_singleton_behavior():
    container = ServiceContainer()
    
    # Get services twice
    cfg1 = container.get_config_service()
    cfg2 = container.get_config_service()
    
    hw1 = container.get_hardware_service()
    hw2 = container.get_hardware_service()
    
    # Assert they are the same instances
    assert cfg1 is cfg2
    assert hw1 is hw2
    assert isinstance(cfg1, ConfigService)
    assert isinstance(hw1, HardwareService)

def test_container_lazy_loading():
    container = ServiceContainer()
    assert "_instances" in container.__dict__
    assert "config" not in container._instances
    
    # Load one
    container.get_config_service()
    assert "config" in container._instances
    assert "hardware" not in container._instances

def test_metadata_service_gets_config_key():
    container = ServiceContainer()
    cfg = container.get_config_service()
    
    # Set a test key
    mock_key = "test-key-from-config-service"
    config_obj = cfg.load()
    config_obj.tmdb_api_key = mock_key
    cfg.save(config_obj)
    
    # Get metadata service
    meta = container.get_metadata_service()
    assert meta.api_key == mock_key
