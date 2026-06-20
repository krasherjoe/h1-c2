import 'package:flutter/material.dart';
import '../../../../services/input_style_service.dart';

class QuickActionButton extends StatelessWidget {
  static const double _verticalPadding = 8;
  static const double _iconSize = 22;
  static const double _iconTextGap = 1;
  static const double _textFontSize = 11;

  static double get itemHeight =>
      (_verticalPadding * 2 + _iconSize + _iconTextGap + _textFontSize * 1.4).clamp(56.0, double.infinity);
  final double? width;
  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const QuickActionButton({
    super.key,
    this.width,
    required this.icon,
    required this.label,
    required this.accentColor,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final lightColor = isDark ? cs.surfaceContainerHigh : cs.surface;
    final darkColor = isDark
        ? cs.surfaceContainerHighest
        : cs.surfaceContainerLow;
    final textColor = isDark
        ? cs.onSurface.withValues(alpha: 0.85)
        : cs.onSurface;
    return ValueListenableBuilder<String>(
      valueListenable: inputStyleNotifier,
      builder: (context, inputStyle, _) {
        final showShadow = inputStyle == 'raised';
        final btn = Container(
          width: width,
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: _verticalPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.9,
              colors: [lightColor, darkColor],
            ),
            boxShadow: showShadow
                ? [
                    BoxShadow(
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                      color: cs.shadow.withValues(alpha: 0.25),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(icon, color: accentColor, size: _iconSize),
              SizedBox(height: _iconTextGap),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: _textFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
        if (onTap == null && onLongPress == null) return btn;
        return GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: btn,
        );
      },
    );
  }
}
