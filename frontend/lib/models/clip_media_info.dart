class ClipMediaInfo {
  const ClipMediaInfo({
    required this.source,
    required this.durationUs,
    required this.width,
    required this.height,
    required this.isVariableFrameRate,
    required this.frameRateReason,
  });

  final String source;
  final int durationUs;
  final int width;
  final int height;
  final bool isVariableFrameRate;
  final String frameRateReason;

  factory ClipMediaInfo.fromJson(Map<String, dynamic> json) => ClipMediaInfo(
    source: json['source'] as String,
    durationUs: json['duration_us'] as int,
    width: json['width'] as int,
    height: json['height'] as int,
    isVariableFrameRate: json['is_variable_frame_rate'] as bool,
    frameRateReason: json['frame_rate_reason'] as String,
  );
}
