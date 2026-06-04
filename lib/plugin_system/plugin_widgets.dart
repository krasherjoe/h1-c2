import 'package:flutter/material.dart';
import 'generated_manifest.dart';

class PluginAppBarTitle extends StatelessWidget {
  final String fallbackTitle;

  const PluginAppBarTitle({super.key, this.fallbackTitle = ''});

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context)?.settings.name ?? '/';
    final item = GeneratedManifest.byRoute(route);
    if (item != null) {
      return Text('${item.id}: ${item.title}');
    }
    return Text(fallbackTitle);
  }
}