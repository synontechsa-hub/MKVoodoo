import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
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

  Future<void> startDownload(BuildContext context) async {
    if (_metadata == null) return;
    _isDownloading = true;
    _downloadProgress = 0.0;
    _logs.clear();
    _logs.add('🚀 Starting download for: ${_metadata!['title']}');
    notifyListeners();

    try {
      _downloadSubscription = _bridge
          .downloadYoutube(_url, audioOnly: _audioOnly, format: _selectedFormat)
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
                    '✅ Download complete! Adding to conversion workflow...',
                  );
                  _addToConversionQueue(path);
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

  Future<void> _addToConversionQueue(String path) async {
    try {
      final config = await _bridge.getConfig();
      final globalOutput = config['output_dir'] as String?;

      if (globalOutput == null || globalOutput.isEmpty) {
        _logs.add(
          '❌ Cannot add to queue: Output directory not set in Settings.',
        );
        notifyListeners();
        return;
      }

      final outPath = _buildOutputPath(path, globalOutput);

      // When adding a downloaded file, we set delete_source_after_done = true
      final jobs = [
        {
          'source': path,
          'output': outPath,
          'delete_source_after_done': true,
          'keep_all_audio': true,
          'keep_all_subtitles': true,
        },
      ];

      await _bridge.addJobs(jobs);
      _logs.add('📂 File added to Conversion Queue with Auto-Cleanup enabled.');
      notifyListeners();
    } catch (e) {
      _logs.add('❌ Failed to add to queue: $e');
      notifyListeners();
    }
  }

  String _buildOutputPath(String sourcePath, String outputDir) {
    final fileName = p.basename(sourcePath);
    // Replace .mp4, .webm, .mkv extensions from source with .mkv
    final outName = fileName.replaceAll(
      RegExp(r'\.(mp4|webm|mkv)$', caseSensitive: false),
      '.mkv',
    );

    // Ensure we don't just return the filename if it didn't have an extension
    final finalName = outName.endsWith('.mkv') ? outName : '$outName.mkv';

    return p.join(outputDir, 'YouTube Downloads', finalName);
  }

  void cancelDownload() {
    _downloadSubscription?.cancel();
    _bridge.stopActiveProcess();
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
