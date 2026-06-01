import 'package:flutter/material.dart';

class QuickActionButton extends StatelessWidget {
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
    final lightColor = isDark ? const Color(0xFF2A2A3A) : Colors.white;
    final darkColor = isDark
        ? const Color(0xFF3A3A4E)
        : const Color(0xFFEEEEEE);
    final textColor = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : Colors.grey[800]!;
    final btn = Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [lightColor, darkColor],
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            offset: const Offset(0, 4),
            color: cs.shadow.withValues(alpha: 0.25),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: accentColor, size: 22),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
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
  }
}
