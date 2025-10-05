/// شاشة الحضور والانصراف مع دعم تحديد الموقع والمرفقات + مزامنة مباشرة مع السيرفر.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../services/biometric_auth.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  static const String _kLastAttendanceStateKey = 'attendance_last_state';

  bool _checkedIn = false;
  DateTime? _time;
  bool _loading = false;
  String? _lastAction; // check_in / check_out / early_check_out

  String? _locationId;   // UUID نص
  String? _locationName; // اسم الموقع
  String? _clientName;   // اسم العميل
  String? _lastServerMessage;
  Map<String, dynamic>? _lastData;

  bool _unrestricted = false;
  String? _shiftHint; // نص نافذة/سماحات
  String? _locationsSummary;

  BiometricMethod? _biometricMethod;

  Timer? _pollTimer;    // يتحقق هل السجل ما يزال موجوداً
  Timer? _refreshTimer; // يجلب آخر سجل من السيرفر

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _initBiometrics();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ================================
  // Bootstrap + Timers
  // ================================
  Future<void> _bootstrap({bool forceEmployeeRefresh = false}) async {
    final token = await ApiService.getAccessToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    await _checkCurrentAttendanceStatus();

    // من الكاش/الخادم: معلومات الموظف والمواقع
    final emp = forceEmployeeRefresh
        ? (await ApiService.refreshEmployeeCache()) ?? await ApiService.ensureEmployeeCached()
        : await ApiService.ensureEmployeeCached();

    if (emp != null && emp.locations != null && emp.locations!.isNotEmpty) {
      final firstLoc = emp.locations!.first;
      setState(() {
        _locationId = firstLoc.id?.toString();
        _locationName = firstLoc.name;
        try {
          final dyn = firstLoc as dynamic;
          final cName = (dyn.client_name ?? dyn.clientName);
          if (cName != null && cName.toString().isNotEmpty) {
            _clientName = cName.toString();
          }
        } catch (_) {}
        _locationsSummary = _composeLocationsSummary(emp.locations);
      });
      await _loadUnrestrictedFromCache();

      // تعزيز التحديد من الخادم (أقرب موقع)
      try {
        final pos = await getBestFix();
        final r = await resolveMyLocation(
          baseUrl: kBaseUrl,
          token: token,
          lat: pos.latitude,
          lng: pos.longitude,
          accuracy: pos.accuracy,
        );
        if (r.ok && r.data?['location_id'] != null) {
          setState(() {
            _locationId = r.data!['location_id']?.toString();
            _locationName = (r.data!['name'] ?? _locationName)?.toString();
            final cName = r.data!['client_name']?.toString();
            if (cName != null && cName.isNotEmpty) _clientName = cName;
          });
        }
      } catch (_) {}
    } else {
      setState(() => _locationsSummary = null);
      // تحديد تلقائي كامل عبر الإحداثيات عندما لا تُرجع المواقع من الكاش
      try {
        final pos = await getBestFix();
        final r = await resolveMyLocation(
          baseUrl: kBaseUrl,
          token: token,
          lat: pos.latitude,
          lng: pos.longitude,
          accuracy: pos.accuracy,
        );
        if (r.ok && r.data?['location_id'] != null) {
          setState(() {
            _locationId = r.data!['location_id']?.toString();
            _locationName = r.data!['name']?.toString();
            final cName = r.data!['client_name']?.toString();
            if (cName != null && cName.isNotEmpty) _clientName = cName;
          });
        } else {
          _toast('لم يتم تحديد موقع العمل تلقائيًا: ${r.message}');
        }
      } catch (e) {
        _toast('خطأ في تحديد الموقع: $e');
      }
      await _loadUnrestrictedFromCache();
    }

    _startTimers();
  }

  Future<void> _initBiometrics() async {
    final method = await BiometricAuthService.preferredMethod();
    if (!mounted) return;
    setState(() {
      _biometricMethod = method;
    });
  }

  Future<bool> _ensureBiometricAuthenticated() async {
    final t = AppLocalizations.of(context)!;

    final method = await BiometricAuthService.preferredMethod();
    if (!mounted) {
      return false;
    }

    if (method == null) {
      setState(() {
        _biometricMethod = null;
      });
      _toast(t.biometric_not_configured);
      return false;
    }

    setState(() {
      _biometricMethod = method;
    });

    final success = await BiometricAuthService.authenticate(
      reason: t.biometric_auth_reason(_biometricMethodLabel(t, method)),
    );
    if (!success) {
      if (!mounted) {
        return false;
      }
      _toast(t.biometric_auth_failed);
      return false;
    }

    return true;
  }

  void _startTimers() {
    _pollTimer?.cancel();
    _refreshTimer?.cancel();

    // تحقق من وجود السجل كل 10 ثوانٍ — لو انحذف في السيرفر، امسح الكاش مباشرة
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      final id = _currentRecordId();
      if (id == null) return;
      try {
        final exists = await ApiService.attendanceExists(id);
        if (!exists && mounted) {
          await _clearPersistedAttendanceState();
          setState(() {
            _lastData = null;
            _lastAction = null;
            _checkedIn = false;
            _time = null;
          });
          _toast('تم حذف آخر تسجيل من السيرفر.');
        }
      } catch (_) {
        // تجاهل شبكات
      }
    });

    // جلب آخر سجل من السيرفر كل 60 ثانية لتحديث الوقت/الرسالة
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _refreshLastFromServer();
    });
  }

  // يجلب أحدث سجل من السيرفر ويعرضه (إن توفّر endpoint)
  Future<void> _refreshLastFromServer() async {
    try {
      final m = await ApiService.fetchLastAttendance();
      if (!mounted) return;
      if (m == null) return;
      // m يحتوي مفاتيح متوقعة: id, check_in_time, check_out_time, location_name, employee_name ...
      final action = _deriveActionFromPayload(m);
      final recordedAtRaw = m['check_out_time'] ?? m['check_in_time'] ?? m['timestamp'];
      final recordedAt = _tryParseDateTime(recordedAtRaw) ?? DateTime.now();

      setState(() {
        _lastData = m;
        _lastAction = action;
        _checkedIn = action == 'check_in';
        _time = recordedAt;
        _locationName = (m['location_name'] ?? _locationName)?.toString();
        _clientName = (m['client_name'] ?? _clientName)?.toString();
        _lastServerMessage ??= 'تم التحديث من الخادم';
      });

      // حدّث الحالة المحفوظة بنفس البنية الحالية
      await _persistLastAttendanceState(
        action: action,
        timestamp: recordedAt,
        message: _lastServerMessage,
        data: m,
      );
    } catch (_) {
      // تجاهل
    }
  }

  // ================================
  // قراءة/كتابة الحالة المحلية
  // ================================
  Future<void> _loadUnrestrictedFromCache() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final txt = sp.getString('employee_json');
      if (txt == null || txt.isEmpty) {
        setState(() { _unrestricted = false; _shiftHint = null; });
        return;
      }
      final Map<String, dynamic> j = jsonDecode(txt);
      final assigns = (j['shift_assignments'] is List) ? (j['shift_assignments'] as List) : const [];
      bool anyUn = false;
      String? hint;
      for (final x in assigns) {
        if (x is! Map) continue;
        final m = Map<String, dynamic>.from(x as Map);
        final active = m['active'] == true;
        if (!active) continue;

        final un = m['unrestricted'] == true;
        if (un) {
          anyUn = true;
          hint = 'وردية غير مقيّدة – يُسمح بالحضور والانصراف في أي وقت.';
          break;
        }

        final st = (m['start_time'] ?? '').toString();
        final et = (m['end_time'] ?? '').toString();
        final cgi = int.tryParse(m['checkin_grace']?.toString() ?? '');
        final cgo = int.tryParse(m['checkout_grace']?.toString() ?? '');
        final cgh = double.tryParse(m['checkout_grace_hours']?.toString() ?? '');
        final exitText = (cgh != null && cgh > 0)
            ? 'الانصراف بعد ${_fmtHour(cgh)}'
            : (cgo != null && cgo > 0 ? 'الانصراف بعد $cgo دقيقة' : 'بدون سماح انصراف');
        final inText = (cgi != null && cgi > 0) ? 'الحضور خلال $cgi دقيقة من بداية الوردية' : 'بدون سماح حضور';
        hint = 'الوردية: ${st.isEmpty ? '-' : st} → ${et.isEmpty ? '-' : et} | $inText | $exitText';
        break;
      }
      setState(() {
        _unrestricted = anyUn;
        _shiftHint = hint;
      });
    } catch (_) {
      setState(() { _unrestricted = false; _shiftHint = null; });
    }
  }

  Future<void> _clearPersistedAttendanceState() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_kLastAttendanceStateKey);
    } catch (_) {}
  }

  void _resetAttendanceState() {
    if (!mounted) return;
    setState(() {
      _checkedIn = false;
      _lastAction = null;
      _time = null;
      _lastServerMessage = null;
      _lastData = null;
      _locationsSummary = null;
    });
  }

  Future<void> _checkCurrentAttendanceStatus() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_kLastAttendanceStateKey);
      if (raw == null || raw.isEmpty) {
        _resetAttendanceState();
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await _clearPersistedAttendanceState();
        _resetAttendanceState();
        return;
      }

      final map = Map<String, dynamic>.from(decoded as Map);
      final rawAction = map['action']?.toString();
      final action = _normalizeAction(rawAction) ?? rawAction;
      final isoTime = map['time']?.toString();
      DateTime? parsedTime;
      if (isoTime != null && isoTime.isNotEmpty) {
        try {
          parsedTime = DateTime.parse(isoTime).toLocal();
        } catch (_) {}
      }

      Map<String, dynamic>? cachedData;
      final dataRaw = map['data'];
      if (dataRaw is Map) {
        cachedData = Map<String, dynamic>.from(dataRaw as Map);
      }

      final currentEmployee = await ApiService.getCachedEmployee();
      final storedEmployeeRaw = map['employee_id']?.toString();
      final storedEmployeeId = int.tryParse(storedEmployeeRaw ?? '');
      final today = DateTime.now();
      final storedDay = map['day']?.toString();
      String? currentDayKey;
      if (storedDay != null && storedDay.isNotEmpty) {
        currentDayKey = storedDay;
      } else if (parsedTime != null) {
        currentDayKey = DateFormat('yyyy-MM-dd').format(parsedTime);
      }
      final todayKey = DateFormat('yyyy-MM-dd').format(today);
      final mismatchEmployee =
          currentEmployee != null && storedEmployeeId != null && currentEmployee.id != storedEmployeeId;
      final missingEmployeeForNewUser = currentEmployee != null && storedEmployeeId == null;
      final outdated = currentDayKey != null && currentDayKey != todayKey;

      if (missingEmployeeForNewUser || mismatchEmployee || outdated) {
        await _clearPersistedAttendanceState();
        _resetAttendanceState();
        return;
      }

      if (!mounted) return;
      setState(() {
        _lastAction = action;
        _checkedIn = action == 'check_in';
        _time = parsedTime;
        _lastServerMessage = map['message']?.toString();
        final locName = map['location_name']?.toString();
        if (locName != null && locName.isNotEmpty) _locationName = locName;
        final clientName = map['client_name']?.toString();
        if (clientName != null && clientName.isNotEmpty) _clientName = clientName;
        _lastData = cachedData;
      });
    } catch (_) {
      await _clearPersistedAttendanceState();
      _resetAttendanceState();
    }
  }

  // ================================
  // إجراءات الحضور/الانصراف
  // ================================
  Future<void> _openEarlyCheckoutDialog() async {
    final reasonController = TextEditingController();
    File? attachment;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setS) {
          return AlertDialog(
            title: const Text("طلب انصراف مبكر"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'اكتب سبب الانصراف',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (attachment != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(attachment!, height: 110, fit: BoxFit.cover),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('كاميرا'),
                        onPressed: () async {
                          final picked = await ImagePicker()
                              .pickImage(source: ImageSource.camera, imageQuality: 75);
                          if (picked != null) {
                            setS(() => attachment = File(picked.path));
                          }
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('المعرض'),
                        onPressed: () async {
                          final picked = await ImagePicker()
                              .pickImage(source: ImageSource.gallery, imageQuality: 85);
                          if (picked != null) {
                            setS(() => attachment = File(picked.path));
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
              ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: const Text("إرسال"),
                onPressed: () {
                  if (reasonController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('الرجاء كتابة السبب.')),
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
              ),
            ],
          );
        });
      },
    );

    if (ok == true) {
      await _handleAction("early_check_out",
          reason: reasonController.text.trim(), attachment: attachment);
    }
  }

  Future<void> _handleAction(
    String action, {
    String? reason,
    File? attachment,
  }) async {
    final authorized = await _ensureBiometricAuthenticated();
    if (!authorized) {
      return;
    }

    // تأكد من الموقع/الصلاحيات
    final canProceed = await _ensureLocationEnabled();
    if (!canProceed) return;

    final token = await ApiService.getAccessToken();
    if (token == null || token.isEmpty) {
      _toast('يرجى تسجيل الدخول أولاً.');
      return;
    }

    setState(() => _loading = true);
    try {
      final pos = await getBestFix();

      final auto = await resolveMyLocation(
        baseUrl: kBaseUrl,
        token: token,
        lat: pos.latitude,
        lng: pos.longitude,
        accuracy: pos.accuracy,
      );
      if (!(auto.ok && auto.data != null && auto.data!['location_id'] != null)) {
        final msg = auto.message.trim();
        _toast(msg.isNotEmpty
            ? 'تعذر تحديد موقع العمل تلقائيًا: $msg'
            : 'تعذر تحديد موقع العمل تلقائيًا. يرجى الاقتراب من الموقع وإعادة المحاولة.');
        return;
      }

      final locId = auto.data!['location_id']?.toString();
      setState(() {
        _locationId = locId;
        final nm = auto.data!['name']?.toString();
        if (nm != null && nm.isNotEmpty) _locationName = nm;
        final cName = auto.data!['client_name']?.toString();
        if (cName != null && cName.isNotEmpty) _clientName = cName;
      });

      final res = await sendAttendanceWithPosition(
        baseUrl: kBaseUrl,
        token: token,
        locationId: locId!,
        action: action,
        pos: pos,
        earlyReason: reason,
        earlyAttachment: attachment,
      );

      if (res.ok) {
        final data = res.data;
        final canonicalAction = _deriveActionFromPayload(data, fallbackAction: action);
        final recordedRaw = data?['recorded_at'] ??
            data?['timestamp'] ??
            data?['time'] ??
            data?['checked_at'];
        final recordedAt = _tryParseDateTime(recordedRaw) ?? DateTime.now();

        setState(() {
          _checkedIn = (canonicalAction == 'check_in');
          _lastAction = canonicalAction;
          _time = recordedAt;
          _lastServerMessage = res.message;
          _lastData = data;

          // حدّث الاسم/العميل من الرد
          if (data != null) {
            final locName = data['location_name']?.toString();
            if (locName != null && locName.isNotEmpty) _locationName = locName;
            final clientName = data['client_name']?.toString();
            if (clientName != null && clientName.isNotEmpty) _clientName = clientName;
          }
        });

        await _persistLastAttendanceState(
          action: canonicalAction,
          timestamp: _time ?? DateTime.now(),
          message: res.message,
          data: data,
        );

        // تحديث فوري من السيرفر بعد النجاح
        await _refreshLastFromServer();
      } else {
        _toast(res.message);
      }
    } catch (e) {
      _toast('خطأ غير متوقع: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ================================
  // Utilities
  // ================================
  String _fmtHour(double h) {
    final isInt = h == h.truncateToDouble();
    return isInt ? '${h.toInt()} ساعة' : '${h.toStringAsFixed(1)} ساعة';
    }

  Future<bool> _ensureLocationEnabled() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      try { await Geolocator.openLocationSettings(); } catch (_) {}
      _toast('يرجى تفعيل خدمة الموقع (GPS) من الإعدادات ثم المحاولة مرة أخرى.');
      return false;
    }
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        _toast('تم رفض صلاحية الموقع.');
        return false;
      }
    }
    if (perm == LocationPermission.deniedForever) {
      try { await Geolocator.openAppSettings(); } catch (_) {}
      _toast('يرجى منح صلاحية الموقع للتطبيق من الإعدادات.');
      return false;
    }
    return true;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  DateTime? _tryParseDateTime(dynamic raw) {
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  String? _composeLocationsSummary(List<dynamic>? locations) {
    if (locations == null || locations.isEmpty) return null;
    final List<String> names = [];
    final Set<String> seenIds = {};
    for (final loc in locations) {
      try {
        final dyn = loc as dynamic;
        final id = (dyn.id ?? dyn['id']).toString();
        if (seenIds.contains(id)) continue;
        seenIds.add(id);
        final rawName = (dyn.name ?? dyn['name'])?.toString();
        if (rawName != null && rawName.trim().isNotEmpty) names.add(rawName.trim());
      } catch (_) {
        continue;
      }
    }
    if (names.isEmpty) return null;
    return names.join('، ');
  }

  String? _normalizeAction(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final collapsed = trimmed.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    switch (collapsed) {
      case 'checkin':
      case 'signin':
        return 'check_in';
      case 'checkout':
      case 'signout':
        return 'check_out';
      case 'earlycheckout':
      case 'earlysignout':
        return 'early_check_out';
      default:
        return null;
    }
  }

  bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) return false;
      if (['true', '1', 'yes', 'y', 't'].contains(normalized)) {
        return true;
      }
      if (['false', '0', 'no', 'n', 'f'].contains(normalized)) {
        return false;
      }
    }
    return false;
  }

  String _deriveActionFromPayload(
    Map<String, dynamic>? payload, {
    String? fallbackAction,
  }) {
    final normalizedFallback = _normalizeAction(fallbackAction);
    if (payload == null) {
      return normalizedFallback ?? fallbackAction ?? 'check_in';
    }

    final normalizedFromPayload =
        _normalizeAction(payload['action']?.toString());
    final hasCheckoutTime = payload['check_out_time'] != null ||
        payload['checkout_time'] != null ||
        payload['checked_out_at'] != null;
    final hasCheckInTime = payload['check_in_time'] != null ||
        payload['checkin_time'] != null ||
        payload['checked_in_at'] != null;
    final isEarly = _parseBool(payload['early_checkout']);

    if (normalizedFromPayload != null) {
      if (normalizedFromPayload == 'early_check_out' && !isEarly && hasCheckoutTime) {
        return 'check_out';
      }
      return normalizedFromPayload;
    }

    if (hasCheckoutTime) {
      return isEarly ? 'early_check_out' : 'check_out';
    }
    if (hasCheckInTime) {
      return 'check_in';
    }

    return normalizedFallback ?? 'check_in';
  }

  String _biometricMethodLabel(AppLocalizations t, [BiometricMethod? method]) {
    switch (method ?? _biometricMethod) {
      case BiometricMethod.face:
        return t.biometric_method_face;
      case BiometricMethod.fingerprint:
        return t.biometric_method_fingerprint;
      case BiometricMethod.iris:
        return t.biometric_method_iris;
      case BiometricMethod.generic:
      case null:
        return t.biometric_method_generic;
    }
  }

  String _statusLabelFor(String? action) {
    switch (_normalizeAction(action)) {
      case 'check_in':
        return 'تم تسجيل الحضور';
      case 'check_out':
        return 'تم تسجيل الانصراف';
      case 'early_check_out':
        return 'تم تسجيل انصراف مبكر';
      default:
        return 'لم يتم تسجيل أي إجراء بعد';
    }
  }

  IconData _statusIconFor(String? action) {
    switch (_normalizeAction(action)) {
      case 'check_in':
        return Icons.login;
      case 'check_out':
        return Icons.logout;
      case 'early_check_out':
        return Icons.emergency_share_outlined;
      default:
        return Icons.access_time;
    }
  }

  Future<void> _persistLastAttendanceState({
    required String action,
    required DateTime timestamp,
    String? message,
    Map<String, dynamic>? data,
  }) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final employee = await ApiService.getCachedEmployee();
      Map<String, dynamic>? safeData;
      if (data != null) {
        try {
          final encoded = jsonEncode(data);
          safeData = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
        } catch (_) {
          safeData = null;
        }
      }

      final payload = <String, dynamic>{
        'action': action,
        'time': timestamp.toUtc().toIso8601String(),
        'day': DateFormat('yyyy-MM-dd').format(timestamp.toLocal()),
        if (employee != null) 'employee_id': employee.id,
        if (message != null && message.isNotEmpty) 'message': message,
        if (_locationName != null && _locationName!.isNotEmpty) 'location_name': _locationName,
        if (_clientName != null && _clientName!.isNotEmpty) 'client_name': _clientName,
        if (safeData != null) 'data': safeData,
      };

      await sp.setString(_kLastAttendanceStateKey, jsonEncode(payload));
    } catch (_) {}
  }

  /// يحاول إيجاد record_id الحالي من الرد أو الحالة المحفوظة
  String? _currentRecordId() {
    // من آخر رد
    final fromLast = _lastData?['record_id']?.toString();
    if (fromLast != null && fromLast.isNotEmpty) return fromLast;

    // أو من الحالة المحفوظة (لو كنت تخزن جزء من الرد داخل data)
    try {
      final data = _lastData;
      if (data is Map && data?['id'] != null) {
        return data?['id'].toString();
      }
    } catch (_) {}

    // لو أردت أن تقرأ من SharedPreferences مباشرة:
    // (نفس البنية التي تحفظها في _persistLastAttendanceState)
    // لكن بما أننا حفظنا الرد داخل `data` فاستغنينا عنها هنا.

    return null;
  }

  // ================================
  // UI
  // ================================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusKey = _normalizeAction(_lastAction) ?? (_checkedIn ? 'check_in' : null);
    final statusText = _statusLabelFor(statusKey);
    final statusIcon = _statusIconFor(statusKey);
    final timeStr = (statusKey == null || _time == null) ? null : DateFormat.Hm().format(_time!);

    return RefreshIndicator(
      onRefresh: () async {
        await _bootstrap(forceEmployeeRefresh: true);
        // تحديث مباشر من السيرفر كذلك
        await _refreshLastFromServer();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_unrestricted)
            Card(
              color: cs.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('وردية غير مقيّدة'),
                subtitle: const Text('يمكنك تسجيل الحضور أو الانصراف في أي وقت.'),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(statusIcon, size: 36, color: cs.primary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          statusText,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (timeStr != null) Text(timeStr),
                    ],
                  ),
                  if (_locationName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('الموقع: $_locationName',
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                  if (_clientName != null && _clientName!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text('العميل: $_clientName',
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                  if (_locationsSummary != null && _locationsSummary!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Text(
                        'المواقع المتاحة: $_locationsSummary',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_shiftHint != null && _shiftHint!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_shiftHint!, style: const TextStyle(fontSize: 12))),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text("تسجيل الحضور"),
                  onPressed: (_checkedIn || _loading)
                      ? null
                      : () => _handleAction("check_in"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text("تسجيل الانصراف"),
                  onPressed: (!_checkedIn || _loading)
                      ? null
                      : () => _handleAction("check_out"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.emergency_share_outlined),
              label: const Text("انصراف مبكر"),
              onPressed: (_loading) ? null : _openEarlyCheckoutDialog,
            ),
          ),
          if (_loading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_lastServerMessage != null || _lastData != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("تفاصيل آخر تسجيل:",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_lastServerMessage != null) Text(_lastServerMessage!),
                    if (_lastData != null) ...[
                      const SizedBox(height: 8),
                      _ResultTable(map: _lastData!, fmt: _fmtIsoDateTimeLocal),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmtIsoDateTimeLocal(dynamic v) {
    if (v == null) return '-';
    try {
      final dt = DateTime.parse(v.toString()).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (_) {
      return v.toString();
    }
  }
}

// جدول عرض بسيط للنتائج
class _ResultTable extends StatelessWidget {
  const _ResultTable({required this.map, required this.fmt});
  final Map<String, dynamic> map;
  final String Function(dynamic) fmt;

  @override
  Widget build(BuildContext context) {
    final recId = map['record_id'] ?? map['id'];
    final employee = map['employee'] ?? map['employee_name'];
    final location = map['location'] ?? map['location_name'];
    final detail = map['detail'];
    final note = map['note'];
    final un = map['unrestricted'] == true;
    final sws = map['shift_window_start'];
    final swe = map['shift_window_end'];

    final rows = <_KV>[
      if (detail != null) _KV('الرسالة', detail),
      if (note != null && note.toString().trim().isNotEmpty) _KV('ملاحظة', note),
      if (employee != null) _KV('الموظف', employee),
      if (location != null) _KV('الموقع', location),
      if (recId != null) _KV('رقم السجل', recId),
      _KV('نوع الوردية', un ? 'غير مقيّدة' : 'مقيّدة'),
      if (!un) _KV('نافذة الوردية', '${fmt(sws)} → ${fmt(swe)}'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows
          .map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                        width: 120,
                        child: Text('${e.k}:',
                            style: const TextStyle(fontWeight: FontWeight.w600))),
                    const SizedBox(width: 6),
                    Expanded(child: Text(e.v.toString())),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _KV {
  final String k;
  final dynamic v;
  const _KV(this.k, this.v);
}
