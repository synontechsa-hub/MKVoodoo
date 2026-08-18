import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/clip_frame.dart';
import '../models/clip_media_info.dart';
import '../models/clip_selection.dart';
import '../models/thumbnail_candidate.dart';
import '../services/clipper_api.dart';
import 'package:flutter/foundation.dart';

class ClipperController extends ChangeNotifier {
  ClipperController(this._api) {
    _positionSubscription = player.stream.position.listen(_onPosition);
    _playingSubscription = player.stream.playing.listen((playing) {
      _isPlaying = playing;
      notifyListeners();
    });
  }

  final ClipperApi _api;
  final Player player = Player();
  late final VideoController videoController = VideoController(player);
  late final StreamSubscription<Duration> _positionSubscription;
  late final StreamSubscription<bool> _playingSubscription;
  final List<Directory> _tempDirectories = [];

  ClipMediaInfo? _mediaInfo;
  ClipSelection _selection = const ClipSelection();
  List<ThumbnailCandidate> _thumbnails = const [];
  int _currentUs = 0;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isExporting = false;
  bool _isGeneratingThumbnails = false;
  bool _loopSelection = false;
  String? _errorMessage;
  String? _successMessage;

  ClipMediaInfo? get mediaInfo => _mediaInfo;
  ClipSelection get selection => _selection;
  List<ThumbnailCandidate> get thumbnails => _thumbnails;
  int get currentUs => _currentUs;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  bool get isExporting => _isExporting;
  bool get isGeneratingThumbnails => _isGeneratingThumbnails;
  bool get loopSelection => _loopSelection;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  bool get hasSource => _mediaInfo != null;
  bool get canExport => hasSource && _selection.isComplete && !_isExporting;

  Future<void> openSource(String source) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      final info = await _api.getMediaInfo(source);
      await player.open(Media(source));
      _mediaInfo = info;
      _selection = const ClipSelection();
      _thumbnails = const [];
      _currentUs = 0;
    } catch (error) {
      _errorMessage = 'Could not open this video: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> seekTo(int targetUs) async {
    final duration = _mediaInfo?.durationUs ?? 0;
    final clamped = targetUs.clamp(0, duration);
    await player.seek(Duration(microseconds: clamped));
    _currentUs = clamped;
    notifyListeners();
  }

  Future<void> stepFrame(int direction) async {
    final source = _mediaInfo?.source;
    if (source == null || direction == 0) return;
    _errorMessage = null;
    notifyListeners();
    try {
      final frames = await _api.getNearbyFrames(
        source,
        _currentUs,
        before: direction < 0 ? 1 : 0,
        after: direction > 0 ? 1 : 0,
      );
      final next = _selectStepFrame(frames, direction);
      if (next != null) await seekTo(next.ptsUs);
    } catch (error) {
      _errorMessage = 'Could not resolve the next frame: $error';
      notifyListeners();
    }
  }

  Future<void> setIn() => _setBoundary(isIn: true);
  Future<void> setOut() => _setBoundary(isIn: false);

  Future<void> _setBoundary({required bool isIn}) async {
    final source = _mediaInfo?.source;
    if (source == null) return;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      final frames = await _api.getNearbyFrames(
        source,
        _currentUs,
        before: 1,
        after: 1,
      );
      final boundaryUs = _closestFrame(frames)?.ptsUs ?? _currentUs;
      final next = isIn
          ? ClipSelection(inUs: boundaryUs, outUs: _selection.outUs)
          : ClipSelection(inUs: _selection.inUs, outUs: boundaryUs);
      if (next.inUs != null && next.outUs != null && next.outUs! < next.inUs!) {
        _errorMessage = 'Out must be on or after In.';
        return;
      }
      _selection = next;
    } catch (error) {
      _errorMessage = 'Could not set ${isIn ? 'In' : 'Out'}: $error';
    } finally {
      notifyListeners();
    }
  }

  void clearSelection() {
    _selection = const ClipSelection();
    _thumbnails = const [];
    _successMessage = null;
    notifyListeners();
  }

  void setLoopSelection(bool value) {
    _loopSelection = value;
    notifyListeners();
  }

  Future<void> togglePlayback() async {
    if (player.state.playing) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> export(String output, String container) async {
    final source = _mediaInfo?.source;
    if (source == null || !_selection.isComplete || _isExporting) return;
    _isExporting = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      await _api.exportClip(
        source,
        output,
        _selection.inUs!,
        _selection.outUs!,
        container,
      );
      _successMessage = 'Clip exported to $output';
    } catch (error) {
      _errorMessage = 'Clip export failed: $error';
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  Future<void> generateThumbnails() async {
    final source = _mediaInfo?.source;
    if (source == null || !_selection.isComplete || _isGeneratingThumbnails) {
      return;
    }
    _isGeneratingThumbnails = true;
    _errorMessage = null;
    notifyListeners();
    try {
      for (final dir in _tempDirectories) {
        try {
          if (dir.existsSync()) dir.deleteSync(recursive: true);
        } catch (_) {}
      }
      _tempDirectories.clear();

      final cache = await Directory.systemTemp.createTemp('mkvoodoo-clipper-');
      _tempDirectories.add(cache);
      _thumbnails = await _api.generateThumbnails(
        source,
        _selection.inUs!,
        _selection.outUs!,
        cache.path,
      );
    } catch (error) {
      _errorMessage = 'Thumbnail generation failed: $error';
    } finally {
      _isGeneratingThumbnails = false;
      notifyListeners();
    }
  }

  Future<void> saveThumbnail(
    String output,
    String format, {
    int? timestampUs,
  }) async {
    final source = _mediaInfo?.source;
    if (source == null) return;
    try {
      await _api.saveThumbnail(
        source,
        timestampUs ?? _currentUs,
        output,
        format,
      );
      _successMessage = 'Thumbnail saved to $output';
    } catch (error) {
      _errorMessage = 'Thumbnail save failed: $error';
    }
    notifyListeners();
  }

  ClipFrame? _selectStepFrame(List<ClipFrame> frames, int direction) {
    final eligible = frames.where(
      (frame) =>
          direction < 0 ? frame.ptsUs < _currentUs : frame.ptsUs > _currentUs,
    );
    if (eligible.isEmpty) return null;
    return direction < 0
        ? eligible.reduce(
            (left, right) => left.ptsUs > right.ptsUs ? left : right,
          )
        : eligible.reduce(
            (left, right) => left.ptsUs < right.ptsUs ? left : right,
          );
  }

  ClipFrame? _closestFrame(List<ClipFrame> frames) {
    if (frames.isEmpty) return null;
    return frames.reduce(
      (left, right) =>
          (left.ptsUs - _currentUs).abs() <= (right.ptsUs - _currentUs).abs()
          ? left
          : right,
    );
  }

  void _onPosition(Duration position) {
    _currentUs = position.inMicroseconds;
    final outUs = _selection.outUs;
    final inUs = _selection.inUs;
    if (_loopSelection && inUs != null && outUs != null && _currentUs > outUs) {
      unawaited(player.seek(Duration(microseconds: inUs)));
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSubscription.cancel();
    _playingSubscription.cancel();
    for (final dir in _tempDirectories) {
      try {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } catch (_) {}
    }
    _tempDirectories.clear();
    unawaited(player.dispose());
    super.dispose();
  }
}
