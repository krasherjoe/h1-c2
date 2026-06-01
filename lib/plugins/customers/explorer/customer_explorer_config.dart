import 'package:flutter/material.dart';
import '../../../plugins/explorer/h1_explorer_config.dart';
import '../../../models/customer_model.dart';
import '../../../services/customer_repository.dart';
import '../../../services/error_reporter.dart';
import '../../../screens/customer_edit_screen.dart';
import '../../../screens/customer_master/logic/customer_search_filter.dart';
import '../../../screens/customer_master/logic/customer_import_export.dart';
import '../../../screens/customer_master/logic/customer_dialogs.dart';
import '../../../screens/customer_master/logic/customer_utils.dart';
import '../models/customer_explorer_item.dart';

class CustomerExplorerConfig extends H1ExplorerConfig<CustomerExplorerItem> {
  String _sortKey = 'name_asc';

  CustomerExplorerConfig();

  @override
  String get explorerTitle => '得意先マスター';

  @override
  String get searchHint => '顧客名で検索';

  @override
  IconData get itemIcon => Icons.person;

  @override
  String get emptyMessage => '顧客が登録されていません';

  @override
  List<SortOption> get sortOptions => [
        const SortOption(key: 'name_asc', label: '名前順'),
        const SortOption(key: 'name_desc', label: '名前順（降順）'),
      ];

  @override
  String get currentSortKey => _sortKey;

  @override
  void onSortChanged(String key) {
    _sortKey = key;
  }

  @override
  String? groupKey(CustomerExplorerItem item) {
    return kanaCharToGroup(kanaFirstChar(item.customer));
  }

  @override
  Future<List<CustomerExplorerItem>> fetchItems(String query) async {
    final repo = CustomerRepository();
    List<Customer> customers;
    if (query.isNotEmpty) {
      customers = await repo.searchCustomers(query);
    } else {
      customers = await repo.getAllCustomers();
    }
    final list = List<Customer>.from(customers);
    await sortCustomers(
      list: list,
      sortKey: _sortKey,
      showHidden: false,
      ignoreCorpPrefix: true,
    );
    return list.map((c) => CustomerExplorerItem(c)).toList();
  }

  @override
  Widget buildViewer(BuildContext context, CustomerExplorerItem item) {
    return CustomerEditScreen(customer: item.customer);
  }

  @override
  Widget buildEditor(BuildContext context, CustomerExplorerItem? item) {
    return CustomerEditScreen(customer: item?.customer);
  }

  @override
  Future<bool> canDelete(CustomerExplorerItem item) async => true;

  @override
  Future<void> deleteItem(CustomerExplorerItem item) async {
    final repo = CustomerRepository();
    await repo.deleteCustomer(item.customer.id);
  }

  @override
  List<({String id, IconData icon, String label})> get overflowActions => [
    (id: 'import', icon: Icons.file_upload, label: 'CSV取込'),
    (id: 'export', icon: Icons.file_download, label: 'CSV出力'),
    (id: 'honorific', icon: Icons.auto_fix_high, label: '敬称の重複をチェック'),
  ];

  @override
  void onOverflowAction(
    BuildContext context,
    String id, {
    required VoidCallback onListChanged,
  }) async {
    switch (id) {
      case 'import':
        importCsv(context, onListChanged);
      case 'export':
        final repo = CustomerRepository();
        final all = await repo.getAllCustomers();
        exportCsv(all);
      case 'honorific':
        final repo = CustomerRepository();
        final all = await repo.getAllCustomers();
        cleanDuplicateHonorific(
          context: context,
          customers: all,
          customerRepo: repo,
          onComplete: onListChanged,
        );
    }
  }

  @override
  List<({IconData icon, String label, VoidCallback onTap})>? fabActions(
          BuildContext context) =>
      [
        (
          icon: Icons.edit_note,
          label: '手入力で新規作成',
          onTap: () => _openNewEditor(context),
        ),
        (
          icon: Icons.contact_phone,
          label: '電話帳から取り込む',
          onTap: () => _openPhonebookImport(context),
        ),
      ];

  void _openNewEditor(BuildContext context) async {
    try {
      final result = await Navigator.push<Customer>(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerEditScreen(),
        ),
      );
      if (result != null && context.mounted) {
        final repo = CustomerRepository();
        await repo.saveCustomer(result);
        if (context.mounted) {
          onListChanged?.call();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('「${result.displayName}」を登録しました'),
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ErrorReporter.showError(
        context,
        message: '顧客登録エラー',
        detail: e.toString(),
        screenId: 'C3',
        stackTrace: e is Error ? e.stackTrace : null,
      );
    }
  }

  void _openPhonebookImport(BuildContext context) {
    showPhonebookImport(
      context: context,
      customerRepo: CustomerRepository(),
      onComplete: () {},
    );
  }
}
