import 'dart:async';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'database_helper.dart';
import 'google_auth_service.dart';

class SyncQueue {
  static final SyncQueue instance = SyncQueue._();
  SyncQueue._();

  String? _parentEmail;
  int _lastCheck = 0;
  bool _polling = false;
  bool _isActive = true;
  String? _prevDbPath;
  final List<String> _queue = [];
  Timer? _flushTimer;
  Timer? _pollTimer;
  bool _dbDirty = false;

  bool get isParent => _parentEmail == null || _parentEmail!.isEmpty;

  // --- 法人切替 ---
  Future<void> onCompanySwitch() async {
    final db = await DatabaseHelper().database; // ← これで新しい法人のDBが開かれる
    final newPath = db.path;
    if (_prevDbPath != null && _prevDbPath != newPath) {
      // 旧法人を非アクティブに。flushだけしてpollは止める
      _flush();
    }
    _prevDbPath = null; // force reload
    await init();
  }

  // --- 初期化（DBから読込） ---
  Future<void> init() async {
    try {
      final db = await DatabaseHelper().database;
      _prevDbPath = db.path;
      final maps = await db.query('sync_config');
      final config = {for (final m in maps) m['key'] as String? ?? '': m['value'] as String? ?? ''};
      _parentEmail = config['parent_email'];
      _lastCheck = int.tryParse(config['last_check'] ?? '') ?? 0;
      _isActive = true;

      // 親分は常時poll、子分はアクティブ時だけ2分
      _restartPolling();
    } catch (_) {}
  }

  // --- DB書き込み ---
  Future<void> _dbSet(String key, String value) async {
    try {
      final db = await DatabaseHelper().database;
      await db.insert('sync_config', {'key': key, 'value': value},
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  Future<void> setParentEmail(String? email) async {
    _parentEmail = email;
    if (email != null) await _dbSet('parent_email', email);
    else { try { final db = await DatabaseHelper().database; await db.delete('sync_config', where: 'key = ?', whereArgs: ['parent_email']); } catch (_) {} }
    _restartPolling();
  }

  // --- アクティブ状態 ---
  void setActive(bool active) {
    _isActive = active;
    _restartPolling();
  }

  int get _pollSeconds {
    if (isParent) return 120;           // 親分: 常時2分
    if (_isActive) return 120;          // 子分アクティブ: 2分
    return 43200;                       // 子分非アクティブ: 12時間
  }

  // --- Queue（電車モデル） ---
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
      final client = await GoogleAuthService.instance.getAuthenticatedClient();
      if (client == null) return;
      final api = gmail.GmailApi(client);
      final boundary = 'b${DateTime.now().millisecondsSinceEpoch}';
      final raw = 'Content-Type: multipart/mixed; boundary=$boundary\nMIME-Version: 1.0\n'
          'To: $_parentEmail\nSubject: [Sync:h1]${DateTime.now().millisecondsSinceEpoch}\n'
          'X-H1-Source: ${await GoogleAuthService.instance.getEmail()}\n\n'
          '--$boundary\nContent-Type: text/plain; charset=UTF-8\n\n${batch.join("\n")}\n--$boundary--';
      await api.users.messages.send(gmail.Message(raw: _b64(_utf8encode(raw))), 'me');
      client.close();
    } catch (_) {}
  }

  // --- Polling ---
  void startPolling() { _polling = true; _restartPolling(); }
  void stopPolling() { _polling = false; _pollTimer?.cancel(); _flushTimer?.cancel(); }

  void _restartPolling() {
    _pollTimer?.cancel();
    if (!_polling && !isParent) return; // 子分は startPolling されたときだけ
    if (!_polling) return;
    _pollLoop();
  }

  Future<void> _pollLoop() async {
    while (_polling) {
      final seconds = _pollSeconds;
      _pollTimer = Timer(Duration(seconds: seconds), () {});
      await Future.delayed(Duration(seconds: seconds));
      if (!_polling) break;

      // 子分非アクティブ: flushだけしてpollしない（半日後にまた来る）
      if (!isParent && !_isActive) {
        _flush();
        continue;
      }

      try {
        final me = await GoogleAuthService.instance.getEmail();
        if (me == null || me.isEmpty) continue;
        final client = await GoogleAuthService.instance.getAuthenticatedClient();
        if (client == null) continue;
        final api = gmail.GmailApi(client);

        if (isParent) {
          // 親分: 子分からの変更を受信
          final list = await api.users.messages.list('me', q: 'subject:[Sync:h1] after:$_lastCheck');
          if (list.messages != null) {
            for (final msg in list.messages!) {
              final full = await api.users.messages.get('me', msg.id!, format: 'full');
              final src = full.payload?.headers?.where((h) => h.name == 'X-H1-Source').firstOrNull?.value;
              if (src == null) continue;
              final body = full.payload?.parts?.firstOrNull?.body?.data ?? '';
              if (body.isNotEmpty) _processIncoming(src, _utf8decode(_b64decode(body)));
            }
          }
        }
        _lastCheck = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await _dbSet('last_check', _lastCheck.toString());
        client.close();
      } catch (_) {}
    }
  }

  void _processIncoming(String source, String body) {
    // 受信データをDBに反映（実装は後日）
  }
}

String _b64(List<int> bytes) =>
    String.fromCharCodes(bytes).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
List<int> _b64decode(String s) => s.replaceAll('-', '+').replaceAll('_', '/').codeUnits.toList();
String _utf8decode(List<int> bytes) {
  final sb = StringBuffer();
  int i = 0;
  while (i < bytes.length) {
    final c = bytes[i];
    if (c < 0x80) { sb.writeCharCode(c); i++; }
    else if (c < 0xE0) { sb.writeCharCode(((c & 0x1F) << 6) | (bytes[i+1] & 0x3F)); i += 2; }
    else { sb.writeCharCode(((c & 0x0F) << 12) | ((bytes[i+1] & 0x3F) << 6) | (bytes[i+2] & 0x3F)); i += 3; }
  }
  return sb.toString();
}
List<int> _utf8encode(String s) {
  final r = <int>[];
  for (int i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c < 0x80) r.add(c);
    else if (c < 0x800) { r.add(0xC0 | (c >> 6)); r.add(0x80 | (c & 0x3F)); }
    else { r.add(0xE0 | (c >> 12)); r.add(0x80 | ((c >> 6) & 0x3F)); r.add(0x80 | (c & 0x3F)); }
  }
  return r;
}
