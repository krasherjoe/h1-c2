import 'package:flutter/material.dart';
import '../../../models/customer_model.dart';
import '../models/customer_list_types.dart';
import '../logic/customer_utils.dart';
import 'customer_card.dart';
import 'customer_kana_chips.dart';

class CustomerListView extends StatelessWidget {
  final List<Customer> filtered;
  final String? selectedKanaGroup;
  final String? selectedKanaChar;
  final bool isLoading;
  final ValueChanged<String?> onKanaGroupChanged;
  final ValueChanged<String?> onKanaCharChanged;
  final ValueChanged<Customer> onCustomerTap;
  final ValueChanged<Customer> onCustomerLongPress;

  const CustomerListView({
    super.key,
    required this.filtered,
    this.selectedKanaGroup,
    this.selectedKanaChar,
    this.isLoading = false,
    required this.onKanaGroupChanged,
    required this.onKanaCharChanged,
    required this.onCustomerTap,
    required this.onCustomerLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final group = selectedKanaGroup ?? kanaGroupOrder.first;
    final items = filtered.where((c) => customerInSubGroup(c, group, selectedKanaChar)).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('顧客が見つかりません'));
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: KanaGroupChips(
            filtered: filtered,
            selectedGroup: selectedKanaGroup,
            selectedChar: selectedKanaChar,
            onGroupChanged: onKanaGroupChanged,
            onCharChanged: onKanaCharChanged,
          ),
        ),
        if (selectedKanaChar != null && selectedKanaChar != '英数')
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                '「$selectedKanaChar」で始まる顧客 (${items.length}件)',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        if (selectedKanaChar == '英数')
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                '英数字で始まる顧客 (${items.length}件)',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final c = items[index];
              return CustomerCard(
                customer: c,
                onTap: () => onCustomerTap(c),
                onLongPress: () => onCustomerLongPress(c),
              );
            },
            childCount: items.length,
          ),
        ),
      ],
    );
  }
}
