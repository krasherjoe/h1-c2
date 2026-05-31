import 'package:flutter/material.dart';

typedef GuardWriteCallback = Future<void> Function();

Future<void> guardWrite(
  BuildContext context,
  GuardWriteCallback callback, {
  String? successMessage,
}) async {
  try {
    await callback();
    if (successMessage != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e')),
      );
    }
  }
}
