import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(LoginScreen.route);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Image.asset('assets/images/logo.png', height: 96),
            ),
            const SizedBox(height: 16),
            Text(t.app_title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            const SizedBox(width: 160, child: LinearProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
