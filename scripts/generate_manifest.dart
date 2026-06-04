import 'dart:convert';
import 'dart:io';

void main() {
  final json = File('plugins-manifest.json').readAsStringSync();
  final manifest = jsonDecode(json) as Map<String, dynamic>;

  final buffer = StringBuffer();
  buffer.writeln('// AUTO GENERATED from plugins-manifest.json');
  buffer.writeln('// DO NOT EDIT MANUALLY');
  buffer.writeln('// 生成コマンド: dart run scripts/generate_manifest.dart');
  buffer.writeln();
  buffer.writeln("import 'package:flutter/material.dart';");
  buffer.writeln("import 'menu_item.dart';");
  buffer.writeln();
  buffer.writeln('/// plugins-manifest.json から自動生成された全MenuItem');
  buffer.writeln('class GeneratedManifest {');
  buffer.writeln('  GeneratedManifest._();');
  buffer.writeln();

  // getAll()
  buffer.writeln('  static List<MenuItem> getAll() => _items;');
  buffer.writeln();

  // byRoute()
  buffer.writeln('  static MenuItem? byRoute(String route) {');
  buffer.writeln('    for (final item in _items) {');
  buffer.writeln('      if (item.route == route) return item;');
  buffer.writeln('    }');
  buffer.writeln('    return null;');
  buffer.writeln('  }');
  buffer.writeln();

  // byId()
  buffer.writeln('  static MenuItem? byId(String id) {');
  buffer.writeln('    for (final item in _items) {');
  buffer.writeln('      if (item.id == id) return item;');
  buffer.writeln('    }');
  buffer.writeln('    return null;');
  buffer.writeln('  }');
  buffer.writeln();

  // byCategory()
  buffer.writeln('  static List<MenuItem> byCategory(String category) {');
  buffer.writeln('    return _items.where((item) => item.category == category).toList();');
  buffer.writeln('  }');
  buffer.writeln();

  // getCategories()
  buffer.writeln('  static List<String> getCategories() {');
  buffer.writeln('    final set = <String>{};');
  buffer.writeln('    for (final item in _items) {');
  buffer.writeln('      set.add(item.category);');
  buffer.writeln('    }');
  buffer.writeln('    return set.toList();');
  buffer.writeln('  }');
  buffer.writeln();

  // _items
  buffer.writeln('  static final List<MenuItem> _items = <MenuItem>[');
  final plugins = manifest['plugins'] as List<dynamic>;
  for (final plugin in plugins) {
    final screens = plugin['screens'] as List<dynamic>?;
    if (screens == null || screens.isEmpty) continue;
    buffer.writeln('    // --- ${plugin['name']} (${plugin['id']}) ---');
    for (final screen in screens) {
      final id = screen['id'];
      final title = screen['title'];
      final route = screen['route'];
      final category = screen['category'];
      final icon = screen['icon'];
      final description = screen['description'];
      buffer.writeln('    MenuItem(');
      buffer.writeln("      id: '$id',");
      buffer.writeln("      title: '$title',");
      buffer.writeln("      route: '$route',");
      buffer.writeln("      category: '$category',");
      buffer.writeln('      icon: ${icon},');
      if (description != null) {
        buffer.writeln("      description: '$description',");
      }
      buffer.writeln('    ),');
    }
  }
  buffer.writeln('  ];');
  buffer.writeln('}');

  final outputPath = 'lib/plugin_system/generated_manifest.dart';
  File(outputPath).writeAsStringSync(buffer.toString());
  final count = (plugins.expand((p) => (p['screens'] as List<dynamic>? ?? [])).length);
  print('Generated $outputPath ($count MenuItems)');
}
