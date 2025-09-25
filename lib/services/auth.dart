// lib/services/auth.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String kAuthHeaderKey = 'auth_token';
const String kRefreshKey    = 'refresh_token';

Future<void> _saveTokens({required String access, String? refresh}) async {
  final sp = await SharedPreferences.getInstance();
  await sp.setString(kAuthHeaderKey, 'Bearer $access');
  if (refresh != null && refresh.isNotEmpty) {
    await sp.setString(kRefreshKey, refresh);
  }
}

Future<String?> getAuthHeader() async =>
    (await SharedPreferences.getInstance()).getString(kAuthHeaderKey);

Future<void> logout() async {
  final sp = await SharedPreferences.getInstance();
  await sp.remove(kAuthHeaderKey);
  await sp.remove(kRefreshKey);
}

/// يجرّب عدة مسارات شائعة حتى ينجح
// lib/services/auth.dart
Future<({bool ok, String message})> loginAndStoreToken({
  required String baseUrl, // مثال: http://192.168.1.50:8000 (بدون / في النهاية)
  required String username,
  required String password,
}) async {
  baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  // اختر المسار الفعّال عندك (أحد الخيارين):
  final uri = Uri.parse("$baseUrl/auth/guard/login/");              // خيار A (SimpleJWT)
  // final uri = Uri.parse("$baseUrl/api/auth/jwt/create/"); // خيار B (Djoser)

  final res = await http.post(
    uri,
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    body: jsonEncode({'username': username, 'password': password}),
  );

  final body = utf8.decode(res.bodyBytes);
  final ct = (res.headers['content-type'] ?? '').toLowerCase();

  Map<String, dynamic>? data;
  if (ct.contains('application/json')) {
    try { data = jsonDecode(body) as Map<String, dynamic>; } catch (_) {}
  }

  if (res.statusCode >= 200 && res.statusCode < 300 && data != null) {
    final access  = (data['access'] ?? data['token'])?.toString();
    final refresh = data['refresh']?.toString();
    if (access != null && access.isNotEmpty) {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('auth_token', 'Bearer $access');
      if (refresh != null) await sp.setString('refresh_token', refresh);
      return (ok: true, message: "تم تسجيل الدخول");
    }
  }

  // رسائل تشخيص واضحة
  if (!ct.contains('application/json')) {
    return (ok: false, message: "الخادم أعاد HTML/غير JSON (status ${res.statusCode}). العنوان: ${res.request?.url}");
  }
  return (ok: false, message: data?['detail']?.toString() ?? "فشل تسجيل الدخول (status ${res.statusCode})");
}

