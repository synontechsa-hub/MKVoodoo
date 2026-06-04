"""Custom exceptions for MKVoodoo."""

class MKVoodooError(Exception):
    """Base class for all MKVoodoo exceptions."""
    pass

class ConfigError(MKVoodooError):
    """Raised when configuration is missing or malformed."""
    pass

class HardwareError(MKVoodooError):
    """Raised when hardware detection or initialization fails."""
    pass

class GPUInitError(HardwareError):
    """Specific error when a GPU backend exists but fails to start."""
    pass

class ScannerError(MKVoodooError):
    """Raised during directory scanning or file identification."""
    pass

class NamingError(MKVoodooError):
    """Raised during template parsing or filename generation."""
    pass

class ConversionError(MKVoodooError):
    """Base class for conversion failures."""
    pass

class FFmpegError(ConversionError):
    """Raised when FFmpeg returns a non-zero exit code or crashes."""
    pass

class DiskFullError(ConversionError):
    """Raised when the output drive has insufficient space."""
    pass

class PresetError(MKVoodooError):
    """Raised when a requested preset is missing or invalid."""
    pass
