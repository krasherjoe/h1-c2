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

/// 背景色に対して最大コントラストの文字色を返す。
/// 純白/純黒ではなく、僅かに色味を帯びた色を使う（視覚的に自然）。
const Color _nearBlack = Color(0xFF1A1A2E);
const Color _nearWhite = Color(0xFFF0F0F0);

Color textColorOn(Color background) {
  final darkContrast = contrastRatio(background, _nearBlack);
  final lightContrast = contrastRatio(background, _nearWhite);
  return darkContrast >= lightContrast ? _nearBlack : _nearWhite;
}

/// 背景色に対して読みやすいテキスト色（白 or 濃いネイビー）を返す。
@Deprecated('textColorOn を使用してください')
Color appBarForeground(Color background) {
  return textColorOn(background);
}

/// カードの表面色を背景に対して視認できるよう自動調整する。
///
/// Material3 の `surface`（カード）と `surfaceContainerLowest`（壁紙）は
/// 近い輝度になりがち。この関数は [minRatio] のコントラスト比（デフォルト1.5:1）を
/// 下回る場合、カード色を明るく/暗くして差を確保する。
Color adjustSurfaceContrast(Color card, Color background, {double minRatio = 1.5}) {
  if (contrastRatio(card, background) >= minRatio) return card;

  final hsl = HSLColor.fromColor(card);
  Color? best;

  void tryDirection(bool lighten) {
    for (int i = 1; i <= 18; i++) {
      final step = i * 0.05;
      final newLightness = lighten
          ? (hsl.lightness + step).clamp(0.0, 1.0)
          : (hsl.lightness - step).clamp(0.0, 1.0);
      final candidate = hsl.withLightness(newLightness).toColor();
      if (contrastRatio(candidate, background) >= minRatio) {
        best = candidate;
        return;
      }
    }
  }

  tryDirection(true);
  tryDirection(false);

  return best ?? card;
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

/// テーマの二重影リスト
List<BoxShadow> cardBoxShadow(ColorScheme cs) => [
  BoxShadow(color: cs.shadow.withValues(alpha: 0.12), blurRadius: 8, offset: Offset(0, 2)),
  BoxShadow(color: cs.shadow.withValues(alpha: 0.06), blurRadius: 16, offset: Offset(0, 4)),
];

/// カード風コンテナの BoxDecoration（二重影 + surface + radius）
BoxDecoration cardDecoration(ColorScheme cs, {Color? color, double radius = 12}) => BoxDecoration(
  color: color ?? cs.surface,
  borderRadius: BorderRadius.circular(radius),
  boxShadow: cardBoxShadow(cs),
);
