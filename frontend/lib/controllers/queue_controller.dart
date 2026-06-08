import 'dart:async';
import 'package:flutter/material.dart';
import '../services/backend_bridge.dart';
import '../models/job.dart';

class QueueController extends ChangeNotifier {
  final BackendBridge _bridge;
  StreamSubscription<String>? _queueSubscription;

  List<Job>? _jobs;
  bool _isLoading = true;
  bool _isProcessing = false;
  final List<String> _consoleLogs = [];
  final Set<String> _selectedIds = {};
  final Map<String, double> _jobProgress = {};
  final Map<String, int> _jobTimerLineIndex = {};

  QueueController(this._bridge) {
    refreshQueue();
  }

  // Getters
  List<Job>? get jobs => _jobs;
  bool get isLoading => _isLoading;
  bool get isProcessing => _isProcessing;
  List<String> get consoleLogs => _consoleLogs;
  Set<String> get selectedIds => _selectedIds;
  Map<String, double> get jobProgress => _jobProgress;

  // Selected selection utilities
  bool isSelected(String id) => _selectedIds.contains(id);
  
  void toggleSelect(String id, bool selected) {
    if (selected) {
      _selectedIds.add(id);
    } else {
      _selectedIds.remove(id);
    }
    notifyListeners();
  }

  void toggleSelectAll(bool selectAll) {
    if (selectAll && _jobs != null) {
      _selectedIds.addAll(_jobs!.map((j) => j.id));
    } else {
      _selectedIds.clear();
    }
    notifyListeners();
  }

  void clearConsole() {
    _consoleLogs.clear();
    notifyListeners();
  }

  Future<void> refreshQueue() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _bridge.getQueueStatus();
      final List? rawJobs = data['jobs'] as List?;
      if (rawJobs != null) {
        _jobs = rawJobs.map((j) => Job.fromJson(j as Map<String, dynamic>)).toList();
      } else {
        _jobs = [];
      }
    } catch (e) {
      _jobs = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addToQueue(List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await _bridge.addToQueue(paths);
      await refreshQueue();
    } catch (_) {
      rethrow;
    }
  }

  Future<void> clearCompleted() async {
    try {
      await _bridge.clearCompletedJobs();
      await refreshQueue();
    } catch (_) {
      rethrow;
    }
  }

  Future<void> resetFailed() async {
    try {
      await _bridge.resetFailedJobs();
      await refreshQueue();
    } catch (_) {
      rethrow;
    }
  }

  Future<void> removeSelected() async {
    if (_selectedIds.isEmpty) return;
    try {
      await _bridge.removeJobs(_selectedIds.toList());
      _selectedIds.clear();
      await refreshQueue();
    } catch (_) {
      rethrow;
    }
  }

  Future<void> clearAllHistory() async {
    try {
      await _bridge.clearAllHistory();
      await refreshQueue();
    } catch (_) {
      rethrow;
    }
  }

  Future<void> stopProcessing() async {
    _queueSubscription?.cancel();
    _queueSubscription = null;
    await _bridge.stopActiveProcess();
    _isProcessing = false;
    _consoleLogs.add("🛑 Processing stopped by user.");
    await refreshQueue();
  }

  void resumeQueue() {
    _isProcessing = true;
    _consoleLogs.clear();
    _jobProgress.clear();
    _jobTimerLineIndex.clear();
    _consoleLogs.add("🚀 Resuming conversion queue...");
    notifyListeners();

    _queueSubscription = _bridge.resumeQueue().listen(
      (line) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) return;

        if (trimmed.contains('⏱')) {
          final jobIdMatch = RegExp(r'\[(.*?)\]').firstMatch(trimmed);
          final jobId = jobIdMatch?.group(1);
          
          if (jobId != null) {
            final pctMatch = RegExp(r'Progress: ([\d\.]+)%').firstMatch(trimmed);
            if (pctMatch != null) {
              _jobProgress[jobId] = double.tryParse(pctMatch.group(1)!) ?? 0.0;
            }

            if (_jobTimerLineIndex.containsKey(jobId)) {
              final idx = _jobTimerLineIndex[jobId]!;
              if (idx < _consoleLogs.length && _consoleLogs[idx].contains('[$jobId]')) {
                _consoleLogs[idx] = trimmed;
              } else {
                _jobTimerLineIndex[jobId] = _consoleLogs.length;
                _consoleLogs.add(trimmed);
              }
            } else {
              _jobTimerLineIndex[jobId] = _consoleLogs.length;
              _consoleLogs.add(trimmed);
            }
          } else {
            _consoleLogs.add(trimmed);
          }
        } else {
          _consoleLogs.add(trimmed);
        }
        notifyListeners();
      },
      onDone: () async {
        _isProcessing = false;
        await refreshQueue();
      },
      onError: (e) async {
        _consoleLogs.add("❌ Error: $e");
        _isProcessing = false;
        await refreshQueue();
      },
    );
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    super.dispose();
  }
}
