import 'package:flutter/material.dart';

class InvoiceHistoryScreen extends StatefulWidget {
  final bool isPickerMode;
  const InvoiceHistoryScreen({super.key, this.isPickerMode = false});

  @override
  State<InvoiceHistoryScreen> createState() => _InvoiceHistoryScreenState();
}

class _InvoiceHistoryScreenState extends State<InvoiceHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('伝票履歴')),
      body: const Center(child: Text('伝票履歴（準備中）')),
    );
  }
}
