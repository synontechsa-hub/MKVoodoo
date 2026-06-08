import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/backend_status.dart';
import '../models/scan_proposal.dart';

/// The bridge between Flutter and the Python MKVoodoo backend.
class BackendBridge {
  static final BackendBridge _instance = BackendBridge._internal();
  factory BackendBridge() => _instance;
  BackendBridge._internal();

  Process? _activeProcess;

  String get _backendRoot {
    final envRoot = Platform.environment['MKVOODOO_ROOT'];
    if (envRoot != null && envRoot.isNotEmpty) {
      return envRoot;
    }

    final exeDir = File(Platform.resolvedExecutable).parent;
    Directory dir = exeDir;
    for (int i = 0; i < 6; i++) {
      final venv = Directory(p.join(dir.path, '.venv'));
      if (venv.existsSync()) return dir.path;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }

    return Directory.current.path;
  }

  String get _pythonPath {
    final root = _backendRoot;
    
    // 1. Check for compiled backend executable first (Release Mode)
    final compiledPath = p.join(root, 'mkvoodoo_backend.exe');
    if (File(compiledPath).existsSync()) {
      return compiledPath;
    }

    // 2. Fallback to Python venv (Dev Mode)
    if (Platform.isWindows) {
      return p.join(root, '.venv', 'Scripts', 'python.exe');
    }
    return p.join(root, '.venv', 'bin', 'python');
  }

  /// Helper to determine if we are running the compiled backend
  bool get _isCompiled => _pythonPath.endsWith('.exe') && !_pythonPath.contains('python');

  List<String> _buildArgs(List<String> args) {
    if (_isCompiled) {
      // If compiled, we don't need "-u -m backend.main"
      // We just pass the command and its arguments directly
      return args;
    }
    return ['-u', '-m', 'backend.main', ...args];
  }

  Future<BackendStatus> checkStatus() async {
    try {
      final result = await Process.run(
        _pythonPath,
        _isCompiled ? ['--help'] : ['-u', '-m', 'backend.main', '--help'],
        workingDirectory: _backendRoot,
        environment: _pythonEnv,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (result.exitCode == 0) return BackendStatus.ready;

      if (result.stderr.toString().contains('No module named backend')) {
        return BackendStatus.moduleMissing;
      }
      return BackendStatus.error;
    } catch (e) {
      return BackendStatus.pythonMissing;
    }
  }

  Future<Map<String, dynamic>> getConfig() async {
    final result = await Process.run(
      _pythonPath,
      _buildArgs(['config', '--get']),
      workingDirectory: _backendRoot,
      environment: _pythonEnv,
      stdoutEncoding: utf8,
    );

    if (result.exitCode != 0) {
      throw Exception('Failed to get config: ${result.stderr}');
    }

    return jsonDecode(result.stdout as String) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getAvailableEncoders() async {
    final result = await Process.run(
      _pythonPath,
      _buildArgs(['encoders']),
      workingDirectory: _backendRoot,
      environment: _pythonEnv,
      stdoutEncoding: utf8,
    );

    if (result.exitCode != 0) {
      throw Exception('Failed to get encoders: ${result.stderr}');
    }

    final List<dynamic> list = jsonDecode(result.stdout as String);
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<void> setConfig(Map<String, dynamic> config) async {
    final configJson = jsonEncode(config);
    final result = await Process.run(
      _pythonPath,
      _buildArgs(['config', '--set', configJson]),
      workingDirectory: _backendRoot,
      environment: _pythonEnv,
      stdoutEncoding: utf8,
    );

    if (result.exitCode != 0) {
      throw Exception('Failed to set config: ${result.stderr}');
    }
  }

  Future<void> stopActiveProcess() async {
    _activeProcess?.kill();
    _activeProcess = null;

    if (Platform.isWindows) {
      await Process.run('taskkill', ['/F', '/IM', 'ffmpeg.exe', '/T']);
    }
  }

  Future<void> clearCompletedJobs() async {
    final result = await Process.run(
      _pythonPath,
      _buildArgs(['queue', '--clear-done']),
      workingDirectory: _backendRoot,
      environment: _pythonEnv,
    );
    if (result.exitCode != 0) {
      throw Exception('Failed to clear queue: ${result.stderr}');
    }
  }

  Future<void> resetFailedJobs() async {
    final result = await Process.run(
      _pythonPath,
      _buildArgs(['queue', '--reset-failed']),
      workingDirectory: _backendRoot,
      environment: _pythonEnv,
    );
    if (result.exitCode != 0) {
      throw Exception('Failed to reset queue: ${result.stderr}');
    }
  }

  Future<void> removeJobs(List<String> jobIds) async {
    if (jobIds.isEmpty) return;
    final idsParam = jobIds.join(',');
    final result = await Process.run(
      _pythonPath,
      _buildArgs(['queue', '--remove', idsParam]),
      workingDirectory: _backendRoot,
      environment: _pythonEnv,
    );
    if (result.exitCode != 0) {
      throw Exception('Failed to remove jobs: ${result.stderr}');
    }
  }

  Future<void> addToQueue(List<String> filePaths) async {
    if (filePaths.isEmpty) return;
    final result = await Process.run(
      _pythonPath,
      _buildArgs(['queue', '--add', ...filePaths]),
      workingDirectory: _backendRoot,
      environment: _pythonEnv,
    );
    if (result.exitCode != 0) {
      throw Exception('Failed to add to queue: ${result.stderr}');
    }
  }


  Future<void> addJobs(List<Map<String, dynamic>> jobs) async {
    if (jobs.isEmpty) return;
    final jobsJson = jsonEncode(jobs);
    final result = await Process.run(
      _pythonPath,
      _buildArgs(['queue', '--jobs', jobsJson]),
      workingDirectory: _backendRoot,
      environment: _pythonEnv,
    );
    if (result.exitCode != 0) {
      throw Exception('Failed to add jobs: ${result.stderr}');
    }
  }

  Future<void> clearAllHistory() async {
    final result = await Process.run(
      _pythonPath,
      _buildArgs(['queue', '--clear-all']),
      workingDirectory: _backendRoot,
      environment: _pythonEnv,
    );
    if (result.exitCode != 0) {
      throw Exception('Failed to clear all history: ${result.stderr}');
    }
  }

  Stream<String> resumeQueue() async* {
    _activeProcess = await Process.start(
      _pythonPath,
      _buildArgs(['queue', '--resume']),
      workingDirectory: _backendRoot,
      environment: _pythonEnv,
    );
    
    final process = _activeProcess;
    if (process == null) {
      throw Exception('Failed to start resume process.');
    }
    
    final controller = StreamController<String>();

    process.stdout
        .transform(Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) => controller.add(line));

    process.stderr
        .transform(Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) => controller.add(line));

    process.exitCode.then((_) {
      if (!controller.isClosed) controller.close();
    });

    yield* controller.stream;
  }

  Future<Map<String, dynamic>> getQueueStatus() async {
    final result = await Process.run(
      _pythonPath,
      _buildArgs(['status', '--json']),
      workingDirectory: _backendRoot,
      environment: _pythonEnv,
      stdoutEncoding: utf8,
    );

    if (result.exitCode != 0) return {};

    final Map<String, dynamic> data = jsonDecode(result.stdout as String);
    return data;
  }

  Future<Map<String, List<Map<String, dynamic>>>> getTracks(String filePath) async {
    final result = await Process.run(
      _pythonPath,
      _buildArgs(['probe', '--input', filePath]),
      workingDirectory: _backendRoot,
      environment: _pythonEnv,
      stdoutEncoding: utf8,
    );

    if (result.exitCode != 0) {
      throw Exception('Failed to probe file: ${result.stderr}');
    }

    final Map<String, dynamic> data = jsonDecode(result.stdout as String);
    return {
      'audio': (data['audio'] as List).cast<Map<String, dynamic>>(),
      'subtitles': (data['subtitles'] as List).cast<Map<String, dynamic>>(),
    };
  }

  Future<List<ScanProposal>> scanInputs(List<String> inputs) async {
    final result = await Process.run(
      _pythonPath,
      _buildArgs(['scan', '--input', ...inputs, '--json']),
      workingDirectory: _backendRoot,
      environment: _pythonEnv,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );

    if (result.exitCode != 0) {
      throw Exception('Scan failed: ${result.stderr}');
    }

    final List<dynamic> data = jsonDecode(result.stdout as String);
    return data
        .map((item) => ScanProposal.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Stream<String> convert({
    required String input,
    required String output,
    String? preset,
    bool review = false,
  }) async* {
    final List<String> cmdArgs = [
      'convert',
      '--input', input,
      '--output', output,
    ];

    if (preset != null) cmdArgs.addAll(['--preset', preset]);
    if (!review) cmdArgs.add('--no-review');

    _activeProcess = await Process.start(
      _pythonPath,
      _buildArgs(cmdArgs),
      workingDirectory: _backendRoot,
      environment: _pythonEnv,
    );
    
    final process = _activeProcess;
    if (process == null) {
      throw Exception('Failed to start backend process.');
    }
    
    final controller = StreamController<String>();

    process.stdout
        .transform(Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) => controller.add(line));

    process.stderr
        .transform(Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) => controller.add(line));

    process.exitCode.then((_) {
      if (!controller.isClosed) controller.close();
    });

    yield* controller.stream;
  }
}
