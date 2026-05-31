import 'package:flutter/material.dart';

class SimpleVariantEditorScreen extends StatelessWidget {
  final dynamic parent;
  const SimpleVariantEditorScreen({super.key, this.parent});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('バリエーション編集')),
      body: const Center(child: Text('準備中')),
    );
  }
}
