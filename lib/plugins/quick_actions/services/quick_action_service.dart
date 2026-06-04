import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../plugin_system/plugin_registry.dart';
import '../../../plugin_system/menu_item.dart';
import '../models/quick_action_page.dart';

class QuickActionService {
  static const _kPagesKey = 'quick_action_pages';

  Future<List<QuickActionPage>> loadPages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPagesKey);
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List<dynamic>;
      final pages = list
          .map((e) => QuickActionPage.fromJson(e as Map<String, dynamic>))
          .toList();
      pages.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return pages;
    }
    return _defaultPages();
  }

  Future<void> savePages(List<QuickActionPage> pages) async {
    final prefs = await SharedPreferences.getInstance();
    for (var i = 0; i < pages.length; i++) {
      pages[i].sortOrder = i;
    }
    final raw = jsonEncode(pages.map((p) => p.toJson()).toList());
    await prefs.setString(_kPagesKey, raw);
  }

  List<QuickActionPage> _defaultPages() {
    return [
      QuickActionPage(
        id: 'page1', name: '伝票管理', sortOrder: 0,
        actionIds: ['/documents', '/customers', '/products'],
      ),
      QuickActionPage(
        id: 'page2', name: '在庫・仕入', sortOrder: 1,
        actionIds: ['/inventory', '/inventory/inbound', '/inventory/outbound', '/purchase'],
      ),
    ];
  }

  Map<String, MenuItem> get allActions {
    final registry = PluginRegistry.instance;
    final map = <String, MenuItem>{};
    for (final item in registry.getAllMenuItems()) {
      map[item.route] = item;
    }
    return map;
  }

  static Color accentFor(MenuItem item, ColorScheme cs) {
    final category = item.category;
    if (category.contains('マスタ')) return cs.secondary;
    if (category.contains('販売')) return cs.primary;
    if (category.contains('仕入')) return cs.tertiary;
    if (category.contains('在庫')) return cs.primaryContainer;
    if (category.contains('集計') || category.contains('会計'))
      return cs.onSurfaceVariant;
    if (category.contains('設定') || category.contains('システム'))
      return cs.secondaryContainer;
    return cs.onSurfaceVariant;
  }
}
