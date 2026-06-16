import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../logic/memorandum_pdf_generator.dart';
import '../models/memorandum_model.dart';
import '../../../constants/screen_ids.dart';

class MemorandumPreviewScreen extends StatefulWidget {
  final Memorandum memorandum;

  const MemorandumPreviewScreen({super.key, required this.memorandum});

  @override
  State<MemorandumPreviewScreen> createState() => _MemorandumPreviewScreenState();
}

class _MemorandumPreviewScreenState extends State<MemorandumPreviewScreen> {
  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    final pdf = await buildMemorandumDocument(widget.memorandum);
    return pdf.save();
  }

  Future<void> _saveToFile() async {
    try {
      final pdf = await buildMemorandumDocument(widget.memorandum);
      final bytes = await pdf.save();
      final fileName = '覚書_${widget.memorandum.documentNumber}_${widget.memorandum.customerName}.pdf';
      final dir = await _getDownloadDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存しました: ${dir.path}/$fileName')),
      );
    } catch (e) {
      debugPrint('[MemoPreview] _saveToFile error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存エラー: $e')),
      );
    }
  }

  Future<Directory> _getDownloadDirectory() async {
    try {
      if (Platform.isAndroid) {
        try {
          final dir = Directory('/storage/emulated/0/Download');
          if (await dir.exists()) {
            return dir;
          }
        } catch (_) {}
      } else if (Platform.isIOS) {
        return await getApplicationDocumentsDirectory();
      }
    } catch (e) {
      debugPrint('[MemoPreview] getDownloadDirectory error: $e');
    }
    return await getApplicationDocumentsDirectory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('\${S.mp}:覚書プレビュー'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'ダウンロードに保存',
            onPressed: _saveToFile,
          ),
        ],
      ),
      body: PdfPreview(
        build: _buildPdf,
        pdfFileName: '覚書_${widget.memorandum.documentNumber}',
      ),
    );
  }
}
