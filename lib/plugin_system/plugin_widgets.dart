import 'package:flutter/material.dart';
import 'menu_item.dart';
import 'plugin_registry.dart';

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
      return Text('${item.id}: ${item.title}');
    }
    return Text(fallbackTitle);
  }
}