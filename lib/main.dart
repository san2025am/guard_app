import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SanamApp());
}

class SanamApp extends StatelessWidget {
  const SanamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سنام الأمن',
      debugShowCheckedModeBanner: false,
      theme: sanamLightTheme,
      darkTheme: sanamDarkTheme,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
    );
  }
}
