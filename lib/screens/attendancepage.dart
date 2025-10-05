import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import 'package:shared_preferences/shared_preferences.dart';


import '../services/api.dart';  // لو عندك AppSettings (الثيم/اللغة)

import 'package:intl/intl.dart';


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
  bool _checkedIn = false;
  DateTime? _time;
  bool _loading = false;

  String? _locationId;      // UUID نص
  String? _locationName;    // اسم الموقع
  String? _clientName;      // اسم العميل المرتبط بالموقع
  String? _lastServerMessage;
  Map<String, dynamic>? _lastData;

  // قائمة المواقع المتاحة للحارس (لمعرّفات وأسماء وعملاء) لاختيارها يدويًا
  List<dynamic> _locations = [];

  // عرض حالة “غير مقيّدة” + تلميح نصي
  bool _unrestricted = false;
  String? _shiftHint; // نص موجز عن النافذة/السماحا

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = await ApiService.getAccessToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    await _checkCurrentAttendanceStatus();

    // من الكاش
    final emp = await ApiService.ensureEmployeeCached();
    if (emp != null && emp.locations != null && emp.locations!.isNotEmpty) {
      // استخدم أول موقع مخصّص للحارس لتعبئة الاسم والمعرّف واسم العميل إن وجد
      final firstLoc = emp.locations!.first;
      setState(() {
        _locationId = firstLoc.id?.toString();
        _locationName = firstLoc.name;
        // خزّن كل المواقع المتاحة لاستخدامها في اختيار يدوي لاحقًا
        try {
          final locs = emp.locations;
          if (locs != null) {
            // إزالة العناصر المكررة وفقًا للمعرّف لتجنب ظهور عناصر ذات نفس القيمة في DropdownButton
            final List<dynamic> uniques = [];
            final Set<String> seenIds = {};
            for (final loc in locs) {
              try {
                final dyn = loc as dynamic;
                final id = (dyn.id ?? dyn['id']).toString();
                if (!seenIds.contains(id)) {
                  seenIds.add(id);
                  uniques.add(loc);
                }
              } catch (_) {
                // عند الخطأ نتجاهل هذا الموقع
              }
            }
            _locations = uniques;
          }
        } catch (_) {}
        try {
          final dyn = firstLoc as dynamic;
          final cName = (dyn.client_name ?? dyn.clientName);
          if (cName != null && cName.toString().isNotEmpty) {
            _clientName = cName.toString();
          }
        } catch (_) {}
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
      } catch (_) {}
    } else {
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
      } catch (e) {
        _toast('خطأ في تحديد الموقع: $e');
      }
      await _loadUnrestrictedFromCache();
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

  Future<void> _checkCurrentAttendanceStatus() async {
    // حتى الآن: نفترض لا يوجد سجل مفتوح
    setState(() {
      _checkedIn = false;
      _time = null;
    });
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
      }) async {
    // تأكد من تفعيل الموقع وصلاحياته قبل المتابعة
    final canProceed = await _ensureLocationEnabled();
    if (!canProceed) return;
    final token = await ApiService.getAccessToken();
    if (token == null || token.isEmpty) {
      _toast('يرجى تسجيل الدخول أولاً.');
      return;
    }
    // سيتم تحديد الموقع تلقائيًا قبل كل عملية حضور/انصراف

    setState(() => _loading = true);
    try {
      // نلتقط أفضل إحداثيات
      final pos = await getBestFix();

      // نحدد الموقع المكلّف به تلقائيًا عبر الـ API
      final auto = await resolveMyLocation(
        baseUrl: kBaseUrl,
        token: token,
        lat: pos.latitude,
        lng: pos.longitude,
        accuracy: pos.accuracy,
      );

      String? locId;
      if (auto.ok && auto.data != null && auto.data!['location_id'] != null) {
        locId = auto.data!['location_id']?.toString();
        // حدّث معلومات الموقع والعميل من الرد
        setState(() {
          _locationId = locId;
          final nm = auto.data!['name']?.toString();
          if (nm != null && nm.isNotEmpty) _locationName = nm;
          final cName = auto.data!['client_name']?.toString();
          if (cName != null && cName.isNotEmpty) _clientName = cName;
        });
      }

      // إذا لم نستطع تحديد الموقع تلقائيًا ولا يوجد موقع مخزن مسبقًا، نعرض رسالة وننهي
      if (locId == null && _locationId == null) {
        _toast('لم يتم تحديد موقع العمل تلقائيًا: ${auto.message}');
        return;
      }

      // اختر المعرف إما من الرد أو من القيمة الحالية
      final usedLocId = locId ?? _locationId!;

      final res = await sendAttendanceWithPosition(
        baseUrl: kBaseUrl,
        token: token,
        locationId: usedLocId,
        action: action,
        pos: pos,
        earlyReason: reason,
        earlyAttachment: attachment,
      );

      if (res.ok) {
        setState(() {
          _checkedIn = (action == 'check_in');
          _time = DateTime.now();
          _lastServerMessage = res.message;
          _lastData = res.data;

          // حدّث معلومات الموقع من الرد الرئيسي أيضًا
          final data = res.data;
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
      } else {
        _toast(res.message);
      }
    } catch (e) {
      _toast('خطأ غير متوقع: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
    final timeStr = _time == null ? null : DateFormat.Hm().format(_time!);

    return ListView(
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
                    Icon(_checkedIn ? Icons.login : Icons.logout, size: 36, color: cs.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _checkedIn ? "تم تسجيل الحضور" : "تم تسجيل الانصراف",
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
                // عرض اسم العميل المرتبط بالموقع إن وجد
                if (_clientName != null && _clientName!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text('العميل: $_clientName',
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                // اختيار الموقع يدويًا من قائمة المواقع المتاحة
                // تم إيقاف الاختيار اليدوي ليكون التحديد تلقائيًا دومًا
                if (false && _locations.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Builder(
                      builder: (context) {
                        // حدد القيمة المختارة فقط إذا كانت موجودة ضمن العناصر
                        String? selectedValue = _locationId;
                        if (_locationId != null) {
                          bool exists = false;
                          for (final loc in _locations) {
                            try {
                              final dyn = loc as dynamic;
                              final id  = (dyn.id ?? dyn['id']).toString();
                              if (id == _locationId) {
                                exists = true;
                                break;
                              }
                            } catch (_) {}
                          }
                          if (!exists) selectedValue = null;
                        }
                        // بُنية العناصر في القائمة: إزالة أي تكرار بالقيمة نفسها
                        final Map<String, dynamic> uniqueMap = {};
                        for (final loc in _locations) {
                          try {
                            final dyn = loc as dynamic;
                            final id = (dyn.id ?? dyn['id']).toString();
                            uniqueMap[id] = loc;
                          } catch (_) {
                            // تجاهل العناصر غير الصالحة
                          }
                        }
                        final List<DropdownMenuItem<String>> items = uniqueMap.entries.map((e) {
                          final loc = e.value;
                          try {
                            final dyn = loc as dynamic;
                            final name = (dyn.name ?? dyn['name'])?.toString() ?? '';
                            return DropdownMenuItem<String>(value: e.key, child: Text(name));
                          } catch (_) {
                            return const DropdownMenuItem<String>(value: null, child: Text('خطأ'));
                          }
                        }).toList();

                        // إذا كانت القيمة الحالية غير موجودة ضمن العناصر، نعطي null
                        final currentVal = (selectedValue != null && uniqueMap.containsKey(selectedValue)) ? selectedValue : null;

                        return DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'اختر الموقع يدويًا',
                            border: OutlineInputBorder(),
                          ),
                          value: currentVal,
                          items: items,
                          onChanged: (val) {
                            if (val == null) return;
                            final sel = uniqueMap[val];
                            setState(() {
                              _locationId = val;
                              try {
                                final dyn = sel as dynamic;
                                _locationName = (dyn.name ?? dyn['name'])?.toString();
                                final cName = (dyn.client_name ?? dyn['client_name'] ?? dyn.clientName ?? dyn['clientName']);
                                if (cName != null && cName.toString().isNotEmpty) {
                                  _clientName = cName.toString();
                                }
                              } catch (_) {}
                            });
                          },
                        );
                      },
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
    );
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
