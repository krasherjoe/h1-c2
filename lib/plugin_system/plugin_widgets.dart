import 'package:flutter/material.dart';
import 'plugin_registry.dart';
import '../utils/theme_utils.dart';

class PluginAppBarTitle extends StatelessWidget {
  final String fallbackTitle;

  const PluginAppBarTitle({super.key, this.fallbackTitle = ''});

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context)?.settings.name ?? '/';
    final screen = PluginRegistry.instance.getScreenByRoute(route);
    final cs = Theme.of(context).colorScheme;
    // AppBar 背景がカスタム色の場合でも確実に読める色を適用
    final defaultForeground = textColorOn(cs.surface);
    final titleStyle = TextStyle(color: defaultForeground);
    if (screen != null) {
      return Text('${screen.id}: ${screen.title}', style: titleStyle);
    }
    return Text(fallbackTitle, style: titleStyle);
  }
}
