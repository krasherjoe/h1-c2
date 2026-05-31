import 'package:flutter/material.dart';
import '../../widgets/screen_id_title.dart';

/// 請求書入力画面（メインエントリポイント）
/// コア版では簡易実装
class InvoiceInputForm extends StatefulWidget {
  final String? invoiceId;
  const InvoiceInputForm({super.key, this.invoiceId});
  @override
  State<InvoiceInputForm> createState() => _InvoiceInputFormState();
}

class _InvoiceInputFormState extends State<InvoiceInputForm> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const ScreenAppBarTitle(screenId: 'P2', title: '請求書入力')),
      body: const Center(child: Text('請求書入力 - 準備中')),
    );
  }
}
