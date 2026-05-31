import 'package:flutter/material.dart';

class CustomerSortMenu extends StatelessWidget {
  final String currentSortKey;
  final ValueChanged<String> onChanged;

  const CustomerSortMenu({
    super.key,
    required this.currentSortKey,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: currentSortKey,
        icon: Icon(Icons.sort, color: Theme.of(context).colorScheme.onPrimary),
        dropdownColor: Theme.of(context).colorScheme.surface,
        items: const [
          DropdownMenuItem(value: 'name_asc', child: Text('名前順', style: TextStyle(fontSize: 13))),
          DropdownMenuItem(value: 'name_desc', child: Text('名前順(逆)', style: TextStyle(fontSize: 13))),
          DropdownMenuItem(value: 'nearby', child: Text('現在地から近い順', style: TextStyle(fontSize: 13))),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
