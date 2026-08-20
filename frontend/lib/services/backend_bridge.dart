import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/backend_status.dart';
import '../models/scan_proposal.dart';

/// The bridge between Flutter and the Python MKVoodoo backend.
class BackendBridge {
  static final BackendBridge _instance = BackendBridge.internal();
  factory BackendBridge() => _instance;
  BackendBridge.internal();

  final Map<String, Process> _activeProcesses = {};

  void _trackProcess(String operationId, Process process) {
    _activeProcesses[operationId] = process;
  }

  void _untrackProcess(String operationId, Process process) {
    // A replacement operation may already be running under this ID. Only
    // remove this process's entry so an older exit callback cannot untrack it.
    if (_activeProcesses[operationId] == process) {
      _activeProcesses.remove(operationId);
    }
  }

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
  bool get _isCompiled =>
      _pythonPath.endsWith('.exe') && !_pythonPath.contains('python');

  List<String> _buildArgs(List<String> args) {
    if (_isCompiled) {
      // If compiled, we don't need "-u -m backend.main"
      // We just pass the command and its arguments directly
      return args;
    }
    return ['-u', '-m', 'backend.main', ...args];
  }

  Map<String, String> get _pythonEnv => {
    ...Platform.environment,
    'PYTHONIOENCODING': 'utf-8',
    'PYTHONUTF8': '1',
  };

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

  Future<void> stopActiveProcess({String? operationId}) async {
    if (operationId != null) {
      await cancelOperation(operationId);
      return;
    }
    await cancelAllOperations();
  }

  Future<void> cancelOperation(String operationId) async {
    final process = _activeProcesses.remove(operationId);
    if (process == null) return;

    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/F', '/T', '/PID', '${process.pid}']);
      } else {
        process.kill(ProcessSignal.sigterm);
      }
    } catch (_) {
      process.kill();
    }
  }

  Future<void> cancelAllOperations() async {
    final entries = List<MapEntry<String, Process>>.from(
      _activeProcesses.entries,
    );
    _activeProcesses.clear();
    for (final entry in entries) {
      final process = entry.value;
      try {
        if (Platform.isWindows) {
          await Process.run('taskkill', ['/F', '/T', '/PID', '${process.pid}']);
        } else {
          process.kill(ProcessSignal.sigterm);
        }
      } catch (_) {
        process.kill();
      }
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
    const operationId = 'queue_resume';
    await cancelOperation(operationId);
    final process = await Process.start(
      _pythonPath,
      _buildArgs(['queue', '--resume']),
      workingDirectory: _backendRoot,
      environment: _pythonEnv,
    );
    _trackProcess(operationId, process);

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
      _untrackProcess(operationId, process);
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

  Future<Map<String, List<Map<String, dynamic>>>> getTracks(
    String filePath,
  ) async {
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

  Future<Map<String, dynamic>> getClipMediaInfo(String filePath) async {
    final result = await Process.run(
      _pythonPath,
      _buildArgs(['probe', '--input', filePath, '--clip-info']),
      workingDirectory: _backendRoot,
      environment: _pythonEnv,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );

    if (result.exitCode != 0) {
      throw Exception('Failed to probe Clipper media: ${result.stderr}');
    }
    return jsonDecode(result.stdout as String) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getNearbyClipFrames(
    String filePath,
    int aroundMicroseconds, {
    int before = 1,
    int after = 1,
  }) async {
    final result = await Process.run(
      _pythonPath,
      _buildArgs([
        'probe',
        '--input',
        filePath,
        '--around-us',
        aroundMicroseconds.toString(),
        '--before',
        before.toString(),
        '--after',
        after.toString(),
      ]),
      workingDirectory: _backendRoot,
      environment: _pythonEnv,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );

    if (result.exitCode != 0) {
      throw Exception(
        'Failed to resolve nearby Clipper frames: ${result.stderr}',
      );
    }
    final values = jsonDecode(result.stdout as String) as List<dynamic>;
    return values.map((value) => value as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> exportClip(
    String filePath,
    String outputPath,
    int inMicroseconds,
    int outMicroseconds,
    String container,
  ) async {
    final result = await Process.run(
      _pythonPath,
      _buildArgs([
        'clip',
        '--input',
        filePath,
        '--output',
        outputPath,
        '--in-us',
        inMicroseconds.toString(),
        '--out-us',
        outMicroseconds.toString(),
        '--container',
        container,
      ]),
      workingDirectory: _backendRoot,
      environment: _pythonEnv,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (result.exitCode != 0) {
      throw Exception('Failed to export precise clip: ${result.stderr}');
    }
    return jsonDecode(result.stdout as String) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> extractClipThumbnail(
    String filePath,
    int timestampMicroseconds,
    String outputPath, {
    String imageFormat = 'png',
  }) async {
    final result = await Process.run(
      _pythonPath,
      _buildArgs([
        'thumbnail',
        '--input',
        filePath,
        '--timestamp-us',
        timestampMicroseconds.toString(),
        '--output',
        outputPath,
        '--format',
        imageFormat,
      ]),
      workingDirectory: _backendRoot,
      environment: _pythonEnv,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (result.exitCode != 0) {
      throw Exception('Failed to extract Clipper thumbnail: ${result.stderr}');
    }
    return jsonDecode(result.stdout as String) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getClipThumbnailCandidates(
    String filePath,
    int inMicroseconds,
    int endMicroseconds,
    String cacheDirectory, {
    int count = 4,
  }) async {
    final result = await Process.run(
      _pythonPath,
      _buildArgs([
        'thumbnail',
        '--input',
        filePath,
        '--in-us',
        inMicroseconds.toString(),
        '--end-us',
        endMicroseconds.toString(),
        '--cache-dir',
        cacheDirectory,
        '--count',
        count.toString(),
      ]),
      workingDirectory: _backendRoot,
      environment: _pythonEnv,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (result.exitCode != 0) {
      throw Exception(
        'Failed to generate Clipper thumbnail candidates: ${result.stderr}',
      );
    }
    final values = jsonDecode(result.stdout as String) as List<dynamic>;
    return values.map((value) => value as Map<String, dynamic>).toList();
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
      '--input',
      input,
      '--output',
      output,
    ];

    if (preset != null) cmdArgs.addAll(['--preset', preset]);
    if (!review) cmdArgs.add('--no-review');

    const operationId = 'conversion';
    await cancelOperation(operationId);
    final process = await Process.start(
      _pythonPath,
      _buildArgs(cmdArgs),
      workingDirectory: _backendRoot,
      environment: _pythonEnv,
    );
    _trackProcess(operationId, process);

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
      _untrackProcess(operationId, process);
      if (!controller.isClosed) controller.close();
    });

    yield* controller.stream;
  }

  Future<Map<String, dynamic>> getYoutubeInfo(String url) async {
    final result = await Process.run(
      _pythonPath,
      _buildArgs(['youtube', '--info', url]),
      workingDirectory: _backendRoot,
      environment: _pythonEnv,
      stdoutEncoding: utf8,
    );

    if (result.exitCode != 0) {
      throw Exception('Failed to fetch YouTube info: ${result.stderr}');
    }

    return jsonDecode(result.stdout as String) as Map<String, dynamic>;
  }

  Stream<String> downloadYoutube(
    String url, {
    bool audioOnly = false,
    String format = 'mp3',
    String videoQuality = '1080',
  }) async* {
    final List<String> args = ['youtube', '--download', url];
    if (audioOnly) {
      args.addAll(['--audio-only', '--format', format]);
    } else {
      args.addAll(['--video-quality', videoQuality]);
    }

    const operationId = 'youtube_download';
    await cancelOperation(operationId);
    final process = await Process.start(
      _pythonPath,
      _buildArgs(args),
      workingDirectory: _backendRoot,
      environment: _pythonEnv,
    );
    _trackProcess(operationId, process);

    final controller = StreamController<String>();

    process.stdout
        .transform(Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) => controller.add(line));

    process.stderr
        .transform(Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) => controller.add(line));

    final exitCodeFuture = process.exitCode;
    exitCodeFuture.then((_) {
      _untrackProcess(operationId, process);
      if (!controller.isClosed) controller.close();
    });

    yield* controller.stream;

    final exitCode = await exitCodeFuture;
    if (exitCode != 0) {
      throw Exception(
        'YouTube download failed. See the download log for details.',
      );
    }
  }

  Future<Map<String, dynamic>> checkUpdate() async {
    final result = await Process.run(
      _pythonPath,
      _buildArgs(['check-update']),
      workingDirectory: _backendRoot,
      environment: _pythonEnv,
      stdoutEncoding: utf8,
    );

    if (result.exitCode != 0) {
      throw Exception('Failed to check for updates: ${result.stderr}');
    }

    return jsonDecode(result.stdout as String) as Map<String, dynamic>;
  }

  Future<String> updateDownloader() async {
    final result = await Process.run(
      _pythonPath,
      _buildArgs(['update-downloader']),
      workingDirectory: _backendRoot,
      environment: _pythonEnv,
      stdoutEncoding: utf8,
    );

    if (result.exitCode != 0) {
      throw Exception('Failed to update downloader: ${result.stderr}');
    }

    return result.stdout as String;
  }

  Future<List<Map<String, dynamic>>> searchMetadata(
    String query, {
    bool isTv = false,
  }) async {
    final args = ['metadata', '--search', query];
    if (isTv) args.add('--tv');

    final result = await Process.run(
      _pythonPath,
      _buildArgs(args),
      workingDirectory: _backendRoot,
      environment: _pythonEnv,
      stdoutEncoding: utf8,
    );

    if (result.exitCode != 0) {
      throw Exception('Metadata search failed: ${result.stderr}');
    }

    final List<dynamic> data = jsonDecode(result.stdout as String);
    return data.map((e) => e as Map<String, dynamic>).toList();
  }
}
