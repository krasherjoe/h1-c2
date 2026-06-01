import 'package:flutter/material.dart';
import 'plugin_registry.dart';

class PluginAppBarTitle extends StatelessWidget {
  final String fallbackTitle;

  const PluginAppBarTitle({super.key, this.fallbackTitle = ''});

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context)?.settings.name ?? '/';
    final screen = PluginRegistry.instance.getScreenByRoute(route);
    if (screen != null) {
      return Text('${screen.id}: ${screen.title}');
    }
    return Text(fallbackTitle);
  }
}