import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:h_1_core/constants/screen_ids.dart';
import 'package:h_1_core/widgets/screen_id_title.dart';

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
    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanned) return;
    
    final barcode = capture.barcodes.first;
    if (barcode.rawValue != null) {
      setState(() => _isScanned = true);
      
      // バイブレーションでフィードバック
      // (必要に応じて追加)
      
      Navigator.pop(context, barcode.rawValue);
    }
  }

  void _toggleTorch() {
    setState(() {
      _isTorchOn = !_isTorchOn;
    });
    _controller.toggleTorch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const ScreenAppBarTitle(screenId: S.sh4, title: 'バーコードスキャン'),
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
                    _controller.start();
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
