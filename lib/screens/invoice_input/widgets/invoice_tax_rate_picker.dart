import 'package:flutter/material.dart';

Future<Map<String, dynamic>?> showTaxRatePicker(
  BuildContext context, {
  required double currentRate,
}) async {
  final selected = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('消費税率を選択'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, '10'),
          child: const ListTile(
            leading: Icon(Icons.percent),
            title: Text('10%'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, '8'),
          child: const ListTile(
            leading: Icon(Icons.percent),
            title: Text('8%'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, '0'),
          child: const ListTile(
            leading: Icon(Icons.money_off),
            title: Text('非課税 (0%)'),
          ),
        ),
        const Divider(),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, 'tax_inclusive_10'),
          child: ListTile(
            leading: Icon(Icons.shopping_cart, color: Theme.of(ctx).colorScheme.secondary),
            title: const Text('税込み (10%)'),
            subtitle: const Text('単価を税込価格として扱い、消費税を逆算', style: TextStyle(fontSize: 11)),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, 'tax_inclusive_8'),
          child: ListTile(
            leading: Icon(Icons.shopping_cart, color: Theme.of(ctx).colorScheme.secondary),
            title: const Text('税込み (8%)'),
            subtitle: const Text('単価を税込価格として扱い、消費税を逆算', style: TextStyle(fontSize: 11)),
          ),
        ),
      ],
    ),
  );

  if (selected == null) return null;

  switch (selected) {
    case '10':
      return {
        'taxRate': 0.10,
        'includeTax': true,
        'isTaxInclusiveMode': false,
        'logMsg': '消費税率を 10% に変更しました',
      };
    case '8':
      return {
        'taxRate': 0.08,
        'includeTax': true,
        'isTaxInclusiveMode': false,
        'logMsg': '消費税率を 8% に変更しました',
      };
    case '0':
      return {
        'taxRate': 0.0,
        'includeTax': false,
        'isTaxInclusiveMode': false,
        'logMsg': '非課税 (0%) に変更しました',
      };
    case 'tax_inclusive_10':
      return {
        'taxRate': 0.10,
        'includeTax': true,
        'isTaxInclusiveMode': true,
        'logMsg': '税込みモード (10% 逆算) に変更しました',
      };
    case 'tax_inclusive_8':
      return {
        'taxRate': 0.08,
        'includeTax': true,
        'isTaxInclusiveMode': true,
        'logMsg': '税込みモード (8% 逆算) に変更しました',
      };
    default:
      return null;
  }
}
