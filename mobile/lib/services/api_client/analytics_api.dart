import '../../models/models.dart';
import 'api_client.dart';

class AnalyticsApi {
  final ApiClient _client;

  AnalyticsApi(this._client);

  Future<ApiResponse<Map<String, dynamic>>> uploadAnalyticsEvents({
    required List<Map<String, dynamic>> events,
    String? deviceId,
    String? platform,
    String? appVersion,
  }) async {
    final body = <String, dynamic>{'events': events};
    if (deviceId != null) {
      body['device_id'] = deviceId;
    }
    if (platform != null) {
      body['platform'] = platform;
    }
    if (appVersion != null) {
      body['app_version'] = appVersion;
    }

    return _client.post(
      '/analytics/events',
      fromJsonT: (data) => data as Map<String, dynamic>,
      body: body,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> getAnalyticsDashboard({
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, String>{};
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;

    return _client.get(
      '/analytics/dashboard',
      fromJsonT: (data) => data as Map<String, dynamic>,
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );
  }

  String buildAnalyticsExportUrl({
    required String startDate,
    required String endDate,
    List<String>? eventNames,
  }) {
    var url = _client.buildUrl('/analytics/export/csv');
    url = '$url?start_date=$startDate&end_date=$endDate&download=true';
    return url;
  }
}
