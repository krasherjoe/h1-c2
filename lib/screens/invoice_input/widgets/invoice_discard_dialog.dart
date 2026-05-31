import 'package:flutter/material.dart';

Future<bool> showDiscardConfirmDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('変更を破棄しますか？'),
      content: const Text('保存されていない編集内容は失われます。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('編集に戻る'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
          child: const Text('破棄して戻る'),
        ),
      ],
    ),
  );
  return result ?? false;
}
