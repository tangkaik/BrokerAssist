import '../models/models.dart';
import 'api_client/ai_api.dart';
import 'api_client/analytics_api.dart';
import 'api_client/api_client.dart';
import 'api_client/auth_api.dart';
import 'api_client/customer_api.dart';
import 'api_client/record_api.dart';
import 'api_client/transcription_api.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  ApiService._internal() : _client = ApiClient() {
    _auth = AuthApi(_client);
    _customers = CustomerApi(_client);
    _records = RecordApi(_client);
    _transcriptions = TranscriptionApi(_client);
    _ai = AiApi(_client);
    _analytics = AnalyticsApi(_client);
  }

  final ApiClient _client;
  late final AuthApi _auth;
  late final CustomerApi _customers;
  late final RecordApi _records;
  late final TranscriptionApi _transcriptions;
  late final AiApi _ai;
  late final AnalyticsApi _analytics;

  Future<ApiResponse<AuthSessionData>> register({
    required String account,
    required String password,
    String? name,
  }) async {
    return _auth.register(account: account, password: password, name: name);
  }

  Future<ApiResponse<AuthSessionData>> login({
    required String account,
    required String password,
  }) async {
    return _auth.login(account: account, password: password);
  }

  Future<ApiResponse<AuthUser>> me() async {
    return _auth.me();
  }

  Future<ApiResponse<AuthUser>> updatePreferences({
    required String industryKey,
  }) async {
    return _auth.updatePreferences(industryKey: industryKey);
  }

  Future<ApiResponse<PaginatedData<Customer>>> getCustomers({
    int page = 1,
    int pageSize = 20,
  }) async {
    return _customers.getCustomers(page: page, pageSize: pageSize);
  }

  Future<ApiResponse<PaginatedData<Record>>> getCustomerRecords({
    required String customerId,
    int limit = 50,
  }) async {
    return _records.getCustomerRecords(customerId: customerId, limit: limit);
  }

  Future<ApiResponse<PaginatedData<Record>>> getRecords({
    String? customerId,
    int page = 1,
    int pageSize = 20,
  }) async {
    return _records.getRecords(
      customerId: customerId,
      page: page,
      pageSize: pageSize,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> createRecord({
    required String customerId,
    required String content,
  }) async {
    return _records.createRecord(customerId: customerId, content: content);
  }

  Future<ApiResponse<Map<String, dynamic>>> uploadAndTranscribe(
    String filePath,
  ) async {
    return _transcriptions.uploadAndTranscribe(filePath);
  }

  Future<ApiResponse<Map<String, dynamic>>> getTranscription(
    String transcriptionId,
  ) async {
    return _transcriptions.getTranscription(transcriptionId);
  }

  Future<ApiResponse<Map<String, dynamic>>> createCustomer({
    required String name,
    String? phone,
    String? gender,
    int? age,
    String? location,
    List<String>? tags,
  }) async {
    return _customers.createCustomer(
      name: name,
      phone: phone,
      gender: gender,
      age: age,
      location: location,
      tags: tags,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> getCustomerDetail(
    String customerId,
  ) async {
    return _customers.getCustomerDetail(customerId);
  }

  Future<ApiResponse<PaginatedData<Customer>>> searchCustomers({
    String? keyword,
    int page = 1,
    int pageSize = 20,
    String sortBy = 'updated_at',
    String sortOrder = 'desc',
    String? summaryStatus,
    bool staleContact = false,
  }) async {
    return _customers.searchCustomers(
      keyword: keyword,
      page: page,
      pageSize: pageSize,
      sortBy: sortBy,
      sortOrder: sortOrder,
      summaryStatus: summaryStatus,
      staleContact: staleContact,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> confirmTranscription({
    required String transcriptionId,
    required String content,
    required String customerId,
  }) async {
    return _transcriptions.confirmTranscription(
      transcriptionId: transcriptionId,
      content: content,
      customerId: customerId,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> createRecordDirect({
    required String customerId,
    required String content,
  }) async {
    return _records.createRecordDirect(
      customerId: customerId,
      content: content,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> createRecordWithImages({
    required String customerId,
    required String content,
    List<String> imagePaths = const [],
    String? locationRaw,
  }) async {
    return _records.createRecordWithImages(
      customerId: customerId,
      content: content,
      imagePaths: imagePaths,
      locationRaw: locationRaw,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> generateSummary(
    String customerId,
  ) async {
    return _customers.generateSummary(customerId);
  }

  Future<ApiResponse<Map<String, dynamic>>> generateAdvice(
    String customerId,
  ) async {
    return _customers.generateAdvice(customerId);
  }

  Future<ApiResponse<Map<String, dynamic>>> getSavedAdvice(
    String customerId,
  ) async {
    return _customers.getSavedAdvice(customerId);
  }

  Future<ApiResponse<Map<String, dynamic>>> getSummaryStats() async {
    return _customers.getSummaryStats();
  }

  Future<ApiResponse<Map<String, dynamic>>> deleteCustomer(
    String customerId,
  ) async {
    return _customers.deleteCustomer(customerId);
  }

  Future<ApiResponse<Map<String, dynamic>>> updateCustomer({
    required String customerId,
    String? name,
    String? phone,
    String? gender,
    int? age,
    String? location,
    List<String>? tags,
  }) async {
    return _customers.updateCustomer(
      customerId: customerId,
      name: name,
      phone: phone,
      gender: gender,
      age: age,
      location: location,
      tags: tags,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> updateRecord({
    required String recordId,
    String? content,
  }) async {
    return _records.updateRecord(recordId: recordId, content: content);
  }

  Future<ApiResponse<Map<String, dynamic>>> updateRecordWithImages({
    required String recordId,
    required String content,
    List<String> keepImageUrls = const [],
    List<String> imagePaths = const [],
    String? locationRaw,
  }) async {
    return _records.updateRecordWithImages(
      recordId: recordId,
      content: content,
      keepImageUrls: keepImageUrls,
      imagePaths: imagePaths,
      locationRaw: locationRaw,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> deleteRecord(
    String recordId,
  ) async {
    return _records.deleteRecord(recordId);
  }

  Future<ApiResponse<Map<String, dynamic>>> analyzeRecordImage({
    required String recordId,
    required String imageUrl,
    List<String> analyzeModes = const [],
  }) async {
    return _records.analyzeRecordImage(
      recordId: recordId,
      imageUrl: imageUrl,
      analyzeModes: analyzeModes,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> aiChat({
    required String question,
    List<Map<String, String>> recentMessages = const [],
  }) async {
    return _ai.aiChat(question: question, recentMessages: recentMessages);
  }

  Future<ApiResponse<Map<String, dynamic>>> aiChatWithImage({
    required String question,
    required String imagePath,
  }) async {
    return _ai.aiChatWithImage(question: question, imagePath: imagePath);
  }

  Future<ApiResponse<Map<String, dynamic>>> chatWithCustomer({
    required String customerId,
    required String question,
  }) async {
    return _ai.chatWithCustomer(customerId: customerId, question: question);
  }

  Future<ApiResponse<Map<String, dynamic>>> uploadAnalyticsEvents({
    required List<Map<String, dynamic>> events,
    String? deviceId,
    String? platform,
    String? appVersion,
  }) async {
    return _analytics.uploadAnalyticsEvents(
      events: events,
      deviceId: deviceId,
      platform: platform,
      appVersion: appVersion,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> getAnalyticsDashboard({
    String? startDate,
    String? endDate,
  }) async {
    return _analytics.getAnalyticsDashboard(
      startDate: startDate,
      endDate: endDate,
    );
  }

  String buildAnalyticsExportUrl({
    required String startDate,
    required String endDate,
    List<String>? eventNames,
  }) {
    return _analytics.buildAnalyticsExportUrl(
      startDate: startDate,
      endDate: endDate,
      eventNames: eventNames,
    );
  }
}

final apiService = ApiService();
