import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart'; // إن لم تكن تستخدمه، أضفه: provider:^6.0.5
import 'package:security_quard/services/api.dart';
import 'app_settings.dart';
import 'theme.dart';
import 'l10n/app_localizations.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/home_guard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = AppSettings();
  await settings.load();

  runApp(
    ChangeNotifierProvider.value(value: settings, child: const SanamApp()),
  );
}

class SanamApp extends StatelessWidget {
  const SanamApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();

    return MaterialApp(
      title: 'سنام الأمن',
      debugShowCheckedModeBanner: false,

      // ثيم + وضع ليل/نهار
      theme: sanamLightTheme,
      darkTheme: sanamDarkTheme,
      themeMode: settings.themeMode,

      // اللغة والـ delegates
      locale: settings.locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate, // <-- مولّد تلقائيًا
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      builder: (context, child) => SessionTimeoutWatcher(child: child),

      home: const Shell(child: SplashScreen()),

      routes: {
        LoginScreen.route: (_) => const Shell(child: LoginScreen()),
        ForgotPasswordScreen.route: (_) =>
            const Shell(child: ForgotPasswordScreen()),
        ResetPasswordScreen.route: (_) =>
            const Shell(child: ResetPasswordScreen()),
        HomeGuard.route: (_) => const Shell(child: HomeGuard()),
      },
    );
  }
}

/// شيل يضيف AppBar موحّد بأزرار (تبديل الثيم واللغة) لكل شاشة
class Shell extends StatelessWidget {
  final Widget child;
  const Shell({super.key, required this.child});
  Future<void> _logout(BuildContext context) async {
    await ApiService.logout();
    SessionTimeoutWatcher.refreshAuth(context);
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login', // LoginScreen.route
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final settings = context.watch<AppSettings>();
    final isDark = settings.themeMode == ThemeMode.dark;

    return Directionality(
      // RTL للعربي تلقائيًا
      textDirection: settings.locale.languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.app_title),
          actions: [
            // تبديل الثيم
            IconButton(
              tooltip: t.toggle_theme,
              onPressed: () => settings.toggleTheme(),
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            ),
            // اختيار اللغة
            PopupMenuButton<String>(
              tooltip: t.language,
              icon: const Icon(Icons.language),
              onSelected: (v) {
                settings.setLocale(Locale(v));
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(value: 'ar', child: Text(t.arabic)),
                PopupMenuItem(value: 'en', child: Text(t.english)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: t.logout, // أو نص يدوي "تسجيل الخروج"
              onPressed: () => _logout(context),
            ),
          ],
        ),
        body: child,
      ),
    );
  }
}

class SessionTimeoutWatcher extends StatefulWidget {
  const SessionTimeoutWatcher({super.key, required this.child});

  final Widget? child;

  static void refreshAuth(BuildContext context) {
    context
        .findAncestorStateOfType<_SessionTimeoutWatcherState>()
        ?._updateAuthState();
  }

  @override
  State<SessionTimeoutWatcher> createState() => _SessionTimeoutWatcherState();
}

class _SessionTimeoutWatcherState extends State<SessionTimeoutWatcher>
    with WidgetsBindingObserver {
  static const Duration _inactiveDuration = Duration(minutes: 1);
  static const Duration _graceDuration = Duration(seconds: 10);

  Timer? _idleTimer;
  Timer? _graceTimer;
  bool _dialogActive = false;
  bool _monitoringEnabled = false;
  bool _authCheckInProgress = false;
  DateTime? _pausedAt;
  DateTime? _lastAuthCheck;
  final ValueNotifier<int> _countdown = ValueNotifier<int>(
    _graceDuration.inSeconds,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateAuthState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_monitoringEnabled && !_authCheckInProgress) {
      _updateAuthState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    _graceTimer?.cancel();
    _countdown.dispose();
    super.dispose();
  }

  void _onPointerEvent() {
    if (!_monitoringEnabled) {
      final now = DateTime.now();
      if (_lastAuthCheck == null ||
          now.difference(_lastAuthCheck!) > const Duration(seconds: 5)) {
        _updateAuthState();
      }
    }
    if (!_monitoringEnabled) return;

    if (_dialogActive) {
      Navigator.of(context, rootNavigator: true).maybePop(true);
    }
    _resetIdleTimer();
  }

  Future<void> _updateAuthState() async {
    if (_authCheckInProgress) return;
    _authCheckInProgress = true;
    _lastAuthCheck = DateTime.now();
    try {
      final token = await ApiService.getAccessToken();
      final shouldMonitor = token != null && token.isNotEmpty;
      if (!mounted) return;
      if (shouldMonitor != _monitoringEnabled) {
        setState(() {
          _monitoringEnabled = shouldMonitor;
        });
        if (shouldMonitor) {
          _resetIdleTimer();
        } else {
          _cancelGraceFlow();
          _idleTimer?.cancel();
        }
      } else if (shouldMonitor) {
        _resetIdleTimer();
      }
    } finally {
      _authCheckInProgress = false;
    }
  }

  void _resetIdleTimer() {
    if (!_monitoringEnabled) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(_inactiveDuration, _handleInactivityTimeout);
  }

  void _handleInactivityTimeout() {
    if (!_monitoringEnabled || !mounted) return;
    _showTimeoutDialog();
  }

  void _cancelGraceFlow() {
    _graceTimer?.cancel();
    _graceTimer = null;
    _countdown.value = _graceDuration.inSeconds;
    _dialogActive = false;
  }

  Future<void> _showTimeoutDialog() async {
    if (_dialogActive || !mounted) return;
    _dialogActive = true;
    _countdown.value = _graceDuration.inSeconds;

    _graceTimer?.cancel();
    _graceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown.value <= 1) {
        timer.cancel();
        _graceTimer = null;
        if (_dialogActive) {
          Navigator.of(context, rootNavigator: true).pop(false);
        }
      } else {
        _countdown.value = _countdown.value - 1;
      }
    });

    final t = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(t.session_timeout_title),
          content: ValueListenableBuilder<int>(
            valueListenable: _countdown,
            builder: (_, seconds, __) =>
                Text(t.session_timeout_message(seconds)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(t.session_timeout_logout),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(t.session_timeout_keep),
            ),
          ],
        );
      },
    );

    _cancelGraceFlow();

    if (result == true) {
      _resetIdleTimer();
    } else {
      await _logout();
    }
  }

  Future<void> _logout() async {
    _idleTimer?.cancel();
    _monitoringEnabled = false;
    try {
      await ApiService.logout();
    } catch (_) {
      // تجاهل الأخطاء أثناء تسجيل الخروج
    }
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    _updateAuthState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _idleTimer?.cancel();
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedFor = _pausedAt != null
          ? DateTime.now().difference(_pausedAt!)
          : Duration.zero;
      _pausedAt = null;
      _updateAuthState().whenComplete(() {
        if (!_monitoringEnabled) return;
        if (pausedFor >= _inactiveDuration) {
          _handleInactivityTimeout();
        } else {
          _resetIdleTimer();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child ?? const SizedBox.shrink();
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onPointerEvent(),
      onPointerMove: (_) => _onPointerEvent(),
      onPointerSignal: (_) => _onPointerEvent(),
      child: child,
    );
  }
}
