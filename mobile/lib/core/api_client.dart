import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiException implements Exception {
  final String message;
  final bool unauthorized;
  const ApiException(this.message, {this.unauthorized = false});
  @override
  String toString() => message;
}

class ApiClient {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  String? _token;
  ApiClient({Dio? dio, FlutterSecureStorage? storage})
      : _dio = dio ?? Dio(BaseOptions(
          baseUrl: const String.fromEnvironment('API_BASE_URL',
            defaultValue: 'http://10.0.2.2:3000/api/v1'),
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15))),
        _storage = storage ?? const FlutterSecureStorage();

  Future<void> restore() async {
    _token = await _storage.read(key: 'attendance_token');
  }
  Future<void> saveToken(String token) async {
    await _storage.write(key: 'attendance_token', value: token);
    _token = token;
  }
  Future<void> clearToken() async {
    _token = null;
    await _storage.delete(key: 'attendance_token');
  }
  bool get hasToken => _token != null;

  Future<Map<String, dynamic>> request(String path,
      {String method = 'GET', Map<String, dynamic>? data,
      Map<String, dynamic>? query}) async {
    try {
      final response = await _dio.request<dynamic>(path,
        data: data, queryParameters: query,
        options: Options(method: method, headers: {
          if (_token != null) 'Authorization': 'Bearer $_token',
        }));
      return response.data == null ? {} :
        Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (error) {
      final body = error.response?.data;
      final details = body is Map ? body['error'] : null;
      final message = details is Map ? details['message'] as String? : null;
      throw ApiException(message ?? 'Unable to connect. Check your connection and try again.',
        unauthorized: error.response?.statusCode == 401);
    }
  }
}
