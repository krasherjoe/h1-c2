import 'package:flutter/material.dart';
import '../models/invoice_models.dart' show Invoice;

class ReceiptProcessingScreen extends StatefulWidget {
  final Invoice initialInvoice;
  const ReceiptProcessingScreen({super.key, required this.initialInvoice});

  @override
  State<ReceiptProcessingScreen> createState() => _ReceiptProcessingScreenState();
}

class _ReceiptProcessingScreenState extends State<ReceiptProcessingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('入金登録')),
      body: Center(
        child: Text(
          '入金登録機能はコア版では利用できません',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
