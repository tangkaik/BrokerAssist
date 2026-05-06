class AuthUser {
  final String id;
  final String account;
  final String? name;
  final String industryKey;
  final bool industrySelected;
  final DateTime? createdAt;

  AuthUser({
    required this.id,
    required this.account,
    this.name,
    this.industryKey = 'generic',
    this.industrySelected = false,
    this.createdAt,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      account: json['account'] as String,
      name: json['name'] as String?,
      industryKey: (json['industry_key'] as String?) ?? 'generic',
      industrySelected: (json['industry_selected'] as bool?) ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'account': account,
    'name': name,
    'industry_key': industryKey,
    'industry_selected': industrySelected,
    'created_at': createdAt?.toIso8601String(),
  };
}

class AuthSessionData {
  final String token;
  final AuthUser user;

  AuthSessionData({required this.token, required this.user});

  factory AuthSessionData.fromJson(Map<String, dynamic> json) {
    return AuthSessionData(
      token: json['token'] as String,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
