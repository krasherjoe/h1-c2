import 'package:flutter/material.dart';

class AppTheme {
  // --- トークン ---
  static const wallpaperLight = Color(0xFFDCDCE0);
  static const wallpaperDark = Color(0xFF2C2C2E);
  static const cardLight = Color(0xFFFFFFFF);
  static const cardDark = Color(0xFF3E3E42);
  static const fontFamily = 'IPAexGothic';

  // --- テーマ構築 ---
  static ThemeData light({String inputStyle = 'raised'}) =>
    _build(seedColor: Colors.indigo, brightness: Brightness.light, inputStyle: inputStyle);

  static ThemeData dark({String inputStyle = 'raised'}) =>
    _build(seedColor: Colors.indigo, brightness: Brightness.dark, inputStyle: inputStyle);

  static ThemeData _build({
    required Color seedColor,
    required Brightness brightness,
    required String inputStyle,
  }) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness).copyWith(
      surfaceContainerLowest: isDark ? wallpaperDark : wallpaperLight,
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: scheme.surfaceContainerLowest,
      brightness: brightness,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: scheme.onPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? cardDark : cardLight,
        elevation: 3,
        surfaceTintColor: Colors.transparent,
        shadowColor: isDark ? const Color(0x50000000) : const Color(0x22000000),
      ),
      inputDecorationTheme: _inputTheme(isDark, inputStyle),
    );
  }

  static InputDecorationTheme _inputTheme(bool isDark, String style) {
    const radius = BorderRadius.all(Radius.circular(12));
    const pad = EdgeInsetsDirectional.fromSTEB(12, 16, 12, 12);
    if (style == 'raised') {
      return InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF3E3E42) : Colors.white,
        contentPadding: pad,
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: isDark ? const Color(0xFF555559) : const Color(0xFFE0E0E3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: isDark ? const Color(0xFF555559) : const Color(0xFFE0E0E3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: const Color(0xFF6366F1), width: 2),
        ),
      );
    }
    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? cardDark : Colors.white,
      contentPadding: pad,
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: isDark ? const Color(0xFF555559) : const Color(0xFFE0E0E3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: isDark ? const Color(0xFF555559) : const Color(0xFFE0E0E3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
      ),
    );
  }
}
