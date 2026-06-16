import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/gemini_ocr_service.dart';
import '../../../services/database_helper.dart';
import '../services/auto_journal_service.dart';
import '../../../constants/screen_ids.dart';

class ReceiptPhotoScreen extends StatefulWidget {
  const ReceiptPhotoScreen({super.key});
  @override
  State<ReceiptPhotoScreen> createState() => _ReceiptPhotoScreenState();
}

class _ReceiptPhotoScreenState extends State<ReceiptPhotoScreen> {
  final _picker = ImagePicker();
  final _ocr = GeminiOcrService();
  File? _image;
  ReceiptOcrResult? _result;
  bool _analyzing = false;
  String? _error;
  bool _saving = false;

  Future<void> _pickImage(ImageSource source) async {
    final x = await _picker.pickImage(source: source, maxWidth: 1024);
    if (x == null) return;
    setState(() { _image = File(x.path); _result = null; _error = null; });
  }

  Future<void> _analyze() async {
    if (_image == null) return;
    setState(() { _analyzing = true; _error = null; });
    final result = await _ocr.analyzeReceipt(_image!.path);
    if (!mounted) return;
    setState(() { _analyzing = false; _result = result; _error = result == null ? '解析に失敗しました' : null; });
  }

  Future<void> _saveAsJournal() async {
    if (_result == null) return;
    setState(() => _saving = true);
    try {
      final date = _result!.date != null ? DateTime.tryParse(_result!.date!) : null;
      await AutoJournalService().createFromReceiptPhoto(
        total: _result!.total,
        description: _result!.items.isNotEmpty
            ? _result!.items.take(3).join('、')
            : 'レシート撮影',
        date: date,
        vendor: _result!.vendor,
        tax: _result!.tax,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('仕訳を登録しました')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '保存エラー: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('${S.rc}:レシート撮影')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_image != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(_image!, height: 240, fit: BoxFit.cover, width: double.infinity),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _analyzing ? null : _analyze,
              icon: _analyzing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: Text(_analyzing ? '解析中...' : 'AI解析'),
            ),
          ] else ...[
            Container(
              height: 200, width: double.infinity,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long, size: 48, color: cs.onSurfaceVariant),
                    const SizedBox(height: 8),
                    Text('レシートを撮影または選択', style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: FilledButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('撮影'),
              )),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('選択'),
              )),
            ]),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: cs.error)),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            Card(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('解析結果', style: Theme.of(context).textTheme.titleMedium),
                const Divider(),
                if (_result!.vendor != null) _row('事業者', _result!.vendor!),
                if (_result!.date != null) _row('日付', _result!.date!),
                _row('合計', '${_result!.total}円'),
                if (_result!.subtotal != null) _row('小計', '${_result!.subtotal}円'),
                if (_result!.tax != null) _row('消費税', '${_result!.tax}円'),
                if (_result!.items.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('品目:', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                  ..._result!.items.map((item) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text('・$item', style: const TextStyle(fontSize: 12)),
                  )),
                ],
              ]),
            )),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _saveAsJournal,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_saving ? '保存中...' : '仕訳として登録'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
        Expanded(child: Text(value)),
      ]),
    );
  }
}
