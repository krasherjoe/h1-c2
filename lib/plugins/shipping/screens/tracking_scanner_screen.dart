import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:h_1_core/constants/screen_ids.dart';
import 'package:h_1_core/services/error_log_service.dart';

class TrackingScannerScreen extends StatefulWidget {
  const TrackingScannerScreen({super.key});

  @override
  State<TrackingScannerScreen> createState() => _TrackingScannerScreenState();
}

class _TrackingScannerScreenState extends State<TrackingScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isScanned = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    try {
      _controller.start();
    } catch (e, stackTrace) {
      ErrorLogService.instance.logError(
        'カメラ起動エラー: $e',
        stackTrace: stackTrace.toString(),
        screen: 'TrackingScannerScreen',
        context: 'initState',
      );
    }
  }

  @override
  void dispose() {
    try {
      _controller.dispose();
    } catch (e, stackTrace) {
      ErrorLogService.instance.logError(
        'カメラコントローラ破棄エラー: $e',
        stackTrace: stackTrace.toString(),
        screen: 'TrackingScannerScreen',
        context: 'dispose',
      );
    }
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanned) return;
    
    if (capture.barcodes.isEmpty) return;
    
    try {
      final barcode = capture.barcodes.first;
      if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
        setState(() => _isScanned = true);
        
        // バイブレーションでフィードバック
        // (必要に応じて追加)
        
        Navigator.pop(context, barcode.rawValue);
      }
    } catch (e, stackTrace) {
      ErrorLogService.instance.logError(
        'バーコードスキャンエラー: $e',
        stackTrace: stackTrace.toString(),
        screen: 'TrackingScannerScreen',
        context: 'バーコード検出処理',
      );
    }
  }

  void _toggleTorch() {
    try {
      setState(() {
        _isTorchOn = !_isTorchOn;
      });
      _controller.toggleTorch();
    } catch (e, stackTrace) {
      ErrorLogService.instance.logError(
        'トライトグルエラー: $e',
        stackTrace: stackTrace.toString(),
        screen: 'TrackingScannerScreen',
        context: 'トライトグル',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('${S.sh4}:バーコードスキャン'),
        actions: [
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleTorch,
          ),
        ],
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
        errorBuilder: (context, error, child) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('カメラエラー: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    try {
                      _controller.start();
                    } catch (e, stackTrace) {
                      ErrorLogService.instance.logError(
                        'カメラ再起動エラー: $e',
                        stackTrace: stackTrace.toString(),
                        screen: 'TrackingScannerScreen',
                        context: 'カメラ再起動',
                      );
                    }
                  },
                  child: const Text('再試行'),
                ),
              ],
            ),
          );
        },
        fit: BoxFit.contain,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.black54,
        child: const Text(
          'バーコードまたはQRコードをカメラに向けてください',
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
