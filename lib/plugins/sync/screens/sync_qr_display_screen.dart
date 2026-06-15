import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/google_auth_service.dart';

class SyncQrDisplayScreen extends StatefulWidget {
  const SyncQrDisplayScreen({super.key});
  @override
  State<SyncQrDisplayScreen> createState() => _SyncQrDisplayScreenState();
}

class _SyncQrDisplayScreenState extends State<SyncQrDisplayScreen> {
  String? _qrData;
  String? _token;
  final _tokenTime = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _generateQr();
  }

  Future<void> _generateQr() async {
    final email = await GoogleAuthService.instance.getEmail();
    if (email == null || email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Googleアカウントでログインしてください')),
        );
        Navigator.pop(context);
      }
      return;
    }
    _token = '${_tokenTime}_${email.hashCode}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sync_qr_token_$_token', email);
    setState(() {
      _qrData = 'h1sync://register?e=${Uri.encodeComponent(email)}&t=$_token';
    });
  }

  @override
  void dispose() {
    if (_token != null) {
      SharedPreferences.getInstance().then((prefs) => prefs.remove('sync_qr_token_$_token'));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('子分を追加')),
      body: Center(
        child: _qrData == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cs.primary, width: 2),
                    ),
                    child: QrImageView(
                      data: _qrData!,
                      version: QrVersions.auto,
                      size: 250,
                      eyeStyle: QrEyeStyle(color: Colors.black, eyeShape: QrEyeShape.square),
                      dataModuleStyle: const QrDataModuleStyle(color: Colors.black, dataModuleShape: QrDataModuleShape.square),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('このQRを子分に読み取らせてください',
                      style: TextStyle(fontSize: 14, color: cs.onSurface)),
                  const SizedBox(height: 8),
                  Text('画面を閉じるとトークンは無効になります',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              ),
      ),
    );
  }
}
