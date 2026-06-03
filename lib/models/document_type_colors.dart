import 'package:flutter/material.dart';
import '../plugins/documents/models/document_model.dart' show DocumentType;

Color documentTypeColor(DocumentType type, ColorScheme cs, bool isDark) {
  final base = switch (type) {
    DocumentType.estimation => const Color(0xFF29B6F6),
    DocumentType.order => cs.secondary,
    DocumentType.delivery => cs.tertiary,
    DocumentType.invoice => cs.error,
    DocumentType.receipt => const Color(0xFF388E3C),
  };
  if (isDark) {
    return HSLColor.fromColor(base).withLightness(0.55).toColor();
  }
  return base;
}

Color documentTypeBadgeColor(DocumentType type) {
  return switch (type) {
    DocumentType.estimation => const Color(0xFF29B6F6),
    DocumentType.order => const Color(0xFF7B1FA2),
    DocumentType.delivery => const Color(0xFFF57C00),
    DocumentType.invoice => const Color(0xFFD32F2F),
    DocumentType.receipt => const Color(0xFF388E3C),
  };
}

class DocumentColors {
  static Color documentTypeColor(String type, bool isDark) {
    return switch (type) {
      'estimation' => isDark ? const Color(0xFF0D47A1) : const Color(0xFF29B6F6),
      'order' => isDark ? const Color(0xFF4A148C) : const Color(0xFF7B1FA2),
      'delivery' => isDark ? const Color(0xFFE65100) : const Color(0xFFF57C00),
      'invoice' => isDark ? const Color(0xFFB71C1C) : const Color(0xFFD32F2F),
      'receipt' => isDark ? const Color(0xFF1B5E20) : const Color(0xFF388E3C),
      _ => isDark ? const Color(0xFF37474F) : const Color(0xFF607D8B),
    };
  }
}
