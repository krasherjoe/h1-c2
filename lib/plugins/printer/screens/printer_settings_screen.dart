import 'package:flutter/material.dart';
import '../../documents/models/document_model.dart';
import '../../../constants/screen_ids.dart';

class PrinterSettingsScreen extends StatefulWidget {
  final DocumentModel? document;
  const PrinterSettingsScreen({super.key, this.document});
  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  String _preview = '';

  @override
  void initState() {
    super.initState();
    if (widget.document != null) _generatePreview();
  }

  void _generatePreview() {
    final doc = widget.document!;
    final sb = StringBuffer();
    sb.writeln(' ${doc.documentType.label}');
    sb.writeln('=' * 32);
    sb.writeln(' ${doc.date.year}/${doc.date.month}/${doc.date.day}');
    sb.writeln(' ${doc.documentNumber}');
    sb.writeln(' ${doc.customerName}');
    sb.writeln('-' * 32);
    for (final item in doc.items) {
      sb.writeln(' ${item.productName}');
      sb.writeln('  ${item.quantity} x ${item.unitPrice}');
    }
    sb.writeln('-' * 32);
    sb.writeln(' 合計: ${doc.total}');
    sb.writeln('=' * 32);
    sb.writeln(' 署名: _________________');
    setState(() => _preview = sb.toString());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('${S.pt}:レシート印刷')),
      body: _preview.isEmpty
          ? Center(child: Text('プレビューがありません', style: TextStyle(color: cs.onSurfaceVariant)))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: Text(_preview, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: cs.onSurface)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Androidの共有メニューからBluetooth印刷を選択できます',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
    );
  }
}
