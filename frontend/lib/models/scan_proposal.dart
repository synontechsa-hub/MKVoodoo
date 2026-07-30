class ScanProposal {
  final String source;
  final String relative;
  final String outputFilename;
  final String originalFilename;
  final int season;
  final int episode;
  final String title;
  final Map<String, List<Map<String, dynamic>>> tracks;

  // Metadata selection
  List<int>? selectedAudioTracks;
  List<int>? selectedSubtitleTracks;
  String? audioBitrate;
  String? posterUrl;
  String? description;

  ScanProposal({
    required this.source,
    required this.relative,
    required this.outputFilename,
    required this.originalFilename,
    required this.season,
    required this.episode,
    required this.title,
    required this.tracks,
    this.selectedAudioTracks,
    this.selectedSubtitleTracks,
    this.audioBitrate,
  });

  factory ScanProposal.fromJson(Map<String, dynamic> json) {
    return ScanProposal(
      source: json['source'] as String,
      relative: json['relative'] as String,
      outputFilename: json['output_filename'] as String,
      originalFilename: json['original_filename'] as String? ?? (json['output_filename'] as String),
      season: json['season'] as int,
      episode: json['episode'] as int,
      title: json['title'] as String,
      tracks: {
        'audio': (json['tracks']['audio'] as List).cast<Map<String, dynamic>>(),
        'subtitles': (json['tracks']['subtitles'] as List).cast<Map<String, dynamic>>(),
      },
    );
  }
}
