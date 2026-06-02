import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../models/product_model.dart';
import '../../../models/product_category_model.dart';
import '../../../models/customer_model.dart';
import '../../../services/product_repository.dart';
import '../../../services/product_category_repository.dart';
import '../../../services/customer_repository.dart';
import '../../../services/permission_service.dart';
import '../../../services/sys_logger.dart';
import '../../../plugins/explorer/h1_explorer.dart';
import '../../../plugins/customers/explorer/customer_explorer_config.dart';
import '../../../plugins/customers/models/customer_explorer_item.dart';
import '../../../widgets/h1_text_field.dart';

// ---- カテゴリ関連ダイアログ ----

Future<String?> showRenameCategoryDialog(BuildContext context, String currentName) async {
  final ctrl = TextEditingController(text: currentName);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('カテゴリ名を編集'),
      content: H1TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'カテゴリ名'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
        TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('保存')),
      ],
    ),
  );
}

Future<bool> confirmDeleteCategory(BuildContext context, ProductCategory c) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('カテゴリを削除'),
      content: Text('「${c.name}」を削除しますか？\nこのカテゴリが設定された商品は「未分類」になります。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('削除', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<String?> showCategoryPicker({
  required BuildContext context,
  required List<ProductCategory> categories,
  required ProductCategoryRepository categoryRepo,
  required VoidCallback onDataRefresh,
}) async {
  final theme = Theme.of(context);
  final TextEditingController newCatCtrl = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheet) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            builder: (_, scrollCtrl) => Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('カテゴリを選択',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: H1TextField(
                          controller: newCatCtrl,
                          decoration: InputDecoration(
                            hintText: '新規カテゴリ名',
                            isDense: true,
                            filled: true,
                            fillColor: theme.cardColor,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: theme.dividerColor),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final name = newCatCtrl.text.trim();
                          if (name.isEmpty) return;
                          final id = await categoryRepo.getOrCreateCategoryId(name);
                          onDataRefresh();
                          if (ctx.mounted) Navigator.pop(ctx, id);
                        },
                        child: const Text('追加'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 16),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    children: [
                      Card(
                        color: theme.cardColor,
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          title: const Text('未分類', style: TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: const Text('カテゴリ未設定'),
                          onTap: () => Navigator.pop(ctx, ''),
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            child: Icon(Icons.folder_off, color: theme.colorScheme.outline, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final cat in categories) ...[
                        Card(
                          color: theme.cardColor,
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Text('ID: ${cat.id.substring(0, 8)}...'),
                            onTap: () => Navigator.pop(ctx, cat.id),
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.secondaryContainer,
                              child: Icon(Icons.folder, color: theme.colorScheme.secondary, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

// ---- バッチ操作 ----

Future<bool> confirmBatchDelete({
  required BuildContext context,
  required int productCount,
  required int categoryCount,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('一括削除の確認'),
      content: Text('選択された ${productCount}件の商品と ${categoryCount}件のカテゴリを削除しますか？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('削除', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<String?> confirmBatchMoveCategory({
  required BuildContext context,
  required List<ProductCategory> categories,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('移動先カテゴリ', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ListTile(
          leading: const Icon(Icons.folder_off),
          title: const Text('未分類'),
          onTap: () => Navigator.pop(ctx, ''),
        ),
        for (final cat in categories)
          ListTile(
            leading: const Icon(Icons.folder),
            title: Text(cat.name),
            onTap: () => Navigator.pop(ctx, cat.id),
          ),
      ],
    ),
  );
}

Future<void> batchDelete({
  required BuildContext context,
  required ProductRepository productRepo,
  required Set<String> selectedIds,
  required Set<String> selectedCatIds,
  required ProductCategoryRepository categoryRepo,
  required VoidCallback onComplete,
}) async {
  if (!await guardWrite(context, AppFeature.masterEdit)) return;
  var deleted = 0;
  for (final id in selectedIds) {
    try {
      await productRepo.deleteProduct(id);
      deleted++;
    } catch (e) {
      debugPrint('[P1] batch delete error: $e');
    }
  }
  for (final id in selectedCatIds) {
    try {
      await categoryRepo.deleteCategory(id);
      deleted++;
    } catch (e) {
      debugPrint('[P1] batch category delete error: $e');
    }
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$deleted件を削除しました')));
  onComplete();
}

// ---- オプション・バリエーション関連ダイアログ ----

Future<void> showOptionGroupDialog({
  required BuildContext context,
  required Product parent,
  required ProductRepository productRepo,
  required VoidCallback onComplete,
}) async {
  final groups = await productRepo.getOptionGroups(parent.id);
  if (!context.mounted) return;
  final ctrl = TextEditingController();
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) => AlertDialog(
        title: const Text('オプショングループ管理'),
        content: SizedBox(
          width: 400,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final g in groups) ...[
                ListTile(
                  dense: true,
                  title: Text(g.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () async {
                      await productRepo.deleteOptionGroup(g.id);
                      setDlgState(() {});
                    },
                  ),
                  onTap: () async {
                    final values = await productRepo.getOptionValues(g.id);
                    if (!ctx.mounted) return;
                    await showOptionValuesDialog(ctx, g, values, productRepo);
                    if (!ctx.mounted) return;
                    setDlgState(() {});
                  },
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: H1TextField(
                      controller: ctrl,
                      decoration: const InputDecoration(hintText: 'グループ名（品種・容量など）', isDense: true),
                    )),
                    IconButton(
                      icon: const Icon(Icons.add_circle),
                      onPressed: () async {
                        if (ctrl.text.trim().isEmpty) return;
                        await productRepo.saveOptionGroup(ProductOptionGroup(
                          id: const Uuid().v4(),
                          productId: parent.id,
                          name: ctrl.text.trim(),
                        ));
                        ctrl.clear();
                        setDlgState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
        ],
      ),
    ),
  );
  onComplete();
}

Future<void> showOptionValuesDialog(
  BuildContext parentCtx,
  ProductOptionGroup group,
  List<ProductOptionValue> values,
  ProductRepository productRepo,
) async {
  final ctrl = TextEditingController();
  await showDialog(
    context: parentCtx,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) => AlertDialog(
        title: Text('${group.name} の値'),
        content: SizedBox(
          width: 300,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final v in values)
                ListTile(
                  dense: true,
                  title: Text(v.value),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () async {
                      await productRepo.deleteOptionValue(v.id);
                      setDlgState(() {});
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: H1TextField(
                      controller: ctrl,
                      decoration: const InputDecoration(hintText: '値を入力', isDense: true),
                    )),
                    IconButton(
                      icon: const Icon(Icons.add_circle),
                      onPressed: () async {
                        if (ctrl.text.trim().isEmpty) return;
                        await productRepo.saveOptionValue(ProductOptionValue(
                          id: const Uuid().v4(),
                          groupId: group.id,
                          value: ctrl.text.trim(),
                        ));
                        ctrl.clear();
                        setDlgState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
        ],
      ),
    ),
  );
}

Future<void> showCreateVariantDialog({
  required BuildContext context,
  required Product parent,
  required ProductRepository productRepo,
  required VoidCallback onComplete,
}) async {
  final groups = await productRepo.getOptionGroups(parent.id);
  if (groups.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('先にオプショングループを追加してください')));
    return;
  }
  final selections = <String, String?>{};
  for (final g in groups) {
    selections[g.id] = null;
  }
  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) {
        return AlertDialog(
          title: const Text('バリエーション作成'),
          content: SizedBox(
            width: 350,
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text('各オプションを選択して「作成」をタップ'),
                const SizedBox(height: 8),
                for (final g in groups) ...[
                  FutureBuilder<List<ProductOptionValue>>(
                    future: productRepo.getOptionValues(g.id),
                    builder: (ctx, snap) {
                      final vals = snap.data ?? [];
                      return DropdownButtonFormField<String>(
                        decoration: InputDecoration(labelText: g.name, isDense: true),
                        value: selections[g.id],
                        items: vals.map((v) => DropdownMenuItem(value: v.id, child: Text(v.value))).toList(),
                        onChanged: (v) => setDlgState(() => selections[g.id] = v),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('作成'),
              onPressed: () async {
                if (selections.values.any((v) => v == null)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('全てのオプションを選択してください')));
                  return;
                }
                final nameParts = <String>[parent.name];
                for (final g in groups) {
                  final vals = await productRepo.getOptionValues(g.id);
                  final selId = selections[g.id];
                  final val = vals.firstWhere((v) => v.id == selId);
                  nameParts.add(val.value);
                }
                final variantId = const Uuid().v4();
                await productRepo.saveProduct(Product(
                  id: variantId,
                  name: nameParts.join(' '),
                  parentId: parent.id,
                  defaultUnitPrice: parent.defaultUnitPrice,
                  wholesalePrice: parent.wholesalePrice,
                  category: parent.category,
                  categoryId: parent.categoryId,
                  barcode: parent.barcode,
                ));
                await productRepo.setVariantOptions(
                  variantId,
                  selections.values.where((v) => v != null).cast<String>().toList(),
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                onComplete();
              },
            ),
          ],
        );
      },
    ),
  );
}

Future<void> showCustomerPriceDialog({
  required BuildContext context,
  required Product p,
  required ProductRepository productRepo,
  required VoidCallback onComplete,
}) async {
  final prices = await productRepo.getCustomerPrices(p.id);
  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) => AlertDialog(
        title: Text('${p.name} の顧客別価格'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (prices.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('顧客別価格が設定されていません'),
                ),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final pr in prices)
                      FutureBuilder<String>(
                        future: _customerName(pr.customerId),
                        builder: (ctx, snap) => ListTile(
                          dense: true,
                          title: Text(snap.data ?? pr.customerId),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('¥${NumberFormat('#,###').format(pr.price)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                onPressed: () async {
                                  await productRepo.deleteCustomerPrice(pr.customerId, pr.productId);
                                  setDlgState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('顧客を選択して価格設定'),
                onPressed: () async {
                  final picked = await Navigator.push<CustomerExplorerItem>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => H1Explorer(
                        config: CustomerExplorerConfig(),
                        selectionMode: true,
                      ),
                    ),
                  );
                  if (picked == null) return;
                  final customer = picked.customer;
                  if (!ctx.mounted) return;
                  final priceCtrl = TextEditingController();
                  final existingPrice = prices.firstWhere(
                    (pr) => pr.customerId == customer.id,
                    orElse: () => CustomerProductPrice(customerId: '', productId: '', price: 0),
                  );
                  priceCtrl.text = existingPrice.price > 0 ? existingPrice.price.toString() : p.defaultUnitPrice.toString();
                  final newPrice = await showDialog<int>(
                    context: ctx,
                    builder: (ctx2) => AlertDialog(
                      title: Text('${customer.displayName} の価格'),
                      content: H1TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '価格(円)'),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('キャンセル')),
                        FilledButton(onPressed: () => Navigator.pop(ctx2, int.tryParse(priceCtrl.text) ?? 0), child: const Text('保存')),
                      ],
                    ),
                  );
                  if (newPrice == null || newPrice <= 0) return;
                  await productRepo.setCustomerPrice(CustomerProductPrice(
                    customerId: customer.id,
                    productId: p.id,
                    price: newPrice,
                  ));
                  setDlgState(() {});
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
        ],
      ),
    ),
  );
  onComplete();
}

Future<String> _customerName(String customerId) async {
  final repo = CustomerRepository();
  final c = await repo.getById(customerId);
  return c?.displayName ?? customerId;
}

// ---- 詳細パネル ----

Future<void> showDetailPane({
  required BuildContext context,
  required Product p,
  required VoidCallback onEdit,
  required VoidCallback? onOptions,
  required VoidCallback? onVariant,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.45,
      maxChildSize: 0.8,
      minChildSize: 0.35,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          controller: scrollController,
          children: [
            Row(
              children: [
                Icon(
                  p.isLocked ? Icons.link : Icons.inventory_2,
                  color: p.isLocked ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: p.isLocked ? Theme.of(context).colorScheme.onSurfaceVariant : null,
                    ),
                  ),
                ),
                Chip(label: Text(p.category ?? '未分類', overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final textColor = Theme.of(context).textTheme.bodyMedium?.color;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("単価: ￥${p.defaultUnitPrice}", style: TextStyle(color: textColor)),
                    if (!p.isNonStockCategory)
                      Text("在庫: ${p.stockQuantity?.toString() ?? '管理なし'}", style: TextStyle(color: textColor)),
                    if (p.barcode != null && p.barcode!.isNotEmpty)
                      Text("バーコード: ${p.barcode}", style: TextStyle(color: textColor)),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text("編集"),
                  onPressed: () {
                    Navigator.pop(context);
                    onEdit();
                  },
                ),
                if (!p.isVariant) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.tune),
                    label: const Text("オプション"),
                    onPressed: () async {
                      Navigator.pop(context);
                      onOptions?.call();
                    },
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add_box),
                    label: const Text("バリエーション"),
                    onPressed: () {
                      Navigator.pop(context);
                      onVariant?.call();
                    },
                  ),
                ],
                if (!p.isLocked)
                  OutlinedButton.icon(
                    icon: Icon(Icons.visibility_off, color: Theme.of(context).colorScheme.error),
                    label: Text("非表示", style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("非表示の確認"),
                          content: Text("${p.name}を非表示にしますか？\n（電子帳簿保存法対応：履歴は保持されます）"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("キャンセル")),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text("非表示", style: TextStyle(color: Theme.of(context).colorScheme.error)),
                            ),
                          ],
                        ),
                      );
                      if (!context.mounted) return;
                      if (confirmed == true) {
                        final repo = ProductRepository();
                        await repo.setHiddenProduct(p.id, true);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      }
                    },
                  ),
                if (p.isLocked)
                  Chip(
                    label: const Text("ロック済み"),
                    avatar: const Icon(Icons.link, size: 16),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// ---- 重複整理 ----

Future<void> cleanupDuplicateVersions({
  required BuildContext context,
  required ProductRepository productRepo,
  required VoidCallback onComplete,
}) async {
  final theme = Theme.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('重複商品を整理'),
      content: const Text(
        '同じ商品名で複数のレコードが存在する場合、\n古い方を非現行化＆非表示にします。\n\nデータは削除されません。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: theme.cardColor,
          ),
          child: const Text('整理する'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    final count = await productRepo.cleanupDuplicateVersions();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(count > 0 ? '$count件の古いレコードを非表示にしました' : '重複は見つかりませんでした'),
        backgroundColor: count > 0 ? Theme.of(context).colorScheme.primary : null,
      ),
    );
    onComplete();
  } catch (e) {
    SysLogger.instance.logError('P1', e);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('エラー: $e'), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }
}
