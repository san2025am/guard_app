import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    Timer(const Duration(seconds: 7), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Background gradient that echoes your web hero
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    cs.brightness == Brightness.dark
                        ? const Color(0xFF111417)
                        : const Color(0xFFEFE9DF),
                    cs.surface.withOpacity(.2),
                  ],
                ),
              ),
            ),
            // Soft spotlight
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 900,
                height: 400,
                decoration: const BoxDecoration(
                  shape: BoxShape.rectangle,
                  gradient: RadialGradient(
                    radius: .7,
                    colors: [Color(0x33FFFFFF), Colors.transparent],
                  ),
                ),
              ),
            ),
            FadeTransition(
              opacity: _fade,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.35), blurRadius: 40, spreadRadius: 4)],
                        gradient: LinearGradient(colors: [cs.surface.withOpacity(.35), cs.surface.withOpacity(.15)]),
                        border: Border.all(color: Colors.white.withOpacity(.15)),
                      ),
                      child: Column(
                        children: [
                          Image.asset('assets/images/logo.png', height: 88, fit: BoxFit.contain),
                          const SizedBox(height: 12),
                          const _BrandTitle(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    const CircularProgressIndicator.adaptive(),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Text('سنام الأمن', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        Text('SANAM ALAMN', style: textTheme.bodyMedium?.copyWith(letterSpacing: 2.0)),
      ],
    );
  }
}
