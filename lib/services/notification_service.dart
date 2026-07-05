import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'database_helper.dart';

enum NotificationType {
  chat,       // チャットメッセージ
  sync,       // 同期完了
  error,      // エラー
  info,       // 情報
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String? body;
  final bool isRead;
  final DateTime createdAt;
  final String? actionRoute;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.isRead = false,
    required this.createdAt,
    this.actionRoute,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'title': title,
    'body': body,
    'is_read': isRead ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'action_route': actionRoute,
  };

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
    id: map['id'] as String,
    type: NotificationType.values.firstWhere(
      (e) => e.name == map['type'],
      orElse: () => NotificationType.info,
    ),
    title: map['title'] as String,
    body: map['body'] as String?,
    isRead: (map['is_read'] as int?) == 1,
    createdAt: DateTime.parse(map['created_at'] as String),
    actionRoute: map['action_route'] as String?,
  );
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// 通知テーブルを作成
  Future<void> ensureTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT,
        is_read INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        action_route TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(is_read)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications(created_at)',
    );
  }

  /// 通知を追加
  Future<void> add({
    required NotificationType type,
    required String title,
    String? body,
    String? actionRoute,
  }) async {
    final db = await DatabaseHelper().database;
    await ensureTable(db);

    final notification = AppNotification(
      id: const Uuid().v4(),
      type: type,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      actionRoute: actionRoute,
    );

    await db.insert('notifications', notification.toMap());
    _log('通知追加: ${type.name} - $title');
  }

  /// 未読通知数を取得
  Future<int> getUnreadCount() async {
    final db = await DatabaseHelper().database;
    await ensureTable(db);
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM notifications WHERE is_read = 0');
    return result.first['count'] as int? ?? 0;
  }

  /// 通知一覧を取得
  Future<List<AppNotification>> getAll({int limit = 50}) async {
    final db = await DatabaseHelper().database;
    await ensureTable(db);
    final rows = await db.query(
      'notifications',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map((r) => AppNotification.fromMap(r)).toList();
  }

  /// 未読通知を取得
  Future<List<AppNotification>> getUnread({int limit = 20}) async {
    final db = await DatabaseHelper().database;
    await ensureTable(db);
    final rows = await db.query(
      'notifications',
      where: 'is_read = 0',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map((r) => AppNotification.fromMap(r)).toList();
  }

  /// 既読にする
  Future<void> markAsRead(String id) async {
    final db = await DatabaseHelper().database;
    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 全て既読にする
  Future<void> markAllAsRead() async {
    final db = await DatabaseHelper().database;
    await db.update('notifications', {'is_read': 1});
  }

  /// 古い通知を削除（30日以上前）
  Future<void> cleanup() async {
    final db = await DatabaseHelper().database;
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    await db.delete(
      'notifications',
      where: 'created_at < ?',
      whereArgs: [cutoff.toIso8601String()],
    );
  }

  /// チャット通知を追加（ヘルパー）
  Future<void> addChatNotification({
    required String senderName,
    required String content,
    String? actionRoute,
  }) async {
    await add(
      type: NotificationType.chat,
      title: '$senderName からのメッセージ',
      body: content.length > 100 ? '${content.substring(0, 100)}...' : content,
      actionRoute: actionRoute,
    );
  }

  /// 同期通知を追加（ヘルパー）
  Future<void> addSyncNotification({
    required int syncedCount,
    required int failedCount,
  }) async {
    final title = failedCount > 0
        ? '同期完了（失敗: $failedCount件）'
        : '同期完了（$syncedCount件）';
    await add(
      type: NotificationType.sync,
      title: title,
    );
  }

  /// エラー通知を追加（ヘルパー）
  Future<void> addErrorNotification({
    required String title,
    String? body,
  }) async {
    await add(
      type: NotificationType.error,
      title: title,
      body: body,
    );
  }

  void _log(String msg) {
    debugPrint('[Notification] $msg');
  }
}
