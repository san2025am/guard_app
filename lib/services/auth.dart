// // lib/services/auth.dart
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../models/employee.dart';
//
//
// const _kAccessKey  = 'access_token';
// const _kRefreshKey = 'refresh_token';
//
// Future<void> saveTokensRaw({required String access, String? refresh}) async {
//   final sp = await SharedPreferences.getInstance();
//   await sp.setString(_kAccessKey, access);        // نخزن الـ access خام فقط
//   if (refresh != null && refresh.isNotEmpty) {
//     await sp.setString(_kRefreshKey, refresh);
//   }
// }
//
// Future<String?> getAccessToken() async =>
//     (await SharedPreferences.getInstance()).getString(_kAccessKey);
//
// Map<String, String> buildAuthHeader(String accessRaw) => {
//   'Authorization': 'Bearer $accessRaw',           // صيغة صحيحة 100%
// };
//
// Future<void> logout() async {
//   final sp = await SharedPreferences.getInstance();
//   await sp.remove(_kAccessKey);
//   await sp.remove(_kRefreshKey);
// }
//
// Future<String?> getAuthHeader() async =>
//     (await SharedPreferences.getInstance()).getString(_kAccessKey);
//
// // auth.dart
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
//
// const _kAccessKey  = 'access_token';
// const _kRefreshKey = 'refresh_token';
//
// Future<void> saveTokensRaw({required String access, String? refresh}) async {
//   final sp = await SharedPreferences.getInstance();
//   await sp.setString(_kAccessKey, access);
//   if (refresh != null && refresh.isNotEmpty) {
//     await sp.setString(_kRefreshKey, refresh);
//   }
// }
//
// Future<String?> getAccessToken() async =>
//     (await SharedPreferences.getInstance()).getString(_kAccessKey);
//
// Map<String, String> buildAuthHeader(String accessRaw) => {
//   'Authorization': 'Bearer $accessRaw',
// };
//
// // نموذج مبسّط (استبدله بنموذجك إن وُجد)
// class EmployeeMe {
//   final dynamic id;
//   final String? fullName;
//   final List<dynamic> locations;
//   EmployeeMe({this.id, this.fullName, this.locations = const []});
//   factory EmployeeMe.fromJson(Map<String, dynamic> j) => EmployeeMe(
//     id: j['id'],
//     fullName: j['full_name']?.toString(),
//     locations: (j['locations'] is List) ? (j['locations'] as List) : const [],
//   );
// }
//
// typedef LoginResult = ({bool ok, String message, EmployeeMe? employee, Map<String, dynamic>? raw});
//
// /// يحاول جلب بروفايل الموظف من عدة endpoints شائعة
// Future<Map<String, dynamic>?> _fetchEmployeeFromAPI(String baseUrl, String access) async {
//   baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
//
//   // جرّب هذه المسارات بالترتيب حتى ينجح واحد منها
//   final candidates = <String>[
//     'auth/guard/me/',
//     'auth/me/',
//     'guard/me/',
//     'employee/me/',
//     'employees/me/',
//   ];
//
//   for (final path in candidates) {
//     final uri = Uri.parse('$baseUrl/$path');
//     try {
//       final res = await http.get(uri, headers: {
//         'Accept': 'application/json',
//         ...buildAuthHeader(access),
//       });
//       if (res.statusCode >= 200 && res.statusCode < 300) {
//         final txt = utf8.decode(res.bodyBytes);
//         final obj = jsonDecode(txt);
//
//         if (obj is Map<String, dynamic>) {
//           // أحيانًا JSON يكون { employee: {...} } وأحيانًا يكون {...} مباشرة
//           if (obj['employee'] is Map) {
//             return Map<String, dynamic>.from(obj['employee']);
//           }
//           // لو يحتوي حقول معروفة اعتبره هو الـ employee نفسه
//           if (obj.containsKey('full_name') || obj.containsKey('locations')) {
//             return obj;
//           }
//         }
//       }
//     } catch (_) {/* جرّب التالي */}
//   }
//   return null;
// }
//
// /// يسجّل الدخول ويحفظ التوكنات ويضمن حفظ employee_json حتى لو لم ترجع في استجابة الدخول
// Future<LoginResult> guardLoginAndStore({
//   required String baseUrl,   // مثال: http://HOST/api أو https://domain.com/api/v1 (بدون / في النهاية)
//   required String username,
//   required String password,
// }) async {
//   try {
//     baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
//     final uri = Uri.parse("$baseUrl/auth/guard/login/"); // عدّل إذا Endpoint مختلف
//
//     final res = await http.post(
//       uri,
//       headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
//       body: jsonEncode({'username': username, 'password': password}),
//     );
//
//     final bodyText = utf8.decode(res.bodyBytes);
//     Map<String, dynamic>? body;
//     try { body = jsonDecode(bodyText) as Map<String, dynamic>; } catch (_) {}
//
//     if (res.statusCode >= 200 && res.statusCode < 300 && body != null) {
//       final access  = (body['access'] ?? body['token'])?.toString();
//       final refresh = body['refresh']?.toString();
//       if (access == null || access.isEmpty) {
//         return (ok: false, message: "لم يستلم التطبيق access token.", employee: null, raw: body);
//       }
//       await saveTokensRaw(access: access, refresh: refresh);
//
//       final sp = await SharedPreferences.getInstance();
//       if (body['user'] is Map) {
//         final u = body['user'] as Map;
//         await sp.setString('username', (u['username'] ?? '').toString());
//         await sp.setString('role', (u['role_label'] ?? u['role'] ?? '').toString());
//       }
//
//       // 1) حاول أخذ employee من استجابة الدخول
//       Map<String, dynamic>? empJson;
//       if (body['employee'] is Map) {
//         empJson = Map<String, dynamic>.from(body['employee']);
//       }
//
//       // 2) إن لم يوجد، نفّذ نداءً ثانياً لجلبه
//       empJson ??= await _fetchEmployeeFromAPI(baseUrl, access);
//
//       // 3) خزّنه إن وُجد
//       EmployeeMe? empModel;
//       if (empJson != null) {
//         await sp.setString('employee_json', jsonEncode(empJson));
//         try { empModel = EmployeeMe.fromJson(empJson); } catch (_) {}
//       }
//
//       return (ok: true, message: "تم تسجيل الدخول", employee: empModel, raw: body);
//     }
//
//     if (body != null) {
//       final msg = (body['detail'] ?? body['message'] ?? "فشل تسجيل الدخول").toString();
//       return (ok: false, message: msg, employee: null, raw: body);
//     }
//
//     return (ok: false, message: "الخادم أعاد محتوى غير JSON (status ${res.statusCode}). تأكّد من العنوان.", employee: null, raw: null);
//   } catch (e) {
//     return (ok: false, message: "Network error: $e", employee: null, raw: null);
//   }
// }
