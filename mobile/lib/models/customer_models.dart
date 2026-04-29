class Customer {
  final String id;
  final String name;
  final String? avatar;
  final String? phone;
  final String? gender;
  final String? locationRaw;
  final String? locationCity;
  final String? locationDistrict;
  final String? locationSubarea;
  final List<String> tags;
  final String? summary;
  final String? summaryStatus;
  final DateTime? lastContactAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Customer({
    required this.id,
    required this.name,
    this.avatar,
    this.phone,
    this.gender,
    this.locationRaw,
    this.locationCity,
    this.locationDistrict,
    this.locationSubarea,
    this.tags = const [],
    this.summary,
    this.summaryStatus,
    this.lastContactAt,
    required this.createdAt,
    this.updatedAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final name = json['name'] as String?;

    if (id == null || name == null) {
      throw FormatException('Customer 缺少必要字段: id=$id, name=$name');
    }

    DateTime? parsedDate;
    final dateStr =
        json['created_at'] as String? ?? json['updated_at'] as String?;
    if (dateStr != null) {
      try {
        parsedDate = DateTime.parse(dateStr);
      } catch (_) {
        parsedDate = null;
      }
    }

    var parsedTags = <String>[];
    final tagsJson = json['tags'];
    if (tagsJson != null && tagsJson is List) {
      parsedTags = tagsJson.map((e) => e.toString()).toList();
    }

    return Customer(
      id: id,
      name: name,
      avatar: json['avatar'] as String?,
      phone: json['phone'] as String?,
      gender: json['gender'] as String?,
      locationRaw: json['location_raw'] as String?,
      locationCity: json['location_city'] as String?,
      locationDistrict: json['location_district'] as String?,
      locationSubarea: json['location_subarea'] as String?,
      tags: parsedTags,
      summary: (json['summary'] ?? json['summary_text']) as String?,
      summaryStatus: json['summary_status'] as String?,
      lastContactAt: json['last_contact_at'] != null
          ? DateTime.tryParse(json['last_contact_at'] as String)
          : null,
      createdAt: parsedDate ?? DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'summary': summary,
      'last_contact_at': lastContactAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
