/// تعريف الثيمات الفاتحة والداكنة وأساس الهوية البصرية للتطبيق.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ألوان الهوية
const Color kBgDark = Color(0xFF222831);
const Color kPanel  = Color(0xFF393E46);
const Color kAccent = Color(0xFF948979);
const Color kText   = Color(0xFFDFD0B8);
const Color kTextInverse = Color(0xFF222831);

/// يجهّز خطوط Tajawal مع احترام وضع السطوع الحالي.
TextTheme _tajawalTextTheme(Brightness b) {
  // لا تحمّل من الشبكة أثناء runtime إذا ما في إنترنت
  GoogleFonts.config.allowRuntimeFetching = false;

  final base = b == Brightness.dark
      ? ThemeData.dark().textTheme
      : ThemeData.light().textTheme;

  // إن فشل التحميل الشبكي سيستخدم fallback تلقائيًا
  return GoogleFonts.tajawalTextTheme(base);
}

/// الثيم الداكن المستخدم عند اختيار الوضع الليلي.
ThemeData sanamDarkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kBgDark,
  colorScheme: const ColorScheme.dark(
    primary: kAccent,
    secondary: kAccent,
    surface: kPanel,
    onPrimary: kTextInverse,
  ),
  textTheme: _tajawalTextTheme(Brightness.dark).apply(bodyColor: kText, displayColor: kText),
  appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0x1AFFFFFF),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0x33FFFFFF)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: kAccent, width: 1.5),
    ),
    labelStyle: const TextStyle(color: kText),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kAccent,
      foregroundColor: kTextInverse,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontWeight: FontWeight.w800),
    ),
  ),
);

/// الثيم الفاتح الافتراضي للتطبيق.
ThemeData sanamLightTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: const Color(0xFFDFD0B8),
  colorScheme: const ColorScheme.light(
    primary: kAccent,
    secondary: kAccent,
    surface: Colors.white,
    onPrimary: kTextInverse,
  ),
  textTheme: _tajawalTextTheme(Brightness.light).apply(
    bodyColor: const Color(0xFF222831),
    displayColor: const Color(0xFF222831),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFF2F3F5),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFD4D7DC)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.black87, width: 1.5),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.black87,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontWeight: FontWeight.w800),
    ),
  ),
);
