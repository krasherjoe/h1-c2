import 'package:flutter_test/flutter_test.dart';
import 'package:h_1_core/models/user_model.dart';

void main() {
  group('User Model', () {
    test('toMap/fromMap roundtrip', () {
      final user = User(
        id: 'test-id',
        email: 'test@example.com',
        displayName: 'Test User',
        role: 'member',
      );

      final map = user.toMap();
      final restored = User.fromMap(map);

      expect(restored.id, user.id);
      expect(restored.email, user.email);
      expect(restored.displayName, user.displayName);
      expect(restored.role, user.role);
    });

    test('copyWith preserves fields', () {
      final user = User(
        id: 'test-id',
        email: 'test@example.com',
        displayName: 'Test User',
      );

      final updated = user.copyWith(displayName: 'Updated Name');

      expect(updated.id, user.id);
      expect(updated.email, user.email);
      expect(updated.displayName, 'Updated Name');
    });

    test('defaults are correct', () {
      final user = User(id: 'id', email: 'test@example.com');

      expect(user.role, 'member');
      expect(user.isActive, true);
      expect(user.displayName, isNull);
      expect(user.photoUrl, isNull);
      expect(user.createdAt, isNull);
      expect(user.lastLoginAt, isNull);
    });

    test('isActive maps to 0/1 in toMap', () {
      final active = User(id: 'id', email: 'a@b.com', isActive: true);
      final inactive = User(id: 'id', email: 'a@b.com', isActive: false);

      expect(active.toMap()['is_active'], 1);
      expect(inactive.toMap()['is_active'], 0);
    });

    test('fromMap handles null/missing fields', () {
      final map = <String, dynamic>{
        'id': 'id',
        'email': 'test@example.com',
      };

      final user = User.fromMap(map);

      expect(user.displayName, isNull);
      expect(user.role, 'member');
      expect(user.photoUrl, isNull);
      expect(user.isActive, false);
      expect(user.createdAt, isNull);
      expect(user.lastLoginAt, isNull);
    });
  });
}
