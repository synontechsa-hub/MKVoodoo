class ThumbnailCandidate {
  const ThumbnailCandidate({
    required this.timestampUs,
    required this.path,
    required this.score,
  });

  final int timestampUs;
  final String path;
  final double score;

  factory ThumbnailCandidate.fromJson(Map<String, dynamic> json) =>
      ThumbnailCandidate(
        timestampUs: json['timestamp_us'] as int,
        path: json['path'] as String,
        score: (json['score'] as num).toDouble(),
      );
}
