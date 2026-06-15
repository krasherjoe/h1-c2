import 'package:flutter/material.dart';
import 'plugin_registry.dart';
import '../widgets/google_auth_badge.dart';

class PluginAppBarTitle extends StatelessWidget {
  final String fallbackTitle;

  const PluginAppBarTitle({super.key, this.fallbackTitle = ''});

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context)?.settings.name ?? '/';
    final items = PluginRegistry.instance.getAllMenuItems();
    final idx = items.indexWhere((m) => m.route == route);
    if (idx >= 0) {
      final item = items[idx];
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${item.id}: ${item.title}'),
          const SizedBox(width: 6),
          const GoogleAuthBadge(),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(fallbackTitle),
        const SizedBox(width: 6),
        const GoogleAuthBadge(),
      ],
    );
  }
}