import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:h_1_core/services/company_service.dart';
import 'package:h_1_core/services/debug_console.dart';
import 'package:h_1_core/plugin_system/plugin_registry.dart';

class IceStateCollector {
  final Database _db;
  final PluginRegistry _registry;

  IceStateCollector(this._db, SharedPreferences _prefs, this._registry);

  Future<Map<String, dynamic>> collect() async {
    return {
      'system': await _collectSystem(),
      'database': await _collectDbStats(),
      'plugins': _collectPlugins(),
      'company': await _collectCompany(),
      'errors': await _collectErrors(),
      'console': _collectConsole(),
    };
  }

  Future<Map<String, dynamic>> _collectSystem() async {
    final info = await PackageInfo.fromPlatform();
    final dir = await CompanyService.getCompanyDirectory();
    return {
      'version': info.version,
      'buildNumber': info.buildNumber,
      'packageName': info.packageName,
      'platform': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'host': Platform.localHostname,
      'dbDirectory': dir.path,
      'dartVersion': Platform.version,
    };
  }

  Future<Map<String, dynamic>> _collectDbStats() async {
    try {
      final file = File(_db.path);
      final size = await file.length();
      final tables = await _db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );
      final tableStats = <String, int>{};
      for (final t in tables) {
        final name = t['name'] as String;
        try {
          final cnt = await _db.rawQuery('SELECT COUNT(*) as c FROM "$name"');
          tableStats[name] = cnt.first['c'] as int;
        } catch (_) {
          tableStats[name] = -1;
        }
      }
      return {
        'path': _db.path,
        'sizeBytes': size,
        'sizeKB': (size / 1024).round(),
        'tables': tableStats,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Map<String, dynamic> _collectPlugins() {
    final plugins = _registry.allPlugins;
    final result = <String, dynamic>{};
    for (final p in plugins) {
      result[p.id] = {
        'name': p.name,
        'version': p.version,
        'enabled': _registry.isEnabled(p.id),
      };
    }
    return result;
  }

  Future<Map<String, dynamic>> _collectCompany() async {
    try {
      final current = CompanyService.activeCompanyNotifier.value;
      final list = await CompanyService.getCompanyList();
      return {
        'active': current,
        'available': list,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> _collectErrors() async {
    try {
      final rows = await _db.rawQuery(
        "SELECT * FROM activity_logs WHERE action LIKE '%error%' OR action LIKE '%exception%' ORDER BY timestamp DESC LIMIT 20",
      );
      return rows.map((r) => {
        'id': r['id'],
        'action': r['action'],
        'target_type': r['target_type'],
        'details': r['details'],
        'screen_id': r['screen_id'],
        'timestamp': r['timestamp'],
      }).toList();
    } catch (e) {
      try {
        final rows = await _db.rawQuery(
          'SELECT * FROM activity_logs ORDER BY timestamp DESC LIMIT 10',
        );
        return rows.map((r) => {
          'id': r['id'],
          'action': r['action'],
          'target_type': r['target_type'],
          'details': r['details'],
          'screen_id': r['screen_id'],
          'timestamp': r['timestamp'],
        }).toList();
      } catch (_) {
        return [];
      }
    }
  }

  Map<String, dynamic> _collectConsole() {
    final cmds = DebugConsole.registered;
    return {
      'commands': cmds,
      'commandCount': cmds.length,
    };
  }
}
