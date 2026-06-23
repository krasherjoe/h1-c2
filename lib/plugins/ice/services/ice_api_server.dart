import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:h_1_core/plugin_system/plugin_registry.dart';
import 'package:h_1_core/services/company_service.dart';
import 'package:h_1_core/services/debug_console.dart';
import 'package:h_1_core/services/error_log_service.dart';
import 'package:h_1_core/services/project_repository.dart';
import 'package:h_1_core/models/project_model.dart';
import 'package:h_1_core/plugins/project/models/gantt_preset.dart';
import 'package:h_1_core/utils/app_theme.dart';
import 'package:h_1_core/services/backup_operation_service.dart';
import 'package:h_1_core/services/screenshot_service.dart';
import 'package:h_1_core/services/test_runner_service.dart';
import 'package:h_1_core/services/mattermost_polling_service.dart';
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
        // バージョン文字列から不要なプレフィックスを削除
        var version = info.version;
        version = version.replaceAll(RegExp(r'^v+'), '');
        _version = '$version(${info.buildNumber})';
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
          if (method == 'POST') {
            final action = uri.queryParameters['action'];
            if (action == 'create') {
              await _handleApiProjectCreate(request);
            } else {
              await _handleApiProjectUpdate(request);
            }
          } else if (method == 'GET') {
            await _handleApiProjects(request.response);
          } else {
            await _error(request.response, HttpStatus.methodNotAllowed, 'GET or POST required');
            return;
          }

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

        case '/api/errors':
          if (method == 'DELETE') {
            await _handleApiErrorsClear(request.response);
          } else if (method == 'GET') {
            await _handleApiErrors(request.response);
          } else {
            await _error(request.response, HttpStatus.methodNotAllowed, 'GET or DELETE required');
            return;
          }

        case '/api/backup-status':
          if (method != 'GET') {
            await _error(request.response, HttpStatus.methodNotAllowed, 'GET required');
            return;
          }
          await _handleApiBackupStatus(request.response);

        case '/api/backup-history':
          if (method != 'GET') {
            await _error(request.response, HttpStatus.methodNotAllowed, 'GET required');
            return;
          }
          await _handleApiBackupHistory(request.response, request);

        case '/api/plugins/debug':
          if (method != 'GET') {
            await _error(request.response, HttpStatus.methodNotAllowed, 'GET required');
            return;
          }
          await _handleApiPluginsDebug(request.response);

        case '/api/screenshot':
          if (method != 'GET') {
            await _error(request.response, HttpStatus.methodNotAllowed, 'GET required');
            return;
          }
          await _handleApiScreenshot(request.response);

        case '/api/test/list':
          if (method != 'GET') {
            await _error(request.response, HttpStatus.methodNotAllowed, 'GET required');
            return;
          }
          await _handleApiTestList(request.response);

        case '/api/test/run':
          if (method != 'POST') {
            await _error(request.response, HttpStatus.methodNotAllowed, 'POST required');
            return;
          }
          await _handleApiTestRun(request.response, request);

        case '/api/test/result':
          if (method != 'GET') {
            await _error(request.response, HttpStatus.methodNotAllowed, 'GET required');
            return;
          }
          await _handleApiTestResult(request.response);

        default:
          if (path.startsWith('/api/plugins/') && path.endsWith('/debug')) {
            if (method != 'GET') {
              await _error(request.response, HttpStatus.methodNotAllowed, 'GET required');
              return;
            }
            final pluginId = path.substring('/api/plugins/'.length, path.length - '/debug'.length);
            await _handleApiPluginDebug(request.response, pluginId);
          } else {
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
                'GET  /api/errors',
                'DELETE /api/errors',
                'GET  /api/backup-status',
                'GET  /api/backup-history',
                'GET  /api/plugins/debug',
                'GET  /api/plugins/<id>/debug',
                'GET  /api/screenshot',
                'GET  /api/test/list',
                'POST /api/test/run',
                'GET  /api/test/result',
              ],
            });
          }
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
    final useMattermostFallback = (data['use_mattermost_fallback'] as bool?) ?? false;

    if (name == null || name.isEmpty) {
      await _error(request.response, HttpStatus.badRequest, 'command is required');
      return;
    }

    final args = (argsRaw ?? []).map((a) => a.toString()).toList();
    
    String result;
    if (useMattermostFallback) {
      // Mattermostフォールバック
      try {
        final mmService = MattermostPollingService();
        await mmService.initialize();
        if (!mmService.isConfigured) {
          await _error(request.response, HttpStatus.serviceUnavailable, 'Mattermost not configured');
          return;
        }
        
        final commandMessage = '$name ${args.join(' ')}';
        result = await mmService.sendAgentMessage(commandMessage);
      } catch (e) {
        await _error(request.response, HttpStatus.serviceUnavailable, 'Mattermost fallback failed: $e');
        return;
      }
    } else {
      // 通常のDebugConsole実行
      result = await DebugConsole.call(name, args);
    }

    await _respond(request.response, {
      'command': name,
      'args': args,
      'result': result,
      'method': useMattermostFallback ? 'mattermost' : 'direct',
    });
  }

  Future<void> _handleDbQuery(HttpRequest request) async {
    final body = await utf8.decodeStream(request);
    final data = jsonDecode(body) as Map<String, dynamic>;
    final sql = data['sql'] as String?;
    // 任意パスの DB を読み取り専用で調査するオプション（read-only限定）
    final externalPath = data['path'] as String?;

    if (sql == null || sql.trim().isEmpty) {
      await _error(request.response, HttpStatus.badRequest, 'sql is required');
      return;
    }

    final trimmed = sql.trim().toUpperCase();
    final isRead = trimmed.startsWith('SELECT') || trimmed.startsWith('PRAGMA');
    final isWrite = trimmed.startsWith('INSERT') || trimmed.startsWith('UPDATE') || trimmed.startsWith('DELETE');

    if (!isRead && !isWrite) {
      await _error(request.response, HttpStatus.badRequest, 'Only SELECT/PRAGMA/INSERT/UPDATE/DELETE queries allowed');
      return;
    }

    // 外部パス指定時は読み取り専用のみ許可
    if (externalPath != null && !isRead) {
      await _error(request.response, HttpStatus.forbidden, 'Write queries are not allowed on external DB paths');
      return;
    }

    String resolvedPath;
    if (externalPath != null) {
      resolvedPath = externalPath;
    } else {
      final state = await _collector.collect();
      final dbPath = (state['database'] as Map<String, dynamic>)['path'] as String?;
      if (dbPath == null) {
        await _error(request.response, HttpStatus.internalServerError, 'DB not available');
        return;
      }
      resolvedPath = dbPath;
    }

    final db = await openDatabase(resolvedPath, readOnly: externalPath != null);
    try {
      if (isRead) {
        final rows = await db.rawQuery(sql);
        await _respond(request.response, {'sql': sql, 'path': resolvedPath, 'rows': rows, 'count': rows.length});
      } else if (trimmed.startsWith('DELETE')) {
        final rowsAffected = await db.rawDelete(sql);
        await _respond(request.response, {'sql': sql, 'rowsAffected': rowsAffected});
      } else {
        final rowsAffected = await db.rawUpdate(sql);
        await _respond(request.response, {'sql': sql, 'rowsAffected': rowsAffected});
      }
    } finally {
      await db.close();
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

  Future<void> _handleApiProjectUpdate(HttpRequest request) async {
    try {
      final body = await utf8.decodeStream(request);
      final data = jsonDecode(body) as Map<String, dynamic>;
      final projectId = data['project_id'] as String?;
      final ganttConfig = data['gantt_config'] as String?;

      if (projectId == null || projectId.isEmpty) {
        await _error(request.response, HttpStatus.badRequest, 'project_id is required');
        return;
      }

      final repo = ProjectRepository();
      final project = await repo.getById(projectId);
      if (project == null) {
        await _error(request.response, HttpStatus.notFound, 'Project not found: $projectId');
        return;
      }

      final updated = project.copyWith(ganttConfig: ganttConfig);
      await repo.save(updated);

      await _respond(request.response, {
        'updated': true,
        'project_id': projectId,
        'gantt_config': ganttConfig,
      });
    } catch (e) {
      await ErrorLogService.instance.logError(
        'ICE-API project update error: $e',
        screen: 'IceApiServer',
        context: 'POST /api/projects',
      );
      await _error(request.response, HttpStatus.internalServerError, 'Failed to update project: $e');
    }
  }

  Future<void> _handleApiProjectCreate(HttpRequest request) async {
    try {
      final body = await utf8.decodeStream(request);
      final data = jsonDecode(body) as Map<String, dynamic>;
      final name = data['name'] as String?;
      final ganttPresetId = data['gantt_preset'] as String?;
      final startDateStr = data['start_date'] as String?;
      final contractMonths = data['contract_months'] as int?;

      if (name == null || name.isEmpty) {
        await _error(request.response, HttpStatus.badRequest, 'name is required');
        return;
      }

      final preset = ganttPresetId != null
          ? GanttPreset.getById(ganttPresetId)
          : null;

      final repo = ProjectRepository();
      final project = Project(
        id: const Uuid().v4(),
        name: name,
        status: ProjectStatus.active,
        startDate: startDateStr != null ? DateTime.tryParse(startDateStr) : DateTime.now(),
        contractMonths: contractMonths ?? 6,
        totalAmount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        type: ProjectType.development,
        pipelineStage: '要件定義',
        ganttConfig: preset != null ? jsonEncode(preset.toJson()) : null,
      );

      await repo.save(project);

      await _respond(request.response, {
        'created': true,
        'project_id': project.id,
        'name': project.name,
        'gantt_preset': preset?.id,
      });
    } catch (e) {
      await ErrorLogService.instance.logError(
        'ICE-API project create error: $e',
        screen: 'IceApiServer',
        context: 'POST /api/projects?action=create',
      );
      await _error(request.response, HttpStatus.internalServerError, 'Failed to create project: $e');
    }
  }

  Future<void> _handleApiBackupStatus(HttpResponse response) async {
    try {
      final opService = BackupOperationService();
      final summary = await opService.getSummary();
      await _respond(response, summary);
    } catch (e) {
      await _error(response, HttpStatus.internalServerError, 'Failed to get backup status: $e');
    }
  }

  Future<void> _handleApiBackupHistory(HttpResponse response, HttpRequest request) async {
    try {
      final opService = BackupOperationService();
      final limitStr = request.uri.queryParameters['limit'];
      final limit = limitStr != null ? int.tryParse(limitStr) ?? 50 : 50;
      final operations = await opService.getRecentOperations(limit: limit);
      await _respond(response, {
        'operations': operations.map((op) => op.toJson()).toList(),
        'count': operations.length,
      });
    } catch (e) {
      await _error(response, HttpStatus.internalServerError, 'Failed to get backup history: $e');
    }
  }

  Future<void> _handleApiPluginsDebug(HttpResponse response) async {
    try {
      final plugins = _registry.allPlugins;
      final result = <String, dynamic>{};
      for (final p in plugins) {
        try {
          final debugInfo = await p.getDebugInfo();
          result[p.id] = {
            'name': p.name,
            'version': p.version,
            'enabled': _registry.isEnabled(p.id),
            'debug': debugInfo,
          };
        } catch (e) {
          result[p.id] = {
            'name': p.name,
            'version': p.version,
            'enabled': _registry.isEnabled(p.id),
            'debug': {'error': e.toString()},
          };
        }
      }
      await _respond(response, result);
    } catch (e) {
      await _error(response, HttpStatus.internalServerError, 'Failed to get plugins debug: $e');
    }
  }

  Future<void> _handleApiPluginDebug(HttpResponse response, String pluginId) async {
    try {
      final plugin = _registry.getPlugin(pluginId);
      if (plugin == null) {
        await _error(response, HttpStatus.notFound, 'Plugin not found: $pluginId');
        return;
      }
      final debugInfo = await plugin.getDebugInfo();
      await _respond(response, {
        'id': plugin.id,
        'name': plugin.name,
        'version': plugin.version,
        'enabled': _registry.isEnabled(plugin.id),
        'debug': debugInfo,
      });
    } catch (e) {
      await _error(response, HttpStatus.internalServerError, 'Failed to get plugin debug: $e');
    }
  }

  Future<void> _handleApiScreenshot(HttpResponse response) async {
    try {
      final screenshotService = ScreenshotService();
      if (!screenshotService.isEnabled) {
        await _error(response, HttpStatus.notImplemented, 'Screenshot requires ICE-API plugin to be enabled');
        return;
      }
      final base64 = await screenshotService.captureToBase64();
      await _respond(response, {
        'format': 'png',
        'encoding': 'base64',
        'data': base64,
      });
    } catch (e) {
      await _error(response, HttpStatus.internalServerError, 'Failed to capture screenshot: $e');
    }
  }

  Future<void> _handleApiTestList(HttpResponse response) async {
    try {
      final testRunner = TestRunnerService();
      final testFiles = await testRunner.listTestFiles();
      await _respond(response, {
        'test_files': testFiles,
        'count': testFiles.length,
      });
    } catch (e) {
      await _error(response, HttpStatus.internalServerError, 'Failed to list test files: $e');
    }
  }

  Future<void> _handleApiTestRun(HttpResponse response, HttpRequest request) async {
    try {
      final body = await utf8.decodeStream(request);
      final data = jsonDecode(body) as Map<String, dynamic>;
      final testFile = data['test_file'] as String?;

      if (testFile == null || testFile.isEmpty) {
        await _error(response, HttpStatus.badRequest, 'test_file is required');
        return;
      }

      final testRunner = TestRunnerService();
      final result = await testRunner.runTest(testFile);
      await _respond(response, result);
    } catch (e) {
      await _error(response, HttpStatus.internalServerError, 'Failed to run test: $e');
    }
  }

  Future<void> _handleApiTestResult(HttpResponse response) async {
    try {
      final testRunner = TestRunnerService();
      final result = testRunner.getLastResult();
      await _respond(response, result);
    } catch (e) {
      await _error(response, HttpStatus.internalServerError, 'Failed to get test result: $e');
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

  Future<void> _handleApiErrors(HttpResponse response) async {
    try {
      final logs = await ErrorLogService.instance.getLogs();
      await _respond(response, {
        'count': logs.length,
        'errors': logs.map((e) => e.toJson()).toList(),
      });
    } catch (e) {
      await _error(response, HttpStatus.internalServerError, 'Failed to get errors: $e');
    }
  }

  Future<void> _handleApiErrorsClear(HttpResponse response) async {
    try {
      await ErrorLogService.instance.clearLogs();
      await _respond(response, {'cleared': true});
    } catch (e) {
      await _error(response, HttpStatus.internalServerError, 'Failed to clear errors: $e');
    }
  }
}
