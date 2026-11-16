import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../features/auth/user.dart';
import '../features/attendance/attendance_record.dart';

class AppController extends ChangeNotifier {
  final ApiClient api;
  AppUser? user;
  bool initializing = true;
  String? startupError;
  AppController(this.api);

  Future<void> initialize() async {
    startupError = null;
    initializing = true;
    notifyListeners();
    try {
      await api.restore();
      if (api.hasToken) {
        final result = await call('/auth/me');
        user = AppUser.fromJson(Map<String, dynamic>.from(result['data'] as Map));
      }
    } catch (error) {
      if (error is! ApiException || !error.unauthorized) {
        startupError = 'Unable to restore your session. Check your connection and retry.';
      }
    } finally { initializing = false; notifyListeners(); }
  }

  Future<Map<String, dynamic>> call(String path, {String method = 'GET',
    Map<String, dynamic>? data, Map<String, dynamic>? query}) async {
    try { return await api.request(path, method: method, data: data, query: query); }
    on ApiException catch (error) {
      if (error.unauthorized && api.hasToken) {
        user = null;
        await api.clearToken();
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    final result = await call('/auth/login', method: 'POST',
      data: {'email': email.trim(), 'password': password});
    final data = Map<String, dynamic>.from(result['data'] as Map);
    await api.saveToken(data['token'] as String);
    user = AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
    notifyListeners();
  }

  Future<void> logout() async {
    await call('/auth/logout', method: 'POST');
    await api.clearToken();
    user = null;
    notifyListeners();
  }

  Future<void> changePassword(String current, String next) async {
    await call('/auth/password', method: 'POST',
      data: {'currentPassword': current, 'newPassword': next});
    await api.clearToken();
    user = null;
    notifyListeners();
  }

  Future<AttendanceRecord?> today() async {
    final result = await call('/attendance/today');
    return result['data'] == null ? null :
      AttendanceRecord.fromJson(Map<String, dynamic>.from(result['data'] as Map));
  }
  Future<void> markAttendance(bool checkout) async {
    await call('/attendance/${checkout ? 'check-out' : 'check-in'}', method: 'POST');
  }
}
