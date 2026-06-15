import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:uuid/uuid.dart';
import 'database_helper.dart';
import 'google_auth_service.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;

class SyncQueue {
  static final SyncQueue instance = SyncQueue._();
  SyncQueue._();
  final _uuid = const Uuid();

  String? _parentEmail;
  int _lastCheck = 0;
  bool _polling = false;
  bool _isActive = true;
  String? _prevDbPath;
  final List<String> _queue = [];
  Timer? _flushTimer;
  Timer? _pollTimer;
  final Set<String> _processedMsgIds = {};
  String? _syncLabelId;

  bool get isParent => _parentEmail == null || _parentEmail!.isEmpty;

  // --- 法人切替 ---
  Future<void> onCompanySwitch() async {
    final db = await DatabaseHelper().database;
    final newPath = db.path;
    if (_prevDbPath != null && _prevDbPath != newPath) { _flush(); }
    _prevDbPath = null;
    await init();
  }

  // --- 初期化 ---
  Future<void> init() async {
    try {
      final db = await DatabaseHelper().database;
      _prevDbPath = db.path;
      final maps = await db.query('sync_config');
      final config = {for (final m in maps) m['key'] as String? ?? '': m['value'] as String? ?? ''};
      _parentEmail = config['parent_email'];
      _lastCheck = int.tryParse(config['last_check'] ?? '') ?? 0;
      _isActive = true;
      _restartPolling();
    } catch (_) {}
  }

  Future<void> _dbSet(String key, String value) async {
    try {
      final db = await DatabaseHelper().database;
      await db.insert('sync_config', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  Future<void> setParentEmail(String? email) async {
    _parentEmail = email;
    if (email != null) await _dbSet('parent_email', email);
    else { try { final db = await DatabaseHelper().database; await db.delete('sync_config', where: 'key = ?', whereArgs: ['parent_email']); } catch (_) {} }
    _restartPolling();
  }

  void setActive(bool active) { _isActive = active; _restartPolling(); }

  int get _pollSeconds {
    if (isParent) return 120;
    if (_isActive) return 120;
    return 43200;
  }

  // --- Queue ---
  void push(String changeJson) {
    _queue.add(changeJson);
    if (_queue.length >= 50) _flush();
    else { _flushTimer?.cancel(); _flushTimer = Timer(Duration(seconds: _isActive ? 120 : 30), _flush); }
  }

  void _flush() {
    if (_queue.isEmpty) return;
    final batch = _queue.take(50).toList();
    _queue.removeRange(0, batch.length);
    _doSend(batch);
    if (_queue.isNotEmpty) { _flushTimer?.cancel(); _flushTimer = Timer(const Duration(seconds: 120), _flush); }
  }

  Future<void> _doSend(List<String> batch) async {
    if (_parentEmail == null || _parentEmail!.isEmpty) return;
    try {
      final msgId = _uuid.v4();
      final client = await GoogleAuthService.instance.getAuthenticatedClient();
      if (client == null) return;
      final api = gmail.GmailApi(client);
      final boundary = 'b${DateTime.now().millisecondsSinceEpoch}';
      final hasNotify = !isParent;
      final raw = 'Content-Type: multipart/mixed; boundary=$boundary\nMIME-Version: 1.0\n'
          'To: $_parentEmail\nSubject: [Sync:h1]${DateTime.now().millisecondsSinceEpoch}\n'
          'X-H1-Msg-Id: $msgId\n'
          'X-H1-Source: ${await GoogleAuthService.instance.getEmail()}\n'
          '${hasNotify ? "X-H1-Notify: true\n" : ""}'
          '\n'
          '--$boundary\nContent-Type: text/plain; charset=UTF-8\n\n${batch.join("\n")}\n--$boundary--';
      final encoded = base64UrlEncode(utf8.encode(raw));
      await api.users.messages.send(gmail.Message(raw: encoded), 'me');
      client.close();
    } catch (_) {}
  }

  // --- Polling ---
  void startPolling() { _polling = true; _restartPolling(); }
  void stopPolling() { _polling = false; _pollTimer?.cancel(); _flushTimer?.cancel(); }

  void _restartPolling() {
    _pollTimer?.cancel();
    if (!_polling && !isParent) return;
    if (!_polling) return;
    _pollLoop();
  }

  Future<void> _pollLoop() async {
    while (_polling) {
      final seconds = _pollSeconds;
      _pollTimer = Timer(Duration(seconds: seconds), () {});
      await Future.delayed(Duration(seconds: seconds));
      if (!_polling) break;

      if (!isParent && !_isActive) { _flush(); continue; }

      try {
        final me = await GoogleAuthService.instance.getEmail();
        if (me == null || me.isEmpty) continue;
        final client = await GoogleAuthService.instance.getAuthenticatedClient();
        if (client == null) continue;
        final api = gmail.GmailApi(client);

        if (isParent) {
          final query = 'subject:[Sync:h1] after:$_lastCheck';
          if (_syncLabelId != null) {
            // フィルタラベルが設定済みならそのラベル＋afterで検索
          }
          final list = await api.users.messages.list('me', q: query, maxResults: 20);
          if (list.messages != null) {
            for (final msg in list.messages!) {
              final full = await api.users.messages.get('me', msg.id!, format: 'full');
              final msgId = full.payload?.headers?.where((h) => h.name == 'X-H1-Msg-Id').firstOrNull?.value;
              final src = full.payload?.headers?.where((h) => h.name == 'X-H1-Source').firstOrNull?.value;
              if (src == null || msgId == null) continue;
              if (_processedMsgIds.contains(msgId)) continue;
              _processedMsgIds.add(msgId);
              final body = full.payload?.parts?.firstOrNull?.body?.data ?? '';
              if (body.isNotEmpty) {
                final decoded = utf8.decode(base64Url.decode(body));
                _processIncoming(src, decoded);
              }
              // 処理済みはtrash
              try { await api.users.messages.trash('me', msg.id!); } catch (_) {}
            }
          }
        }

        _lastCheck = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await _dbSet('last_check', _lastCheck.toString());
        client.close();
      } catch (e) {
        debugPrint('[Sync] poll error: $e');
      }
    }
  }

  void _processIncoming(String source, String body) {
    // 通知として処理（register/notify タイプ）
    try {
      final json = jsonDecode(body.trim()) as Map<String, dynamic>;
      final type = json['type'] as String?;

      if (type == 'register') {
        final email = json['email'] as String? ?? source;
        DatabaseHelper().database.then((db) async {
          try {
            await db.insert('sync_children', {
              'email': email,
              'registered_at': DateTime.now().toIso8601String(),
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (_) {}
        });
        _saveNotification(source, '子分登録', 'メール: $email');
        return;
      }

      if (type == 'notify') {
        _saveNotification(source, json['title'] as String? ?? '', json['detail'] as String? ?? '');
        return;
      }
    } catch (_) {}

    // データ同期として処理
    final lines = body.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final parts = trimmed.split('\t');
        if (parts.length < 3) continue;
        final table = parts[0];
        final action = parts[1];
        final jsonData = parts.sublist(2).join('\t');
        final data = jsonDecode(jsonData) as Map<String, dynamic>;
        data['sync_source'] = source;

        DatabaseHelper().database.then((db) async {
          try {
            if (action == 'insert') {
              await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
            } else if (action == 'update') {
              final id = data['id'] as String?;
              if (id != null) await db.update(table, data, where: 'id = ?', whereArgs: [id]);
            } else if (action == 'delete') {
              final id = data['id'] as String?;
              if (id != null) await db.delete(table, where: 'id = ?', whereArgs: [id]);
            }
          } catch (_) {}
        });
      } catch (_) {}
    }
  }

  void _saveNotification(String source, String title, String detail) {
    DatabaseHelper().database.then((db) async {
      try {
        await db.insert('sync_notifications', {
          'source': source, 'title': title, 'detail': detail,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    });
  }

  Future<void> sendNotification(String title, String detail) async {
    push(jsonEncode({'type': 'notify', 'title': title, 'detail': detail}));
  }

  // --- ラベル/フィルタ設定（親分のみ） ---
  Future<void> setupGmailFilter() async {
    if (!isParent) return;
    try {
      final client = await GoogleAuthService.instance.getAuthenticatedClient();
      if (client == null) return;
      final api = gmail.GmailApi(client);

      // Sync-H1 ラベルを作成（なければ）
      final labels = await api.users.labels.list('me');
      final existing = labels.labels?.where((l) => l.name == 'Sync-H1').firstOrNull;
      if (existing?.id != null) {
        _syncLabelId = existing!.id;
      } else {
        final created = await api.users.labels.create(gmail.Label(name: 'Sync-H1', labelListVisibility: 'labelShow', messageListVisibility: 'show'), 'me');
        _syncLabelId = created.id;
      }

      // フィルタを確認・作成（受信箱非表示＋Sync-H1ラベル）
      final filters = await api.users.settings.filters.list('me');
      final hasFilter = filters.filter?.any((f) =>
        f.criteria?.query?.contains('[Sync:h1]') == true) ?? false;
      if (!hasFilter && _syncLabelId != null) {
        await api.users.settings.filters.create(gmail.Filter(
          criteria: gmail.FilterCriteria(query: 'subject:[Sync:h1]'),
          action: gmail.FilterAction(addLabelIds: [_syncLabelId!], removeLabelIds: ['INBOX']),
        ), 'me');
      }

      client.close();
    } catch (_) {}
  }
}
