class AuthUser {
  final String id;
  final String account;
  final String? name;
  final DateTime? createdAt;

  AuthUser({
    required this.id,
    required this.account,
    this.name,
    this.createdAt,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      account: json['account'] as String,
      name: json['name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'account': account,
    'name': name,
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
