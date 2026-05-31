import 'package:flutter/material.dart';

class SwipeToUnlock extends StatelessWidget {
  final VoidCallback onUnlocked;
  const SwipeToUnlock({super.key, required this.onUnlocked});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ElevatedButton.icon(
          onPressed: onUnlocked,
          icon: const Icon(Icons.lock_open),
          label: const Text('スワイプしてロック解除'),
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            minimumSize: const Size(double.infinity, 56),
          ),
        ),
      ),
    );
  }
}
