import 'package:flutter/material.dart';
import '../../../plugins/explorer/h1_explorer_config.dart';
import '../../../utils/theme_utils.dart';
import '../../../services/input_style_service.dart';
import '../models/accounting_voucher.dart';
import '../services/accounting_voucher_repository.dart';
import '../../../constants/screen_ids.dart';

class AccountingExplorerConfig extends H1ExplorerConfig<AccountingVoucher> {
  AccountingExplorerConfig();

  @override
  bool get viewerHasOwnScaffold => true;

  @override
  Widget buildViewer(BuildContext context, AccountingVoucher item) {
    // TODO: 会計伝票詳細画面
    return Scaffold(
      appBar: AppBar(title: Text(item.voucherNumber)),
      body: Center(child: Text('会計伝票詳細: ${item.voucherNumber}')),
    );
  }

  @override
  Widget buildEditor(BuildContext context, AccountingVoucher? item) {
    // TODO: 会計伝票編集画面
    return Scaffold(
      appBar: AppBar(title: Text(item != null ? '編集' : '新規')),
      body: Center(child: Text('会計伝票編集')),
    );
  }

  static const _typeOptions = [
    (value: '', label: 'すべて', icon: Icons.all_inbox),
    (value: 'sales', label: '売上', icon: Icons.trending_up),
    (value: 'cashIn', label: '入金', icon: Icons.account_balance_wallet),
    (value: 'cashOut', label: '出金', icon: Icons.payment),
    (value: 'transfer', label: '振替', icon: Icons.swap_horiz),
  ];

  @override
  String get explorerTitle => '${S.d2}:会計伝票';

  @override
  List<({String value, String label, IconData icon})> get typeFilterOptions => _typeOptions;

  @override
  String get searchHint => '伝票番号・顧客名で検索';

  @override
  bool get showSearch => true;

  @override
  IconData get itemIcon => Icons.receipt_long;

  @override
  String get emptyMessage => '会計伝票がありません';

  static IconData _typeIcon(AccountingVoucherType type) => switch (type) {
    AccountingVoucherType.sales => Icons.trending_up,
    AccountingVoucherType.cashIn => Icons.account_balance_wallet,
    AccountingVoucherType.cashOut => Icons.payment,
    AccountingVoucherType.transfer => Icons.swap_horiz,
  };

  @override
  List<({IconData icon, String label, Future<void> Function() onTap})>? fabActions(
          BuildContext context) =>
      AccountingVoucherType.values.map((t) => (
        icon: _typeIcon(t),
        label: '${t.fullName}を新規作成',
        onTap: () => _openNewVoucher(context, t),
      )).toList();

  Future<void> _openNewVoucher(BuildContext context, AccountingVoucherType type) async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => AccountingExplorerConfig().buildEditor(context, null),
      ),
    );
    if (result != null) {
      onListChanged?.call();
    }
  }

  @override
  Future<List<AccountingVoucher>> fetchItems(String query) async {
    final repo = AccountingVoucherRepository();
    AccountingVoucherType? filterType;
    if (typeFilter.isNotEmpty) {
      filterType = AccountingVoucherTypeExtension.fromString(typeFilter);
    }
    return repo.fetchAll(
      filterType: filterType,
      query: query,
      statusFilter: statusFilter.isNotEmpty ? statusFilter : null,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
  }

  @override
  Widget buildItemTileContent(BuildContext context, AccountingVoucher item) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 伝票タイプ色
    final typeColor = switch (item.type) {
      AccountingVoucherType.sales => Colors.green,
      AccountingVoucherType.cashIn => Colors.blue,
      AccountingVoucherType.cashOut => Colors.red,
      AccountingVoucherType.transfer => Colors.orange,
    };
    
    final shortType = item.type.label;
    final verticalType = shortType.split('').join('\n');
    final date = '${item.date.year}/${item.date.month.toString().padLeft(2, '0')}/${item.date.day.toString().padLeft(2, '0')}';
    final money = '¥${item.amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    final hasDraft = item.isDraft;

    // 会計伝票特有の表示
    final entityName = switch (item.type) {
      AccountingVoucherType.sales => item.customerName,
      AccountingVoucherType.cashIn => item.customerName,
      AccountingVoucherType.cashOut => item.accountName,
      AccountingVoucherType.transfer => item.accountName,
    };

    return ValueListenableBuilder<String>(
      valueListenable: inputStyleNotifier,
      builder: (context, inputStyle, _) {
        final isRaised = inputStyle == 'raised';
        final cardBg = hasDraft
            ? cs.surfaceContainerLow
            : (Theme.of(context).cardTheme.color ?? cs.surface);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isRaised ? [
              BoxShadow(color: cs.shadow.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2)),
              BoxShadow(color: cs.shadow.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
            ] : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: (88 * MediaQuery.textScalerOf(context).scale(1.0)).ceilToDouble(),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    color: typeColor,
                    alignment: Alignment.center,
                    child: Text(verticalType,
                        style: TextStyle(color: _textColorOn(typeColor), fontSize: 11, fontWeight: FontWeight.bold, height: 1.15),
                        textAlign: TextAlign.center),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(date, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(item.voucherNumber,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            if (hasDraft) _statusBadge('下書き', Colors.orange, cs),
                          ]),
                          if (entityName != null)
                            Text(entityName!,
                                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (item.description != null)
                            Text(item.description!,
                                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          Row(children: [
                            Text('💰', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                            const SizedBox(width: 4),
                            Text(money,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.primary)),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _textColorOn(Color color) {
    // 簡易的な明暗判定
    final luminance = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  Widget _statusBadge(String text, Color color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    );
  }

  @override
  Future<bool> canDelete(AccountingVoucher item) async => item.isDraft;

  @override
  Future<void> deleteItem(AccountingVoucher item) async {
    final repo = AccountingVoucherRepository();
    await repo.delete(item.id);
  }
}
