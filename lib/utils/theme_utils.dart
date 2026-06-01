import 'package:flutter/material.dart';
import '../models/invoice_models.dart' show DocumentType;

/// WCAG AA 基準のコントラスト比 (4.5:1) を計算。
double contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

/// 背景色に対して最大コントラスト（かつ色相が離れた）文字色を返す。
/// 輝度ベースで白/黒を選択。同系統色での視認性低下を防ぐ。
Color textColorOn(Color background) {
  final blackContrast = contrastRatio(background, Colors.black);
  final whiteContrast = contrastRatio(background, Colors.white);
  return blackContrast >= whiteContrast ? Colors.black : Colors.white;
}

/// 背景色に対して読みやすいテキスト色（白 or 濃いネイビー）を返す。
@Deprecated('textColorOn を使用してください')
Color appBarForeground(Color background) {
  return textColorOn(background);
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
