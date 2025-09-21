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
    ChangeNotifierProvider.value(
      value: settings,
      child: const SanamApp(),
    ),
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
        AppLocalizations.delegate,                 // <-- مولّد تلقائيًا
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const Shell(child: SplashScreen()),

      routes: {
        LoginScreen.route: (_) => const Shell(child: LoginScreen()),
        ForgotPasswordScreen.route: (_) => const Shell(child: ForgotPasswordScreen()),
        ResetPasswordScreen.route: (_) => const Shell(child: ResetPasswordScreen()),
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
          ? TextDirection.rtl : TextDirection.ltr,
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
