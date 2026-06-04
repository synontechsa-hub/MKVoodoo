import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../services/backend_bridge.dart';
import '../models/scan_proposal.dart';

class WizardController extends ChangeNotifier {
  final BackendBridge _bridge;
  StreamSubscription<String>? _conversionSubscription;

  List<String> _inputPaths = [];
  String? _outputPath;
  String? _defaultAudioBitrate;
  List<ScanProposal>? _proposals;
  bool _isScanning = false;
  bool _isConverting = false;
  bool _isAborting = false;
  bool _useSmartNaming = true;

  final List<String> _conversionLog = [];
  final Map<String, int> _jobTimerLineIndex = {};

  WizardController(this._bridge) {
    _loadDefaultSettings();
  }

  // Getters
  List<String> get inputPaths => _inputPaths;
  String? get outputPath => _outputPath;
  String? get defaultAudioBitrate => _defaultAudioBitrate;
  List<ScanProposal>? get proposals => _proposals;
  bool get isScanning => _isScanning;
  bool get isConverting => _isConverting;
  bool get isAborting => _isAborting;
  bool get useSmartNaming => _useSmartNaming;
  List<String> get conversionLog => _conversionLog;

  // Setters
  set useSmartNaming(bool val) {
    _useSmartNaming = val;
    notifyListeners();
  }

  set outputPath(String? val) {
    _outputPath = val;
    notifyListeners();
  }

  Future<void> _loadDefaultSettings() async {
    try {
      final config = await _bridge.getConfig();
      _outputPath = config['output_dir'] as String?;
      _defaultAudioBitrate = config['default_audio_bitrate'] as String?;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> pickInputFolder() async {
    final folder = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Input Folder',
    );
    if (folder != null) {
      _inputPaths = [folder];
      _proposals = null;
      _conversionLog.clear();
      notifyListeners();
      await runScan();
    }
  }

  Future<void> pickInputFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      dialogTitle: 'Select Input Files',
    );
    if (result != null && result.paths.isNotEmpty) {
      _inputPaths = result.paths.whereType<String>().toList();
      _proposals = null;
      _conversionLog.clear();
      notifyListeners();
      await runScan();
    }
  }

  void handleDroppedFiles(List<String> paths) {
    if (paths.isNotEmpty) {
      _inputPaths = paths;
      _proposals = null;
      _conversionLog.clear();
      notifyListeners();
      runScan();
    }
  }

  Future<void> pickOutputFolder() async {
    final folder = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Output Folder',
    );
    if (folder != null) {
      _outputPath = folder;
      notifyListeners();
    }
  }

  void updateProposalTracks(ScanProposal proposal, List<int>? audio, List<int>? subs, String? bitrate) {
    proposal.selectedAudioTracks = audio;
    proposal.selectedSubtitleTracks = subs;
    proposal.audioBitrate = bitrate;
    notifyListeners();
  }

  Future<void> runScan() async {
    if (_inputPaths.isEmpty) return;
    _isScanning = true;
    notifyListeners();
    try {
      final result = await _bridge.scanInputs(_inputPaths);
      _proposals = result;
    } catch (_) {
      _proposals = [];
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  void applyBulkSettings(Map<String, dynamic> settings) {
    if (_proposals == null) return;
    for (var p in _proposals!) {
      if (settings['bitrate'] != null) {
        p.audioBitrate = settings['bitrate'];
      }
      if (settings['audio_strategy'] == 'all') {
        p.selectedAudioTracks = null;
      } else if (settings['audio_strategy'] == 'first') {
        p.selectedAudioTracks = [1];
      }
      if (settings['sub_strategy'] == 'all') {
        p.selectedSubtitleTracks = null;
      } else if (settings['sub_strategy'] == 'none') {
        p.selectedSubtitleTracks = [];
      }
    }
    notifyListeners();
  }

  void reset() {
    _conversionSubscription?.cancel();
    _conversionSubscription = null;
    _inputPaths = [];
    _proposals = null;
    _conversionLog.clear();
    _isConverting = false;
    _isAborting = false;
    _jobTimerLineIndex.clear();
    notifyListeners();
  }

  Future<void> abortConversion() async {
    _isAborting = true;
    notifyListeners();
    try {
      await _bridge.stopActiveProcess();
      _conversionLog.add('❌ Conversion aborted by user.');
    } catch (e) {
      _conversionLog.add('Error aborting: $e');
    } finally {
      _isConverting = false;
      _isAborting = false;
      notifyListeners();
    }
  }

  Future<void> startConversion() async {
    if (_proposals == null || _proposals!.isEmpty || _outputPath == null) return;
    
    _isConverting = true;
    _conversionLog.clear();
    _jobTimerLineIndex.clear();
    _conversionLog.add('🚀 Starting conversion batch...');
    notifyListeners();

    try {
      final jobs = _proposals!.map((p_scan) {
        final outName = _useSmartNaming ? p_scan.outputFilename : p_scan.originalFilename;
        return {
          'source': p_scan.source,
          'output': p.join(_outputPath!, outName),
          'smart_name': _useSmartNaming,
          'output_filename': outName,
          'audio_tracks': p_scan.selectedAudioTracks,
          'subtitle_tracks': p_scan.selectedSubtitleTracks,
          'audio_bitrate': p_scan.audioBitrate,
          'keep_all_audio': p_scan.selectedAudioTracks == null,
          'keep_all_subtitles': p_scan.selectedSubtitleTracks == null,
        };
      }).toList();

      await _bridge.addJobs(jobs);
      
      _conversionSubscription = _bridge.resumeQueue().listen(
        (line) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) return;

          if (trimmed.contains('⏱')) {
            final jobIdMatch = RegExp(r'\[(.*?)\]').firstMatch(trimmed);
            final jobId = jobIdMatch?.group(1);
            if (jobId != null) {
              if (_jobTimerLineIndex.containsKey(jobId)) {
                final idx = _jobTimerLineIndex[jobId]!;
                if (idx < _conversionLog.length && _conversionLog[idx].contains('[$jobId]')) {
                  _conversionLog[idx] = trimmed;
                } else {
                  _jobTimerLineIndex[jobId] = _conversionLog.length;
                  _conversionLog.add(trimmed);
                }
              } else {
                _jobTimerLineIndex[jobId] = _conversionLog.length;
                _conversionLog.add(trimmed);
              }
            } else {
              _conversionLog.add(trimmed);
            }
          } else {
            _conversionLog.add(trimmed);
          }
          notifyListeners();
        },
        onDone: () {
          _isConverting = false;
          notifyListeners();
        },
        onError: (e) {
          _conversionLog.add('Error during conversion: $e');
          _isConverting = false;
          notifyListeners();
        }
      );
    } catch (e) {
      _conversionLog.add('Error: $e');
      _isConverting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _conversionSubscription?.cancel();
    super.dispose();
  }
}
