import 'package:flutter/material.dart';
import '../services/backend_bridge.dart';

class SettingsController extends ChangeNotifier {
  final BackendBridge _bridge;

  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _config;
  List<Map<String, dynamic>> _availableEncoders = [];

  String _selectedRes = '720p';
  String _selectedQuality = 'medium';
  String _selectedAudioBitrate = '128k';

  final TextEditingController outputDirController = TextEditingController();
  final TextEditingController namingTemplateController = TextEditingController();
  final TextEditingController maxRetriesController = TextEditingController();
  final TextEditingController parallelJobsController = TextEditingController();

  SettingsController(this._bridge) {
    loadSettings();
  }

  // Getters
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  Map<String, dynamic>? get config => _config;
  List<Map<String, dynamic>> get availableEncoders => _availableEncoders;
  String get selectedRes => _selectedRes;
  String get selectedQuality => _selectedQuality;
  String get selectedAudioBitrate => _selectedAudioBitrate;

  // Setters for dropdowns
  void setSelectedRes(String val) {
    _selectedRes = val;
    notifyListeners();
  }

  void setSelectedQuality(String val) {
    _selectedQuality = val;
    notifyListeners();
  }

  void setSelectedAudioBitrate(String val) {
    _selectedAudioBitrate = val;
    notifyListeners();
  }

  void setConfigValue(String key, dynamic value) {
    if (_config != null) {
      _config![key] = value;
      notifyListeners();
    }
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();
    try {
      final loadedConfig = await _bridge.getConfig();
      final loadedEncoders = await _bridge.getAvailableEncoders();

      _config = loadedConfig;
      _availableEncoders = loadedEncoders;

      outputDirController.text = loadedConfig['output_dir'] ?? '';
      namingTemplateController.text = loadedConfig['naming_template'] ?? '';
      maxRetriesController.text = (loadedConfig['max_retries'] ?? 1).toString();
      parallelJobsController.text = (loadedConfig['parallel_jobs'] ?? 1).toString();
      _selectedAudioBitrate = loadedConfig['default_audio_bitrate'] ?? '128k';

      final preset = loadedConfig['default_preset'] as String? ?? '720p_medium';
      final parts = preset.split('_');
      if (parts.length == 2) {
        _selectedRes = parts[0];
        final rawQuality = parts[1];
        if (rawQuality == 'mobile') {
          _selectedQuality = 'medium';
        } else if (rawQuality == 'saver') {
          _selectedQuality = 'low';
        } else if (['high', 'medium', 'low'].contains(rawQuality)) {
          _selectedQuality = rawQuality;
        } else {
          _selectedQuality = 'medium';
        }
      } else {
        _selectedRes = '720p';
        _selectedQuality = 'medium';
      }
    } catch (e) {
      _config = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveSettings() async {
    if (_config == null) return false;
    _isSaving = true;
    notifyListeners();
    try {
      final updates = {
        'output_dir': outputDirController.text,
        'naming_template': namingTemplateController.text,
        'max_retries': int.tryParse(maxRetriesController.text) ?? 1,
        'parallel_jobs': int.tryParse(parallelJobsController.text) ?? 1,
        'show_notifications': _config!['show_notifications'] ?? true,
        'default_preset': '${_selectedRes}_$_selectedQuality',
        'default_audio_bitrate': _selectedAudioBitrate,
        'review_before_convert': _config!['review_before_convert'],
        'skip_existing': _config!['skip_existing'],
        'force_encoder': _config!['force_encoder'],
      };
      await _bridge.setConfig(updates);
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    outputDirController.dispose();
    namingTemplateController.dispose();
    maxRetriesController.dispose();
    parallelJobsController.dispose();
    super.dispose();
  }
}
