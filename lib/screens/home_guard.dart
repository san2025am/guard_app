
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';

import '../app_settings.dart';
import '../models/employee.dart';
import '../services/api.dart';  // لو عندك AppSettings (الثيم/اللغة)



import 'attendancepage.dart';




class HomeGuard extends StatelessWidget {
  static const route = '/home';
  const HomeGuard({super.key});

  @override
  Widget build(BuildContext context) => const HomeGuardScreen();
}

class HomeGuardScreen extends StatefulWidget {
  const HomeGuardScreen({super.key});

  @override
  State<HomeGuardScreen> createState() => _HomeGuardScreenState();
}

class _HomeGuardScreenState extends State<HomeGuardScreen> {
  int _index = 0;

  final _pages = const [
    GuardProfilePage(),
    AttendancePage(),
    ReportsRequestsPage(),
  ];
  Future<void> _logout(BuildContext context) async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login', // LoginScreen.route
          (route) => false,
    );
  }
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final settings = context.read<AppSettings?>(); // قد يكون null لو ما تستخدم provider
    final isDark = settings?.themeMode == ThemeMode.dark;

    return Scaffold(

      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.person), label: t.profile),
          BottomNavigationBarItem(icon: const Icon(Icons.check_circle), label: t.attendance),
          BottomNavigationBarItem(icon: const Icon(Icons.assignment), label: t.reports_requests),
        ],
      ),
    );
  }
}
// تبويب برفايل الموظف


class GuardProfilePage extends StatefulWidget {
  const GuardProfilePage({super.key});
  @override
  State<GuardProfilePage> createState() => _GuardProfilePageState();
}

class _GuardProfilePageState extends State<GuardProfilePage> {
  EmployeeMe? _emp;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // يحاول جلب من الكاش، وإن لم يجد يجلب من السيرفر ويحفظ
    final e = await ApiService.refreshEmployeeCache();
    setState(() {
      _emp = e;
      _loading = false;
    });
  }

  // ===== Helpers =====
  String _safe(String? s) => (s == null || s.trim().isEmpty) ? '-' : s.trim();

  String _fmt(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '-';
    // إذا التاريخ بصيغة YYYY-MM-DD نعرضه كما هو. لو أردت تحويلًا محليًا أضف intl.
    return isoDate;
  }

  bool _has(String? s) => s != null && s.trim().isNotEmpty;

  Divider _divider() => const Divider(height: 0);

  ListTile _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle.isEmpty ? '-' : subtitle),
      trailing: trailing,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_emp == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.sync_hint),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text(t.sync),
            ),
          ],
        ),
      );
    }

    final e = _emp!;
    final hasEmpInstr = _has(e.employeeInstructions);
    final hasLocInstr = (e.locationInstructions?.where((x) => _has(x)).isNotEmpty) == true;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ===== بطاقة الرأس =====
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: cs.primaryContainer,
                    child: const Icon(Icons.person, size: 36),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (e.fullName.isNotEmpty ? e.fullName : e.username),
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.roleLabel ?? (e.role ?? '-'),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ===== بيانات أساسية =====
          Card(
            child: Column(
              children: [
                _tile(
                  icon: Icons.badge,
                  title: t.role,
                  subtitle: e.roleLabel ?? (e.role ?? '-'),
                ),
                _divider(),
                _tile(
                  icon: Icons.person,
                  title: t.username,
                  subtitle: e.username,
                ),
                if (e.fullName.isNotEmpty) _divider(),
                if (e.fullName.isNotEmpty)
                  _tile(
                    icon: Icons.account_circle,
                    title: t.profile, // أو "الاسم الكامل"
                    subtitle: e.fullName,
                  ),
                if (_has(e.email)) _divider(),
                if (_has(e.email))
                  _tile(
                    icon: Icons.email,
                    title: "البريد الإلكتروني",
                    subtitle: e.email!,
                  ),
                if (_has(e.phoneNumber)) _divider(),
                if (_has(e.phoneNumber))
                  _tile(
                    icon: Icons.phone_android,
                    title: "رقم الجوال",
                    subtitle: e.phoneNumber!,
                  ),
                if (_has(e.nationalId)) _divider(),
                if (_has(e.nationalId))
                  _tile(
                    icon: Icons.credit_card,
                    title: "رقم الهوية",
                    subtitle: e.nationalId!,
                  ),
                if (_has(e.hireDate)) _divider(),
                if (_has(e.hireDate))
                  _tile(
                    icon: Icons.calendar_today,
                    title: "تاريخ التعيين",
                    subtitle: _fmt(e.hireDate),
                  ),

                // الحقول الجديدة: تاريخ الميلاد و انتهاء الهوية
                if (_has(e.dateOfBirthGregorian)) _divider(),
                if (_has(e.dateOfBirthGregorian))
                  _tile(
                    icon: Icons.cake,
                    title: "تاريخ الميلاد",
                    subtitle: _fmt(e.dateOfBirthGregorian),
                  ),
                if (_has(e.idExpiryDate)) _divider(),
                if (_has(e.idExpiryDate))
                  _tile(
                    icon: Icons.event_busy,
                    title: "انتهاء الهوية",
                    subtitle: _fmt(e.idExpiryDate),
                  ),

                // بنكي (اختياري)
                if (_has(e.bankAccount)) _divider(),
                if (_has(e.bankAccount))
                  _tile(
                    icon: Icons.account_balance,
                    title: "الحساب البنكي",
                    subtitle: e.bankAccount!,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ===== بطاقة المشرف =====
          if (_has(e.supervisorName) || _has(e.supervisorPhone))
            Card(
              child: Column(
                children: [
                  _tile(
                    icon: Icons.supervisor_account,
                    title: "المشرف",
                    subtitle: _safe(e.supervisorName),
                    trailing: _has(e.supervisorPhone)
                        ? IconButton(
                      onPressed: () {
                        // يمكنك استخدام url_launcher للاتصال
                        // launchUrl(Uri.parse('tel:${e.supervisorPhone}'));
                      },
                      icon: const Icon(Icons.phone),
                    )
                        : null,
                  ),
                  if (_has(e.supervisorPhone)) _divider(),
                  if (_has(e.supervisorPhone))
                    _tile(
                      icon: Icons.phone,
                      title: "هاتف المشرف",
                      subtitle: e.supervisorPhone!,
                    ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // ===== تعليمات الموظف والمواقع =====
          if (hasEmpInstr || hasLocInstr)
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.rule),
                title: const Text("التعليمات"),
                childrenPadding: const EdgeInsets.only(bottom: 12),
                children: [
                  if (hasEmpInstr)
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text("تعليمات الموظف"),
                      subtitle: Text(_safe(e.employeeInstructions)),
                    ),


                ],
              ),
            ),

          if (e.tasks.isNotEmpty)
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.assignment),
                title: const Text("المهام"),
                subtitle: Text('${e.tasks.length} مهمة'),
                children: e.tasks.map((t) => ListTile(
                  title: Text(t.title),
                  subtitle: Text("${t.description}\nالموقع: ${t.locationName}"),
                  trailing: Text(t.status),
                )).toList(),
              ),
            ),

          if (e.shifts.isNotEmpty)
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.schedule),
                title: const Text("الورديات"),
                subtitle: Text('${e.shifts.length} وردية'),
                children: e.shifts.map((s) => ListTile(
                  title: Text(s.shiftName),
                  subtitle: Text("التاريخ: ${s.date}\nمن ${s.startTime} إلى ${s.endTime}"),
                  trailing: Text(s.active ? "نشطة" : "منتهية"),
                )).toList(),
              ),
            ),


          const SizedBox(height: 12),

          // ===== المواقع المكلف بها =====
          if (e.locations.isNotEmpty)
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.location_on),
                title: const Text("المواقع"),
                subtitle: Text('${e.locations.length} موقع'),
                children: e.locations.map((l) {

                  final hasLInstr = _has(l.instructions);
                  return Column(
                    children: [
                      ListTile(
                        title: Text(l.name),
                        subtitle: Text(_safe(l.clientName)),
                      ),
                      if (hasLInstr)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 16, end: 16, bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.sticky_note_2_outlined, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l.instructions!,
                                  textAlign: TextAlign.start,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Divider(height: 0),
                    ],
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 12),

          // ===== تفاصيل الراتب =====
          Card(
            child: Column(
              children: [
                _tile(
                  icon: Icons.payments,
                  title: "الراتب الأساسي",
                  subtitle: e.salary.baseSalary ?? '-',
                ),
                _divider(),
                _tile(
                  icon: Icons.add,
                  title: "المكافآت",
                  subtitle: e.salary.bonuses ?? '-',
                ),
                _divider(),
                _tile(
                  icon: Icons.access_time,
                  title: "العمل الإضافي",
                  subtitle: e.salary.overtime ?? '-',
                ),
                _divider(),
                _tile(
                  icon: Icons.remove_circle,
                  title: "الخصومات",
                  subtitle: e.salary.deductions ?? '-',
                ),
                _divider(),
                ListTile(
                  leading: const Icon(Icons.calculate),
                  title: const Text("إجمالي الراتب"),
                  subtitle: Text(e.salary.totalSalary ?? '-'),
                  trailing: Text(_safe(e.salary.payDate)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: Text(t.sync),
          ),
        ],
      ),
    );
  }
}






<<<<<<< HEAD
  // جديد: عرض حالة “غير مقيّدة” + تلميح نصي
  bool _unrestricted = false;
  String? _shiftHint; // نص موجز عن النافذة/السماحات لعرضه تحت الأزرار

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

    // جرّب الاستفادة من الكاش لتحديد الموقع وقراءة حالة الوردية/السماحات
    final emp = await ApiService.ensureEmployeeCached();
    if (emp != null && emp.locations != null && emp.locations!.isNotEmpty) {
      setState(() {
        _locationId = emp.locations!.first.id?.toString();
        _locationName = emp.locations!.first.name;
      });
      // قراءة السماحات من الكاش (employee_json) إن كانت متوفرة
      await _loadUnrestrictedFromCache();
      // تعزيز التحديد من الخادم
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
            _locationId = r.data!['location_id'];
            _locationName = (r.data!['name'] ?? _locationName)?.toString();
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
            _locationId = r.data!['location_id']; // UUID
            _locationName = r.data!['name'];
          });
        } else {
          _showSnackBar('لم يتم تحديد موقع العمل تلقائيًا: ${r.message}');
        }
      } catch (e) {
        _showSnackBar('خطأ في تحديد الموقع: $e');
      }
      // حتى لو لم نحدد الموقع، حاول قراءة حالة الوردية من الكاش
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
          hint = 'الوردية غير مقيّدة — يُسمح بالحضور والانصراف في أي وقت.';
          break;
        }

        // إن لم تكن غير مقيّدة: ابنِ تلميحًا موجزًا بالبيانات المتاحة
        final st = (m['start_time'] ?? '').toString();
        final et = (m['end_time'] ?? '').toString();
        final cgi = int.tryParse(m['checkin_grace']?.toString() ?? '');
        final cgo = int.tryParse(m['checkout_grace']?.toString() ?? '');
        final cgh = double.tryParse(m['checkout_grace_hours']?.toString() ?? '');
        final exitText = (cgh != null && cgh > 0)
            ? 'سماح الانصراف: ${_fmtHour(cgh)}'
            : (cgo != null && cgo > 0 ? 'سماح الانصراف: $cgo دقيقة' : 'بدون سماح انصراف');
        final inText = (cgi != null && cgi > 0) ? 'سماح الحضور: $cgi دقيقة' : 'بدون سماح حضور';
        hint = 'الوردية: ${st.isEmpty ? '-' : st} → ${et.isEmpty ? '-' : et} | $inText | $exitText';
        // لا تكسر الحلقة — قد يكون هناك أكثر من تعيين، نكتفي بأول نشط
        break;
      }
      setState(() {
        _unrestricted = anyUn;
        _shiftHint = hint;
      });
    } catch (_) {
      // تجاهل أي خطأ في قراءة الكاش
      setState(() { _unrestricted = false; _shiftHint = null; });
    }
  }

  String _fmtHour(double h) {
    // 1.0 => "1 ساعة" ، 1.5 => "1.5 ساعة"
    final isInt = h == h.truncateToDouble();
    return isInt ? '${h.toInt()} ساعة' : '${h.toStringAsFixed(1)} ساعة';
  }

  Future<void> _checkCurrentAttendanceStatus() async {
    // لا يوجد endpoint بعد — نفترض لا يوجد سجل مفتوح
    setState(() {
      _checkedIn = false;
      _time = null;
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _looksLikeUuid(String? s) {
    if (s == null) return false;
    final re = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$');
    return re.hasMatch(s);
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

  Future<void> _handleAction(String action) async {
    final token = await ApiService.getAccessToken();
    if (token == null || token.isEmpty) {
      _showSnackBar('لا يوجد توكن. سجّل الدخول أولاً.');
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    if (_locationId == null) {
      _showSnackBar('لم يتم تحديد موقع العمل. يرجى التأكد من صلاحيات الموقع أو تحديث الصفحة.');
      return;
    }

    // تأكيد UUID — وإن لم يكن، حاول استنتاجه من الإحداثيات
    String? effectiveLocationId = _locationId;
    if (!_looksLikeUuid(effectiveLocationId)) {
      try {
        final posFix = await getBestFix();
        final r = await resolveMyLocation(
          baseUrl: kBaseUrl,
          token: token,
          lat: posFix.latitude,
          lng: posFix.longitude,
          accuracy: posFix.accuracy,
        );
        if (r.ok && r.data?['location_id'] is String) {
          effectiveLocationId = r.data!['location_id'] as String;
          setState(() {
            _locationId = effectiveLocationId;
            _locationName = r.data!['name']?.toString() ?? _locationName;
          });
        } else {
          _showSnackBar('لا يمكن تحديد موقع العمل تلقائيًا. اقترب من الموقع أو أعد المحاولة.');
          return;
        }
      } catch (_) {
        _showSnackBar('تعذر تحديد موقع العمل تلقائيًا.');
        return;
      }
    }

    setState(() => _loading = true);
    try {
      final pos = await getBestFix();

      final res = await sendAttendanceWithPosition(
        baseUrl: kBaseUrl,
        token: token,
        locationId: effectiveLocationId!,
        action: action,    // "check_in" أو "check_out"
        pos: pos,
      );

      final msg = res.message;
      if (res.ok) {
        final data = res.data ?? {};
        final note = (data['note'] ?? '').toString();
        final unrestricted = data['unrestricted'] == true;

        setState(() {
          _checkedIn = (action == 'check_in');
          _time = DateTime.now();
          _lastServerMessage = note.isNotEmpty ? note : msg;
          _lastData = data;
          // حدّث الحالة العلوية أيضًا (بانر غير مقيّد) إن وُجدت من الخادم
          _unrestricted = unrestricted;
        });

        if (unrestricted) {
          _showSnackBar(note.isNotEmpty
              ? note
              : 'تمت العملية بنجاح — الوردية غير مقيّدة زمنيًا.');
        } else {
          // إن كانت نافذة محددة، حاول عرضها للمستخدم
          final sws = data['shift_window_start'];
          final swe = data['shift_window_end'];
          final win = (sws != null || swe != null)
              ? 'نافذة الوردية: ${_fmtIsoDateTimeLocal(sws)} → ${_fmtIsoDateTimeLocal(swe)}'
              : '';
          final base = note.isNotEmpty ? note : 'تمت العملية بنجاح ضمن نافذة الوردية.';
          _showSnackBar(win.isEmpty ? base : '$base\n$win');
        }
      } else {
        // خطأ — اعرض رسالة عربية مفهومة + أي ملاحظات من الخادم
        String nice = msg;
        final d = res.data;
        if (d is Map<String, dynamic>) {
          final note = (d['note'] ?? '').toString();
          if (d['detail'] is String) {
            nice = d['detail'];
            if (note.isNotEmpty) {
              nice = '$note\n$nice';
            }
          } else if (d['non_field_errors'] is List && d['non_field_errors'].isNotEmpty) {
            nice = d['non_field_errors'].join('، ');
          }
        }
        _showSnackBar(nice.isEmpty ? 'فشل الإرسال.' : nice);
      }
    } catch (e) {
      _showSnackBar('خطأ: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final timeStr = _time == null ? null : DateFormat.Hm().format(_time!);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // بانر توضيحي عند الوردية غير المقيّدة
        if (_unrestricted)
          MaterialBanner(
            content: const Text(
              'تنبيه: ورديتك الحالية غير مقيّدة زمنيًا — يُسمح بالحضور والانصراف في أي وقت.',
            ),
            actions: [
              TextButton(onPressed: () {}, child: const Text('حسناً')),
            ],
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
                    child: Text('الموقع: $_locationName', style: Theme.of(context).textTheme.titleSmall),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // تلميح نصي عن النافذة والسماحات (من الكاش إن وُجد)
        if (_shiftHint != null && _shiftHint!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              _shiftHint!,
              style: const TextStyle(fontSize: 12),
            ),
          ),

        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text("تسجيل الحضور"),
                onPressed: (_checkedIn || _loading || _locationId == null) ? null : () => _handleAction("check_in"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text("تسجيل الانصراف"),
                onPressed: (!_checkedIn || _loading || _locationId == null) ? null : () => _handleAction("check_out"),
              ),
            ),
          ],
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
                  const Text("آخر نتيجة:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_lastServerMessage != null) Text(_lastServerMessage!),
                  if (_lastData != null) ...[
                    const SizedBox(height: 8),
                    Text(_prettyData(_lastData!), style: const TextStyle(fontFamily: 'monospace')),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _prettyData(Map<String, dynamic> map) {
    final recId = map['record_id'];
    final employee = map['employee'];
    final location = map['location'];
    final detail = map['detail'];
    final note = map['note'];
    final un = map['unrestricted'] == true;
    final sws = map['shift_window_start'];
    final swe = map['shift_window_end'];

    final parts = <String>[];
    if (detail != null) parts.add("الرسالة: $detail");
    if (note != null && note.toString().trim().isNotEmpty) parts.add("ملاحظة: $note");
    if (recId != null) parts.add("رقم السجل: $recId");
    if (employee != null) parts.add("الموظف: $employee");
    if (location != null) parts.add("الموقع: $location");
    parts.add("الوردية: ${un ? "غير مقيّدة" : "مقيّدة"}");
    if (!un && (sws != null || swe != null)) {
      parts.add("نافذة الوردية: ${_fmtIsoDateTimeLocal(sws)} → ${_fmtIsoDateTimeLocal(swe)}");
    }
    return parts.join("\n");
  }
}
=======
>>>>>>> a7f51d3 (تسجيل الحضور)
/// تبويب 3: التقارير والطلبات (واجهة مبدئية)
class ReportsRequestsPage extends StatelessWidget {
  const ReportsRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.note_add),
            title: Text(t.create_report),
            subtitle: Text(t.create_report_hint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.coming_soon)));
            },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.assignment_outlined),
            title: Text(t.open_requests),
            subtitle: Text(t.open_requests_hint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.coming_soon)));
            },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.beenhere_outlined),
            title: Text(t.request_leave),
            subtitle: Text(t.request_leave_hint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.coming_soon)));
            },
          ),
        ),
      ],
    );
  }
}

