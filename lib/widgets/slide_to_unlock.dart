import 'package:flutter/material.dart';

class SlideToUnlock extends StatefulWidget {
  final VoidCallback onUnlocked;
  final String lockedText;
  final String unlockedText;
  final IconData lockedIcon;
  final IconData unlockedIcon;
  final bool isLocked;
  final double? height;
  final double? thumbSize;
  final Color? backgroundColor;
  final Color? accentColor;

  const SlideToUnlock({
    super.key,
    required this.onUnlocked,
    this.lockedText = "スライドして解除",
    this.unlockedText = "UNLOCKED",
    this.lockedIcon = Icons.lock,
    this.unlockedIcon = Icons.check_circle,
    this.isLocked = true,
    this.height = 72,
    this.thumbSize = 52,
    this.backgroundColor,
    this.accentColor,
  });

  @override
  State<SlideToUnlock> createState() => _SlideToUnlockState();
}

class _SlideToUnlockState extends State<SlideToUnlock> {
  double _position = 0.0;
  static const double _trackPadding = 14.0;
  bool _showSuccessOverlay = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.isLocked) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final double thumbSize = widget.thumbSize ?? 52;
        final double trackWidth = (maxWidth - thumbSize - (_trackPadding * 2)).clamp(0, maxWidth);
        final double progressRatio = trackWidth == 0 ? 0 : (_position / trackWidth).clamp(0, 1);
        final double innerWidth = thumbSize + trackWidth;
        final double progressWidth = (innerWidth * progressRatio + thumbSize * (1 - progressRatio)).clamp(thumbSize, innerWidth);
        final ColorScheme cs = Theme.of(context).colorScheme;
        final Color background = widget.backgroundColor ?? cs.surfaceContainerHighest;
        final Color accentStart = (widget.accentColor ?? cs.primary).withValues(alpha: 0.9);
        final Color accentEnd = widget.accentColor ?? cs.primary;
        final Color textColor = cs.onSurfaceVariant;
        final Color iconColor = cs.onSurfaceVariant;

        return Container(
          height: widget.height ?? 72,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 4)),
            ],
          ),
          child: Stack(
            children: [
              // 進行バー
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _trackPadding, vertical: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    width: progressWidth,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        colors: [
                          accentStart,
                          accentEnd,
                        ],
                      ),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                ),
              ),
              // 背景テキスト
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _showSuccessOverlay
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          key: const ValueKey('unlocked'),
                          children: [
                            Icon(widget.unlockedIcon, color: textColor, size: 24),
                            const SizedBox(width: 6),
                            Text(widget.unlockedText, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                          ],
                        )
                      : Row(
                          key: const ValueKey('locked'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(widget.lockedIcon, color: iconColor.withValues(alpha: 0.85), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              widget.lockedText,
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                            ),
                          ],
                        ),
                ),
              ),
              // スライドつまみ
              Positioned(
                left: _trackPadding + _position,
                top: ((widget.height ?? 72) - (widget.thumbSize ?? 52)) / 2,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _position += details.delta.dx;
                      if (_position < 0) _position = 0;
                      if (_position > trackWidth) _position = trackWidth;
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_position >= trackWidth * 0.65) {
                      setState(() {
                        _position = trackWidth;
                        _showSuccessOverlay = true;
                      });
                      widget.onUnlocked();
                      Future.delayed(const Duration(milliseconds: 450), () {
                        if (!mounted) return;
                        setState(() {
                          _position = 0;
                          _showSuccessOverlay = false;
                        });
                      });
                    } else {
                      // 失敗時はバネのように戻る（簡易）
                      setState(() => _position = 0);
                    }
                  },
                  child: Container(
                    width: thumbSize,
                    height: widget.thumbSize ?? 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular((widget.thumbSize ?? 52) / 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 4)),
                      ],
                    ),
                    child: Icon(Icons.arrow_forward_ios, color: accentEnd, size: 20),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
