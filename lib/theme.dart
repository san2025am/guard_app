import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Brand palette from your web styles (bg, panel, accent, text).
const Color kBgDark = Color(0xFF222831);   // bg
const Color kPanel  = Color(0xFF393E46);   // panel
const Color kAccent = Color(0xFF948979);   // accent
const Color kText   = Color(0xFFDFD0B8);   // text

const Color kTextInverse = Color(0xFF222831);

ThemeData sanamDarkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kBgDark,
  colorScheme: const ColorScheme.dark(
    primary: kAccent,
    secondary: kAccent,
    surface: kPanel,
    onPrimary: kTextInverse,
  ),
  textTheme: GoogleFonts.tajawalTextTheme(ThemeData.dark().textTheme)
      .apply(bodyColor: kText, displayColor: kText),
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

ThemeData sanamLightTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: const Color(0xFFDFD0B8), // text color in dark mode used as BG in light web
  colorScheme: const ColorScheme.light(
    primary: kAccent,
    secondary: kAccent,
    surface: Colors.white,
    onPrimary: kTextInverse,
  ),
  textTheme: GoogleFonts.tajawalTextTheme(ThemeData.light().textTheme).apply(
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
