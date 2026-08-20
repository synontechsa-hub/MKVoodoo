import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mkvoodoo_ui/services/backend_bridge.dart';

class YoutubeController extends ChangeNotifier {
  final BackendBridge _bridge;
  StreamSubscription<String>? _downloadSubscription;

  String _url = '';
  Map<String, dynamic>? _metadata;
  bool _isLoading = false;
  bool _isDownloading = false;
  bool _audioOnly = false;
  String _selectedFormat = 'mp3';
  String _selectedVideoQuality = '1080';
  double _downloadProgress = 0.0;
  String? _errorMessage;
  final List<String> _logs = [];

  YoutubeController(this._bridge);

  // Getters
  String get url => _url;
  Map<String, dynamic>? get metadata => _metadata;
  bool get isLoading => _isLoading;
  bool get isDownloading => _isDownloading;
  bool get audioOnly => _audioOnly;
  String get selectedFormat => _selectedFormat;
  String get selectedVideoQuality => _selectedVideoQuality;
  double get downloadProgress => _downloadProgress;
  String? get errorMessage => _errorMessage;
  List<String> get logs => _logs;

  void setUrl(String value) {
    _url = value;
    _metadata = null;
    _errorMessage = null;
    notifyListeners();
  }

  void setAudioOnly(bool value) {
    _audioOnly = value;
    notifyListeners();
  }

  void setSelectedFormat(String value) {
    _selectedFormat = value;
    notifyListeners();
  }

  void setSelectedVideoQuality(String value) {
    _selectedVideoQuality = value;
    notifyListeners();
  }

  Future<void> fetchMetadata() async {
    if (_url.isEmpty) return;
    _isLoading = true;
    _errorMessage = null;
    _metadata = null;
    notifyListeners();

    try {
      _metadata = await _bridge.getYoutubeInfo(_url);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> startDownload({
    void Function(String path)? onVideoDownloaded,
  }) async {
    if (_metadata == null) return;
    _isDownloading = true;
    _downloadProgress = 0.0;
    _logs.clear();
    _logs.add('🚀 Starting download for: ${_metadata!['title']}');
    notifyListeners();

    try {
      _downloadSubscription = _bridge
          .downloadYoutube(
            _url,
            audioOnly: _audioOnly,
            format: _selectedFormat,
            videoQuality: _selectedVideoQuality,
          )
          .listen(
            (line) {
              final trimmed = line.trim();
              if (trimmed.isEmpty) return;
              _logs.add(trimmed);

              if (trimmed.contains('⏱ Progress:')) {
                final pctMatch = RegExp(
                  r'Progress: ([\d\.]+)%',
                ).firstMatch(trimmed);
                if (pctMatch != null) {
                  _downloadProgress =
                      double.tryParse(pctMatch.group(1)!) ?? 0.0;
                }
              }

              if (trimmed.contains('✓ Downloaded to:')) {
                final path = trimmed.split('Downloaded to:')[1].trim();
                if (_audioOnly) {
                  _logs.add('✅ Audio extraction complete!');
                } else {
                  _logs.add(
                    '✅ Download complete! Opening in Precision Clipper...',
                  );
                  onVideoDownloaded?.call(path);
                }
              }
              notifyListeners();
            },
            onDone: () {
              _isDownloading = false;
              notifyListeners();
            },
            onError: (e) {
              _errorMessage = e.toString();
              _isDownloading = false;
              notifyListeners();
            },
          );
    } catch (e) {
      _errorMessage = e.toString();
      _isDownloading = false;
      notifyListeners();
    }
  }

  void cancelDownload() {
    _downloadSubscription?.cancel();
    _bridge.cancelOperation('youtube_download');
    _isDownloading = false;
    _logs.add('🛑 Download cancelled by user.');
    notifyListeners();
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
  }
}
