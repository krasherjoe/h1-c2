import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:h_1_core/plugin_system/plugin_interface.dart';
import 'package:h_1_core/plugin_system/plugin_context.dart';
import 'package:h_1_core/plugin_system/plugin_registry.dart';
import 'package:h_1_core/plugin_system/screen_definition.dart';
import 'package:h_1_core/constants/screen_ids.dart';
import 'package:h_1_core/services/company_service.dart';
import 'package:h_1_core/services/debug_console.dart';
import 'package:h_1_core/services/ssh_tunnel_service.dart';
import 'screens/ice_settings_screen.dart';
import 'services/ice_api_server.dart';

class IcePlugin extends H1Plugin {
  IceApiServer? _apiServer;

  @override
  String get id => 'com.h1.core.ice';

  @override
  String get name => 'ICEデバッグ';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'SSH/ICE デバッグAPIサーバー（opencode連携）';

  @override
  List<ScreenDefinition> get screens => [
    ScreenDefinition(
      id: S.ice,
      title: 'ICEデバッグ',
      route: '/ice',
      builder: (_) => IceSettingsScreen(apiServer: _apiServer!),
      category: 'システム',
      icon: Icons.developer_mode,
      description: 'ICE APIサーバー設定',
    ),
  ];

  @override
  Future<void> initialize(PluginContext context) async {
    final port = context.preferences.getInt('ice_port') ?? 8080;
    _apiServer = IceApiServer(
      port: port,
      database: context.database,
      prefs: context.preferences,
      registry: PluginRegistry.instance,
    );
    await _apiServer!.start();
    DebugConsole.register('ice.status', (_) async {
      if (_apiServer == null) return 'ICE: 未初期化';
      return 'ICE: ${_apiServer!.isRunning ? "稼働中" : "停止中"} (port: ${_apiServer!.port})';
    });
    DebugConsole.register('ice.start', (args) async {
      final p = args.isNotEmpty ? int.tryParse(args[0]) ?? 8080 : 8080;
      await _apiServer?.restart(port: p);
      return 'ICE起動: localhost:$p';
    });
    DebugConsole.register('ice.stop', (_) async {
      await _apiServer?.stop();
      return 'ICE停止';
    });
    await _autoConnectSsh();
    debugPrint('[IcePlugin] Initialized (port: $port)');
  }

  Future<void> _autoConnectSsh() async {
    try {
      final dir = await CompanyService.getCompanyDirectory();
      final configFile = File('${dir.path}/.ssh/config');
      final keyFile = File('${dir.path}/.ssh/id_ed25519');
      if (!await configFile.exists() || !await keyFile.exists()) return;
      final config = await configFile.readAsString();
      final key = await keyFile.readAsString();
      if (config.trim().isEmpty || key.trim().isEmpty) return;
      final ssh = SshTunnelService.instance;
      ssh.configText = config;
      ssh.keyText = key;
      await ssh.connect();
      debugPrint('[IcePlugin] SSH auto-connect succeeded');
    } catch (e) {
      debugPrint('[IcePlugin] SSH auto-connect failed: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await _apiServer?.stop();
    debugPrint('[IcePlugin] Disposed');
  }

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/ice': (_) => IceSettingsScreen(apiServer: _apiServer!),
  };

  @override
  Future<void> createTables(Database db) async {}
}
