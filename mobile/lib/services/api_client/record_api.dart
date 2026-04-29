import 'dart:convert';

import '../../models/models.dart';
import 'api_client.dart';

class RecordApi {
  final ApiClient _client;

  RecordApi(this._client);

  Future<ApiResponse<PaginatedData<Record>>> getCustomerRecords({
    required String customerId,
    int limit = 50,
  }) async {
    return _client.get(
      '/customers/$customerId/records',
      fromJsonT: (data) => PaginatedData.fromJson(
        data as Map<String, dynamic>,
        (item) => Record.fromJson(item as Map<String, dynamic>),
      ),
      queryParams: {'limit': limit.toString()},
    );
  }

  Future<ApiResponse<PaginatedData<Record>>> getRecords({
    String? customerId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (customerId != null) {
      queryParams['customer_id'] = customerId;
    }

    return _client.get(
      '/records',
      fromJsonT: (data) => PaginatedData.fromJson(
        data as Map<String, dynamic>,
        (item) => Record.fromJson(item as Map<String, dynamic>),
      ),
      queryParams: queryParams,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> createRecord({
    required String customerId,
    required String content,
  }) async {
    return _client.post(
      '/records',
      fromJsonT: (data) => data as Map<String, dynamic>,
      body: {'customer_id': customerId, 'content': content},
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> createRecordDirect({
    required String customerId,
    required String content,
  }) async {
    return createRecord(customerId: customerId, content: content);
  }

  Future<ApiResponse<Map<String, dynamic>>> createRecordWithImages({
    required String customerId,
    required String content,
    List<String> imagePaths = const [],
    String? locationRaw,
  }) async {
    return _client.postMultipart(
      '/records/with-images',
      fromJsonT: (data) => data as Map<String, dynamic>,
      fields: {
        'customer_id': customerId,
        'content': content,
        if (locationRaw != null && locationRaw.isNotEmpty)
          'location_raw': locationRaw,
      },
      filePaths: imagePaths,
      fileFieldName: 'images',
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> updateRecord({
    required String recordId,
    String? content,
  }) async {
    final body = <String, dynamic>{};
    if (content != null) {
      body['content'] = content;
    }

    return _client.put(
      '/records/$recordId',
      fromJsonT: (data) => data as Map<String, dynamic>,
      body: body,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> updateRecordWithImages({
    required String recordId,
    required String content,
    List<String> keepImageUrls = const [],
    List<String> imagePaths = const [],
    String? locationRaw,
  }) async {
    return _client.putMultipart(
      '/records/$recordId/with-images',
      fromJsonT: (data) => data as Map<String, dynamic>,
      fields: {
        'content': content,
        if (keepImageUrls.isNotEmpty)
          'keep_image_urls': jsonEncode(keepImageUrls),
        if (locationRaw != null && locationRaw.isNotEmpty)
          'location_raw': locationRaw,
      },
      filePaths: imagePaths,
      fileFieldName: 'images',
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> analyzeRecordImage({
    required String recordId,
    required String imageUrl,
    List<String> analyzeModes = const [],
  }) async {
    return _client.postMultipart(
      '/records/$recordId/images/analyze',
      fromJsonT: (data) => data as Map<String, dynamic>,
      fields: {
        'image_url': imageUrl,
        if (analyzeModes.isNotEmpty) 'analyze_modes': jsonEncode(analyzeModes),
      },
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> deleteRecord(
    String recordId,
  ) async {
    return _client.delete(
      '/records/$recordId',
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }
}
