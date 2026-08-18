class ClipSelection {
  const ClipSelection({this.inUs, this.outUs});

  final int? inUs;
  final int? outUs;

  bool get isComplete => inUs != null && outUs != null && outUs! >= inUs!;
  int? get durationUs => isComplete ? outUs! - inUs! : null;
}
