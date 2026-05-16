import '../../models/models.dart';
import 'api_client.dart';

class TranscriptionApi {
  final ApiClient _client;

  TranscriptionApi(this._client);

  Future<ApiResponse<Map<String, dynamic>>> uploadAndTranscribe(
    String filePath,
  ) async {
    return _client.postMultipartFile(
      '/transcriptions/upload',
      fieldName: 'file',
      filePath: filePath,
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> getTranscription(
    String transcriptionId,
  ) async {
    return _client.get(
      '/transcriptions/$transcriptionId',
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> confirmTranscription({
    required String transcriptionId,
    required String content,
    required String customerId,
  }) async {
    return _client.post(
      '/transcriptions/$transcriptionId/confirm',
      fromJsonT: (data) => data as Map<String, dynamic>,
      body: {'content': content, 'customer_id': customerId},
    );
  }
}
