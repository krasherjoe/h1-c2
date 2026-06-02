import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/sync_log_entry.dart';
import 'database_helper.dart';
import 'google_auth_service.dart';

class SyncService {
  static const _kDeviceIdKey = 'sync_device_id';
  static String? _cachedDeviceId;
  static const _kUserId = 'me';

  static const _labelNames = ['Sync-Processed', 'Sync-Error', 'Sent-PDF-H1'];
  static String? _cachedProcessedLabelId;
  static String? _cachedErrorLabelId;
  static String? _cachedSentPdfLabelId;

  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kDeviceIdKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_kDeviceIdKey, id);
    }
    _cachedDeviceId = id;
    return id;
  }

  static Future<gmail.GmailApi?> _getApi() async {
    final client = await GoogleAuthService.instance.getAuthenticatedClient();
    if (client == null) return null;
    return gmail.GmailApi(client);
  }

  static Future<String?> _getMyEmail() async {
    return GoogleAuthService.instance.getEmail();
  }

  static Future<void> _ensureLabels(gmail.GmailApi api) async {
    final labelsResponse = await api.users.labels.list(_kUserId);
    final existingLabels = labelsResponse.labels ?? [];
    for (final name in _labelNames) {
      final existing = existingLabels.where((l) => l.name == name).firstOrNull;
      if (existing != null) {
        _cacheLabelId(name, existing.id!);
      } else {
        try {
          final created = await api.users.labels.create(
            gmail.Label(
              name: name,
              labelListVisibility: 'labelShow',
              messageListVisibility: 'show',
            ),
            _kUserId,
          );
          _cacheLabelId(name, created.id!);
        } catch (e) {
          debugPrint('[SyncService] Failed to create label $name: $e');
        }
      }
    }
  }

  static void _cacheLabelId(String name, String id) {
    switch (name) {
      case 'Sync-Processed':
        _cachedProcessedLabelId = id;
      case 'Sync-Error':
        _cachedErrorLabelId = id;
      case 'Sent-PDF-H1':
        _cachedSentPdfLabelId = id;
    }
  }

  static String? _getLabelId(String name) {
    switch (name) {
      case 'Sync-Processed':
        return _cachedProcessedLabelId;
      case 'Sync-Error':
        return _cachedErrorLabelId;
      case 'Sent-PDF-H1':
        return _cachedSentPdfLabelId;
      default:
        return null;
    }
  }

  static Future<bool> pushChange({
    required String entityType,
    required String entityId,
    required String action,
    required Map<String, dynamic> data,
  }) async {
    try {
      final db = await DatabaseHelper().database;
      final deviceId = await getDeviceId();
      final now = DateTime.now();

      final jsonData = jsonEncode(data);
      final entry = SyncLogEntry(
        entityType: entityType,
        entityId: entityId,
        action: action,
        data: jsonData,
        deviceId: deviceId,
        createdAt: now,
      );
      final id = await db.insert('sync_log', entry.toMap());
      if (id == -1) return false;

      final email = await _getMyEmail();
      if (email == null) return false;

      final api = await _getApi();
      if (api == null) return false;

      await _ensureLabels(api);

      final envelope = {
        'entity_type': entityType,
        'entity_id': entityId,
        'data': jsonData,
        'timestamp': now.toIso8601String(),
        'device_id': deviceId,
      };
      final hash = _sha256Hex(jsonEncode(envelope));
      envelope['hash'] = hash;

      final subject = '[Sync:v2] $entityType:$action:$entityId';
      final body = jsonEncode(envelope);

      final raw = base64UrlEncode(utf8.encode(
        'To: $email\r\n'
        'Subject: $subject\r\n'
        'MIME-Version: 1.0\r\n'
        'Content-Type: text/plain; charset=UTF-8\r\n\r\n'
        '$body',
      ));

      final sent = await api.users.messages.send(
        gmail.Message(raw: raw),
        _kUserId,
      );

      if (sent.id != null) {
        await db.update(
          'sync_log',
          {'synced_at': now.toIso8601String()},
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      return true;
    } catch (e, st) {
      debugPrint('[SyncService] pushChange error: $e\n$st');
      return false;
    }
  }

  static Future<int> pullChanges() async {
    int count = 0;
    try {
      final api = await _getApi();
      if (api == null) return 0;

      await _ensureLabels(api);

      final listResponse = await api.users.messages.list(
        _kUserId,
        q: 'subject:[Sync:v2] is:unread',
      );
      final messages = listResponse.messages ?? [];
      if (messages.isEmpty) return 0;

      final db = await DatabaseHelper().database;
      final deviceId = await getDeviceId();

      for (final msgSummary in messages) {
        try {
          final fullMsg = await api.users.messages.get(
            _kUserId,
            msgSummary.id!,
            format: 'full',
          );

          final subject = _extractHeader(fullMsg.payload, 'Subject');
          final bodyB64 = _extractBody(fullMsg.payload);
          if (subject == null || bodyB64 == null) continue;

          final envelopeParts = _parseSyncSubject(subject);
          if (envelopeParts == null) continue;
          final (entityType, action_, entityId) = envelopeParts;

          final decodedBody = utf8.decode(base64Url.decode(bodyB64));
          final envelope = jsonDecode(decodedBody) as Map<String, dynamic>;
          final timestamp = envelope['timestamp'] as String?;
          final sourceDeviceId = envelope['device_id'] as String?;

          if (sourceDeviceId == deviceId) {
            _markProcessed(api, fullMsg.id!);
            continue;
          }

          final existing = await db.query(
            'sync_log',
            where: 'entity_type = ? AND entity_id = ? AND action = ? AND device_id = ?',
            whereArgs: [entityType, entityId, action_, sourceDeviceId],
            limit: 1,
          );
          if (existing.isNotEmpty) {
            _markProcessed(api, fullMsg.id!);
            continue;
          }

          await _applyChange(entityType, entityId, action_, envelope);

          await db.insert('sync_log', SyncLogEntry(
            entityType: entityType,
            entityId: entityId,
            action: action_,
            parentId: fullMsg.id,
            data: jsonEncode(envelope['data']),
            deviceId: sourceDeviceId ?? 'unknown',
            createdAt: timestamp != null ? DateTime.parse(timestamp) : DateTime.now(),
          ).toMap());

          _markProcessed(api, fullMsg.id!);
          count++;
        } catch (e) {
          debugPrint('[SyncService] pullChanges: message error: $e');
          if (msgSummary.id != null) {
            try {
              final errorLabelId = _getLabelId('Sync-Error');
              if (errorLabelId != null) {
                await api.users.messages.modify(
                  gmail.ModifyMessageRequest(
                    addLabelIds: [errorLabelId],
                    removeLabelIds: ['UNREAD'],
                  ),
                  _kUserId,
                  msgSummary.id!,
                );
              }
            } catch (_) {}
          }
        }
      }
    } catch (e, st) {
      debugPrint('[SyncService] pullChanges error: $e\n$st');
    }
    return count;
  }

  static void _markProcessed(gmail.GmailApi api, String messageId) {
    try {
      final processedLabelId = _getLabelId('Sync-Processed');
      if (processedLabelId == null) return;
      api.users.messages.modify(
        gmail.ModifyMessageRequest(
          addLabelIds: [processedLabelId],
          removeLabelIds: ['UNREAD'],
        ),
        _kUserId,
        messageId,
      );
    } catch (e) {
      debugPrint('[SyncService] _markProcessed error: $e');
    }
  }

  static Future<void> _applyChange(
    String entityType,
    String entityId,
    String action,
    Map<String, dynamic> envelope,
  ) async {
    // Record the change in sync_log for future processing
    // Entity-specific handlers can be registered here
    debugPrint('[SyncService] Received change: $entityType/$entityId action=$action');
  }

  static Future<int> cleanOldSyncMessages() async {
    int deleted = 0;
    try {
      final api = await _getApi();
      if (api == null) return 0;

      await _ensureLabels(api);
      final processedLabelId = _getLabelId('Sync-Processed');
      if (processedLabelId == null) return 0;

      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      final beforeStr = '${threeDaysAgo.year}/${threeDaysAgo.month.toString().padLeft(2, '0')}/${threeDaysAgo.day.toString().padLeft(2, '0')}';

      final listResponse = await api.users.messages.list(
        _kUserId,
        q: 'label:Sync-Processed before:$beforeStr',
      );
      final messages = listResponse.messages ?? [];
      for (final msg in messages) {
        try {
          await api.users.messages.delete(_kUserId, msg.id!);
          deleted++;
        } catch (e) {
          debugPrint('[SyncService] delete error: $e');
        }
      }
    } catch (e, st) {
      debugPrint('[SyncService] cleanOldSyncMessages error: $e\n$st');
    }
    return deleted;
  }

  static Future<void> labelSentPdf(String messageId) async {
    try {
      final api = await _getApi();
      if (api == null) return;
      await _ensureLabels(api);
      final labelId = _getLabelId('Sent-PDF-H1');
      if (labelId == null) return;
      await api.users.messages.modify(
        gmail.ModifyMessageRequest(addLabelIds: [labelId]),
        _kUserId,
        messageId,
      );
    } catch (e, st) {
      debugPrint('[SyncService] labelSentPdf error: $e\n$st');
    }
  }

  static Future<int> cleanOldBccPdfMessages() async {
    int deleted = 0;
    try {
      final api = await _getApi();
      if (api == null) return 0;

      await _ensureLabels(api);
      final labelId = _getLabelId('Sent-PDF-H1');
      if (labelId == null) return 0;

      final fourteenDaysAgo = DateTime.now().subtract(const Duration(days: 14));
      final beforeStr = '${fourteenDaysAgo.year}/${fourteenDaysAgo.month.toString().padLeft(2, '0')}/${fourteenDaysAgo.day.toString().padLeft(2, '0')}';

      final listResponse = await api.users.messages.list(
        _kUserId,
        q: 'label:Sent-PDF-H1 before:$beforeStr',
      );
      final messages = listResponse.messages ?? [];
      for (final msg in messages) {
        try {
          await api.users.messages.delete(_kUserId, msg.id!);
          deleted++;
        } catch (e) {
          debugPrint('[SyncService] delete BCC error: $e');
        }
      }
    } catch (e, st) {
      debugPrint('[SyncService] cleanOldBccPdfMessages error: $e\n$st');
    }
    return deleted;
  }

  static Future<void> runGarbageCollection() async {
    final deleted = await cleanOldSyncMessages();
    if (deleted > 0) debugPrint('[SyncService] GC: deleted $deleted old sync messages');

    final deletedBcc = await cleanOldBccPdfMessages();
    if (deletedBcc > 0) debugPrint('[SyncService] GC: deleted $deletedBcc old BCC PDF messages');

    try {
      final db = await DatabaseHelper().database;
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
      // Clean old error_reporter Gmail messages
      final expiredSync = await db.delete(
        'sync_log',
        where: 'synced_at IS NOT NULL AND synced_at < ?',
        whereArgs: [sevenDaysAgo],
      );
      if (expiredSync > 0) debugPrint('[SyncService] GC: deleted $expiredSync old sync_log entries');

      final backups = await db.rawQuery(
        'SELECT id FROM sync_log WHERE entity_type = ? ORDER BY created_at DESC',
        ['backup'],
      );
      if (backups.length > 3) {
        final ids = backups.skip(3).map((r) => r['id'] as int).toList();
        for (final id in ids) {
          await db.delete('sync_log', where: 'id = ?', whereArgs: [id]);
        }
        debugPrint('[SyncService] GC: kept latest 3 backups, removed ${ids.length} old ones');
      }
    } catch (e, st) {
      debugPrint('[SyncService] GC error: $e\n$st');
    }
  }

  static String _sha256Hex(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static String? _extractHeader(gmail.MessagePart? payload, String name) {
    if (payload == null) return null;
    final headers = payload.headers ?? [];
    for (final h in headers) {
      if (h.name?.toLowerCase() == name.toLowerCase()) return h.value;
    }
    return null;
  }

  static String? _extractBody(gmail.MessagePart? payload) {
    if (payload == null) return null;
    if (payload.body?.data != null && payload.body!.data!.isNotEmpty) {
      return payload.body!.data!;
    }
    if (payload.parts != null) {
      for (final part in payload.parts!) {
        if (part.mimeType == 'text/plain' && part.body?.data != null) {
          return part.body!.data!;
        }
        final nested = _extractBody(part);
        if (nested != null) return nested;
      }
    }
    return null;
  }

  static (String, String, String)? _parseSyncSubject(String subject) {
    final pattern = RegExp(r'^\[Sync:v2\]\s+(\w+):(\w+):(.+)$');
    final match = pattern.firstMatch(subject);
    if (match == null) return null;
    return (match.group(1)!, match.group(2)!, match.group(3)!);
  }
}
