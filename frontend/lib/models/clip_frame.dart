class ClipFrame {
  const ClipFrame({
    required this.ptsUs,
    this.durationUs,
    required this.keyFrame,
  });

  final int ptsUs;
  final int? durationUs;
  final bool keyFrame;

  factory ClipFrame.fromJson(Map<String, dynamic> json) => ClipFrame(
    ptsUs: json['pts_us'] as int,
    durationUs: json['duration_us'] as int?,
    keyFrame: json['key_frame'] as bool,
  );
}
