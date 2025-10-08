import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:security_quard/services/biometric_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api.dart';  // لو عندك AppSettings (الثيم/اللغة)


class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  static const String _kLastAttendanceStateKey = 'attendance_last_state';
  static const String _kPendingPingCacheKey = 'location_pending_pings_v1';
  static const int _kPendingPingMax = 500;
  // نرسل التتبع كل دقيقة ونحتفظ به عند عدم توفر الاتصال بالشبكة.
  static const Duration _pingIntervalInside = Duration(minutes: 1);
  static const Duration _pingIntervalOutside = Duration(minutes: 1);
  bool _checkedIn = false;
  DateTime? _time;
  bool _loading = false;
  String? _lastAction; // آخر إجراء تم تسجيله (check_in / check_out / early_check_out)

  String? _locationId;      // UUID نص
  String? _locationName;    // اسم الموقع
  String? _clientName;      // اسم العميل المرتبط بالموقع
  String? _lastServerMessage;
  Map<String, dynamic>? _lastData;

  // قائمة المواقع المتاحة للحارس (لمعرّفات وأسماء وعملاء) لاختيارها يدويًا
  // عرض حالة “غير مقيّدة” + تلميح نصي
  bool _unrestricted = false;
  String? _shiftHint; // نص موجز عن النافذة/السماحات
  String? _locationsSummary;
  Timer? _locationPingTimer;
  bool _locationPingInFlight = false;
  bool _locationViolationNotified = false;
  Duration _configuredPingIntervalInside = _pingIntervalInside;
  Duration _configuredPingIntervalOutside = _pingIntervalOutside;
  Duration _currentPingInterval = _pingIntervalInside;
  bool _shouldMonitorLocation = false;
  DateTime? _shiftWindowStart;
  DateTime? _shiftWindowEnd;
  bool _withinShift = true;
  String? _currentShiftName;
  String? _shiftAssignmentLocationName;
  bool _shiftMatchesLocation = true;
  bool _latestRecordLoading = false;
  DateTime? _lastRefreshAt;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      _refreshLastAttendanceFromServer();
    });
  }

  Future<void> _bootstrap({bool forceEmployeeRefresh = false}) async {
    final token = await ApiService.getAccessToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      _stopLocationMonitoring();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    await _flushPendingLocationPings(token);
    await _checkCurrentAttendanceStatus();

    // من الكاش
    final emp = forceEmployeeRefresh
        ? await ApiService.refreshEmployeeCache() ?? await ApiService.ensureEmployeeCached()
        : await ApiService.ensureEmployeeCached();
    if (emp != null && emp.locations != null && emp.locations!.isNotEmpty) {
      // استخدم أول موقع مخصّص للحارس لتعبئة الاسم والمعرّف واسم العميل إن وجد
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

      // تعزيز التحديد من الخادم للحصول على الموقع بدقة أعلى
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
        _applyMonitoringConfig(
          _asMap(r.data?['monitoring']),
          nextPingSeconds: _asInt(r.data?['next_ping_seconds']),
        );
      } catch (_) {}
    } else {
      setState(() {
        _locationsSummary = null;
      });
      // تحديد تلقائي عبر الإحداثيات
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
        _applyMonitoringConfig(
          _asMap(r.data?['monitoring']),
          nextPingSeconds: _asInt(r.data?['next_ping_seconds']),
        );
      } catch (e) {
        _toast('خطأ في تحديد الموقع: $e');
      }
      await _loadUnrestrictedFromCache();
    }
    if (mounted) {
      _updateLocationMonitoring(_checkedIn);
    }

    await _refreshLastAttendanceFromServer();
  }

  void _startLocationMonitoring([Duration? interval]) {
    final target = interval ?? _configuredPingIntervalInside;
    _currentPingInterval = target;
    _shouldMonitorLocation = true;
    _locationPingTimer?.cancel();
    _locationPingTimer = Timer.periodic(target, (_) => _sendLocationPing());
  }

  void _stopLocationMonitoring() {
    _locationPingTimer?.cancel();
    _locationPingTimer = null;
    _currentPingInterval = _configuredPingIntervalInside;
    _locationPingInFlight = false;
    _locationViolationNotified = false;
    _shouldMonitorLocation = false;
  }

  void _updateLocationMonitoring(bool enable, {Duration? interval}) {
    if (enable) {
      final target = interval ?? _configuredPingIntervalInside;
      if (_shouldMonitorLocation && _locationPingTimer != null && target == _currentPingInterval) {
        return;
      }
      _startLocationMonitoring(target);
    } else {
      if (!_shouldMonitorLocation) return;
      _stopLocationMonitoring();
    }
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value as Map);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return int.tryParse(trimmed);
    }
    return null;
  }

  bool? _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'yes') return true;
      if (lower == 'false' || lower == '0' || lower == 'no') return false;
    }
    return null;
  }

  void _applyMonitoringConfig(Map<String, dynamic>? monitoring, {int? nextPingSeconds}) {
    if (!mounted || monitoring == null) return;
    final map = Map<String, dynamic>.from(monitoring);
    final active = _asBool(map['active']);
    final pingSeconds = _asInt(map['ping_interval_seconds']);
    final outsideSeconds = _asInt(map['suggested_outside_ping_seconds'] ?? map['outside_ping_interval_seconds']);
    final insideDuration = (pingSeconds != null && pingSeconds > 0)
        ? Duration(seconds: pingSeconds)
        : _pingIntervalInside;
    final outsideDuration = (outsideSeconds != null && outsideSeconds > 0)
        ? Duration(seconds: outsideSeconds)
        : Duration(seconds: math.max(60, (insideDuration.inSeconds / 2).round()));
    final nextSeconds = nextPingSeconds ?? _asInt(map['next_ping_seconds']);
    final nextDuration = (nextSeconds != null && nextSeconds > 0)
        ? Duration(seconds: nextSeconds)
        : null;

    setState(() {
      _configuredPingIntervalInside = insideDuration;
      _configuredPingIntervalOutside = outsideDuration;
    });

    if (active == true) {
      _updateLocationMonitoring(true, interval: nextDuration ?? insideDuration);
    } else if (active == false) {
      _updateLocationMonitoring(false);
    } else if (active == null) {
      if (_shouldMonitorLocation) {
        _updateLocationMonitoring(true, interval: nextDuration ?? insideDuration);
      } else if (_checkedIn) {
        _updateLocationMonitoring(true, interval: nextDuration ?? insideDuration);
      }
    }
  }

  bool get _canPerformAttendanceActions => _unrestricted || _withinShift;

  void _applyShiftWindow({
    DateTime? start,
    DateTime? end,
    bool? withinShift,
  }) {
    if (!mounted) return;
    setState(() {
      _shiftWindowStart = start;
      _shiftWindowEnd = end;
      if (withinShift != null) {
        _withinShift = withinShift;
      }
    });
  }

  DateTime? _parseShiftInstant(dynamic value) {
    if (value == null) return null;
    return _tryParseDateTime(value);
  }

  Future<List<Map<String, dynamic>>> _loadPendingLocationPings() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kPendingPingCacheKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((item) => item is Map ? Map<String, dynamic>.from(item as Map) : null)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
    } catch (_) {
      // تجاهل أي خلل في التخزين ونبدأ بقائمة جديدة.
    }
    return <Map<String, dynamic>>[];
  }

  Future<void> _savePendingLocationPings(List<Map<String, dynamic>> items) async {
    final sp = await SharedPreferences.getInstance();
    if (items.isEmpty) {
      await sp.remove(_kPendingPingCacheKey);
    } else {
      await sp.setString(_kPendingPingCacheKey, jsonEncode(items));
    }
  }

  Future<void> _queuePendingLocationPing(Map<String, dynamic> ping) async {
    final items = await _loadPendingLocationPings();
    items.add(ping);
    if (items.length > _kPendingPingMax) {
      items.removeRange(0, items.length - _kPendingPingMax);
    }
    await _savePendingLocationPings(items);
  }

  bool _shouldRetryPing(ApiResult res) {
    if (res.ok) return false;
    if (res.data != null && res.data!.isNotEmpty) return false;
    final lower = res.message.toLowerCase();
    return lower.contains('الاتصال') ||
        lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('timeout');
  }

  Future<void> _flushPendingLocationPings(String token) async {
    final pending = await _loadPendingLocationPings();
    if (pending.isEmpty) return;

    final remaining = <Map<String, dynamic>>[];
    for (var i = 0; i < pending.length; i++) {
      final item = pending[i];
      final lat = (item['lat'] as num?)?.toDouble();
      final lng = (item['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) {
        continue;
      }
      final accuracy = (item['accuracy'] as num?)?.toDouble();
      final recordedStr = item['recorded_at']?.toString();
      DateTime? recordedAt;
      if (recordedStr != null) {
        recordedAt = DateTime.tryParse(recordedStr)?.toUtc();
      }

      try {
        final res = await sendLocationPing(
          baseUrl: kBaseUrl,
          token: token,
          latitude: lat,
          longitude: lng,
          accuracyOverride: accuracy,
          recordedAt: recordedAt,
        );
        if (!res.ok && _shouldRetryPing(res)) {
          remaining
            ..add(item)
            ..addAll(pending.sublist(i + 1));
          await _savePendingLocationPings(remaining);
          return;
        }
      } catch (_) {
        remaining
          ..add(item)
          ..addAll(pending.sublist(i + 1));
        await _savePendingLocationPings(remaining);
        return;
      }
    }

    await _savePendingLocationPings(<Map<String, dynamic>>[]);
  }

  Future<void> _sendLocationPing() async {
    if (!mounted || !_shouldMonitorLocation || _locationPingInFlight) return;
    final token = await ApiService.getAccessToken();
    if (token == null || token.isEmpty) return;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return;
    }

    _locationPingInFlight = true;
    Map<String, dynamic>? pendingPayload;
    try {
      await _flushPendingLocationPings(token);
      final pos = await getBestFix();
      final recordedAt = DateTime.now().toUtc();
      pendingPayload = {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'accuracy': pos.accuracy,
        'recorded_at': recordedAt.toIso8601String(),
      };
      final res = await sendLocationPing(
        baseUrl: kBaseUrl,
        token: token,
        pos: pos,
        accuracyOverride: pos.accuracy,
        recordedAt: recordedAt,
      );
      if (!mounted) return;
      if (!res.ok && _shouldRetryPing(res)) {
        await _queuePendingLocationPing(pendingPayload);
        return;
      }
      if (res.ok) {
        if (res.data is Map<String, dynamic>) {
          final data = res.data!;
          _applyMonitoringConfig(
            _asMap(data['monitoring']),
            nextPingSeconds: _asInt(data['next_ping_seconds']),
          );
          final triggered = data['violation_triggered'] == true;
          final violation = data['violation'] == true;
          final withinRadius = data['within_radius'] != false;
          if (triggered && !_locationViolationNotified) {
            final reason = (data['violation_reason'] ?? 'تم تسجيل مخالفة الموقع.').toString();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(reason)),
            );
            _locationViolationNotified = true;
          } else if (!violation) {
            _locationViolationNotified = false;
          }
          if (_shouldMonitorLocation) {
            final shouldUseOutside = (!withinRadius || violation || triggered);
            final targetInterval = shouldUseOutside
                ? _configuredPingIntervalOutside
                : _configuredPingIntervalInside;
            if (targetInterval != _currentPingInterval) {
              _startLocationMonitoring(targetInterval);
            }
          }
        }
        await _flushPendingLocationPings(token);
      } else {
        _applyMonitoringConfig(
          _asMap(res.data?['monitoring']),
          nextPingSeconds: _asInt(res.data?['next_ping_seconds']),
        );
      }
    } catch (_) {
      if (pendingPayload != null) {
        await _queuePendingLocationPing(pendingPayload);
      }
    } finally {
      _locationPingInFlight = false;
    }
  }

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

  String _fmtHour(double h) {
    final isInt = h == h.truncateToDouble();
    return isInt ? '${h.toInt()} ساعة' : '${h.toStringAsFixed(1)} ساعة';
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
      _shiftWindowStart = null;
      _shiftWindowEnd = null;
      _withinShift = true;
      _currentShiftName = null;
      _shiftAssignmentLocationName = null;
      _shiftMatchesLocation = true;
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
      Map<String, dynamic>? cachedMonitoring;
      DateTime? cachedShiftStart;
      DateTime? cachedShiftEnd;
      bool? cachedWithinShift;
      final dataRaw = map['data'];
      if (dataRaw is Map) {
        cachedData = Map<String, dynamic>.from(dataRaw as Map);
        cachedMonitoring = _asMap(cachedData['monitoring']);
        cachedShiftStart = _parseShiftInstant(cachedData['shift_window_start']);
        cachedShiftEnd = _parseShiftInstant(cachedData['shift_window_end']);
        cachedWithinShift = _asBool(cachedData['within_shift']);
      }
      cachedShiftStart ??= _parseShiftInstant(map['shift_window_start']);
      cachedShiftEnd ??= _parseShiftInstant(map['shift_window_end']);
      cachedWithinShift ??= _asBool(map['within_shift']);

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
      _applyShiftWindow(
        start: cachedShiftStart,
        end: cachedShiftEnd,
        withinShift: cachedWithinShift,
      );
      setState(() {
        _lastAction = action;
        _checkedIn = action == 'check_in';
        _time = parsedTime;
        _lastServerMessage = map['message']?.toString();
        final locName = map['location_name']?.toString();
        if (locName != null && locName.isNotEmpty) {
          _locationName = locName;
        }
        final clientName = map['client_name']?.toString();
        if (clientName != null && clientName.isNotEmpty) {
          _clientName = clientName;
        }
        _lastData = cachedData;
        _shiftWindowStart = cachedShiftStart;
        _shiftWindowEnd = cachedShiftEnd;
        if (cachedWithinShift != null) {
          _withinShift = cachedWithinShift!;
        }
      });
      if (cachedMonitoring != null) {
        _applyMonitoringConfig(cachedMonitoring);
      }
      final cachedShift = cachedData?['shift'] is Map ? Map<String, dynamic>.from(cachedData!['shift'] as Map) : null;
      if (cachedShift != null) {
        _currentShiftName = cachedShift['name']?.toString();
        _shiftAssignmentLocationName = cachedShift['assignment_location_name']?.toString();
        _shiftMatchesLocation = _asBool(cachedShift['matches_location']) ?? true;
      }
    } catch (_) {
      await _clearPersistedAttendanceState();
      _resetAttendanceState();
    }
  }

  Future<void> _refreshLastAttendanceFromServer({bool showFeedback = false}) async {
    if (!mounted || _latestRecordLoading) return;

    setState(() {
      _latestRecordLoading = true;
    });

    try {
      final res = await fetchLatestAttendanceRecord(baseUrl: kBaseUrl);
      if (!mounted) return;

      if (res.ok && res.data != null) {
        final data = Map<String, dynamic>.from(res.data!);
        _applyMonitoringConfig(
          _asMap(data['monitoring']),
          nextPingSeconds: _asInt(data['next_ping_seconds']),
        );
        final message = () {
          final detail = data['detail'] ?? data['message'];
          if (detail is String && detail.trim().isNotEmpty) {
            return detail.trim();
          }
          final fallback = res.message.trim();
          return fallback.isNotEmpty ? fallback : null;
        }();

        final action = _normalizeAction(
              data['action']?.toString() ??
              data['attendance_action']?.toString() ??
              data['type']?.toString(),
            ) ??
            _lastAction;

        final recordedRaw = data['recorded_at'] ??
            data['timestamp'] ??
            data['time'] ??
            data['checked_at'] ??
            data['created_at'];
        final recordedAt = _tryParseDateTime(recordedRaw);
        final checkInAt = _tryParseDateTime(data['check_in_time']);
        final checkOutAt = _tryParseDateTime(data['check_out_time']);
        final effectiveTime = recordedAt ?? checkOutAt ?? checkInAt;
        final now = DateTime.now();
        final isToday = effectiveTime != null && _isSameDay(effectiveTime, now);
        final monitoringMap = _asMap(data['monitoring']);
        final monitoringActiveRaw = _asBool(monitoringMap?['active']);
        final monitoringActive = monitoringActiveRaw ?? true;
        final serverShouldMonitor = _asBool(data['should_monitor_location']) ?? monitoringActive;
        final shiftData = _asMap(data['shift']);
        final shiftName = shiftData?['name']?.toString();
        final shiftAssignmentLocation = shiftData?['assignment_location_name']?.toString();
        final shiftMatchesLocation = _asBool(shiftData?['matches_location']);
        final shiftStartPrimary = _parseShiftInstant(data['shift_window_start']);
        final shiftEndPrimary = _parseShiftInstant(data['shift_window_end']);
        final shiftStart = _parseShiftInstant(shiftData?['window_start']) ?? shiftStartPrimary;
        final shiftEnd = _parseShiftInstant(shiftData?['window_end']) ?? shiftEndPrimary;
        bool withinShiftFlag = true;
        final rawWithinShiftShift = _asBool(shiftData?['within_shift']);
        if (rawWithinShiftShift != null) {
          withinShiftFlag = rawWithinShiftShift;
        } else {
          final rawWithinShift = data['within_shift'];
          if (rawWithinShift is bool) {
            withinShiftFlag = rawWithinShift;
          } else if (rawWithinShift is String) {
            withinShiftFlag = rawWithinShift.trim().toLowerCase() != 'false';
          }
        }

        if (effectiveTime == null || !isToday) {
          if (!mounted) return;
          _applyShiftWindow(
            start: shiftStart,
            end: shiftEnd,
            withinShift: withinShiftFlag,
          );
          setState(() {
            _lastData = null;
            _lastAction = null;
            _checkedIn = false;
            _time = null;
            _lastServerMessage = 'لم يتم تسجيل حضور اليوم. يرجى تسجيل الحضور.';
            _currentShiftName = shiftName;
            _shiftAssignmentLocationName = shiftAssignmentLocation;
            _shiftMatchesLocation = shiftMatchesLocation ?? true;
            _lastRefreshAt = DateTime.now();
          });
          await _clearPersistedAttendanceState();
          _updateLocationMonitoring(false);
          if (showFeedback && mounted) {
            _toast('لم يتم العثور على تسجيل حضور لليوم الحالي.');
          }
          return;
        }

        final locName = (data['location_name'] ?? data['location'] ?? data['location_label'])?.toString();
        final clientName = (data['client_name'] ?? data['client'])?.toString();

        setState(() {
          _lastData = data;
          if (message != null && message.isNotEmpty) {
            _lastServerMessage = message;
          } else if (res.message.trim().isNotEmpty) {
            _lastServerMessage = res.message.trim();
          }
          if (action != null) {
            _lastAction = action;
            _checkedIn = action == 'check_in';
          }
          if (effectiveTime != null) {
            _time = effectiveTime;
          }
          if (locName != null && locName.trim().isNotEmpty) {
            _locationName = locName.trim();
          }
          if (clientName != null && clientName.trim().isNotEmpty) {
            _clientName = clientName.trim();
          }
          _shiftWindowStart = shiftStart;
          _shiftWindowEnd = shiftEnd;
          _withinShift = withinShiftFlag;
          _currentShiftName = shiftName;
          _shiftAssignmentLocationName = shiftAssignmentLocation;
          _shiftMatchesLocation = shiftMatchesLocation ?? true;
          _lastRefreshAt = DateTime.now();
        });

        bool hasCheckOut = false;
        final rawCheckOut = data['check_out_time'];
        if (rawCheckOut is String) {
          hasCheckOut = rawCheckOut.trim().isNotEmpty;
        } else if (rawCheckOut != null) {
          hasCheckOut = true;
        }
        final shouldTrack = monitoringActive && (serverShouldMonitor || (isToday && withinShiftFlag && action == 'check_in' && !hasCheckOut));
        _updateLocationMonitoring(shouldTrack);

        if (action != null) {
          await _persistLastAttendanceState(
            action: action,
            timestamp: effectiveTime,
            message: _lastServerMessage,
            data: data,
          );
        }

        if (showFeedback && mounted) {
          _toast('تم تحديث آخر تسجيل.');
        }
      } else {
        if (!res.ok) {
          final dataMap = res.data;
          final detail = dataMap?['detail']?.toString().toLowerCase() ?? '';
          final messageText = res.message.toLowerCase();
          final mentionsNoAttendance = detail.contains('حضور') || messageText.contains('حضور');
          if (mentionsNoAttendance || (dataMap != null && dataMap.containsKey('latest_record_id'))) {
            _updateLocationMonitoring(false);
          }
        }
        if (showFeedback && res.message.trim().isNotEmpty && mounted) {
          _toast(res.message.trim());
        } else if (!res.ok && res.message.trim().isNotEmpty && mounted && _lastServerMessage == null) {
          setState(() {
            _lastServerMessage = res.message.trim();
          });
        }
        _applyMonitoringConfig(
          _asMap(res.data?['monitoring']),
          nextPingSeconds: _asInt(res.data?['next_ping_seconds']),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _latestRecordLoading = false;
          _lastRefreshAt ??= DateTime.now();
        });
      }
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// يتأكد من أن خدمة الموقع مفعّلة وأن التطبيق لديه الصلاحية؛ يفتح الإعدادات عند الحاجة
  Future<bool> _ensureLocationEnabled() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // إذا كانت الخدمة غير مفعّلة، نوجّه المستخدم إلى الإعدادات
      try {
        await Geolocator.openLocationSettings();
      } catch (_) {}
      _toast('يرجى تفعيل خدمة الموقع (GPS) من إعدادات الجهاز ثم المحاولة مرة أخرى.');
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
      // الصلاحية مرفوضة دائمًا: افتح إعدادات التطبيق
      try {
        await Geolocator.openAppSettings();
      } catch (_) {}
      _toast('يرجى منح صلاحية الموقع للتطبيق من الإعدادات.');
      return false;
    }
    return true;
  }

  Future<void> _handleAction(
      String action, {
        String? reason,
        File? attachment,
        BiometricAuthResult? biometricResult,
      }) async {
    if (!_canPerformAttendanceActions) {
      _toast('خارج الوردية المحددة، لا يمكن تنفيذ العملية الآن.');
      return;
    }
    // تأكد من تفعيل الموقع وصلاحياته قبل المتابعة
    final canProceed = await _ensureLocationEnabled();
    if (!canProceed) return;
    final token = await ApiService.getAccessToken();
    if (token == null || token.isEmpty) {
      _toast('يرجى تسجيل الدخول أولاً.');
      return;
    }

    final result = biometricResult ?? await BiometricAuthService().authenticateUserWithRetries();
    if (!result.biometricVerified) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التحقق البيومتري بعد ${result.attempts} محاولات')),
      );
      return;
    }
    // سيتم تحديد الموقع تلقائيًا قبل كل عملية حضور/انصراف

    setState(() => _loading = true);
    try {
      // نلتقط أفضل إحداثيات
      final pos = await getBestFix();

      // نحدد الموقع المكلّف به تلقائيًا عبر الـ API (مع قبول الخروج عن النطاق)
      final auto = await resolveMyLocation(
        baseUrl: kBaseUrl,
        token: token,
        lat: pos.latitude,
        lng: pos.longitude,
        accuracy: pos.accuracy,
      );

      Map<String, dynamic>? resolved = auto.data;
      String? resolvedLocationId =
          resolved != null ? resolved['location_id']?.toString() : null;
      bool withinRadius = true;
      double? distanceMeters;
      double? allowedRadius;
      String? resolvedName;
      String? resolvedClient;
      if (resolved != null) {
        withinRadius = !(resolved['within_radius'] == false);
        final dist = resolved['distance'];
        if (dist is num) distanceMeters = dist.toDouble();
        final radiusVal = resolved['radius'];
        if (radiusVal is num) allowedRadius = radiusVal.toDouble();
        resolvedName = resolved['name']?.toString();
        resolvedClient = resolved['client_name']?.toString();
      }
      final forceLocationPing = resolved != null && resolved['within_radius'] == false;

      String? locId = resolvedLocationId ?? _locationId;
      if (locId == null) {
        final msg = auto.message.trim();
        _toast(msg.isNotEmpty
            ? 'تعذر تحديد موقع العمل. يرجى مراجعة مشرفك لإسناد الموقع.'
            : 'لا يوجد موقع مخصص لك حالياً، لا يمكن متابعة العملية.');
        return;
      }
      // حدّث معلومات الموقع والعميل من الرد
      setState(() {
        _locationId = locId;
        if (resolvedName != null && resolvedName.isNotEmpty) {
          _locationName = resolvedName;
        }
        final cName = resolvedClient;
        if (cName != null && cName.isNotEmpty) {
          _clientName = cName;
        }
      });

      final usedLocId = locId;

      if (!withinRadius) {
        final distText = distanceMeters != null
            ? '${distanceMeters!.toStringAsFixed(1)}م'
            : 'خارج النطاق';
        final radiusText = allowedRadius != null
            ? '${allowedRadius!.toStringAsFixed(0)}م'
            : 'النطاق المحدد';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'تنبيه: أنت خارج نطاق الموقع (${distText} مقابل السماح ${radiusText}). سيتم إرسال مخالفة تلقائيًا إذا استمر الابتعاد.'),
            ),
          );
        }
      }

      if (forceLocationPing) {
        await sendLocationPing(
          baseUrl: kBaseUrl,
          token: token,
          pos: pos,
          accuracyOverride: pos.accuracy,
          recordedAt: DateTime.now().toUtc(),
        ).catchError((_) {});
      }

      final res = await sendAttendanceWithPosition(
        baseUrl: kBaseUrl,
        token: token,
        locationId: usedLocId,
        action: action,
        pos: pos,
        earlyReason: reason,
        earlyAttachment: attachment,
        biometricVerified: result.biometricVerified,
        biometricMethod: result.method,
        biometricAttempts: result.attempts,
      );
      if (res.ok) {
        final data = res.data;
        final responseAction = data?['action']?.toString();
        final canonicalAction =
            _normalizeAction(responseAction) ?? _normalizeAction(action) ?? action;
        final recordedRaw = data?['recorded_at'] ??
            data?['timestamp'] ??
            data?['time'] ??
            data?['checked_at'];
        final recordedAt = _tryParseDateTime(recordedRaw);
        if (data != null) {
          _applyMonitoringConfig(
            _asMap(data['monitoring']),
            nextPingSeconds: _asInt(data['next_ping_seconds']),
          );
        }
        setState(() {
          _checkedIn = (canonicalAction == 'check_in');
          _lastAction = canonicalAction;
          _time = recordedAt ?? DateTime.now();
          _lastServerMessage = res.message;
          _lastData = data;
          _lastRefreshAt = DateTime.now();

          // حدّث معلومات الموقع من الرد الرئيسي أيضًا
          if (data != null) {
            final locName = data['location_name']?.toString();
            if (locName != null && locName.isNotEmpty) {
              _locationName = locName;
            }
            final clientName = data['client_name']?.toString();
            if (clientName != null && clientName.isNotEmpty) {
              _clientName = clientName;
            }
          }
        });
        await _persistLastAttendanceState(
          action: canonicalAction,
          timestamp: _time ?? DateTime.now(),
          message: res.message,
          data: data,
        );
        _updateLocationMonitoring(_checkedIn);
        if (mounted && data != null) {
          final violation = data['violation'] == true;
          final escalated = data['violation_escalated'] == true;
          final reason = (data['violation_reason'] ?? '').toString();
          final duration = data['violation_outside_minutes'];
          if (violation) {
            final msg = StringBuffer();
            if (reason.isNotEmpty) {
              msg.write(reason);
            } else {
              msg.write('تم تسجيل مخالفة موقع.');
            }
            if (duration is num && duration > 0) {
              msg.write(' مدة الابتعاد التقريبية: ${duration.toStringAsFixed(0)} دقيقة.');
            }
            if (escalated) {
              msg.write(' تم إرسال تنبيه للإدارة.');
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg.toString())),
            );
          }
        }
      } else {
        _toast(res.message);
      }
    } catch (e) {
      _toast('خطأ غير متوقع: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> checkIn() async {
    BiometricAuthService biometricService = BiometricAuthService();
    final result = await biometricService.authenticateUserWithRetries();

    if (!result.biometricVerified) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التحقق البيومتري بعد ${result.attempts} محاولات')),
      );
      return;
    }

    await _handleAction(
      "check_in",
      biometricResult: result,
    );
  }

  Future<void> checkOut() async {
    BiometricAuthService biometricService = BiometricAuthService();
    final result = await biometricService.authenticateUserWithRetries();

    if (!result.biometricVerified) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التحقق البيومتري بعد ${result.attempts} محاولات')),
      );
      return;
    }

    await _handleAction(
      "check_out",
      biometricResult: result,
    );
  }

  Future<void> _openEarlyCheckoutDialog() async {
    final reasonController = TextEditingController();
    File? attachment;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
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
                          setState(() { /* لإعادة بناء الـ AlertDialog ضمن السياق الأب */ });
                          attachment = File(picked.path);
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
                          setState(() {});
                          attachment = File(picked.path);
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
                  _toast('الرجاء كتابة السبب.');
                  return;
                }
                Navigator.pop(ctx, true);
              },
            ),
          ],
        );
      },
    );

    if (ok == true) {
      await _handleAction("early_check_out",
          reason: reasonController.text.trim(), attachment: attachment);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shiftLocked = !_canPerformAttendanceActions;
    final shiftStartStr = _shiftWindowStart != null ? DateFormat('HH:mm').format(_shiftWindowStart!) : null;
    final shiftEndStr = _shiftWindowEnd != null ? DateFormat('HH:mm').format(_shiftWindowEnd!) : null;

    return RefreshIndicator(
      onRefresh: () => _bootstrap(forceEmployeeRefresh: true),
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
          if (!_unrestricted && (_shiftWindowStart != null || _shiftWindowEnd != null))
            Card(
              child: ListTile(
                leading: const Icon(Icons.schedule),
                title: Text('نافذة الوردية${_currentShiftName != null ? ' — ${_currentShiftName!}' : ''}'),
                subtitle: Text(
                  '${shiftStartStr ?? '--'} → ${shiftEndStr ?? '--'}',
                ),
                trailing: shiftLocked
                    ? const Icon(Icons.lock_clock, color: Colors.redAccent)
                    : const Icon(Icons.lock_open, color: Colors.green),
              ),
            ),
          if (_shiftAssignmentLocationName != null &&
              _locationName != null &&
              _shiftAssignmentLocationName!.trim().isNotEmpty &&
              _locationName!.trim().isNotEmpty &&
              !_shiftMatchesLocation)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.warning_amber_rounded),
                title: const Text('تنبيه اختلاف الموقع'),
                subtitle: Text(
                  'الوردية الحالية مرتبطة بالموقع: ${_shiftAssignmentLocationName!}. الموقع المحدد الآن: ${_locationName!}. يرجى التأكد من اختيار الموقع الصحيح.',
                ),
              ),
            ),
          if (shiftLocked && !_unrestricted)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: const ListTile(
                leading: Icon(Icons.error_outline),
                title: Text('خارج الوردية الحالية'),
                subtitle: Text('لا يمكن تنفيذ عمليات الحضور أو الانصراف قبل بدء الوردية أو بعد انتهائها.'),
              ),
            ),
          _buildAttendanceSummaryCard(context),
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
                  onPressed: (_checkedIn || _loading || !_canPerformAttendanceActions)
                      ? null
                      : () => checkIn(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text("تسجيل الانصراف"),
                  onPressed: (!_checkedIn || _loading || !_canPerformAttendanceActions)
                      ? null
                      : () => checkOut(),
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
              onPressed: (_loading || !_canPerformAttendanceActions) ? null : _openEarlyCheckoutDialog,
            ),
          ),
          if (_loading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_latestRecordLoading || _lastServerMessage != null || _lastData != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "تفاصيل آخر تسجيل:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'تحديث',
                          onPressed: _latestRecordLoading
                              ? null
                              : () => _refreshLastAttendanceFromServer(showFeedback: true),
                        ),
                      ],
                    ),
                    if (_latestRecordLoading) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(),
                    ],
                    if (_lastServerMessage != null) ...[
                      if (!_latestRecordLoading) const SizedBox(height: 8),
                      Text(_lastServerMessage!),
                    ],
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
        if (rawName != null && rawName.trim().isNotEmpty) {
          names.add(rawName.trim());
        }
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

  Color _statusAccentColor(String? actionKey, ColorScheme cs) {
    switch (actionKey) {
      case 'check_in':
        return cs.primary;
      case 'check_out':
        return cs.secondary;
      case 'early_check_out':
        return cs.error;
      default:
        return cs.outlineVariant;
    }
  }

  Widget _buildInfoChip(ColorScheme cs, IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16, color: cs.onSurfaceVariant),
      label: Text(
        label,
        style: TextStyle(color: cs.onSurfaceVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: cs.surfaceVariant.withOpacity(0.6),
    );
  }

  Widget _buildAttendanceSummaryCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final normalized = _normalizeAction(_lastAction) ?? (_checkedIn ? 'check_in' : null);
    final statusTitle = _statusLabelFor(normalized) ?? 'لم يتم تسجيل أي إجراء بعد';
    final statusIcon = _statusIconFor(normalized);
    final accent = _statusAccentColor(normalized, cs);
    final serverMessage = (_lastServerMessage ?? '').trim();
    final displayMessage = serverMessage.isNotEmpty && serverMessage != statusTitle
        ? serverMessage
        : null;
    final recordedAtLabel = _time != null ? DateFormat('yyyy/MM/dd – HH:mm').format(_time!) : null;
    final lastRefreshLabel =
        _lastRefreshAt != null ? DateFormat('HH:mm:ss').format(_lastRefreshAt!) : null;
    final refreshText = 'آخر تحديث: ${lastRefreshLabel ?? '--:--:--'}';

    final chips = <Widget>[];
    if (_locationName?.trim().isNotEmpty ?? false) {
      chips.add(_buildInfoChip(cs, Icons.place_outlined, _locationName!.trim()));
    } else if (_locationsSummary?.trim().isNotEmpty ?? false) {
      chips.add(_buildInfoChip(cs, Icons.place_outlined, _locationsSummary!.trim()));
    }
    if (_clientName?.trim().isNotEmpty ?? false) {
      chips.add(_buildInfoChip(cs, Icons.apartment_outlined, _clientName!.trim()));
    }
    if (_currentShiftName?.trim().isNotEmpty ?? false) {
      chips.add(_buildInfoChip(cs, Icons.badge_outlined, _currentShiftName!.trim()));
    }
    if (_shiftWindowStart != null || _shiftWindowEnd != null) {
      final startStr =
          _shiftWindowStart != null ? DateFormat('HH:mm').format(_shiftWindowStart!) : '--';
      final endStr = _shiftWindowEnd != null ? DateFormat('HH:mm').format(_shiftWindowEnd!) : '--';
      chips.add(_buildInfoChip(cs, Icons.schedule, '$startStr → $endStr'));
    }
    if (_shiftMatchesLocation == false && _shiftAssignmentLocationName?.trim().isNotEmpty == true) {
      chips.add(_buildInfoChip(
        cs,
        Icons.warning_amber_rounded,
        'موقع الوردية: ${_shiftAssignmentLocationName!.trim()}',
      ));
    }
    final recordId = _lastData?['record_id']?.toString() ?? _lastData?['id']?.toString();
    if (recordId != null && recordId.isNotEmpty) {
      chips.add(_buildInfoChip(cs, Icons.confirmation_number_outlined, '#$recordId'));
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: AlignmentDirectional.topEnd,
            end: AlignmentDirectional.bottomStart,
            colors: [
              accent.withOpacity(0.12),
              cs.surface,
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: accent.withOpacity(0.18),
                  foregroundColor: accent,
                  child: Icon(statusIcon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusTitle,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (recordedAtLabel != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'وقت التسجيل: $recordedAtLabel',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      if (displayMessage != null)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            displayMessage,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (_latestRecordLoading)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chips,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  refreshText,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _latestRecordLoading
                      ? null
                      : () => _refreshLastAttendanceFromServer(showFeedback: true),
                  icon: const Icon(Icons.sync),
                  label: const Text('تحديث'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
        if (_shiftWindowStart != null) 'shift_window_start': _shiftWindowStart!.toUtc().toIso8601String(),
        if (_shiftWindowEnd != null) 'shift_window_end': _shiftWindowEnd!.toUtc().toIso8601String(),
        'within_shift': _withinShift,
      };

      await sp.setString(_kLastAttendanceStateKey, jsonEncode(payload));
    } catch (_) {}
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _stopLocationMonitoring();
    super.dispose();
  }
}
/// تنسيق عرض النتائج بشكل ودّي
class _ResultTable extends StatelessWidget {
  const _ResultTable({required this.map, required this.fmt});
  final Map<String, dynamic> map;
  final String Function(dynamic) fmt;

  @override
  Widget build(BuildContext context) {
    final recId = map['record_id'];
    final employee = map['employee'];
    final location = map['location'];
    final client = map['client_name'];
    final detail = map['detail'];
    final note = map['note'];
    final un = map['unrestricted'] == true;
    final sws = map['shift_window_start'];
    final swe = map['shift_window_end'];
    final recordedAt = map['recorded_at'];
    final checkIn = map['check_in_time'];
    final checkOut = map['check_out_time'];
    final actionRaw = map['attendance_action'] ?? map['action'] ?? map['type'];
    final monitorRaw = map['should_monitor_location'];
    final violationRaw = map['violation'];
    final lastPing = map['last_location_ping'];
    final isTodayRaw = map['is_today'];
    Map<String, dynamic>? shift = map['shift'] is Map
        ? Map<String, dynamic>.from(map['shift'] as Map)
        : null;

    String? actionLabel(String? raw) {
      if (raw == null) return null;
      switch (raw) {
        case 'check_in':
          return 'تسجيل الحضور';
        case 'check_out':
          return 'تسجيل الانصراف';
        case 'early_check_out':
          return 'انصراف مبكر';
        default:
          return raw;
      }
    }

    bool? asBool(dynamic value) {
      if (value is bool) return value;
      if (value is String) {
        final lower = value.trim().toLowerCase();
        if (lower == 'true') return true;
        if (lower == 'false') return false;
      }
      return null;
    }

    String _formatBoolLabel(bool? value, {String trueLabel = 'نعم', String falseLabel = 'لا'}) {
      if (value == null) return '-';
      return value ? trueLabel : falseLabel;
    }

    final actionText = actionLabel(actionRaw?.toString());
    final isTodayFlag = asBool(isTodayRaw);
    final monitorFlag = asBool(monitorRaw);
    final violationFlag = asBool(violationRaw);
    final violationReason = map['violation_reason']?.toString();
    final shiftName = shift?['name']?.toString();
    final shiftLocation = shift?['assignment_location_name']?.toString();
    final shiftMatches = asBool(shift?['matches_location']);
    final shiftWindowStart = shift?['window_start'] ?? sws;
    final shiftWindowEnd = shift?['window_end'] ?? swe;

    final rows = <_KV>[
      if (detail != null) _KV('الرسالة', detail),
      if (note != null && note.toString().trim().isNotEmpty) _KV('ملاحظة', note),
      if (actionText != null) _KV('آخر إجراء', actionText),
      if (recordedAt != null) _KV('وقت التسجيل', fmt(recordedAt)),
      if (checkIn != null) _KV('وقت الحضور', fmt(checkIn)),
      if (checkOut != null) _KV('وقت الانصراف', fmt(checkOut)),
      if (employee != null) _KV('الموظف', employee),
      if (location != null) _KV('الموقع', location),
      if (client != null) _KV('العميل', client),
      if (recId != null) _KV('رقم السجل', recId),
      if (isTodayFlag != null) _KV('ينتمي لليوم', _formatBoolLabel(isTodayFlag)),
      if (shiftName != null && shiftName.trim().isNotEmpty) _KV('الوردية', shiftName),
      if (shiftLocation != null && shiftLocation.trim().isNotEmpty) _KV('موقع الوردية', shiftLocation),
      if (shiftMatches != null) _KV('الوردية للموقع الحالي', _formatBoolLabel(shiftMatches, trueLabel: 'متطابقة', falseLabel: 'مختلفة')),
      _KV('نوع الوردية', un ? 'غير مقيّدة' : 'مقيّدة'),
      if (!un) _KV('نافذة الوردية', '${fmt(shiftWindowStart ?? sws)} → ${fmt(shiftWindowEnd ?? swe)}'),
      if (monitorFlag != null)
        _KV('تتبع الموقع', monitorFlag ? 'مفعّل أثناء الوردية' : 'غير مفعّل'),
      if (map['violation_warning_minutes'] != null)
        _KV('مدة السماح للمخالفة (دقائق)', map['violation_warning_minutes'].toString()),
      if (map['next_ping_seconds'] != null)
        _KV('الفاصل الحالي (ثواني)', map['next_ping_seconds'].toString()),
      if (violationFlag == true)
        _KV(
          'مخالفة',
          (violationReason != null && violationReason.trim().isNotEmpty)
              ? violationReason.trim()
              : 'تم تسجيل مخالفة الموقع.',
        ),
    ];

    if (lastPing is Map) {
      final pingTime = lastPing['recorded_at_local'] ?? lastPing['recorded_at'];
      final withinRadius = asBool(lastPing['within_radius']);
      final triggered = asBool(lastPing['violation_triggered']);
      final distance = lastPing['distance_m'];
      if (pingTime != null) {
        rows.add(_KV('آخر تتبع', fmt(pingTime)));
      }
      if (distance is num) {
        rows.add(_KV('المسافة (م)', distance.toStringAsFixed(1)));
      } else if (distance != null) {
        rows.add(_KV('المسافة (م)', distance.toString()));
      }
      if (withinRadius != null) {
        rows.add(_KV('حالة الموقع', withinRadius ? 'داخل النطاق' : 'خارج النطاق'));
      }
      if (triggered == true) {
        rows.add(_KV('تنبيه مخالفة', 'تم إطلاق مخالفة الموقع.'));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows
          .map((e) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(width: 120, child: Text('${e.k}:', style: const TextStyle(fontWeight: FontWeight.w600))),
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
