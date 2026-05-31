import 'package:flutter/material.dart';

class InvoiceSavingOverlay extends StatelessWidget {
  final ValueNotifier<bool> savingNotifier;

  const InvoiceSavingOverlay({super.key, required this.savingNotifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: savingNotifier,
      builder: (context, saving, child) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: saving
            ? Container(
                key: const ValueKey('saving'),
                color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.3),
                child: Center(
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 32,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 20),
                          const Text(
                            '保存中...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '暗号コード生成中',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(key: ValueKey('idle')),
      ),
    );
  }
}
