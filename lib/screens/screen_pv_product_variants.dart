import 'package:flutter/material.dart';

class ProductVariantsScreen extends StatelessWidget {
  final dynamic parent;
  const ProductVariantsScreen({super.key, this.parent});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('商品バリエーション管理')),
      body: const Center(child: Text('準備中')),
    );
  }
}
