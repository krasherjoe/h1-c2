import 'package:flutter/material.dart';
import '../../../plugins/explorer/h1_explorer_item.dart';
import '../../../models/customer_model.dart';

class CustomerExplorerItem extends H1ExplorerItem {
  final Customer customer;

  CustomerExplorerItem(this.customer);

  @override
  String get id => customer.id;

  @override
  String get title => customer.displayName;

  @override
  String? get subtitle => customer.tel;

  @override
  String? get badge => customer.rank != CustomerRank.none ? customer.rank.label : null;

  @override
  IconData? get icon => Icons.person;

  @override
  DateTime? get updatedAt => customer.updatedAt;
}
