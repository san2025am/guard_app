import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// عدّل هذا العنوان
const String kBaseUrl = "http://31.97.158.157/api/v1";
// مثال إنتاج: "http://31.97.158.157/api/v1"

class ApiService {
  static Uri _u(String path) => Uri.parse("$kBaseUrl$path");

  static Future<Map<String, dynamic>> guardLogin(String username, String password) async {
    final res = await http.post(
      _u("/auth/guard/login/"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    final body = _decode(res);
    if (res.statusCode == 200) {
      final prefs = await SharedPreferences.getInstance();
      if (body['access'] != null) await prefs.setString('access', body['access']);
      if (body['refresh'] != null) await prefs.setString('refresh', body['refresh']);
      if (body['user'] != null) {
        await prefs.setString('username', body['user']['username'] ?? '');
        await prefs.setString('role', body['user']['role']?.toString() ?? '');
      }
      return {'ok': true, 'data': body};
    }
    return {'ok': false, 'message': body['detail']?.toString() ?? 'فشل تسجيل الدخول'};
  }

  /// نسيت كلمة المرور (يرسل كود إلى البريد ويرجع session_id)
  static Future<Map<String, dynamic>> forgotByUsername(String username) async {
    final res = await http.post(
      _u("/auth/password/forgot/username/"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username}),
    );
    final body = _decode(res);
    if (res.statusCode == 200) {
      return {'ok': true, 'session_id': body['session_id'], 'detail': body['detail']};
    }
    return {'ok': false, 'message': body['detail']?.toString() ?? 'تعذر إرسال الكود'};
  }

  /// إعادة التعيين باستخدام session_id + code + new_password
  static Future<Map<String, dynamic>> resetBySession({
    required int sessionId,
    required String code,
    required String newPassword,
  }) async {
    final res = await http.post(
      _u("/auth/password/reset/username/"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'session_id': sessionId, 'code': code, 'new_password': newPassword}),
    );
    final body = _decode(res);
    if (res.statusCode == 200) return {'ok': true, 'detail': body['detail']};
    return {'ok': false, 'message': body['detail']?.toString() ?? 'فشل التحقق من الرمز'};
  }

  static Map<String, dynamic> _decode(http.Response r) {
    try { return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>; }
    catch (_) { return {'detail': r.body}; }
  }
}
