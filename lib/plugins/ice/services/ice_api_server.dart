import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:h_1_core/plugin_system/plugin_registry.dart';
import 'package:h_1_core/services/company_service.dart';
import 'package:h_1_core/services/debug_console.dart';
import 'package:h_1_core/utils/app_theme.dart';
import 'ice_state_collector.dart';

class IceApiServer {
  HttpServer? _server;
  int port;
  bool _running = false;
  late IceStateCollector _collector;
  late final Database _db;
  late final SharedPreferences _prefs;
  late final PluginRegistry _registry;
  String _version = 'unknown';

  IceApiServer({
    this.port = 8080, // ICE API Server
    required Database database,
    required SharedPreferences prefs,
    required PluginRegistry registry,
  }) {
    _db = database;
    _prefs = prefs;
    _registry = registry;
    _collector = IceStateCollector(database, prefs, registry);
  }

  bool get isRunning => _running;
  String get version => _version;

  Future<void> start() async {
    if (_running) return;
    try {
      final envVersion = const String.fromEnvironment('APP_VERSION', defaultValue: '');
      if (envVersion.isNotEmpty) {
        _version = envVersion;
      } else {
        final info = await PackageInfo.fromPlatform();
        _version = '${info.version}(${info.buildNumber})';
      }
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      _running = true;
      debugPrint('[IceApiServer] Started on http://localhost:$port (v$_version)');
      _handleRequests();
    } catch (e) {
      debugPrint('[IceApiServer] Failed to start: $e');
      rethrow;
    }
  }

  Future<void> restart({int? port}) async {
    await stop();
    if (port != null) this.port = port;
    await start();
  }

  Future<void> stop() async {
    _running = false;
    await _server?.close(force: true);
    _server = null;
    debugPrint('[IceApiServer] Stopped');
  }

  void _handleRequests() {
    _server?.listen(
      (request) async {
        try {
          await _handleRequest(request);
        } catch (e) {
          debugPrint('[IceApiServer] Request handler error: $e');
          try {
            request.response.statusCode = HttpStatus.internalServerError;
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode({'error': e.toString()}));
            await request.response.close();
          } catch (_) {}
        }
      },
      onError: (e) {
        debugPrint('[IceApiServer] Server error: $e');
      },
    );
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final uri = Uri.parse(request.uri.toString());
    final path = uri.path;
    final method = request.method;

    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.set('Access-Control-Allow-Headers', 'Content-Type');

    if (method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    try {
      switch (path) {
        case '/health' || '/ping':
          await _respond(request.response, {'status': 'ok', 'uptime': 'running'});

        case '/state':
          final state = await _collector.collect();
          await _respond(request.response, state);

        case '/errors':
          final state = await _collector.collect();
          await _respond(request.response, state['errors']);

        case '/command':
          if (method != 'POST') {
            await _error(request.response, HttpStatus.methodNotAllowed, 'POST required');
            return;
          }
          await _handleCommand(request);

        case '/db/query':
          if (method != 'POST') {
            await _error(request.response, HttpStatus.methodNotAllowed, 'POST required');
            return;
          }
          await _handleDbQuery(request);

        case '/fs/read':
          if (method != 'GET') {
            await _error(request.response, HttpStatus.methodNotAllowed, 'GET required');
            return;
          }
          final readPath = uri.queryParameters['path'];
          if (readPath == null || readPath.isEmpty) {
            await _error(request.response, HttpStatus.badRequest, 'path query parameter is required');
            return;
          }
          await _handleFsRead(request.response, readPath);

        case '/fs/write':
          if (method != 'POST') {
            await _error(request.response, HttpStatus.methodNotAllowed, 'POST required');
            return;
          }
          await _handleFsWrite(request);

        case '/fs/list':
          if (method != 'GET') {
            await _error(request.response, HttpStatus.methodNotAllowed, 'GET required');
            return;
          }
          final listPath = uri.queryParameters['path'] ?? '.';
          await _handleFsList(request.response, listPath);

        case '/fs/download':
          if (method != 'GET') {
            await _error(request.response, HttpStatus.methodNotAllowed, 'GET required');
            return;
          }
          final dlPath = uri.queryParameters['path'];
          if (dlPath == null || dlPath.isEmpty) {
            await _error(request.response, HttpStatus.badRequest, 'path query parameter is required');
            return;
          }
          await _handleFsDownload(request.response, dlPath);

        case '/api/workspace':
          await _handleApiWorkspace(request.response);

        case '/api/commands':
          await _handleApiCommands(request.response);

        case '/api/theme':
          await _handleApiTheme(request.response);

        case '/api/projects':
          if (method != 'GET') {
            await _error(request.response, HttpStatus.methodNotAllowed, 'GET required');
            return;
          }
          await _handleApiProjects(request.response);

        case '/api/db/tables':
          if (method != 'GET') {
            await _error(request.response, HttpStatus.methodNotAllowed, 'GET required');
            return;
          }
          await _handleApiDbTables(request.response);

        case '/api/preferences':
          if (method != 'GET') {
            await _error(request.response, HttpStatus.methodNotAllowed, 'GET required');
            return;
          }
          final key = uri.queryParameters['key'];
          await _handleApiPreferences(request.response, key);

        default:
          await _respond(request.response, {
            'service': 'h-1-core ICE API',
            'version': _version,
            'endpoints': [
              'GET  /health',
              'GET  /state',
              'GET  /errors',
              'POST /command',
              'POST /db/query',
              'GET  /fs/read?path=...',
              'POST /fs/write',
              'GET  /fs/list?path=...',
              'GET  /fs/download?path=...',
              'GET  /api/workspace',
              'GET  /api/commands',
              'GET  /api/db/tables',
              'GET  /api/preferences?key=...',
              'GET  /api/theme',
              'GET  /api/projects',
            ],
          });
      }
    } catch (e) {
      await _error(request.response, HttpStatus.internalServerError, e.toString());
    }
  }

  Future<void> _handleCommand(HttpRequest request) async {
    final body = await utf8.decodeStream(request);
    final data = jsonDecode(body) as Map<String, dynamic>;
    final name = data['command'] as String?;
    final argsRaw = data['args'] as List<dynamic>?;

    if (name == null || name.isEmpty) {
      await _error(request.response, HttpStatus.badRequest, 'command is required');
      return;
    }

    final args = (argsRaw ?? []).map((a) => a.toString()).toList();
    final result = await DebugConsole.call(name, args);

    await _respond(request.response, {
      'command': name,
      'args': args,
      'result': result,
    });
  }

  Future<void> _handleDbQuery(HttpRequest request) async {
    final body = await utf8.decodeStream(request);
    final data = jsonDecode(body) as Map<String, dynamic>;
    final sql = data['sql'] as String?;

    if (sql == null || sql.trim().isEmpty) {
      await _error(request.response, HttpStatus.badRequest, 'sql is required');
      return;
    }

    final trimmed = sql.trim().toUpperCase();
    if (trimmed.startsWith('SELECT') || trimmed.startsWith('PRAGMA')) {
      final state = await _collector.collect();
      final dbPath = (state['database'] as Map<String, dynamic>)['path'] as String?;
      if (dbPath == null) {
        await _error(request.response, HttpStatus.internalServerError, 'DB not available');
        return;
      }
      final db = await openDatabase(dbPath);
      try {
        final rows = await db.rawQuery(sql);
        await _respond(request.response, {'sql': sql, 'rows': rows, 'count': rows.length});
      } finally {
        await db.close();
      }
    } else {
      await _error(request.response, HttpStatus.badRequest, 'Only SELECT/PRAGMA queries allowed');
    }
  }

  Future<void> _handleFsRead(HttpResponse response, String path) async {
    final file = File(path);
    if (!await file.exists()) {
      await _error(response, HttpStatus.notFound, 'File not found: $path');
      return;
    }
    try {
      final bytes = await file.readAsBytes();
      final stat = await file.stat();
      final size = stat.size;

      if (size > 10 * 1024 * 1024) {
        await _error(response, HttpStatus.badRequest, 'File too large: $size bytes (max 10MB)');
        return;
      }

      final isText = ['txt', 'json', 'csv', 'xml', 'html', 'htm', 'md', 'yaml', 'yml', 'sql', 'log', 'key', 'pub'].contains(p.extension(path).replaceFirst('.', ''));

      if (isText) {
        final content = await file.readAsString();
        await _respond(response, {
          'path': path,
          'size': size,
          'text': true,
          'content': content,
        });
      } else {
        final base64Content = base64Encode(bytes);
        response.headers.set('Content-Type', 'application/octet-stream');
        response.headers.set('Content-Disposition', 'attachment; filename="${p.basename(path)}"');
        response.write(jsonEncode({
          'path': path,
          'size': size,
          'text': false,
          'content': base64Content,
        }));
        await response.close();
      }
    } catch (e) {
      await _error(response, HttpStatus.internalServerError, 'Failed to read file: $e');
    }
  }

  Future<void> _handleFsWrite(HttpRequest request) async {
    final body = await utf8.decodeStream(request);
    final data = jsonDecode(body) as Map<String, dynamic>;
    final path = data['path'] as String?;
    final content = data['content'] as String?;
    final isBase64 = (data['isBase64'] as bool?) ?? false;

    if (path == null || path.isEmpty) {
      await _error(request.response, HttpStatus.badRequest, 'path is required');
      return;
    }
    if (content == null) {
      await _error(request.response, HttpStatus.badRequest, 'content is required');
      return;
    }

    try {
      final file = File(path);
      if (isBase64) {
        final bytes = base64Decode(content);
        await file.writeAsBytes(bytes);
      } else {
        await file.writeAsString(content);
      }
      final stat = await file.stat();
      await _respond(request.response, {
        'path': path,
        'size': stat.size,
        'written': true,
      });
    } catch (e) {
      await _error(request.response, HttpStatus.internalServerError, 'Failed to write file: $e');
    }
  }

  Future<void> _handleFsList(HttpResponse response, String path) async {
    final entity = await FileSystemEntity.type(path);
    if (entity == FileSystemEntityType.notFound) {
      await _error(response, HttpStatus.notFound, 'Path not found: $path');
      return;
    }

    try {
      final List<dynamic> entries = [];
      final fsPath = path;

      if (await Directory(fsPath).exists()) {
        final dir = Directory(fsPath);
        await for (final entity2 in dir.list(recursive: false)) {
          final stat = await entity2.stat();
          entries.add({
            'path': entity2.path,
            'name': p.basename(entity2.path),
            'type': stat.type == FileSystemEntityType.directory ? 'directory' : 'file',
            'size': stat.size,
            'isDirectory': stat.type == FileSystemEntityType.directory,
          });
        }
      } else {
        final stat = await File(fsPath).stat();
        entries.add({
          'path': fsPath,
          'name': p.basename(fsPath),
          'type': 'file',
          'size': stat.size,
          'isDirectory': false,
        });
      }

      await _respond(response, {
        'path': path,
        'entries': entries,
        'count': entries.length,
      });
    } catch (e) {
      await _error(response, HttpStatus.internalServerError, 'Failed to list: $e');
    }
  }

  Future<void> _handleFsDownload(HttpResponse response, String path) async {
    final file = File(path);
    if (!await file.exists()) {
      await _error(response, HttpStatus.notFound, 'File not found: $path');
      return;
    }

    try {
      final bytes = await file.readAsBytes();
      response.headers.set('Content-Type', 'application/octet-stream');
      response.headers.set('Content-Disposition', 'attachment; filename="${p.basename(path)}"');
      response.add(bytes);
      await response.close();
    } catch (e) {
      await _error(response, HttpStatus.internalServerError, 'Failed to download: $e');
    }
  }

  Future<void> _handleApiWorkspace(HttpResponse response) async {
    try {
      final dir = await CompanyService.getCompanyDirectory();
      final sshDir = Directory('${dir.path}/.ssh');
      final dbFile = File(_db.path);
      final dbExists = await dbFile.exists();
      final dbSize = dbExists ? await dbFile.length() : 0;

      final workspaceInfo = {
        'company_dir': dir.path,
        'db_path': _db.path,
        'db_exists': dbExists,
        'db_size_bytes': dbSize,
        'ssh_dir': sshDir.path,
        'ssh_config_exists': await File('${sshDir.path}/config').exists(),
        'ssh_private_key_exists': await File('${sshDir.path}/id_ed25519').exists(),
        'ssh_public_key_exists': await File('${sshDir.path}/id_ed25519.pub').exists(),
        'plugins': _registry.allPlugins.map((p) => {'id': p.id, 'name': p.name, 'enabled': _registry.isEnabled(p.id)}).toList(),
      };

      await _respond(response, workspaceInfo);
    } catch (e) {
      await _error(response, HttpStatus.internalServerError, 'Failed to get workspace: $e');
    }
  }

  Future<void> _handleApiCommands(HttpResponse response) async {
    final commands = DebugConsole.registered;
    await _respond(response, {'commands': commands, 'count': commands.length});
  }

  Future<void> _handleApiDbTables(HttpResponse response) async {
    try {
      final tables = await _db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );
      final tableInfo = <Map<String, dynamic>>[];

      for (final t in tables) {
        final name = t['name'] as String;
        try {
          final cnt = await _db.rawQuery('SELECT COUNT(*) as c FROM "$name"');
          final count = cnt.first['c'] as int;
          tableInfo.add({'table': name, 'count': count});
        } catch (e) {
          tableInfo.add({'table': name, 'count': -1, 'error': e.toString()});
        }
      }

      await _respond(response, {'tables': tableInfo, 'count': tableInfo.length});
    } catch (e) {
      await _error(response, HttpStatus.internalServerError, 'Failed to get tables: $e');
    }
  }

  Future<void> _handleApiPreferences(HttpResponse response, String? key) async {
    try {
      if (key == null || key.isEmpty) {
        final allPrefs = _prefs.getKeys();
        final result = <String, dynamic>{};
        for (final k in allPrefs) {
          result[k] = _prefs.get(k);
        }
        await _respond(response, {'preferences': result});
      } else {
        final value = _prefs.get(key);
        await _respond(response, {'key': key, 'value': value});
      }
    } catch (e) {
      await _error(response, HttpStatus.internalServerError, 'Failed to get preferences: $e');
    }
  }

  Future<void> _handleApiTheme(HttpResponse response) async {
    final light = AppTheme.cardLight;
    final dark = AppTheme.cardDark;
    await _respond(response, {
      'mode': 'light',
      'cardLight': '#${light.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}',
      'cardDark': '#${dark.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}',
      'description': 'CardTheme color from AppTheme. Cards without explicit color inherit this. Lost projects use AppTheme.cardLostLight/cardLostDark.',
    });
  }

  Future<void> _handleApiProjects(HttpResponse response) async {
    try {
      final rows = await _db.rawQuery(
        "SELECT id, name, status, customer_name, type, pipeline_stage, progress, total_amount, start_date, end_date, contract_months, created_at, updated_at FROM projects ORDER BY sort_order IS NULL, sort_order, created_at DESC",
      );
      final lightHex = '#${AppTheme.cardLight.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
      final projects = rows.map((r) {
        final status = r['status'] as String? ?? 'active';
        final isLost = status == 'lost';
        return {
          ...r,
          'cardColor': isLost ? 'cardLostLight/cardLostDark' : lightHex,
          'isLost': isLost,
        };
      }).toList();
      await _respond(response, {
        'count': projects.length,
        'cardColorLight': lightHex,
        'projects': projects,
      });
    } catch (e) {
      await _error(response, HttpStatus.internalServerError, 'Failed to get projects: $e');
    }
  }

  Future<void> _respond(HttpResponse response, dynamic data) async {
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(data));
    await response.close();
  }

  Future<void> _error(HttpResponse response, int statusCode, String message) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode({'error': message}));
    await response.close();
  }
}
