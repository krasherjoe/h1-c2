import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:h_1_core/plugin_system/plugin_registry.dart';
import 'package:h_1_core/plugin_system/plugin_interface.dart';
import 'package:h_1_core/plugin_system/plugin_context.dart';
import 'package:h_1_core/plugin_system/screen_definition.dart';
import 'package:h_1_core/plugin_system/menu_item.dart';

class _TestPlugin extends H1Plugin {
  @override
  String get id => 'com.test.test';

  @override
  String get name => 'TestPlugin';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Test plugin';

  @override
  List<ScreenDefinition> get screens => [
    ScreenDefinition(
      id: 'T1',
      title: 'Test',
      route: '/test',
      builder: (ctx) => const SizedBox.shrink(),
      category: 'test',
      icon: Icons.ac_unit,
    ),
  ];

  @override
  Map<String, WidgetBuilder> getRoutes() => {};

  @override
  Future<void> initialize(PluginContext context) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> createTables(Database db) async {}
}

class _TestPlugin2 extends H1Plugin {
  @override
  String get id => 'com.test.test2';

  @override
  String get name => 'TestPlugin2';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Test plugin 2';

  @override
  List<String> get dependencies => ['com.test.test'];

  @override
  List<ScreenDefinition> get screens => [
    ScreenDefinition(
      id: 'T2',
      title: 'Test2',
      route: '/test2',
      builder: (ctx) => const SizedBox.shrink(),
      category: 'test',
      icon: Icons.ac_unit,
    ),
  ];

  @override
  Map<String, WidgetBuilder> getRoutes() => {};

  @override
  Future<void> initialize(PluginContext context) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> createTables(Database db) async {}
}

class _TestPluginSameRoute extends H1Plugin {
  @override
  String get id => 'com.test.sameroute';

  @override
  String get name => 'TestPluginSameRoute';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Test plugin with duplicate route';

  @override
  List<ScreenDefinition> get screens => [
    ScreenDefinition(
      id: 'T3',
      title: 'Test Same Route',
      route: '/test',
      builder: (ctx) => const SizedBox.shrink(),
      category: 'test',
      icon: Icons.ac_unit,
    ),
  ];

  @override
  Map<String, WidgetBuilder> getRoutes() => {};

  @override
  Future<void> initialize(PluginContext context) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> createTables(Database db) async {}
}

void main() {
  late PluginRegistry registry;

  setUp(() {
    registry = PluginRegistry();
  });

  group('PluginRegistry', () {
    test('register plugin', () async {
      final plugin = _TestPlugin();
      await registry.register(plugin);
      expect(registry.allPlugins.length, 1);
    });

    test('duplicate ID throws', () async {
      await registry.register(_TestPlugin());
      expect(
        () async => await registry.register(_TestPlugin()),
        throwsA(isA<Exception>()),
      );
    });

    test('duplicate route throws', () async {
      await registry.register(_TestPlugin());
      expect(
        () async => await registry.register(_TestPluginSameRoute()),
        throwsA(isA<Exception>()),
      );
    });

    test('getScreenById returns correct screen', () async {
      await registry.register(_TestPlugin());
      final screen = registry.getScreenById('T1');
      expect(screen, isNotNull);
      expect(screen!.id, 'T1');
    });

    test('getScreenById returns null for unknown', () async {
      await registry.register(_TestPlugin());
      final screen = registry.getScreenById('UNKNOWN');
      expect(screen, isNull);
    });

    test('getScreenByRoute returns correct screen', () async {
      await registry.register(_TestPlugin());
      final screen = registry.getScreenByRoute('/test');
      expect(screen, isNotNull);
      expect(screen!.id, 'T1');
    });

    test('getScreenByRoute returns null for unknown route', () async {
      await registry.register(_TestPlugin());
      final screen = registry.getScreenByRoute('/unknown');
      expect(screen, isNull);
    });

    test('getAllMenuItems returns menus from all plugins', () async {
      await registry.register(_TestPlugin());
      await registry.register(_TestPlugin2());
      final menus = registry.getAllMenuItems();
      expect(menus, isNotEmpty);
    });

    test('multiple plugins registered', () async {
      await registry.register(_TestPlugin());
      await registry.register(_TestPlugin2());
      expect(registry.allPlugins.length, 2);
    });

    test('dependency check passes when dependency registered', () async {
      await registry.register(_TestPlugin());
      await registry.register(_TestPlugin2());
      expect(registry.allPlugins.length, 2);
    });

    test('isEnabled returns true by default', () async {
      await registry.register(_TestPlugin());
      expect(registry.isEnabled('com.test.test'), isTrue);
    });

    test('setEnabled disables and enables plugin', () async {
      await registry.register(_TestPlugin());
      registry.setEnabled('com.test.test', false);
      expect(registry.isEnabled('com.test.test'), isFalse);
      registry.setEnabled('com.test.test', true);
      expect(registry.isEnabled('com.test.test'), isTrue);
    });
  });
}
