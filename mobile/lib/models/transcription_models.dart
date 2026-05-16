class Transcription {
  final String id;
  final String? customerId;
  final String status;
  final String? transcriptText;
  final String? originalName;
  final String? errorMessage;
  final DateTime createdAt;

  Transcription({
    required this.id,
    this.customerId,
    required this.status,
    this.transcriptText,
    this.originalName,
    this.errorMessage,
    required this.createdAt,
  });

  factory Transcription.fromJson(Map<String, dynamic> json) {
    return Transcription(
      id: json['id'] as String,
      customerId: json['customer_id'] as String?,
      status: json['status'] as String,
      transcriptText: json['transcript_text'] as String?,
      originalName: json['original_name'] as String?,
      errorMessage: json['error_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class DraftRecord {
  final String? transcriptionId;
  final String? transcriptText;
  final String? customerId;
  final List<String> imagePaths;
  final DateTime createdAt;

  DraftRecord({
    this.transcriptionId,
    this.transcriptText,
    this.customerId,
    this.imagePaths = const [],
    required this.createdAt,
  });

  bool get hasCustomer => customerId != null && customerId!.isNotEmpty;

  String get summary => transcriptText?.isNotEmpty == true
      ? transcriptText!.length > 50
            ? '${transcriptText!.substring(0, 50)}...'
            : transcriptText!
      : '无内容';
}
