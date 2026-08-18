import '../models/clip_frame.dart';
import '../models/clip_media_info.dart';
import '../models/thumbnail_candidate.dart';

abstract interface class ClipperApi {
  Future<ClipMediaInfo> getMediaInfo(String source);
  Future<List<ClipFrame>> getNearbyFrames(
    String source,
    int aroundUs, {
    int before,
    int after,
  });
  Future<void> exportClip(
    String source,
    String output,
    int inUs,
    int outUs,
    String container,
  );
  Future<List<ThumbnailCandidate>> generateThumbnails(
    String source,
    int inUs,
    int outUs,
    String cacheDirectory,
  );
  Future<void> saveThumbnail(
    String source,
    int timestampUs,
    String output,
    String format,
  );
}
