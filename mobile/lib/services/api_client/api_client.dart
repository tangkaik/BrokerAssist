import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../config/config.dart';
import '../../models/models.dart';
import '../api_config.dart';
import '../auth_session.dart';
import '../api_error_handler.dart';

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> get jsonHeaders => {
    'Content-Type': 'application/json',
    if (AuthSession.token.isNotEmpty)
      'Authorization': 'Bearer ${AuthSession.token}',
  };

  String buildUrl(String path) {
    final baseUrl = ApiConfig.baseUrl;
    if (path.startsWith('/')) {
      return '$baseUrl$path';
    }
    return '$baseUrl/$path';
  }

  ApiResponse<T> _error<T>([String code = 'UNKNOWN', String message = '未知错误']) {
    final err = ApiResponse<T>(
      success: false,
      error: ApiError(code: code, message: message),
    );
    _onError(message, code: code);
    return err;
  }

  void _onError(String message, {String? code}) {
    ApiErrorHandler.handleError(message, code: code);
  }

  Future<ApiResponse<T>> get<T>(
    String path, {
    required T Function(dynamic) fromJsonT,
    Map<String, String>? queryParams,
  }) async {
    try {
      var url = Uri.parse(buildUrl(path));
      if (queryParams != null && queryParams.isNotEmpty) {
        url = url.replace(queryParameters: queryParams);
      }

      final response = await _client
          .get(url, headers: jsonHeaders)
          .timeout(Duration(seconds: AppConfig.receiveTimeout));

      return _handleResponse(response, fromJsonT);
    } on SocketException catch (_) {
      return _error('NETWORK_ERROR', '网络连接失败');
    } catch (e) {
      return _error('UNKNOWN_ERROR', '请求失败');
    }
  }

  Future<ApiResponse<DownloadedFile>> downloadFile(String path) async {
    try {
      final url = Uri.parse(buildUrl(path));
      final response = await _client
          .get(url, headers: {
            if (AuthSession.token.isNotEmpty)
              'Authorization': 'Bearer ${AuthSession.token}',
          })
          .timeout(Duration(seconds: AppConfig.receiveTimeout));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          success: true,
          data: DownloadedFile(
            bytes: response.bodyBytes,
            filename: _filenameFromContentDisposition(
              response.headers['content-disposition'],
            ),
            contentType: response.headers['content-type'],
          ),
        );
      }

      if (response.statusCode >= 500) {
        return _error('SERVER_ERROR', '服务暂时不可用，请稍后再试');
      }
      return _error('HTTP_${response.statusCode}', '下载失败');
    } on SocketException catch (_) {
      return _error('NETWORK_ERROR', '网络连接失败');
    } catch (_) {
      return _error('DOWNLOAD_ERROR', '下载失败');
    }
  }

  Future<ApiResponse<T>> post<T>(
    String path, {
    required T Function(dynamic) fromJsonT,
    Map<String, dynamic>? body,
  }) async {
    try {
      final url = Uri.parse(buildUrl(path));
      final response = await _client
          .post(
            url,
            headers: jsonHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(Duration(seconds: AppConfig.receiveTimeout));

      return _handleResponse(response, fromJsonT);
    } on SocketException catch (_) {
      return _error('NETWORK_ERROR', '网络连接失败');
    } catch (e) {
      return _error('UNKNOWN_ERROR', '请求失败');
    }
  }

  Future<ApiResponse<T>> delete<T>(
    String path, {
    required T Function(dynamic) fromJsonT,
  }) async {
    try {
      final url = Uri.parse(buildUrl(path));
      final response = await _client
          .delete(url, headers: jsonHeaders)
          .timeout(Duration(seconds: AppConfig.receiveTimeout));

      return _handleResponse(response, fromJsonT);
    } on SocketException catch (_) {
      return _error('NETWORK_ERROR', '网络连接失败');
    } catch (e) {
      return _error('UNKNOWN_ERROR', '请求失败');
    }
  }

  Future<ApiResponse<T>> put<T>(
    String path, {
    required T Function(dynamic) fromJsonT,
    Map<String, dynamic>? body,
  }) async {
    try {
      final url = Uri.parse(buildUrl(path));
      final response = await _client
          .put(
            url,
            headers: jsonHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(Duration(seconds: AppConfig.receiveTimeout));

      return _handleResponse(response, fromJsonT);
    } on SocketException catch (_) {
      return _error('NETWORK_ERROR', '网络连接失败');
    } catch (e) {
      return _error('UNKNOWN_ERROR', '请求失败');
    }
  }

  Future<ApiResponse<T>> patch<T>(
    String path, {
    required T Function(dynamic) fromJsonT,
    Map<String, dynamic>? body,
  }) async {
    try {
      final url = Uri.parse(buildUrl(path));
      final response = await _client
          .patch(
            url,
            headers: jsonHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(Duration(seconds: AppConfig.receiveTimeout));

      return _handleResponse(response, fromJsonT);
    } on SocketException catch (_) {
      return _error('NETWORK_ERROR', '网络连接失败');
    } catch (e) {
      return _error('UNKNOWN_ERROR', '请求失败');
    }
  }

  Future<ApiResponse<T>> postMultipartFile<T>(
    String path, {
    required String fieldName,
    required String filePath,
    required T Function(dynamic) fromJsonT,
  }) async {
    try {
      final url = Uri.parse(buildUrl(path));
      final request = http.MultipartRequest('POST', url);
      if (AuthSession.token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer ${AuthSession.token}';
      }
      request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));

      final streamedResponse = await request.send().timeout(
        Duration(seconds: AppConfig.receiveTimeout),
      );
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response, fromJsonT);
    } on SocketException catch (_) {
      return _error('NETWORK_ERROR', '网络连接失败');
    } catch (e) {
      return _error('UPLOAD_ERROR', '上传失败');
    }
  }

  Future<ApiResponse<T>> postMultipart<T>(
    String path, {
    required T Function(dynamic) fromJsonT,
    Map<String, String>? fields,
    Map<String, List<String>>? listFields,
    List<String>? filePaths,
    String fileFieldName = 'files',
  }) async {
    return _sendMultipart(
      'POST',
      path,
      fromJsonT: fromJsonT,
      fields: fields,
      listFields: listFields,
      filePaths: filePaths,
      fileFieldName: fileFieldName,
    );
  }

  Future<ApiResponse<T>> putMultipart<T>(
    String path, {
    required T Function(dynamic) fromJsonT,
    Map<String, String>? fields,
    Map<String, List<String>>? listFields,
    List<String>? filePaths,
    String fileFieldName = 'files',
  }) async {
    return _sendMultipart(
      'PUT',
      path,
      fromJsonT: fromJsonT,
      fields: fields,
      listFields: listFields,
      filePaths: filePaths,
      fileFieldName: fileFieldName,
    );
  }

  Future<ApiResponse<T>> _sendMultipart<T>(
    String method,
    String path, {
    required T Function(dynamic) fromJsonT,
    Map<String, String>? fields,
    Map<String, List<String>>? listFields,
    List<String>? filePaths,
    required String fileFieldName,
  }) async {
    try {
      final url = Uri.parse(buildUrl(path));
      final request = http.MultipartRequest(method, url);
      if (AuthSession.token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer ${AuthSession.token}';
      }
      if (fields != null) {
        request.fields.addAll(fields);
      }
      if (listFields != null) {
        for (final entry in listFields.entries) {
          for (final value in entry.value) {
            request.fields[entry.key] = value;
          }
        }
      }
      if (filePaths != null) {
        for (final filePath in filePaths) {
          request.files.add(
            await http.MultipartFile.fromPath(fileFieldName, filePath),
          );
        }
      }

      final streamedResponse = await request.send().timeout(
        Duration(seconds: AppConfig.receiveTimeout),
      );
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response, fromJsonT);
    } on SocketException catch (_) {
      return _error('NETWORK_ERROR', '网络连接失败');
    } catch (_) {
      return _error('UPLOAD_ERROR', '上传失败');
    }
  }

  ApiResponse<T> _handleResponse<T>(
    http.Response httpResponse,
    T Function(dynamic) fromJsonT,
  ) {
    if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
      try {
        final json = jsonDecode(httpResponse.body) as Map<String, dynamic>;
        return ApiResponse.fromJson(json, fromJsonT);
      } catch (e) {
        return _error('PARSE_ERROR', '响应解析失败');
      }
    }

    var code = 'HTTP_${httpResponse.statusCode}';
    var message = 'HTTP 错误: ${httpResponse.statusCode}';
    try {
      final json = jsonDecode(httpResponse.body) as Map<String, dynamic>;
      final errorJson = json['error'];
      if (errorJson is Map<String, dynamic>) {
        code = errorJson['code'] as String? ?? code;
        message = errorJson['message'] as String? ?? message;
      }
    } catch (_) {}

    if (httpResponse.statusCode >= 500) {
      code = 'SERVER_ERROR';
      message = '服务暂时不可用，请稍后再试';
    }

    return _error(code, message);
  }

  String _filenameFromContentDisposition(String? contentDisposition) {
    if (contentDisposition == null || contentDisposition.isEmpty) {
      return 'customers.xlsx';
    }
    final utf8Match = RegExp(
      "filename\\*=UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(contentDisposition);
    if (utf8Match != null) {
      return Uri.decodeComponent(utf8Match.group(1)!);
    }
    final asciiMatch = RegExp(
      'filename="?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(contentDisposition);
    return asciiMatch?.group(1) ?? 'customers.xlsx';
  }
}

class DownloadedFile {
  final Uint8List bytes;
  final String filename;
  final String? contentType;

  const DownloadedFile({
    required this.bytes,
    required this.filename,
    this.contentType,
  });
}
