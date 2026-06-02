import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../models/company_info.dart';
import '../../../services/company_repository.dart';
import '../../documents/logic/document_pdf_generator.dart';
import '../../documents/models/document_model.dart';

class SealOffsetAdjustPage extends StatefulWidget {
  final String sealPath;
  final double initialOffsetX;
  final double initialOffsetY;
  final CompanyInfo companyInfo;

  const SealOffsetAdjustPage({
    super.key,
    required this.sealPath,
    required this.initialOffsetX,
    required this.initialOffsetY,
    required this.companyInfo,
  });

  @override
  State<SealOffsetAdjustPage> createState() => _SealOffsetAdjustPageState();
}

class _SealOffsetAdjustPageState extends State<SealOffsetAdjustPage> {
  late double _offsetX;
  late double _offsetY;
  int _rebuildKey = 0;
  final _companyRepo = CompanyRepository();

  @override
  void initState() {
    super.initState();
    _offsetX = widget.initialOffsetX;
    _offsetY = widget.initialOffsetY;
  }

  Future<Uint8List> _buildPreviewBytes(PdfPageFormat format) async {
    final doc = await generateDocumentPdf(
      _dummyDocumentForSealPreview(widget.companyInfo),
      sealOffsetXOverride: _offsetX,
      sealOffsetYOverride: _offsetY,
    );
    return Uint8List.fromList(await doc.save());
  }

  void _moveSeal(bool isX, {required bool toIncreaseDirection, required double amount}) {
    setState(() {
      if (isX) {
        _offsetX = (_offsetX + (toIncreaseDirection ? -amount : amount)).clamp(-200.0, 500.0);
      } else {
        _offsetY = (_offsetY + (toIncreaseDirection ? amount : -amount)).clamp(-200.0, 700.0);
      }
      _rebuildKey++;
    });
  }

  Widget _nudgeRow({
    required String label,
    required double value,
    required bool isX,
  }) {
    final decBig = isX ? Icons.keyboard_double_arrow_left : Icons.keyboard_double_arrow_up;
    final decOne = isX ? Icons.keyboard_arrow_left : Icons.keyboard_arrow_up;
    final incOne = isX ? Icons.keyboard_arrow_right : Icons.keyboard_arrow_down;
    final incBig = isX ? Icons.keyboard_double_arrow_right : Icons.keyboard_double_arrow_down;
    final decBigTip = isX ? '左 \u00d75' : '上 \u00d75';
    final decOneTip = isX ? '左 \u00d71' : '上 \u00d71';
    final incOneTip = isX ? '右 \u00d71' : '下 \u00d71';
    final incBigTip = isX ? '右 \u00d75' : '下 \u00d75';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: Icon(decBig),
            onPressed: () => _moveSeal(isX, toIncreaseDirection: false, amount: 5),
            tooltip: decBigTip,
          ),
          IconButton(
            icon: Icon(decOne),
            onPressed: () => _moveSeal(isX, toIncreaseDirection: false, amount: 1),
            tooltip: decOneTip,
          ),
          SizedBox(
            width: 56,
            child: Center(
              child: Text(
                value.toStringAsFixed(1),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            icon: Icon(incOne),
            onPressed: () => _moveSeal(isX, toIncreaseDirection: true, amount: 1),
            tooltip: incOneTip,
          ),
          IconButton(
            icon: Icon(incBig),
            onPressed: () => _moveSeal(isX, toIncreaseDirection: true, amount: 5),
            tooltip: incBigTip,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('角印位置調整'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final updated = widget.companyInfo.copyWith(
                sealOffsetX: _offsetX,
                sealOffsetY: _offsetY,
              );
              await _companyRepo.saveCompanyInfo(updated);
              if (!context.mounted) return;
              final nav = Navigator.of(context);
              nav.pop({'x': _offsetX, 'y': _offsetY});
            },
            icon: const Icon(Icons.check),
            label: const Text('確定'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: PdfPreview(
                    key: ValueKey(_rebuildKey),
                    initialPageFormat: kSealPreviewPageFormat,
                    build: _buildPreviewBytes,
                    allowPrinting: false,
                    allowSharing: false,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    actions: const [],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '方向ボタンで角印を移動 | X:右端からの距離 Y:上端からの距離',
                              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _nudgeRow(label: '横 (左右)', value: _offsetX, isX: true),
                      _nudgeRow(label: '縦 (上下)', value: _offsetY, isX: false),
                      Text(
                        '単位: PDF pt（1pt = 1/72インチ）',
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final updated = widget.companyInfo.copyWith(
                        sealOffsetX: _offsetX,
                        sealOffsetY: _offsetY,
                      );
                      await _companyRepo.saveCompanyInfo(updated);
                      if (!context.mounted) return;
                      final nav = Navigator.of(context);
                      nav.pop({'x': _offsetX, 'y': _offsetY});
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('確定'),
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

DocumentModel _dummyDocumentForSealPreview(CompanyInfo info) {
  return DocumentModel(
    id: '__preview__',
    documentType: DocumentType.invoice,
    customerId: '__preview__',
    customerName: 'サンプル株式会社',
    documentNumber: 'PREVIEW-001',
    date: DateTime.now(),
    status: 'confirmed',
    items: [
      DocumentItem(
        id: 'p1',
        productId: 'p1',
        productName: 'サンプル商品',
        quantity: 1,
        unitPrice: 10000,
      ),
    ],
  );
}
