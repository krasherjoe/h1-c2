import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/sync_queue.dart';

class SyncQrScannerScreen extends StatefulWidget {
  const SyncQrScannerScreen({super.key});
  @override
  State<SyncQrScannerScreen> createState() => _SyncQrScannerScreenState();
}

class _SyncQrScannerScreenState extends State<SyncQrScannerScreen> {
  bool _done = false;

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final qr = capture.barcodes.firstOrNull?.rawValue;
    if (qr == null || !qr.startsWith('h1sync://register?')) return;
    _done = true;
    final uri = Uri.parse(qr);
    final email = uri.queryParameters['e'];
    final token = uri.queryParameters['t'];
    if (email == null || token == null) {
      _done = false;
      return;
    }
    _register(email, token);
  }

  Future<void> _register(String parentEmail, String token) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('親分登録確認'),
        content: Text('「$parentEmail」を親分として登録しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('登録')),
        ],
      ),
    );
    if (confirmed != true) { _done = false; return; }

    await SyncQueue.instance.setParentEmail(parentEmail);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sync_registered_via', 'qr:$token');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('親分「$parentEmail」と同期しました')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('QRコードをスキャン')),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              onDetect: _onDetect,
              fit: BoxFit.cover,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: cs.surface,
            child: Text('親分のQRコードを枠内に合わせてください',
                style: TextStyle(fontSize: 14, color: cs.onSurface),
                textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
