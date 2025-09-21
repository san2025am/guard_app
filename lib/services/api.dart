// lib/services/api.dart
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/employee.dart';

/// عدّل هذا العنوان ليناسب بيئتك (IP أو دومين السيرفر)
const String kBaseUrl = "http://31.97.158.157/api/v1";

class ApiService {
  static final http.Client _client = http.Client();

  static Uri _u(String path) => Uri.parse("$kBaseUrl$path");

  static Map<String, String> _jsonHeaders({String? token}) => {
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  // ----------------------------------------------------------------
  // تسجيل دخول الحارس → يخزن التوكنات وبيانات المستخدم/الموظف
  // ----------------------------------------------------------------

  static Future<Map<String, dynamic>> guardLogin(
      String username,
      String password,
      ) async {
    try {
      final res = await _client
          .post(
        _u('/auth/guard/login/'),
        headers: _jsonHeaders(),
        body: jsonEncode({'username': username, 'password': password}),
      )
          .timeout(const Duration(seconds: 20));

      // _decode يجب أن يُرجع Map<String, dynamic> أو يرمي استثناء على JSON غير صالح.
      final Map<String, dynamic> body = _decode(res) as Map<String, dynamic>;

      if (res.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();

        // Tokens
        await prefs.setString('access', (body['access'] ?? '').toString());
        await prefs.setString('refresh', (body['refresh'] ?? '').toString());

        // User info (قد تكون role = int أو Map أو String)
        final user = (body['user'] is Map) ? body['user'] as Map : <String, dynamic>{};
        await prefs.setString('username', (user['username'] ?? '').toString());

        // طبّع role لأي شكل:
        String roleText = '';
        final roleVal = user['role'];
        if (roleVal is Map) {
          roleText = (roleVal['name'] ?? roleVal['title'] ?? roleVal.toString()).toString();
        } else if (roleVal != null) {
          roleText = roleVal.toString();
        }
        await prefs.setString('role', roleText);

        // employee قد تكون Map أو null أو حتى شيء آخر — تحقّق قبل التحويل
        Map<String, dynamic>? empJson;
        if (body.containsKey('employee') && body['employee'] is Map) {
          empJson = Map<String, dynamic>.from(body['employee'] as Map);
          await prefs.setString('employee_json', jsonEncode(empJson));
        }

        // حاول بناء الموديل بأمان
        EmployeeMe? empModel;
        if (empJson != null) {
          try {
            empModel = EmployeeMe.fromJson(empJson);
          } catch (e) {
            // لو عندك حقول int في الموديل وجتك كنص من السيرفر، هذا يمنع الكراش
            // ويمكنك لاحقاً تكييف fromJson ليحوّل الأنواع safely.
            empModel = null;
          }
        }

        return {'ok': true, 'employee': empModel};
      } else {
        return {
          'ok': false,
          'message': (body['detail'] ?? body['message'] ?? 'Login failed').toString(),
        };
      }
    } catch (e) {
      return {'ok': false, 'message': 'Network error: $e'};
    }
  }

  // ----------------------------------------------------------------
  // قراءة ملف الموظف من الكاش
  // ----------------------------------------------------------------
  // GET /auth/guard/me/  (اضبط المسار حسب باك-إندك: guard/me أو employee/me)
  static Future<EmployeeMe?> fetchEmployeeAndCache() async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString('access');
    if (access == null || access.isEmpty) return null;

    try {
      final res = await _client.get(
        _u('/auth/guard/me/'), // <-- عدّل المسار الصحيح عندك
        headers: {
          ..._jsonHeaders(),
          'Authorization': 'Bearer $access',
        },
      ).timeout(const Duration(seconds: 20));

      final body = _decode(res);
      if (res.statusCode == 200) {
        // توقّع أن الباك يرجّع { employee: {...} } أو مباشرة {...}
        final emp = (body is Map && body.containsKey('employee'))
            ? body['employee']
            : body;

        if (emp is Map<String, dynamic>) {
          await prefs.setString('employee_json', jsonEncode(emp));
          try {
            return EmployeeMe.fromJson(emp);
          } catch (_) {
            // تحوّط لأنواع غير متناسقة
            return null;
          }
        }
      } else {
        // اطبع الخطأ للتشخيص
        debugPrint('fetchEmployeeAndCache ${res.statusCode} -> $body');
      }
    } catch (e) {
      debugPrint('fetchEmployeeAndCache error: $e');
    }
    return null;
  }

  static Future<EmployeeMe?> cachedEmployee() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('employee_json');
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return EmployeeMe.fromJson(map);
      }
    } catch (_) {}
    return null;
  }

  /// مساعد: يضمن وجود الكاش (إن لم يوجد، يجلب من السيرفر)
  static Future<EmployeeMe?> ensureEmployeeCached() async {
    final cached = await cachedEmployee();
    if (cached != null) return cached;
    return await fetchEmployeeAndCache();
  }

  // services/api.dart
  static Future<EmployeeMe?> refreshEmployeeCache() async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString('access');
    if (access == null || access.isEmpty) return null;

    final res = await _client.post(
      _u('/auth/guard/me/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $access',
      },
      body: '{}',
    ).timeout(const Duration(seconds: 20));

    final body = _decode(res);
    if (res.statusCode == 200 && body is Map<String, dynamic>) {
      await prefs.setString('employee_json', jsonEncode(body));
      return EmployeeMe.fromJson(body);
    }
    return null;
  }

  // ----------------------------------------------------------------
  // تسجيل خروج (مسح كل البيانات المحفوظة)
  // ----------------------------------------------------------------
  static Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('access');
    await p.remove('refresh');
    await p.remove('username');
    await p.remove('role');
    await p.remove('employee_json');
  }

  // ----------------------------------------------------------------
  // نسيت كلمة المرور (باسم المستخدم)
  // ----------------------------------------------------------------
  static Future<Map<String, dynamic>> forgotByUsername(
      String username) async {
    try {
      final res = await _client
          .post(
        _u("/auth/password/forgot/username/"),
        headers: _jsonHeaders(),
        body: jsonEncode({'username': username}),
      )
          .timeout(const Duration(seconds: 20));

      final body = _decode(res);
      if (res.statusCode == 200) {
        return {
          'ok': true,
          'session_id': body['session_id'],
          'detail': body['detail'],
        };
      }
      return {
        'ok': false,
        'message': body['detail']?.toString() ?? 'تعذر إرسال الكود',
      };
    } catch (e) {
      return {'ok': false, 'message': 'Network error: $e'};
    }
  }

  // ----------------------------------------------------------------
  // إعادة تعيين كلمة المرور (session_id + code + new_password)
  // ----------------------------------------------------------------
  static Future<Map<String, dynamic>> resetBySession({
    required int sessionId,
    required String code,
    required String newPassword,
  }) async {
    try {
      final res = await _client
          .post(
        _u("/auth/password/reset/username/"),
        headers: _jsonHeaders(),
        body: jsonEncode({
          'session_id': sessionId,
          'code': code,
          'new_password': newPassword,
        }),
      )
          .timeout(const Duration(seconds: 20));

      final body = _decode(res);
      if (res.statusCode == 200) {
        return {'ok': true, 'detail': body['detail']};
      }
      return {
        'ok': false,
        'message': body['detail']?.toString() ?? 'فشل التحقق من الرمز',
      };
    } catch (e) {
      return {'ok': false, 'message': 'Network error: $e'};
    }
  }

  // ----------------------------------------------------------------
  // Decoder موحّد يتعامل مع UTF-8
  // ----------------------------------------------------------------
  static Map<String, dynamic> _decode(http.Response r) {
    try {
      final txt = utf8.decode(r.bodyBytes);
      final j = jsonDecode(txt);
      return j is Map<String, dynamic> ? j : {'detail': j.toString()};
    } catch (_) {
      return {'detail': r.body};
    }
  }
}
