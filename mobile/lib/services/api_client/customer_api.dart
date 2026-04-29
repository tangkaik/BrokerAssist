import '../../models/models.dart';
import 'api_client.dart';

class CustomerApi {
  final ApiClient _client;

  CustomerApi(this._client);

  Future<ApiResponse<PaginatedData<Customer>>> getCustomers({
    int page = 1,
    int pageSize = 20,
  }) async {
    return _client.get(
      '/customers',
      fromJsonT: (data) => PaginatedData.fromJson(
        data as Map<String, dynamic>,
        (item) => Customer.fromJson(item as Map<String, dynamic>),
      ),
      queryParams: {'page': page.toString(), 'page_size': pageSize.toString()},
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> createCustomer({
    required String name,
    String? gender,
    int? age,
    List<String>? tags,
  }) async {
    final body = <String, dynamic>{'name': name};
    if (gender != null) {
      body['gender'] = gender;
    }
    if (age != null) {
      body['age'] = age;
    }
    if (tags != null && tags.isNotEmpty) {
      body['tags'] = tags;
    }

    return _client.post(
      '/customers',
      fromJsonT: (data) => data as Map<String, dynamic>,
      body: body,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> getCustomerDetail(
    String customerId,
  ) async {
    return _client.get(
      '/customers/$customerId',
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }

  Future<ApiResponse<PaginatedData<Customer>>> searchCustomers({
    String? keyword,
    int page = 1,
    int pageSize = 20,
    String sortBy = 'updated_at',
    String sortOrder = 'desc',
  }) async {
    final queryParams = {
      'page': page.toString(),
      'page_size': pageSize.toString(),
      'sort_by': sortBy,
      'sort_order': sortOrder,
    };
    if (keyword != null && keyword.isNotEmpty) {
      queryParams['keyword'] = keyword;
    }

    return _client.get(
      '/customers',
      fromJsonT: (data) => PaginatedData.fromJson(
        data as Map<String, dynamic>,
        (item) => Customer.fromJson(item as Map<String, dynamic>),
      ),
      queryParams: queryParams,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> generateSummary(
    String customerId,
  ) async {
    return _client.post(
      '/customers/$customerId/summary/generate',
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> generateAdvice(
    String customerId,
  ) async {
    return _client.post(
      '/customers/$customerId/advice/generate',
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> deleteCustomer(
    String customerId,
  ) async {
    return _client.delete(
      '/customers/$customerId',
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> updateCustomer({
    required String customerId,
    String? name,
    String? phone,
    String? gender,
    String? location,
    List<String>? tags,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) {
      body['name'] = name;
    }
    if (phone != null) {
      body['phone'] = phone;
    }
    if (gender != null) {
      body['gender'] = gender;
    }
    if (location != null) {
      body['location'] = location;
    }
    if (tags != null) {
      body['tags'] = tags;
    }

    return _client.put(
      '/customers/$customerId',
      fromJsonT: (data) => data as Map<String, dynamic>,
      body: body,
    );
  }
}
