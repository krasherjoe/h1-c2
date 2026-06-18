import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'plugin_interface.dart';
import 'plugin_context.dart';
import 'menu_item.dart';
import 'screen_definition.dart';
import '../services/database_helper.dart';

class PluginRegistry {
  static final PluginRegistry instance = PluginRegistry._();

  @visibleForTesting
  PluginRegistry();

  PluginRegistry._();

  final Map<String, H1Plugin> _plugins = {};
  final Map<String, ScreenDefinition> _screensByRoute = {};
  final Map<String, ScreenDefinition> _screensById = {};
  final Set<String> _disabledPlugins = {};
  PluginContext? _context;
  bool _initialized = false;

  bool get hasPlugins => _plugins.isNotEmpty;
  bool get isInitialized => _initialized;

  void setContext(PluginContext context) {
    _context = context;
    _initialized = true;
  }

  PluginContext? getContext() => _context;

  Future<void> register(H1Plugin plugin) async {
    if (_plugins.containsKey(plugin.id)) {
      throw Exception('Plugin already registered: ${plugin.id}');
    }

    for (final screen in plugin.screens) {
      if (_screensById.containsKey(screen.id)) {
        throw Exception('Screen ID "${screen.id}" already registered');
      }
      if (_screensByRoute.containsKey(screen.route)) {
        throw Exception('Route "${screen.route}" already registered');
      }
    }

    for (final dep in plugin.dependencies) {
      if (!_plugins.containsKey(dep) && dep != 'com.h1.core') {
        throw Exception(
          'Dependency not found: ${plugin.id} requires $dep',
        );
      }
    }

    if (_context != null) {
      try {
        await plugin.createTables(_context!.database);
      } catch (e) {
        debugPrint('[PluginRegistry] Table creation error for ${plugin.id}: $e');
      }
      try {
        await plugin.migrate(_context!.database, 1, DatabaseHelper.databaseVersion);
      } catch (e) {
        debugPrint('[PluginRegistry] Migration error for ${plugin.id}: $e');
      }
      await plugin.initialize(_context!);
    }

    for (final screen in plugin.screens) {
      _screensByRoute[screen.route] = screen;
      _screensById[screen.id] = screen;
    }

    _plugins[plugin.id] = plugin;
    debugPrint('[PluginRegistry] Registered: ${plugin.name} v${plugin.version}');
  }

  Future<void> unregister(String pluginId) async {
    final plugin = _plugins[pluginId];
    if (plugin == null) return;

    final dependents = _findDependentPlugins(pluginId);
    if (dependents.isNotEmpty) {
      throw Exception(
        'Cannot unregister: ${dependents.join(', ')} depends on $pluginId',
      );
    }

    await plugin.dispose();
    _plugins.remove(pluginId);
    debugPrint('[PluginRegistry] Unregistered: ${plugin.name}');
  }

  void setEnabled(String pluginId, bool enabled) {
    if (enabled) {
      _disabledPlugins.remove(pluginId);
    } else {
      _disabledPlugins.add(pluginId);
    }
  }

  bool isEnabled(String pluginId) => !_disabledPlugins.contains(pluginId);

  List<H1Plugin> get allPlugins => _plugins.values.toList();

  List<H1Plugin> get activePlugins =>
    _plugins.values.where((p) => isEnabled(p.id)).toList();

  List<MenuItem> getAllMenuItems() {
    final items = <MenuItem>[];
    for (final plugin in activePlugins) {
      for (final screen in plugin.screens) {
        items.add(MenuItem(
          id: screen.id,
          title: screen.title,
          route: screen.route,
          category: screen.category,
          icon: screen.icon,
          description: screen.description,
        ));
      }
    }
    return items;
  }

  Map<String, List<MenuItem>> getMenuItemsByCategory() {
    final items = getAllMenuItems();
    final result = <String, List<MenuItem>>{};
    for (final item in items) {
      result.putIfAbsent(item.category, () => []).add(item);
    }
    return result;
  }

  Map<String, WidgetBuilder> getAllRoutes() {
    final routes = <String, WidgetBuilder>{};
    for (final plugin in activePlugins) {
      routes.addAll(plugin.getRoutes());
    }
    return routes;
  }

  H1Plugin? getPlugin(String pluginId) => _plugins[pluginId];

  ScreenDefinition? getScreenByRoute(String route) => _screensByRoute[route];
  ScreenDefinition? getScreenById(String id) => _screensById[id];
  List<ScreenDefinition> getAllScreenDefinitions() => _screensByRoute.values.toList();

  List<String> _findDependentPlugins(String pluginId) {
    return _plugins.values
        .where((p) => p.dependencies.contains(pluginId))
        .map((p) => p.name)
        .toList();
  }
}
