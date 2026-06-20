import 'package:flutter/material.dart';

class AppTheme {
  // --- トークン ---
  static const wallpaperLight = Color(0xFFDCDCE0);
  static const wallpaperDark = Color(0xFF2C2C2E);
  static const cardLight = Color(0xFFFFFFFF);
  static const cardDark = Color(0xFF3E3E42);
  static const cardLostLight = Color(0xFFF0ECEA);
  static const cardLostDark = Color(0xFF38373A);
  static const cardProgressBgLight = Color(0xFFF5F3F1);
  static const cardProgressBgDark = Color(0xFF3E3C40);
  static const fontFamily = 'IPAexGothic';

  // --- クイックアクションアクセントカラー ---
  static const accentMaster = Color(0xFFE65100);     // deepOrange 900
  static const accentSales = Color(0xFF1565C0);      // blue 800
  static const accentPurchase = Color(0xFF2E7D32);   // green 800
  static const accentInventory = Color(0xFF6A1B9A);  // purple 900
  static const accentReport = Color(0xFF37474F);     // blueGrey 800
  static const accentSettings = Color(0xFF00838F);   // teal 700
  static const accentDefault = Color(0xFF455A64);    // blueGrey 600

  // --- テーマ構築 ---
  static ThemeData light({String inputStyle = 'raised', String navbarStyle = 'primary'}) =>
    _build(seedColor: Colors.indigo, brightness: Brightness.light, inputStyle: inputStyle, navbarStyle: navbarStyle);

  static ThemeData dark({String inputStyle = 'raised', String navbarStyle = 'primary'}) =>
    _build(seedColor: Colors.indigo, brightness: Brightness.dark, inputStyle: inputStyle, navbarStyle: navbarStyle);

  static Color _navBarColor(ColorScheme cs, bool isDark, String style) {
    return switch (style) {
      'primary' => cs.primary,
      'black' => Colors.black,
      _ => isDark ? const Color(0xFF2C2C2E) : const Color(0xFF2E2E2E), // dark_grey
    };
  }

  static ThemeData _build({
    required Color seedColor,
    required Brightness brightness,
    required String inputStyle,
    required String navbarStyle,
  }) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness).copyWith(
      surfaceContainerLowest: isDark ? wallpaperDark : wallpaperLight,
    );
    final navBarColor = _navBarColor(scheme, isDark, navbarStyle);

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
        iconTheme: IconThemeData(size: 20, color: scheme.onPrimary),
        titleTextStyle: TextStyle(
          color: scheme.onPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? cardDark : cardLight,
        elevation: 3,
        shadowColor: isDark ? const Color(0x50000000) : const Color(0x22000000),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBarColor,
        indicatorColor: scheme.primary.withValues(alpha: 0.2),
      ),
      bottomAppBarTheme: BottomAppBarThemeData(
        color: navBarColor,
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
        borderSide: BorderSide(color: isDark ? const Color(0xFF777779) : const Color(0xFF9E9E9E)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: isDark ? const Color(0xFF777779) : const Color(0xFF9E9E9E)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
      ),
    );
  }
}
