/// شاشة البداية التي تقرر إعادة التوجيه بين تسجيل الدخول والصفحة الرئيسية.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../services/environment_security.dart';
import 'login_screen.dart';
import 'home_guard.dart';

/// تعرض الشعار أثناء تحميل التوكنات ثم تنتقل للشاشة المناسبة.
class SplashScreen extends StatefulWidget {
  static const route = '/';
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// يتحكم في حركة الشعار ومنطق الانتقال السريع.
class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    // إخفاء شريط الحالة مؤقتًا لمظهر نظيف (اختياري)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade  = CurvedAnimation(parent: _ctl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: .92, end: 1.0)
        .animate(CurvedAnimation(parent: _ctl, curve: Curves.easeOutBack));

    _start();
  }

  Future<void> _start() async {
    // شغّل الأنيميشن
    _ctl.forward();

    final status = await EnvironmentSecurity.evaluate();
    if (!mounted) return;
    if (status.shouldBlock) {
      await _showSecurityDialog(status);
      return;
    }

    // تحميل التوكن
    final p = await SharedPreferences.getInstance();
    final access = p.getString('access');

    // نمنح الشعار وقت بسيط للظهور
    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;
    final nextRoute = (access != null && access.isNotEmpty)
        ? HomeGuard.route
        : LoginScreen.route;

    // انتقال سلس
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => (access != null && access.isNotEmpty)
          ? const HomeGuard()
          : const LoginScreen(),
      transitionsBuilder: (_, anim, __, child) {
        final fade = CurvedAnimation(parent: anim, curve: Curves.easeOut);
        return FadeTransition(opacity: fade, child: child);
      },
      settings: RouteSettings(name: nextRoute),
    ));
  }

  Future<void> _showSecurityDialog(EnvironmentStatus status) async {
    final t = AppLocalizations.of(context)!;
    final issues = <String>[];
    if (status.vpnActive) {
      issues.add(t.environment_violation_reason_vpn);
    }
    if (status.mockLocationDetected) {
      issues.add(t.environment_violation_reason_mock);
    }
    final separator = Directionality.of(context) == TextDirection.rtl ? '، ' : ', ';
    final issuesText = issues.join(separator);
    final message = t.environment_violation_message(
      issuesText.isEmpty ? t.environment_violation_reason_vpn : issuesText,
    );

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(t.environment_violation_title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t.environment_violation_exit),
          ),
        ],
      ),
    );

    await Future.delayed(const Duration(milliseconds: 150));
    SystemNavigator.pop();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0E0F12) // خلفية لطيفة للوضع الداكن
          : const Color(0xFFF7F5EF), // خلفية محايدة للوضع الفاتح
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // الشعار
                  Image.asset(
                    'assets/images/logo.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 18),
                  // اسم التطبيق
                  Text(
                    'سنام الأمن',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // مؤشر بسيط
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
