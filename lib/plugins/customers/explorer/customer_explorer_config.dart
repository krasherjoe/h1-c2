import 'package:flutter/material.dart';
import '../../../explorer/h1_explorer_config.dart';
import '../../../services/customer_repository.dart';
import '../../../screens/customer_master/customer_master_screen.dart';
import '../../../screens/customer_edit_screen.dart';
import '../models/customer_explorer_item.dart';

class CustomerExplorerConfig extends H1ExplorerConfig<CustomerExplorerItem> {
  @override
  String get explorerTitle => '顧客マスター';

  @override
  String get searchHint => '顧客名・電話番号で検索';

  @override
  IconData get itemIcon => Icons.person;

  @override
  String get emptyMessage => '顧客が登録されていません';

  @override
  Future<List<CustomerExplorerItem>> fetchItems(String query) async {
    final repo = CustomerRepository();
    if (query.isNotEmpty) {
      final customers = await repo.searchCustomers(query);
      return customers.map((c) => CustomerExplorerItem(c)).toList();
    }
    final customers = await repo.getAllCustomers();
    return customers.map((c) => CustomerExplorerItem(c)).toList();
  }

  @override
  Widget buildViewer(BuildContext context, CustomerExplorerItem item) {
    return const CustomerMasterScreen(selectionMode: false);
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
}
