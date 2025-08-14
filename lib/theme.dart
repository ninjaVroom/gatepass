import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens from research/03-design.md. No literal colours outside this file.
abstract final class C {
  static const brand = Color(0xFF0F4C3A);
  static const brandInk = Color(0xFFFFFFFF);
  static const accent = Color(0xFFC8A24A);
  static const bg = Color(0xFFF5F6F4);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF101828);
  static const ink2 = Color(0xFF475467);
  static const line = Color(0xFFE4E7EC);
  static const ok = Color(0xFF12B76A);
  static const warn = Color(0xFFF79009);
  static const bad = Color(0xFFD92D20);
  static const info = Color(0xFF1570EF);

  // Full-bleed result surfaces, darkened for white-text AA (per Figma package notes).
  static const okSurface = Color(0xFF087443);
  static const warnSurface = Color(0xFF93370D);
  static const badSurface = Color(0xFFD92D20);

  static const segTrack = Color(0xFFEAECEA);
  static const camera = Color(0xFF243029);
  static const avatar = Color(0xFFEDF1EE);
  static const okTint = Color(0xFFE7F6EE);
  static const warnTint = Color(0xFFFEF0C7);
  static const warnInk = Color(0xFF93370D);
  static const shadow = Color(0x14101828); // rgba(16,24,40,.08)
}

abstract final class R {
  static const card = 16.0, control = 12.0, chip = 999.0;
}

const cardShadow = [BoxShadow(color: C.shadow, blurRadius: 16, offset: Offset(0, 4))];

abstract final class T {
  static TextStyle get _base => GoogleFonts.inter(color: C.ink, fontFeatures: const [FontFeature.tabularFigures()]);
  static TextStyle get display => _base.copyWith(fontSize: 56, fontWeight: FontWeight.w800, height: 1.05, color: C.brandInk);
  static TextStyle get h1 => _base.copyWith(fontSize: 34, fontWeight: FontWeight.w700, height: 1.15);
  static TextStyle get h2 => _base.copyWith(fontSize: 22, fontWeight: FontWeight.w600);
  static TextStyle get body => _base.copyWith(fontSize: 17, fontWeight: FontWeight.w400);
  static TextStyle get label => _base.copyWith(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: C.ink2);
  static TextStyle get key => _base.copyWith(fontSize: 30, fontWeight: FontWeight.w500);
  static TextStyle get button => _base.copyWith(fontSize: 18, fontWeight: FontWeight.w700);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: C.brand, primary: C.brand, surface: C.surface),
    scaffoldBackgroundColor: C.bg,
    fontFamily: GoogleFonts.inter().fontFamily,
    focusColor: C.accent.withValues(alpha: .35),
  );
  return base.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.brand,
        foregroundColor: C.brandInk,
        minimumSize: const Size(56, 64),
        textStyle: T.button,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.control)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: C.surface,
        foregroundColor: C.ink,
        minimumSize: const Size(56, 64),
        textStyle: T.button,
        side: const BorderSide(color: C.line, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.control)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.control),
        borderSide: const BorderSide(color: C.line, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.control),
        borderSide: const BorderSide(color: C.brand, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.control),
        borderSide: const BorderSide(color: C.bad, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.control),
        borderSide: const BorderSide(color: C.bad, width: 2),
      ),
    ),
  );
}
