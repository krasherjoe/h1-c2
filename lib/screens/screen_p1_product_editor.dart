import 'package:flutter/material.dart';

class ProductEditorScreen extends StatelessWidget {
  final dynamic product;
  const ProductEditorScreen({super.key, this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('商品編集')),
      body: const Center(child: Text('準備中')),
    );
  }
}
