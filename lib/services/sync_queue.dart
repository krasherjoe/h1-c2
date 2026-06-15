import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'google_auth_service.dart';

class SyncQueue {
  static final SyncQueue instance = SyncQueue._();
  SyncQueue._();

  final List<String> _queue = [];
  Timer? _flushTimer;
  bool _polling = false;
  String? _parentEmail;

  bool get isParent => _parentEmail == null || _parentEmail!.isEmpty;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _parentEmail = prefs.getString('sync_parent_email');
  }

  Future<void> setParentEmail(String? email) async {
    _parentEmail = email;
    final prefs = await SharedPreferences.getInstance();
    if (email != null) await prefs.setString('sync_parent_email', email);
    else await prefs.remove('sync_parent_email');
  }

  void push(String changeJson) {
    _queue.add(changeJson);
    if (_queue.length >= 50) _flush();
    else { _flushTimer?.cancel(); _flushTimer = Timer(const Duration(minutes: 2), _flush); }
  }

  void _flush() {
    if (_queue.isEmpty) return;
    final batch = _queue.take(50).toList();
    _queue.removeRange(0, batch.length);
    _doSend(batch);
    if (_queue.isNotEmpty) { _flushTimer?.cancel(); _flushTimer = Timer(const Duration(minutes: 2), _flush); }
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
      await api.users.messages.send(gmail.Message(raw: _b64(utf8encode(raw))), 'me');
      client.close();
    } catch (_) {}
  }

  void startPolling() {
    if (_polling) return;
    _polling = true;
    _pollLoop();
  }

  void stopPolling() { _polling = false; _flushTimer?.cancel(); }

  Future<void> _pollLoop() async {
    while (_polling) {
      await Future.delayed(const Duration(minutes: 2));
      if (!_polling) break;
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastCheck = prefs.getInt('sync_last_check') ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000 - 300);
        final client = await GoogleAuthService.instance.getAuthenticatedClient();
        if (client == null) continue;
        final api = gmail.GmailApi(client);
        final list = await api.users.messages.list('me', q: 'subject:[Sync:h1] after:$lastCheck');
        if (list.messages != null) {
          for (final msg in list.messages!) {
            final full = await api.users.messages.get('me', msg.id!, format: 'full');
            final src = full.payload?.headers?.where((h) => h.name == 'X-H1-Source').firstOrNull?.value;
            if (src == null) continue;
            final body = full.payload?.parts?.firstOrNull?.body?.data ?? '';
            if (body.isNotEmpty) _processIncoming(src, _utf8decode(_b64decode(body)));
          }
        }
        await prefs.setInt('sync_last_check', DateTime.now().millisecondsSinceEpoch ~/ 1000);
        client.close();
      } catch (_) {}
    }
  }

  void _processIncoming(String source, String body) {}
}

String _b64(List<int> bytes) => String.fromCharCodes(bytes).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
List<int> _b64decode(String s) {
  final normalized = s.replaceAll('-', '+').replaceAll('_', '/');
  return normalized.codeUnits;
}
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

List<int> utf8encode(String s) {
  final r = <int>[];
  for (int i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c < 0x80) r.add(c);
    else if (c < 0x800) { r.add(0xC0 | (c >> 6)); r.add(0x80 | (c & 0x3F)); }
    else { r.add(0xE0 | (c >> 12)); r.add(0x80 | ((c >> 6) & 0x3F)); r.add(0x80 | (c & 0x3F)); }
  }
  return r;
}
