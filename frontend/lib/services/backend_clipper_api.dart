import '../models/clip_frame.dart';
import '../models/clip_media_info.dart';
import '../models/thumbnail_candidate.dart';
import 'backend_bridge.dart';
import 'clipper_api.dart';

class BackendClipperApi implements ClipperApi {
  BackendClipperApi(this._bridge);

  final BackendBridge _bridge;

  @override
  Future<ClipMediaInfo> getMediaInfo(String source) async =>
      ClipMediaInfo.fromJson(await _bridge.getClipMediaInfo(source));

  @override
  Future<List<ClipFrame>> getNearbyFrames(
    String source,
    int aroundUs, {
    int before = 1,
    int after = 1,
  }) async {
    final frames = await _bridge.getNearbyClipFrames(
      source,
      aroundUs,
      before: before,
      after: after,
    );
    return frames.map(ClipFrame.fromJson).toList();
  }

  @override
  Future<void> exportClip(
    String source,
    String output,
    int inUs,
    int outUs,
    String container,
  ) async {
    await _bridge.exportClip(source, output, inUs, outUs, container);
  }

  @override
  Future<List<ThumbnailCandidate>> generateThumbnails(
    String source,
    int inUs,
    int outUs,
    String cacheDirectory,
  ) async {
    final candidates = await _bridge.getClipThumbnailCandidates(
      source,
      inUs,
      outUs,
      cacheDirectory,
    );
    return candidates.map(ThumbnailCandidate.fromJson).toList();
  }

  @override
  Future<void> saveThumbnail(
    String source,
    int timestampUs,
    String output,
    String format,
  ) async {
    await _bridge.extractClipThumbnail(
      source,
      timestampUs,
      output,
      imageFormat: format,
    );
  }
}
