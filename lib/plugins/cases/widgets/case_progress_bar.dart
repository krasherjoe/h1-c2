import 'package:flutter/material.dart';

class CaseProgressBar extends StatelessWidget {
  final int status;
  final int elapsedDays;
  final bool isResolved;

  static const int _expectedDuration = 30;
  static const List<Color> _segmentColors = [
    Color(0xFF9E9E9E),
    Color(0xFFFFA726),
    Color(0xFFE65100),
    Color(0xFFD32F2F),
    Color(0xFF388E3C),
  ];

  double get _progress {
    if (isResolved) return 1.0;
    return (elapsedDays / _expectedDuration).clamp(0.0, 1.0);
  }

  int get _currentSegment {
    if (isResolved) return 4;
    return status.clamp(0, 3);
  }

  const CaseProgressBar({
    super.key,
    required this.status,
    required this.elapsedDays,
    this.isResolved = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = _progress;
    final seg = _currentSegment;

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final barH = 6.0;
      final markerX = (w * progress).clamp(3.0, w - 3);
      final segW = w / 5;

      return SizedBox(
        height: 28,
        child: Stack(clipBehavior: Clip.none, children: [
          // background track
          Positioned(
            top: (28 - barH) / 2,
            left: 0,
            right: 0,
            child: Container(
              height: barH,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          // filled portion (up to marker)
          Positioned(
            top: (28 - barH) / 2,
            left: 0,
            child: Container(
              width: markerX,
              height: barH,
              decoration: BoxDecoration(
                color: _segmentColors[seg],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(3),
                  bottomLeft: Radius.circular(3),
                ),
              ),
            ),
          ),
          // segment dividers
          ...List.generate(4, (i) {
            final x = (i + 1) * segW;
            final isPast = x <= markerX;
            return Positioned(
              top: (28 - barH) / 2,
              left: x - 1,
              child: Container(
                width: 2,
                height: barH,
                decoration: BoxDecoration(
                  color: isPast
                      ? _segmentColors[i].withValues(alpha: 0.8)
                      : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(0.5),
                ),
              ),
            );
          }),
          // vertical marker
          Positioned(
            top: 0,
            left: markerX - 1,
            child: Container(
              width: 2,
              height: 28,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ]),
      );
    });
  }
}
