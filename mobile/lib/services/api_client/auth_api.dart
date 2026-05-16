import '../../models/models.dart';
import 'api_client.dart';

class AuthApi {
  final ApiClient _client;

  AuthApi(this._client);

  Future<ApiResponse<AuthSessionData>> register({
    required String account,
    required String password,
    String? name,
  }) async {
    final body = <String, dynamic>{'account': account, 'password': password};
    if (name != null) {
      body['name'] = name;
    }

    return _client.post(
      '/auth/register',
      fromJsonT: (data) =>
          AuthSessionData.fromJson(data as Map<String, dynamic>),
      body: body,
    );
  }

  Future<ApiResponse<AuthSessionData>> login({
    required String account,
    required String password,
  }) async {
    return _client.post(
      '/auth/login',
      fromJsonT: (data) =>
          AuthSessionData.fromJson(data as Map<String, dynamic>),
      body: {'account': account, 'password': password},
    );
  }

  Future<ApiResponse<AuthUser>> me() async {
    return _client.get(
      '/auth/me',
      fromJsonT: (data) => AuthUser.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<ApiResponse<AuthUser>> updatePreferences({
    required String industryKey,
  }) async {
    return _client.patch(
      '/auth/me/preferences',
      fromJsonT: (data) => AuthUser.fromJson(data as Map<String, dynamic>),
      body: {'industry_key': industryKey},
    );
  }
}
