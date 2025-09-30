// lib/services/api.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
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

// مسارات جاهزة (لمنع الأخطاء المطبعية):
const String _pLogin           = '/auth/guard/login/';
const String _pMeGet           = '/auth/guard/me/';
const String _pMePost          = '/auth/guard/me/'; // إن كانت POST عندك
const String _pForgotUsername  = '/auth/password/forgot/username/';
const String _pResetBySession  = '/auth/password/reset/username/';
const String _pResolveLocation = '/attendance/resolve-location/';
const String _pAttendanceCheck = '/attendance/check/';
const String _pGuardReports    = '/guards/reports/';
const String _pGuardRequests   = '/guards/requests/';

// ========================================================
// مُساعِدات عامة
// ========================================================

String _joinUrl(String base, String path) {
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

String _messageFromBody(dynamic body, String fallback) {
  if (body is Map) {
    final map = body as Map;
    for (final key in ['detail', 'message', 'error']) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    // إذا كان هناك قائمة أخطاء (مثل {'field': ['msg']})
    for (final entry in map.entries) {
      final v = entry.value;
      if (v is List && v.isNotEmpty) {
        final first = v.first;
        if (first != null && first.toString().trim().isNotEmpty) {
          return first.toString();
        }
      }
      if (v is String && v.trim().isNotEmpty) {
        return v;
      }
    }
  } else if (body is List && body.isNotEmpty) {
    final first = body.first;
    if (first != null && first.toString().trim().isNotEmpty) {
      return first.toString();
    }
  } else if (body is String) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return fallback;
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('<!doctype') || lower.contains('<html')) {
      return fallback;
    }
    return trimmed;
  }
  return fallback;
}

String _dateOnly(DateTime date) => date.toIso8601String().split('T').first;

Map<String, dynamic> _stringMap(Map source) =>
    source.map((key, value) => MapEntry(key.toString(), value));

class ReportAttachmentUpload {
  ReportAttachmentUpload({
    required this.file,
    this.contentType,
  });

  final File file;
  final String? contentType;

  MediaType? get mediaType {
    if (contentType == null || contentType!.trim().isEmpty) return null;
    try {
      return MediaType.parse(contentType!);
    } catch (_) {
      return null;
    }
  }
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
        _u(_pLogin),
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
          return {'ok': false, 'message': 'لم يستلم التطبيق رمز الدخول (access token).'};
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
        return {'ok': false, 'message': (body['detail'] ?? body['message'] ?? 'تعذّر تسجيل الدخول').toString()};
      }

      // محتوى غير JSON
      return {'ok': false, 'message': "الخادم أعاد محتوى غير متوقع (رمز ${res.statusCode})."};
    } catch (e) {
      return {'ok': false, 'message': 'خطأ في الشبكة: $e'};
    }
  }

  // ---------------------------------------------
  // جلب ملف الموظف وحفظه في الكاش
  // GET /auth/guard/me/
  // قد يرجع {employee:{...}} أو مباشرة {...}
  // ---------------------------------------------
  static Future<EmployeeMe?> fetchEmployeeAndCache() async {
    final prefs = await SharedPreferences.getInstance();
    final accessRaw = await _getAccessRaw();
    if (accessRaw == null || accessRaw.isEmpty) return null;

    try {
      final res = await _client.get(
        _u(_pMeGet),
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
      _u(_pMePost),
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

  // تسجيل خروج — حذف كل البيانات
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
  // ---------------------------------------------
  static Future<Map<String, dynamic>> forgotByUsername(String username) async {
    try {
      final res = await _client.post(
        _u(_pForgotUsername),
        headers: _jsonHeaders(),
        body: jsonEncode({'username': username}),
      ).timeout(const Duration(seconds: 20));

      final body = _decode(res);
      if (res.statusCode == 200 && body is Map<String, dynamic>) {
        return {'ok': true, 'session_id': body['session_id'], 'detail': body['detail']};
      }
      return {'ok': false, 'message': (body is Map && body['detail'] != null) ? body['detail'].toString() : 'تعذر إرسال الكود'};
    } catch (e) {

      return {'ok': false, 'message': 'خطأ في الشبكة: $e'};
 }
  }

  // ---------------------------------------------
  // إعادة تعيين كلمة المرور (session_id + code + new_password)
  // ---------------------------------------------
  static Future<Map<String, dynamic>> resetBySession({
    required int sessionId,
    required String code,
    required String newPassword,
  }) async {
    try {
      final res = await _client.post(
        _u(_pResetBySession),
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
      return {'ok': false, 'message': 'خطأ في الشبكة: $e'};
    }
  }

  // ---------------------------------------------
  // التقارير والطلبات
  // ---------------------------------------------

  static Future<ApiResult> submitGuardReport({
    required String reportType,
    required String description,
    String? locationId,
    List<ReportAttachmentUpload> attachments = const [],
  }) async {
    final token = await _getAccessRaw();
    if (token == null || token.isEmpty) {
      return (ok: false, message: 'يرجى تسجيل الدخول مجددًا.', data: null);
    }

    try {
      http.Response res;
      final usableAttachments = attachments
          .where((att) => att.file.existsSync())
          .toList(growable: false);

      if (usableAttachments.isEmpty) {
        res = await _client
            .post(
              _u(_pGuardReports),
              headers: {
                ..._jsonHeaders(),
                'Authorization': authHeader(token),
              },
              body: jsonEncode({
                'report_type': reportType,
                'description': description,
                if (locationId != null && locationId.isNotEmpty) 'location': locationId,
              }),
            )
            .timeout(const Duration(seconds: 20));
      } else {
        final req = http.MultipartRequest('POST', _u(_pGuardReports));
        req.headers.addAll({
          'Authorization': authHeader(token),
          'Accept': 'application/json',
        });
        req.fields['report_type'] = reportType;
        req.fields['description'] = description;
        if (locationId != null && locationId.isNotEmpty) {
          req.fields['location'] = locationId;
        }
        for (final att in usableAttachments) {
          req.files.add(await http.MultipartFile.fromPath(
            'attachments',
            att.file.path,
            contentType: att.mediaType,
          ));
        }
        final streamed = await req.send().timeout(const Duration(seconds: 30));
        res = await http.Response.fromStream(streamed);
      }

      final body = _decode(res);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = body is Map<String, dynamic>
            ? Map<String, dynamic>.from(body)
            : {'raw': body};
        return (ok: true, message: 'ok', data: data);
      }

      if (res.statusCode == 404) {
        return (
          ok: false,
          message: 'واجهة التقارير غير متاحة (404). الرجاء التأكد من تحديث خادم sanam_hr.',
          data: body is Map<String, dynamic> ? Map<String, dynamic>.from(body) : null,
        );
      }

      final message = _messageFromBody(body, 'تعذّر إرسال التقرير. تحقق من البيانات المدخلة.');
      final data = body is Map<String, dynamic>
          ? Map<String, dynamic>.from(body)
          : (body is Map
              ? _stringMap(body as Map)
              : null);
      return (ok: false, message: message, data: data);
    } catch (e) {
      return (ok: false, message: 'خطأ في الشبكة: $e', data: null);
    }
  }

  static Future<ApiResult> submitGuardRequest({
    required String requestType,
    required String description,
    DateTime? leaveStart,
    DateTime? leaveEnd,
  }) async {
    final token = await _getAccessRaw();
    if (token == null || token.isEmpty) {
      return (ok: false, message: 'يرجى تسجيل الدخول مجددًا.', data: null);
    }

    final payload = {
      'request_type': requestType,
      'description': description,
      if (leaveStart != null) 'leave_start': leaveStart.toIso8601String(),
      if (leaveEnd != null) 'leave_end': leaveEnd.toIso8601String(),
    };

    try {
      final res = await _client
          .post(
            _u(_pGuardRequests),
            headers: {
              ..._jsonHeaders(),
              'Authorization': authHeader(token),
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));

      final body = _decode(res);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = body is Map<String, dynamic>
            ? Map<String, dynamic>.from(body)
            : {'raw': body};
        return (ok: true, message: 'ok', data: data);
      }

      if (res.statusCode == 404) {
        return (
          ok: false,
          message: 'واجهة الطلبات غير متاحة (404). الرجاء التأكد من تحديث خادم sanam_hr.',
          data: body is Map<String, dynamic> ? Map<String, dynamic>.from(body) : null,
        );
      }

      final message = _messageFromBody(body, 'تعذّر إرسال الطلب. تحقق من البيانات المدخلة.');
      final data = body is Map<String, dynamic>
          ? Map<String, dynamic>.from(body)
          : (body is Map
              ? _stringMap(body as Map)
              : null);
      return (ok: false, message: message, data: data);
    } catch (e) {
      return (ok: false, message: 'خطأ في الشبكة: $e', data: null);
    }
  }

  static Future<ApiResult> fetchGuardRequests({bool includeClosed = false}) async {
    final token = await _getAccessRaw();
    if (token == null || token.isEmpty) {
      return (ok: false, message: 'يرجى تسجيل الدخول مجددًا.', data: null);
    }

    final basePath = _joinUrl(kBaseUrl, _pGuardRequests);
    final uri = includeClosed
        ? Uri.parse('$basePath?include_closed=true')
        : Uri.parse(basePath);

    try {
      final res = await _client
          .get(
            uri,
            headers: {
              ..._jsonHeaders(),
              'Authorization': authHeader(token),
            },
          )
          .timeout(const Duration(seconds: 20));

      final body = _decode(res);
      if (res.statusCode == 200) {
        List<dynamic> results = const [];
        if (body is List) {
          results = List<dynamic>.from(body);
        } else if (body is Map && body['results'] is List) {
          results = List<dynamic>.from(body['results'] as List);
        }
        final data = <String, dynamic>{
          'results': results,
          'raw': body,
        };
        return (ok: true, message: 'ok', data: data);
      }

      if (res.statusCode == 404) {
        return (
          ok: false,
          message: 'واجهة الطلبات غير متاحة (404). الرجاء التأكد من تفعيلها في خادم sanam_hr.',
          data: body is Map<String, dynamic> ? Map<String, dynamic>.from(body) : null,
        );
      }

      final message = _messageFromBody(body, 'تعذّر تحميل الطلبات');
      final data = body is Map<String, dynamic>
          ? Map<String, dynamic>.from(body)
          : (body is Map
              ? _stringMap(body as Map)
              : null);
      return (ok: false, message: message, data: data);
    } catch (e) {
      return (ok: false, message: 'خطأ في الشبكة: $e', data: null);
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
  required String token,        // التوكن الخام أو "Bearer <...>"
  required dynamic locationId,  // int أو UUID
  required String action,       // "check_in" | "check_out" | "early_check_out"
  Duration window = const Duration(seconds: 8),
  String? earlyReason,
  File? earlyAttachment,
}) async {
  try {
    final pos = await getBestFix(window: window);
    return await sendAttendanceWithPosition(
      baseUrl: baseUrl,
      token: token,
      locationId: locationId,
      action: action,
      pos: pos,
      earlyReason: earlyReason,
      earlyAttachment: earlyAttachment,
    );
  } catch (e) {
    return (ok: false, message: e.toString(), data: null);
  }
}

/// إرسال حضور/انصراف بقراءة Position جاهزة
Future<ApiResult> sendAttendanceWithPosition({
  required String baseUrl,
  required String token,
  required dynamic locationId,
  required String action,           // check_in | check_out | early_check_out
  required Position pos,
  String? earlyReason,
  File? earlyAttachment,
}) async {
  try {
    final uri = Uri.parse(_joinUrl(baseUrl, _pAttendanceCheck));

    final Map<String, dynamic> body = {
      'location_id': locationId,
      'action': action,
      'lat': pos.latitude,
      'lng': pos.longitude,
      'accuracy': pos.accuracy,
      if (earlyReason != null && earlyReason.isNotEmpty) 'early_reason': earlyReason,
    };

    http.Response res;
    if (earlyAttachment != null) {
      // مرفق اختياري لانصراف مبكر
      final req = http.MultipartRequest('POST', uri);
      req.headers.addAll({'Authorization': authHeader(token)});
      body.forEach((k, v) => req.fields[k] = v.toString());
      req.files.add(await http.MultipartFile.fromPath('early_attachment', earlyAttachment.path));
      final streamed = await req.send();
      res = await http.Response.fromStream(streamed);
    } else {
      res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': authHeader(token),
        },
        body: jsonEncode(body),
      );
    }

    final text = utf8.decode(res.bodyBytes);
    Map<String, dynamic>? data;
    try { data = jsonDecode(text) as Map<String, dynamic>; } catch (_) {}

    // ok = 200/201 + ok=true (إن وُجد)
    final ok = (res.statusCode == 200 || res.statusCode == 201) && (data?['ok'] ?? true);
    // الرسالة بالعربي إن وُجدت، وإلا fallback لطيف
    final msg = (data?['detail']?.toString() ?? (ok ? 'تم تنفيذ العملية بنجاح' : 'تعذر تنفيذ الطلب'));

    return (ok: ok, message: msg, data: data);
  } catch (e) {
    return (ok: false, message: 'خطأ في الاتصال: $e', data: null);
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
    final uri = Uri.parse(_joinUrl(baseUrl, _pResolveLocation));
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
    final msg = data?['detail']?.toString() ?? (ok ? 'تم' : 'تعذر تحديد الموقع');
    return (ok: ok, message: msg, data: data);
  } catch (e) {
    return (ok: false, message: e.toString(), data: null);
  }
}

// ========================================================
// دوال مختصرة "آلية بالكامل": تحديد موقع + تحقق وردية + إرسال
// تناسب واجهة المستخدم لتقليل الخطوات في الشاشة.
// ========================================================

/// حضور تلقائي: يلتقط GPS -> يحدّد الموقع -> يرسل check_in
Future<ApiResult> checkInAuto({
  String baseUrl = kBaseUrl,
  required String token,
  Duration fixWindow = const Duration(seconds: 8),
}) async {
  try {
    final pos = await getBestFix(window: fixWindow);
    final r = await resolveMyLocation(
      baseUrl: baseUrl,
      token: token,
      lat: pos.latitude,
      lng: pos.longitude,
      accuracy: pos.accuracy,
    );
    if (!r.ok || r.data?['location_id'] == null) {
      return (ok: false, message: r.message.isNotEmpty ? r.message : 'لا يوجد موقع مكلّف به هنا', data: r.data);
    }
    final lid = r.data!['location_id'].toString();
    final res = await sendAttendanceWithPosition(
      baseUrl: baseUrl,
      token: token,
      locationId: lid,
      action: 'check_in',
      pos: pos,
    );
    return res;
  } catch (e) {
    return (ok: false, message: 'تعذّر إتمام الحضور: $e', data: null);
  }
}

/// انصراف تلقائي
Future<ApiResult> checkOutAuto({
  String baseUrl = kBaseUrl,
  required String token,
  Duration fixWindow = const Duration(seconds: 8),
}) async {
  try {
    final pos = await getBestFix(window: fixWindow);
    final r = await resolveMyLocation(
      baseUrl: baseUrl,
      token: token,
      lat: pos.latitude,
      lng: pos.longitude,
      accuracy: pos.accuracy,
    );
    if (!r.ok || r.data?['location_id'] == null) {
      return (ok: false, message: r.message.isNotEmpty ? r.message : 'لا يوجد موقع مكلّف به هنا', data: r.data);
    }
    final lid = r.data!['location_id'].toString();
    final res = await sendAttendanceWithPosition(
      baseUrl: baseUrl,
      token: token,
      locationId: lid,
      action: 'check_out',
      pos: pos,
    );
    return res;
  } catch (e) {
    return (ok: false, message: 'تعذّر إتمام الانصراف: $e', data: null);
  }
}

/// انصراف مبكر تلقائي — مع سبب ومرفق اختياري
Future<ApiResult> earlyCheckOutAuto({
  String baseUrl = kBaseUrl,
  required String token,
  required String reason,
  File? attachment,
  Duration fixWindow = const Duration(seconds: 8),
}) async {
  try {
    final pos = await getBestFix(window: fixWindow);
    final r = await resolveMyLocation(
      baseUrl: baseUrl,
      token: token,
      lat: pos.latitude,
      lng: pos.longitude,
      accuracy: pos.accuracy,
    );
    if (!r.ok || r.data?['location_id'] == null) {
      return (ok: false, message: r.message.isNotEmpty ? r.message : 'لا يوجد موقع مكلّف به هنا', data: r.data);
    }
    final lid = r.data!['location_id'].toString();
    final res = await sendAttendanceWithPosition(
      baseUrl: baseUrl,
      token: token,
      locationId: lid,
      action: 'early_check_out',
      pos: pos,
      earlyReason: reason,
      earlyAttachment: attachment,
    );
    return res;
  } catch (e) {
    return (ok: false, message: 'تعذّر إتمام الانصراف المبكر: $e', data: null);
  }
}
