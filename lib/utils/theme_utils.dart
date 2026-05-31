import 'package:flutter/material.dart';
import '../models/invoice_models.dart' show DocumentType;

/// 背景色に対して読みやすいテキスト色（白 or 濃いネイビー）を返す。
Color appBarForeground(Color background) {
  return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : const Color(0xFF1A1A2E);
}

/// 伝票種別ごとの AppBar 背景色（テーマ対応・ダークモード対応）。
Color documentTypeColor(DocumentType type, ColorScheme cs, bool isDark) {
  final base = switch (type) {
    DocumentType.estimation => const Color(0xFF29B6F6),
    DocumentType.order => cs.secondary,
    DocumentType.delivery => cs.tertiary,
    DocumentType.invoice => cs.error,
    DocumentType.receipt => const Color(0xFF388E3C),
  };
  if (isDark) {
    return HSLColor.fromColor(base).withLightness(0.18).toColor();
  }
  return base;
}
