import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// 角印撮影用カメラ画面（サイズガイド付き）
class SealCameraScreen extends StatefulWidget {
  const SealCameraScreen({super.key});

  @override
  State<SealCameraScreen> createState() => _SealCameraScreenState();
}

class _SealCameraScreenState extends State<SealCameraScreen> {
  CameraController? _controller;
  bool _isReady = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('カメラが見つかりません')));
        Navigator.pop(context);
      }
      return;
    }

    // 背面カメラを使用
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();
    if (mounted) {
      setState(() => _isReady = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    if (_isCapturing ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final photo = await _controller!.takePicture();

      // 写真をアプリの保存領域にコピー
      final tempDir = await getTemporaryDirectory();
      final fileName = 'seal_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = path.join(tempDir.path, fileName);

      await File(photo.path).copy(savedPath);

      if (mounted) {
        Navigator.pop(context, savedPath);
      }
    } catch (e) {
      debugPrint('[SealCamera] $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('撮影に失敗しました: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady || _controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final size = MediaQuery.of(context).size;
    final shortestSide = size.shortestSide;

    // 1cmと2cmのガイドサイズ（画面の密度に応じて計算）
    // 標準的なスマホ画面（約400-500dp幅）を想定
    final cm1Size = shortestSide * 0.15;
    final cm2Size = shortestSide * 0.30;
    final sealSize = shortestSide * 0.25;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),

          CustomPaint(
            size: size,
            painter: _GuideOverlayPainter(
              cm1Size: cm1Size,
              cm2Size: cm2Size,
              sealSize: sealSize,
              cs: cs,
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black54,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '角印を中央の四角枠に合わせてください',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '・内枠 = 角印標準サイズ (約21mm)\n・中枠 = 2cmガイド\n・外枠 = 3cmガイド',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                Container(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 40),

                      GestureDetector(
                        onTap: _takePhoto,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            color: _isCapturing
                                ? cs.outline
                                : cs.surface.withValues(alpha: 0.3),
                          ),
                          child: Center(
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),

                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Center(
            child: IgnorePointer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.54),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '21mm (角印標準)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideOverlayPainter extends CustomPainter {
  final double cm1Size;
  final double cm2Size;
  final double sealSize;
  final ColorScheme cs;

  _GuideOverlayPainter({
    required this.cm1Size,
    required this.cm2Size,
    required this.sealSize,
    required this.cs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final sealPaint = Paint()
      ..color = cs.error.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final guide2cmPaint = Paint()
      ..color = cs.secondary.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final guide3cmPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final cornerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final sealRect = Rect.fromCenter(
      center: center,
      width: sealSize,
      height: sealSize,
    );
    canvas.drawRect(sealRect, sealPaint);

    final cornerLength = sealSize * 0.15;
    _drawCornerMarkers(canvas, sealRect, cornerLength, cornerPaint);

    final guide2cmRect = Rect.fromCenter(
      center: center,
      width: cm2Size,
      height: cm2Size,
    );
    _drawDashedRect(canvas, guide2cmRect, guide2cmPaint, dashPattern: [10, 5]);

    final guide3cmSize = cm2Size * 1.5;
    final guide3cmRect = Rect.fromCenter(
      center: center,
      width: guide3cmSize,
      height: guide3cmSize,
    );
    _drawDashedRect(canvas, guide3cmRect, guide3cmPaint, dashPattern: [5, 10]);

    _drawSizeLabel(
      canvas,
      Offset(center.dx + sealSize / 2 + 8, center.dy),
      '21mm',
      cs.error,
    );
    _drawSizeLabel(
      canvas,
      Offset(center.dx + cm2Size / 2 + 8, center.dy - cm2Size / 2 + 10),
      '2cm',
      cs.secondary,
    );
    _drawSizeLabel(
      canvas,
      Offset(
        center.dx + guide3cmSize / 2 + 8,
        center.dy - guide3cmSize / 2 + 10,
      ),
      '3cm',
      Colors.white70,
    );
  }

  void _drawDashedRect(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    List<double>? dashPattern,
  }) {
    dashPattern ??= [5, 5];

    final path = Path();
    final left = rect.left;
    final top = rect.top;
    final right = rect.right;
    final bottom = rect.bottom;

    final lineWidth = paint.strokeWidth / 2;
    final dashLength = dashPattern[0];
    final gapLength = dashPattern.length > 1 ? dashPattern[1] : dashPattern[0];

    double x = left + lineWidth;
    while (x < right - lineWidth) {
      path.lineTo(x + dashLength, top + lineWidth);
      x += dashLength + gapLength;
    }

    double y = top + lineWidth;
    while (y < bottom - lineWidth) {
      path.moveTo(right - lineWidth, y + dashLength);
      path.lineTo(right - lineWidth, y + dashLength + gapLength);
      y += dashLength + gapLength;
    }

    x = right - lineWidth;
    while (x > left + lineWidth) {
      path.lineTo(x - dashLength, bottom - lineWidth);
      x -= dashLength + gapLength;
    }

    y = bottom - lineWidth;
    while (y > top + lineWidth) {
      path.moveTo(left + lineWidth, y - dashLength);
      path.lineTo(left + lineWidth, y - dashLength - gapLength);
      y -= dashLength + gapLength;
    }

    canvas.drawPath(path, paint..style = PaintingStyle.stroke);
  }

  void _drawCornerMarkers(
    Canvas canvas,
    Rect rect,
    double length,
    Paint paint,
  ) {
    final left = rect.left;
    final top = rect.top;
    final right = rect.right;
    final bottom = rect.bottom;

    canvas.drawLine(Offset(left, top + length), Offset(left, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left + length, top), paint);

    canvas.drawLine(Offset(right - length, top), Offset(right, top), paint);
    canvas.drawLine(Offset(right, top), Offset(right, top + length), paint);

    canvas.drawLine(Offset(left, bottom - length), Offset(left, bottom), paint);
    canvas.drawLine(Offset(left, bottom), Offset(left + length, bottom), paint);

    canvas.drawLine(
      Offset(right - length, bottom),
      Offset(right, bottom),
      paint,
    );
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right, bottom - length),
      paint,
    );
  }

  void _drawSizeLabel(
    Canvas canvas,
    Offset position,
    String text,
    Color color,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
                      backgroundColor: cs.surface.withValues(alpha: 0.54),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
