import '../../models/models.dart';
import 'api_client.dart';

class AiApi {
  final ApiClient _client;

  AiApi(this._client);

  Future<ApiResponse<Map<String, dynamic>>> aiChat({
    required String question,
    List<Map<String, String>> recentMessages = const [],
  }) async {
    return _client.post(
      '/ai/chat',
      fromJsonT: (data) => data as Map<String, dynamic>,
      body: {
        'question': question,
        if (recentMessages.isNotEmpty) 'recent_messages': recentMessages,
      },
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> aiChatWithImage({
    required String question,
    required String imagePath,
  }) async {
    return _client.postMultipart(
      '/ai/chat-with-image',
      fromJsonT: (data) => data as Map<String, dynamic>,
      fields: {'question': question},
      filePaths: [imagePath],
      fileFieldName: 'image',
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> chatWithCustomer({
    required String customerId,
    required String question,
  }) async {
    return _client.post(
      '/customers/$customerId/chat',
      fromJsonT: (data) => data as Map<String, dynamic>,
      body: {'question': question},
    );
  }
}
