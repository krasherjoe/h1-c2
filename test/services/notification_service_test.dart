import 'package:flutter_test/flutter_test.dart';
import 'package:h_1_core/services/notification_service.dart';

void main() {
  group('AppNotification Model', () {
    test('toMap/fromMap roundtrip', () {
      final notification = AppNotification(
        id: 'test-id',
        type: NotificationType.chat,
        title: 'Test Title',
        body: 'Test Body',
        isRead: false,
        createdAt: DateTime(2026, 7, 5),
        actionRoute: '/chat',
      );

      final map = notification.toMap();
      final restored = AppNotification.fromMap(map);

      expect(restored.id, notification.id);
      expect(restored.type, NotificationType.chat);
      expect(restored.title, notification.title);
      expect(restored.body, notification.body);
      expect(restored.isRead, false);
      expect(restored.actionRoute, '/chat');
    });

    test('defaults are correct', () {
      final notification = AppNotification(
        id: 'id',
        type: NotificationType.info,
        title: 'Title',
        createdAt: DateTime.now(),
      );

      expect(notification.isRead, false);
      expect(notification.body, isNull);
      expect(notification.actionRoute, isNull);
    });

    test('fromMap handles missing fields', () {
      final map = <String, dynamic>{
        'id': 'id',
        'type': 'sync',
        'title': 'Sync',
        'is_read': 1,
        'created_at': DateTime.now().toIso8601String(),
      };

      final notification = AppNotification.fromMap(map);

      expect(notification.type, NotificationType.sync);
      expect(notification.isRead, true);
      expect(notification.body, isNull);
    });
  });

  group('NotificationType', () {
    test('has all expected types', () {
      expect(NotificationType.values.length, 4);
      expect(NotificationType.values, contains(NotificationType.chat));
      expect(NotificationType.values, contains(NotificationType.sync));
      expect(NotificationType.values, contains(NotificationType.error));
      expect(NotificationType.values, contains(NotificationType.info));
    });
  });
}
