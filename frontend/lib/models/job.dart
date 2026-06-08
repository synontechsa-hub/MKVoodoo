enum JobStatus {
  pending,
  inProgress,
  done,
  failed,
  skipped;

  static JobStatus fromString(String status) {
    switch (status) {
      case 'pending':
        return JobStatus.pending;
      case 'in_progress':
        return JobStatus.inProgress;
      case 'done':
        return JobStatus.done;
      case 'failed':
        return JobStatus.failed;
      case 'skipped':
        return JobStatus.skipped;
      default:
        return JobStatus.pending;
    }
  }

  String toJson() {
    switch (this) {
      case JobStatus.pending:
        return 'pending';
      case JobStatus.inProgress:
        return 'in_progress';
      case JobStatus.done:
        return 'done';
      case JobStatus.failed:
        return 'failed';
      case JobStatus.skipped:
        return 'skipped';
    }
  }
}

class Job {
  final String id;
  final String source;
  final String output;
  final String preset;
  final JobStatus status;
  final String? error;
  final int attempts;

  Job({
    required this.id,
    required this.source,
    required this.output,
    required this.preset,
    required this.status,
    this.error,
    this.attempts = 0,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'] as String,
      source: json['source'] as String,
      output: json['output'] as String,
      preset: json['preset'] as String,
      status: JobStatus.fromString(json['status'] as String? ?? 'pending'),
      error: json['error'] as String?,
      attempts: json['attempts'] as int? ?? 0,
    );
  }
}
