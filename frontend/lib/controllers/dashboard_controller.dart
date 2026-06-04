import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/backend_status.dart';
import '../services/backend_bridge.dart';

class DashboardController extends ChangeNotifier {
  final BackendBridge _bridge;
  Timer? _refreshTimer;
  
  BackendStatus _status = BackendStatus.error;
  int _activeJobs = 0;
  int _doneJobs = 0;
  int _failedJobs = 0;
  double _processedGB = 0.0;
  Map<String, dynamic> _storage = {};
  Map<String, dynamic> _hardware = {};
  bool _isLoading = true;

  DashboardController(this._bridge) {
    fetchData();
    // Start polling every 3 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      fetchData(silent: true);
    });
  }

  // Getters
  BackendStatus get status => _status;
  int get activeJobs => _activeJobs;
  int get doneJobs => _doneJobs;
  int get failedJobs => _failedJobs;
  double get processedGB => _processedGB;
  Map<String, dynamic> get storage => _storage;
  Map<String, dynamic> get hardware => _hardware;
  bool get isLoading => _isLoading;

  Future<void> fetchData({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    
    try {
      final newStatus = await _bridge.checkStatus();
      _status = newStatus;

      if (_status == BackendStatus.ready) {
        final data = await _bridge.getQueueStatus();
        final stats = data['stats'] ?? {};
        
        _activeJobs = (stats['active_jobs'] ?? 0) as int;
        _doneJobs = (stats['done_jobs'] ?? 0) as int;
        _failedJobs = (stats['failed_jobs'] ?? 0) as int;
        _processedGB = (stats['processed_gb'] ?? 0.0) as double;
        _storage = data['storage'] ?? {};
        _hardware = data['hardware'] ?? {};
      }
    } catch (e) {
      _status = BackendStatus.error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
