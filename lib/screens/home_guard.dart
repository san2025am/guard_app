import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_settings.dart';
import '../models/employee.dart';
import '../services/api.dart';  // لو عندك AppSettings (الثيم/اللغة)

import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

import '../services/auth.dart' show getAuthHeader, logout; // عدّل المسار




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



class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  bool _checkedIn = false;
  DateTime? _time;
  bool _loading = false;

  static const String _baseUrl = "http://31.97.158.157/api/v1"; // عدّلها

  String? _lastServerMessage;
  Map<String, dynamic>? _lastData;

  Future<String?> _getToken() async {
    return await getAuthHeader();
  }

  @override
  void initState() {
    super.initState();
    _ensureLoggedIn();
  }

  Future<void> _ensureLoggedIn() async {
    final token = await _getToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      // روح لصفحة تسجيل الدخول
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  Future<void> _handleAction(String action) async {
    final messenger = ScaffoldMessenger.of(context);

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text("لا يوجد توكن مصادقة. سجّل الدخول أولاً.")));
      return;
    }

    setState(() => _loading = true);
    try {
      // 1) إذن الموقع + أفضل قراءة
      await requestLocationPermissionsOrThrow();
      final pos = await getBestFix();

      // 2) حلّ الموقع من الخادم حسب الموظف المسجّل
      final r = await resolveMyLocation(
        baseUrl: _baseUrl,
        token: token,
        lat: pos.latitude,
        lng: pos.longitude,
        accuracy: pos.accuracy,
      );

      if (!r.ok || r.data == null || r.data!["location_id"] == null) {
        messenger.showSnackBar(SnackBar(content: Text(r.message)));
        return;
      }

      final String locationId = r.data!["location_id"].toString();     // ✅ UUID

      final double radius = asDouble(r.data!["radius"]) ?? 50.0;       // ✅
      final double siteLat = asDouble(r.data!["lat"]) ?? 0.0;          // ✅
      final double siteLng = asDouble(r.data!["lng"]) ?? 0.0;          // ✅


      // (اختياري) تحقق محلي سريع
      final dist = Geolocator.distanceBetween(pos.latitude, pos.longitude, siteLat, siteLng);
      if (dist > radius) {
        messenger.showSnackBar(SnackBar(content: Text("خارج النطاق (${radius.toInt()}م). المسافة: ${dist.toStringAsFixed(1)}م")));
        return;
      }

      // 3) أرسل الحضور/الانصراف لنفس الموقع المحسوم
      final res = await sendAttendanceWithPosition(
        baseUrl: _baseUrl,
        token: token,
        locationId: locationId,
        action: action, // "check_in" | "check_out"
        pos: pos,
      );

      _lastServerMessage = res.message;
      _lastData = res.data;

      if (res.ok) {
        setState(() {
          _checkedIn = (action == "check_in");
          _time = DateTime.now();
        });
        messenger.showSnackBar(SnackBar(content: Text(res.message)));
      } else {
        messenger.showSnackBar(SnackBar(content: Text(res.message)));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("خطأ: $e")));
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(_checkedIn ? Icons.login : Icons.logout, size: 36, color: cs.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(_checkedIn ? "تم تسجيل الحضور" : "تم تسجيل الانصراف",
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                if (timeStr != null) Text(timeStr),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text("تسجيل الحضور"),
                onPressed: (_checkedIn || _loading) ? null : () => _handleAction("check_in"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text("تسجيل الانصراف"),
                onPressed: (!_checkedIn || _loading) ? null : () => _handleAction("check_out"),
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
                  if (_lastData != null) Text(_prettyData(_lastData!), style: const TextStyle(fontFamily: 'monospace')),
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
    return [
      if (detail != null) "الرسالة: $detail",
      if (recId != null) "رقم السجل: $recId",
      if (employee != null) "الموظف: $employee",
      if (location != null) "الموقع: $location",
    ].join("\n");
  }
}

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
