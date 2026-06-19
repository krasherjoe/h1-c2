import 'package:flutter/material.dart';

class CaseProgressBar extends StatelessWidget {
  final int status;
  final int elapsedDays;
  final bool isResolved;

  static const int _expectedDuration = 30;

  double get _progress {
    if (isResolved) return 1.0;
    return (elapsedDays / _expectedDuration).clamp(0.0, 1.0);
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
    return SizedBox(
      height: 18,
      child: CustomPaint(
        painter: _ProgressBarPainter(
          progress: _progress,
          markerColor: cs.onSurface,
          trackColor: cs.surfaceContainerHighest,
        ),
      ),
    );
  }
}

class _ProgressBarPainter extends CustomPainter {
  final double progress;
  final Color markerColor;
  final Color trackColor;

  static const List<Color> _segmentColors = [
    Color(0xFF9E9E9E), // 発見 gray
    Colors.amber,       // 注意
    Colors.deepOrange,  // 警告
    Colors.redAccent,   // 重大
    Colors.green,       // 解決
  ];

  _ProgressBarPainter({
    required this.progress,
    required this.markerColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final barY = h / 2;
    final barH = 4.0;
    final segW = w / 5;

    // background track
    final bgPaint = Paint()
      ..color = trackColor.withValues(alpha: 0.4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(0, barY - barH / 2, w, barY + barH / 2),
        const Radius.circular(2),
      ),
      bgPaint,
    );

    // filled segments
    for (int i = 0; i < 5; i++) {
      final segStart = i * segW;
      final segEnd = (i + 1) * segW;
      final markerX = progress * w;

      if (markerX <= segStart) break;

      final fillEnd = markerX < segEnd ? markerX : segEnd;
      final paint = Paint()..color = _segmentColors[i];

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(segStart, barY - barH / 2, fillEnd, barY + barH / 2),
          const Radius.circular(2),
        ),
        paint,
      );
    }

    // dots at boundaries
    for (int i = 1; i < 5; i++) {
      final dotX = i * segW;
      final isPast = dotX <= progress * w;
      canvas.drawCircle(
        Offset(dotX, barY),
        2.5,
        Paint()..color = isPast ? _segmentColors[i - 1] : _segmentColors[i - 1].withValues(alpha: 0.25),
      );
    }

    // vertical marker
    final markerX = (progress * w).clamp(0.0, w);
    canvas.drawLine(
      Offset(markerX, 2),
      Offset(markerX, h - 2),
      Paint()
        ..color = markerColor
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ProgressBarPainter old) => old.progress != progress;
}
