import 'package:flutter/material.dart';

class InvoiceCalculatorKeypad extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onUpdate;

  const InvoiceCalculatorKeypad({
    super.key,
    required this.controller,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      childAspectRatio: 1.0,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: [
        for (final num in ['7', '8', '9', 'C'])
          ElevatedButton(
            onPressed: () {
              if (num == 'C') {
                controller.text = '';
              } else {
                controller.text += num;
              }
              onUpdate();
            },
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: num == 'C'
                  ? Theme.of(context).colorScheme.errorContainer
                  : Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: num == 'C'
                  ? Theme.of(context).colorScheme.onErrorContainer
                  : Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            child: Text(
              num,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        for (final num in ['4', '5', '6', '00'])
          ElevatedButton(
            onPressed: () {
              controller.text += num;
              onUpdate();
            },
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            child: Text(
              num,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        for (final num in ['1', '2', '3', '0'])
          ElevatedButton(
            onPressed: () {
              controller.text += num;
              onUpdate();
            },
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            child: Text(
              num,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}
