import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../../plugins/explorer/h1_explorer_config.dart';
import '../../../models/customer_model.dart';
import '../../../services/customer_repository.dart';
import '../../../services/database_helper.dart';
import '../../../services/error_reporter.dart';
import '../../../services/gps_service.dart';
import '../screens/customer_edit_screen.dart';
import '../logic/customer_search_filter.dart';
import '../logic/customer_import_export.dart';
import '../logic/customer_dialogs.dart';
import '../logic/customer_utils.dart';
import '../models/customer_explorer_item.dart';

class CustomerExplorerConfig extends H1ExplorerConfig<CustomerExplorerItem> {
  String _sortKey = 'name_asc';

  CustomerExplorerConfig();

  @override
  String get explorerTitle => 'C1:得意先マスター';

  @override
  String get searchHint => '顧客名で検索';

  @override
  bool get showSearch => true;

  @override
  bool get showStatusFilter => false;

  @override
  bool get supportsEdit => false;

  @override
  IconData get itemIcon => Icons.person;

  @override
  String get emptyMessage => '顧客が登録されていません';

  @override
  List<SortOption> get sortOptions => [
        const SortOption(key: 'name_asc', label: '名前順'),
        const SortOption(key: 'name_desc', label: '名前順（降順）'),
        const SortOption(key: 'nearby', label: '📍現在地付近'),
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
    if (_sortKey == 'nearby') {
      final gps = await GpsService.instance.getCurrentLocation();
      if (gps != null) {
        final db = await DatabaseHelper().database;
        final gpsRows = await db.rawQuery('''
          SELECT customer_id, latitude, longitude FROM customer_gps_history
          WHERE id IN (SELECT MAX(id) FROM customer_gps_history GROUP BY customer_id)
        ''');
        final gpsMap = <String, List<double>>{};
        for (final r in gpsRows) {
          final lat = (r['latitude'] as num?)?.toDouble();
          final lng = (r['longitude'] as num?)?.toDouble();
          if (lat != null && lng != null) gpsMap[r['customer_id'] as String? ?? ''] = [lat, lng];
        }
        list.sort((a, b) {
          final posA = gpsMap[a.id];
          final posB = gpsMap[b.id];
          if (posA == null && posB == null) return 0;
          if (posA == null) return 1;
          if (posB == null) return -1;
          final dA = GpsService.distanceKm(gps.latitude, gps.longitude, posA[0], posA[1]);
          final dB = GpsService.distanceKm(gps.latitude, gps.longitude, posB[0], posB[1]);
          return dA.compareTo(dB);
        });
      }
    } else {
      await sortCustomers(
        list: list,
        sortKey: _sortKey,
        showHidden: false,
        ignoreCorpPrefix: true,
      );
    }
    return list.map((c) => CustomerExplorerItem(c)).toList();
  }

  @override
  Widget buildViewer(BuildContext context, CustomerExplorerItem item) {
    return CustomerEditScreen(customer: item.customer, showAppBar: false);
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
      final result = await Navigator.push<dynamic>(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerEditScreen(),
        ),
      );
      if (result != null && context.mounted) {
        onListChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登録しました')),
        );
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
