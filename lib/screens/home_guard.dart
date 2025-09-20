import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_settings.dart'; // لو عندك AppSettings (الثيم/اللغة)

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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final settings = context.read<AppSettings?>(); // قد يكون null لو ما تستخدم provider
    final isDark = settings?.themeMode == ThemeMode.dark;

    return Directionality(
      textDirection: (Localizations.localeOf(context).languageCode == 'ar')
          ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
    
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
      ),
    );
  }
}

/// تبويب 1: بروفايل الحارس
class GuardProfilePage extends StatefulWidget {
  const GuardProfilePage({super.key});

  @override
  State<GuardProfilePage> createState() => _GuardProfilePageState();
}

class _GuardProfilePageState extends State<GuardProfilePage> {
  String _username = '';
  String _role = '';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _username = p.getString('username') ?? '';
      _role = p.getString('role') ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
                  child: Text(
                    _username.isEmpty ? t.username : _username,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.badge),
            title: Text(t.role),
            subtitle: Text(_role.isEmpty ? '-' : _role),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.refresh),
            title: Text(t.sync),
            subtitle: Text(t.sync_hint),
            trailing: IconButton(
              icon: const Icon(Icons.sync),
              onPressed: _loadPrefs,
              tooltip: t.sync,
            ),
          ),
        ),
      ],
    );
  }
}

/// تبويب 2: التحضير (واجهة مبدئية)
class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  bool _checkedIn = false;
  DateTime? _time;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

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
                  child: Text(
                    _checkedIn ? t.checked_in : t.checked_out,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (_time != null) Text(TimeOfDay.fromDateTime(_time!).format(context)),
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
                label: Text(t.check_in),
                onPressed: _checkedIn ? null : () => setState(() { _checkedIn = true; _time = DateTime.now(); }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: Text(t.check_out),
                onPressed: !_checkedIn ? null : () => setState(() { _checkedIn = false; _time = DateTime.now(); }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.history),
            title: Text(t.attendance_history),
            subtitle: Text(t.attendance_history_hint),
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
