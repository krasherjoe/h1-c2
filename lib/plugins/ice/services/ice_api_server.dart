import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:h_1_core/plugin_system/plugin_registry.dart';
import 'package:h_1_core/services/debug_console.dart';
import 'ice_state_collector.dart';

class IceApiServer {
  HttpServer? _server;
  int port;
  bool _running = false;
  late IceStateCollector _collector;

  IceApiServer({
    this.port = 8080,
    required Database database,
    required SharedPreferences prefs,
    required PluginRegistry registry,
  }) {
    _collector = IceStateCollector(database, prefs, registry);
  }

  bool get isRunning => _running;

  Future<void> start() async {
    if (_running) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      _running = true;
      debugPrint('[IceApiServer] Started on http://localhost:$port');
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

        default:
          await _respond(request.response, {
            'service': 'h-1-core ICE API',
            'version': '1.0.0',
            'endpoints': [
              'GET  /health',
              'GET  /state',
              'GET  /errors',
              'POST /command',
              'POST /db/query',
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
