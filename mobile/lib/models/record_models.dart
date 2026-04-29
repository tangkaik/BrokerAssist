class RecordImage {
  final String name;
  final String url;
  final String? contentType;
  final String? visionAnswer;
  final DateTime? visionUpdatedAt;

  RecordImage({
    required this.name,
    required this.url,
    this.contentType,
    this.visionAnswer,
    this.visionUpdatedAt,
  });

  factory RecordImage.fromJson(Map<String, dynamic> json) {
    final vision = json['vision'] as Map<String, dynamic>?;
    return RecordImage(
      name: (json['name'] ?? '') as String,
      url: (json['url'] ?? '') as String,
      contentType: json['content_type'] as String?,
      visionAnswer: vision?['answer'] as String?,
      visionUpdatedAt: vision?['updated_at'] != null
          ? DateTime.tryParse(vision!['updated_at'] as String)
          : null,
    );
  }
}

class Record {
  final String id;
  final String customerId;
  final String content;
  final String? type;
  final DateTime createdAt;
  final List<RecordImage> images;

  Record({
    required this.id,
    required this.customerId,
    required this.content,
    this.type,
    required this.createdAt,
    this.images = const [],
  });

  factory Record.fromJson(Map<String, dynamic> json) {
    return Record(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      content: json['content'] as String,
      type: json['type'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      images: (json['images'] as List<dynamic>? ?? const [])
          .map((item) => RecordImage.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
