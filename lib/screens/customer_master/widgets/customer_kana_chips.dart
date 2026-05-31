import 'package:flutter/material.dart';
import '../../../models/customer_model.dart';
import '../models/customer_list_types.dart';
import '../logic/customer_utils.dart';

class KanaGroupChips extends StatelessWidget {
  final List<Customer> filtered;
  final String? selectedGroup;
  final String? selectedChar;
  final ValueChanged<String?> onGroupChanged;
  final ValueChanged<String?> onCharChanged;

  const KanaGroupChips({
    super.key,
    required this.filtered,
    this.selectedGroup,
    this.selectedChar,
    required this.onGroupChanged,
    required this.onCharChanged,
  });

  @override
  Widget build(BuildContext context) {
    final group = selectedGroup ?? kanaGroupOrder.first;
    final subChars = kanaSubGroups[group]!;
    final allItems = filtered.where((c) => kanaCharToGroup(kanaFirstChar(c)) == group).toList();
    final showSub = allItems.length > 50;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final g in kanaGroupOrder)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ChoiceChip(
                    label: Text(g, style: const TextStyle(fontSize: 16)),
                    selected: selectedGroup == g,
                    onSelected: (_) {
                      onGroupChanged(g);
                      onCharChanged(null);
                    },
                    showCheckmark: false,
                  ),
                ),
            ],
          ),
        ),
        if (showSub)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ActionChip(
                      label: Text('全て(${allItems.length})', style: const TextStyle(fontSize: 12)),
                      onPressed: () => onCharChanged(null),
                    ),
                  ),
                  for (final ch in subChars)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ActionChip(
                        label: Text(
                          '$ch(${allItems.where((c) => kanaFirstChar(c) == ch).length})',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () => onCharChanged(ch),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
