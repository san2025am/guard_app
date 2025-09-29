// lib/services/api.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// لو عندك موديل EmployeeMe جاهز:
import '../models/employee.dart'; // يجب أن يحتوي EmployeeMe.fromJson(Map<String,dynamic>)

// --------------------------------------------------------
// ضبط عنوان الـ API الأساسي (بدون شرطة مائلة في النهاية)
// أمثلة صحيحة:
//  - http://31.97.158.157/api/v1
//  - https://your-domain.com/api
// --------------------------------------------------------
const String kBaseUrl = "http://31.97.158.157/api/v1";

// ========================================================
// مُساعِدات عامة
// ========================================================

String _joinUrl(String base, String path) {
  // يضمن عدم تكرار أو نقص الـ slash
  base = base.trim();
  if (base.endsWith('/')) base = base.substring(0, base.length - 1);
  if (!path.startsWith('/')) path = '/$path';
  return '$base$path';
}


Uri _u(String path) => Uri.parse(_joinUrl(kBaseUrl, path));

Map<String, String> _jsonHeaders() => const {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
};

dynamic _tryDecode(String text) {
  try { return jsonDecode(text); } catch (_) { return null; }
}

dynamic _decode(http.Response res) {
  final text = utf8.decode(res.bodyBytes);
  final obj  = _tryDecode(text);
  return obj ?? text; // قد يكون HTML/نص
}

String authHeader(String tokenOrHeader) {
  final t = tokenOrHeader.trim();
  if (t.startsWith('Bearer ') || t.startsWith('Token ')) return t;
  return 'Bearer $t'; // أضف البادئة إذا كان خام
}

double? asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

int? asInt(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

// ========================================================
// مفاتيح التخزين وتهيئة التوكن (موحّد + ترحيل قديم)
// ========================================================

const _kAccessKeyNew = 'access_token';
const _kAccessKeyOld = 'access';      // توافق خلفي
const _kRefreshKey  = 'refresh_token';
const _kEmpKey      = 'employee_json';

Future<void> _saveTokensRaw({required String access, String? refresh}) async {
  final sp = await SharedPreferences.getInstance();
  await sp.setString(_kAccessKeyNew, access);      // نخزّن access الخام فقط
  if (refresh != null && refresh.isNotEmpty) {
    await sp.setString(_kRefreshKey, refresh);
  }
  // إزالة المفتاح القديم إن وُجد
  await sp.remove(_kAccessKeyOld);
}

/// يرجّع access الخام (ويهاجر أي صيغة قديمة تلقائيًا)
Future<String?> _getAccessRaw() async {
  final sp = await SharedPreferences.getInstance();
  var acc = sp.getString(_kAccessKeyNew) ?? sp.getString(_kAccessKeyOld);
  if (acc == null || acc.isEmpty) return null;
  // قص "Bearer " لو كانت محفوظة بالخطأ
  if (acc.startsWith('Bearer ')) acc = acc.substring(7);
  await sp.setString(_kAccessKeyNew, acc);
  await sp.remove(_kAccessKeyOld);
  return acc;
}

// ========================================================
// نتائج موحّدة
// ========================================================

typedef ApiResult   = ({bool ok, String message, Map<String, dynamic>? data});
typedef LoginResult = ({bool ok, String message, EmployeeMe? employee, Map<String, dynamic>? raw});

// ========================================================
// خدمة الـ API
// ========================================================

class ApiService {
  static final http.Client _client = http.Client();
  static Future<String?> getAccessToken() => _getAccessRaw();

  /// (اختياري) واجهة عامة للوصول السريع لبيانات الموظف من الكاش
  static Future<EmployeeMe?> getCachedEmployee() => cachedEmployee();

  // ---------------------------------------------
  // تسجيل الدخول — يحفظ التوكن + يحاول حفظ employee إن وُجد
  // POST /auth/guard/login/
  // body: {username, password}
  // ---------------------------------------------
  static Future<Map<String, dynamic>> guardLogin(
      String username,
      String password,
      ) async {
    try {
      final res = await _client.post(
        _u('/auth/guard/login/'), // عدّل المسار إن لزم
        headers: _jsonHeaders(),
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(const Duration(seconds: 20));

      final body = _decode(res);

      if (res.statusCode == 200 && body is Map<String, dynamic>) {
        final prefs = await SharedPreferences.getInstance();

        // Tokens (موحّد)
        final access  = (body['access'] ?? body['token'])?.toString() ?? '';
        final refresh = (body['refresh'] ?? '').toString();
        if (access.isEmpty) {
          return {'ok': false, 'message': 'لم يستلم التطبيق access token.'};
        }
        await _saveTokensRaw(access: access, refresh: refresh);

        // User info (اختياري)
        final user = (body['user'] is Map) ? body['user'] as Map : <String, dynamic>{};
        await prefs.setString('username', (user['username'] ?? '').toString());
        final roleVal  = user['role'];
        final roleText = (roleVal is Map)
            ? (roleVal['name'] ?? roleVal['title'] ?? roleVal.toString()).toString()
            : (roleVal?.toString() ?? '');
        await prefs.setString('role', roleText);

        // employee من نفس الرد إن توفر
        Map<String, dynamic>? empJson;
        if (body.containsKey('employee') && body['employee'] is Map) {
          empJson = Map<String, dynamic>.from(body['employee'] as Map);
          await prefs.setString(_kEmpKey, jsonEncode(empJson));
        }

        EmployeeMe? empModel;
        if (empJson != null) {
          try { empModel = EmployeeMe.fromJson(empJson); } catch (_) { empModel = null; }
        }

        return {'ok': true, 'employee': empModel};
      }

      // خطأ JSON مفهوم
      if (body is Map<String, dynamic>) {
        return {'ok': false, 'message': (body['detail'] ?? body['message'] ?? 'Login failed').toString()};
      }

      // محتوى غير JSON
      return {'ok': false, 'message': "الخادم أعاد محتوى غير JSON (status ${res.statusCode})."};
    } catch (e) {
      return {'ok': false, 'message': 'Network error: $e'};
    }
  }

  // ---------------------------------------------
  // جلب ملف الموظف وحفظه في الكاش
  // GET /auth/guard/me/  (عدّل المسار إن لزم)
  // قد يرجع {employee:{...}} أو مباشرة {...}
  // ---------------------------------------------
  static Future<EmployeeMe?> fetchEmployeeAndCache() async {
    final prefs = await SharedPreferences.getInstance();
    final accessRaw = await _getAccessRaw();
    if (accessRaw == null || accessRaw.isEmpty) return null;

    try {
      final res = await _client.get(
        _u('/auth/guard/me/'),
        headers: {
          ..._jsonHeaders(),
          'Authorization': authHeader(accessRaw),
        },
      ).timeout(const Duration(seconds: 20));

      final body = _decode(res);
      if (res.statusCode == 200) {
        final emp = (body is Map && body.containsKey('employee')) ? body['employee'] : body;

        if (emp is Map<String, dynamic>) {
          await prefs.setString(_kEmpKey, jsonEncode(emp));
          try { return EmployeeMe.fromJson(emp); } catch (_) { return null; }
        }
      } else {
        debugPrint('fetchEmployeeAndCache ${res.statusCode} -> $body');
      }
    } catch (e) {
      debugPrint('fetchEmployeeAndCache error: $e');
    }
    return null;
  }

  // قراءة الموظف من الكاش
  static Future<EmployeeMe?> cachedEmployee() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kEmpKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) return EmployeeMe.fromJson(map);
    } catch (_) {}
    return null;
  }

  /// يضمن وجود employee في الكاش (إن لم يوجد سيجلبه من السيرفر)
  static Future<EmployeeMe?> ensureEmployeeCached() async {
    final cached = await cachedEmployee();
    if (cached != null) return cached;
    return await fetchEmployeeAndCache();
  }

  // تحديث الكاش (إن كان مسارك يدعم POST أو غيّره لـ GET)
  static Future<EmployeeMe?> refreshEmployeeCache() async {
    final prefs = await SharedPreferences.getInstance();
    final accessRaw = await _getAccessRaw();
    if (accessRaw == null || accessRaw.isEmpty) return null;

    final res = await _client.post(
      _u('/auth/guard/me/'),
      headers: {
        ..._jsonHeaders(),
        'Authorization': authHeader(accessRaw),
      },
      body: '{}',
    ).timeout(const Duration(seconds: 20));

    final body = _decode(res);
    if (res.statusCode == 200) {
      final emp = (body is Map && body.containsKey('employee')) ? body['employee'] : body;
      if (emp is Map<String, dynamic>) {
        await prefs.setString(_kEmpKey, jsonEncode(emp));
        try { return EmployeeMe.fromJson(emp); } catch (_) { return null; }
      }
    }
    return null;
  }

  // تسجيل خروج — حذف كل البينات
  static Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kAccessKeyNew);
    await p.remove(_kAccessKeyOld);
    await p.remove(_kRefreshKey);
    await p.remove(_kEmpKey);
    await p.remove('username');
    await p.remove('role');
  }

  // ---------------------------------------------
  // نسيت كلمة المرور — باسم المستخدم
  // POST /auth/password/forgot/username/
  // body: {username}
  // ---------------------------------------------
  static Future<Map<String, dynamic>> forgotByUsername(String username) async {
    try {
      final res = await _client.post(
        _u('/auth/password/forgot/username/'),
        headers: _jsonHeaders(),
        body: jsonEncode({'username': username}),
      ).timeout(const Duration(seconds: 20));

      final body = _decode(res);
      if (res.statusCode == 200 && body is Map<String, dynamic>) {
        return {'ok': true, 'session_id': body['session_id'], 'detail': body['detail']};
      }
      return {'ok': false, 'message': (body is Map && body['detail'] != null) ? body['detail'].toString() : 'تعذر إرسال الكود'};
    } catch (e) {
      return {'ok': false, 'message': 'Network error: $e'};
    }
  }

  // ---------------------------------------------
  // إعادة تعيين كلمة المرور (session_id + code + new_password)
  // POST /auth/password/reset/username/
  // ---------------------------------------------
  static Future<Map<String, dynamic>> resetBySession({
    required int sessionId,
    required String code,
    required String newPassword,
  }) async {
    try {
      final res = await _client.post(
        _u('/auth/password/reset/username/'),
        headers: _jsonHeaders(),
        body: jsonEncode({
          'session_id': sessionId,
          'code': code,
          'new_password': newPassword,
        }),
      ).timeout(const Duration(seconds: 20));

      final body = _decode(res);
      if (res.statusCode == 200 && body is Map<String, dynamic>) {
        return {'ok': true, 'detail': body['detail']};
      }
      return {'ok': false, 'message': (body is Map && body['detail'] != null) ? body['detail'].toString() : 'فشل التحقق من الرمز'};
    } catch (e) {
      return {'ok': false, 'message': 'Network error: $e'};
    }
  }
}

// ========================================================
// الموقع والحضور/الانصراف
// ========================================================

/// طلب/تأكيد صلاحيات الموقع
Future<void> requestLocationPermissionsOrThrow() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception("خدمة الموقع غير مفعّلة. فعّل الـ GPS ثم حاول مرة أخرى.");
  }
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
    throw Exception("تم رفض إذن الوصول للموقع. الرجاء منح الإذن من الإعدادات.");
  }
}

/// يلتقط أفضل Fix خلال نافذة زمنية (افتراضي 8 ثوان)
Future<Position> getBestFix({
  Duration window = const Duration(seconds: 8),
  LocationAccuracy accuracy = LocationAccuracy.best,
}) async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception("خدمة الموقع غير مفعّلة. فعّل GPS وحاول مجددًا.");
  }
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
    throw Exception("تم رفض صلاحية الوصول للموقع. الرجاء منح الإذن.");
  }

  final end = DateTime.now().add(window);
  Position? best;
  while (DateTime.now().isBefore(end)) {
    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: accuracy);
    if (best == null || pos.accuracy < best.accuracy) best = pos;
    if (best.accuracy <= 15) break; // دقة ممتازة
    await Future.delayed(const Duration(milliseconds: 800));
  }
  if (best == null) throw Exception("تعذّر الحصول على إحداثيات.");
  return best;
}

/// إرسال حضور/انصراف (يلتقط الموقع داخليًا)
Future<ApiResult> sendAttendance({
  required String baseUrl,      // مثال: http://31.97.158.157/api/v1
  required String token,        // التوكن الخام أو "Bearer <...>" — دالة authHeader تتكفل
  required dynamic locationId,  // int عادةً (أو UUID لو الـ API يسمح)
  required String action,       // "check_in" أو "check_out"
  Duration window = const Duration(seconds: 8),
}) async {
  try {
    final pos = await getBestFix(window: window);
    return await sendAttendanceWithPosition(
      baseUrl: baseUrl,
      token: token,
      locationId: locationId,
      action: action,
      pos: pos,
    );
  } catch (e) {
    return (ok: false, message: e.toString(), data: null);
  }
}

/// إرسال حضور/انصراف بقراءة Position جاهزة

Future<ApiResult> sendAttendanceWithPosition({
  required String baseUrl,
  required String token,        // خام أو مع "Bearer" — سيتم ضبطه
  required dynamic locationId,  // int أو UUID حسب السيرفر
  required String action,       // "check_in" أو "check_out"
  required Position pos,
}) async {
  try {
    final uri = Uri.parse(_joinUrl(baseUrl, 'attendance/check/')); // يبني URL صحيحًا
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': authHeader(token),
      },
      body: jsonEncode({
        'location_id': (locationId is String) ? locationId : locationId?.toString(),
        'action': action,
        'lat': pos.latitude,
        'lng': pos.longitude,
        'accuracy': pos.accuracy,
      }),
    );

    final text = utf8.decode(res.bodyBytes);
    Map<String, dynamic>? data;
    try { data = jsonDecode(text) as Map<String, dynamic>; } catch (_) {}

    final ok = res.statusCode >= 200 && res.statusCode < 300;

    String msg;
    if (ok) {
      msg = data?['detail']?.toString() ?? 'تم';
    } else {
      // استخرج رسالة مفيدة
      if (data != null) {
        if (data['detail'] is String) msg = data['detail'];
        else if (data['non_field_errors'] is List && (data['non_field_errors'] as List).isNotEmpty) {
          msg = (data['non_field_errors'] as List).join('، ');
        } else if (data['errors'] is List && (data['errors'] as List).isNotEmpty) {
          msg = (data['errors'] as List).join('، ');
        } else {
          final snippet = text.replaceAll(RegExp(r'\s+'), ' ');
          msg = 'HTTP ${res.statusCode}: ' + (snippet.length > 180 ? snippet.substring(0, 180) + '…' : snippet);
        }
      } else {
        final snippet = text.replaceAll(RegExp(r'\s+'), ' ');
        msg = 'HTTP ${res.statusCode}: ' + (snippet.length > 180 ? snippet.substring(0, 180) + '…' : snippet);
      }
    }
    return (ok: ok, message: msg, data: data);
  } catch (e) {
    return (ok: false, message: e.toString(), data: null);
  }
}


/// Endpoint مساعد: يحاول تحديد أقرب موقع (اختياري)
Future<ApiResult> resolveMyLocation({
  required String baseUrl,
  required String token,   // خام أو مع "Bearer"
  required double lat,
  required double lng,
  required double accuracy,
}) async {
  try {
    final uri = Uri.parse(_joinUrl(baseUrl, 'attendance/resolve-location/'));
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': authHeader(token),
      },
      body: jsonEncode({'lat': lat, 'lng': lng, 'accuracy': accuracy}),
    );

    final text = utf8.decode(res.bodyBytes);
    Map<String, dynamic>? data;
    try { data = jsonDecode(text) as Map<String, dynamic>; } catch (_) {}

    final ok  = res.statusCode >= 200 && res.statusCode < 300;
    final msg = data?['detail']?.toString() ?? (ok ? 'تم' : 'فشل');
    return (ok: ok, message: msg, data: data);
  } catch (e) {
    return (ok: false, message: e.toString(), data: null);
  }
}
