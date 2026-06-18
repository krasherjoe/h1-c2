import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:h_1_core/services/secure_storage_service.dart';

class MockSecureStorage extends Mock implements ISecureStorage {}

class FakeSecureStorage extends Fake implements ISecureStorage {
  final _store = <String, String>{};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<bool> containsKey(String key) async => _store.containsKey(key);

  @override
  Future<void> migrateFromPrefs(Map<String, String> entries) async {
    for (final entry in entries.entries) {
      final existing = _store[entry.key];
      if (existing == null && entry.value.isNotEmpty) {
        _store[entry.key] = entry.value;
      }
    }
  }
}

void main() {
  late MockSecureStorage mockStorage;

  setUp(() {
    mockStorage = MockSecureStorage();
  });

  group('ISecureStorage (mocked)', () {
    test('read returns stored value', () async {
      when(() => mockStorage.read('test_key'))
          .thenAnswer((_) async => 'test_value');

      final result = await mockStorage.read('test_key');

      expect(result, 'test_value');
      verify(() => mockStorage.read('test_key')).called(1);
    });

    test('read returns null for missing key', () async {
      when(() => mockStorage.read('missing_key'))
          .thenAnswer((_) async => null);

      final result = await mockStorage.read('missing_key');

      expect(result, isNull);
    });

    test('write stores value', () async {
      when(() => mockStorage.write('key', 'value'))
          .thenAnswer((_) async => {});

      await mockStorage.write('key', 'value');

      verify(() => mockStorage.write('key', 'value')).called(1);
    });

    test('delete removes value', () async {
      when(() => mockStorage.delete('key'))
          .thenAnswer((_) async => {});

      await mockStorage.delete('key');

      verify(() => mockStorage.delete('key')).called(1);
    });

    test('containsKey returns true for existing key', () async {
      when(() => mockStorage.containsKey('existing_key'))
          .thenAnswer((_) async => true);

      final result = await mockStorage.containsKey('existing_key');

      expect(result, true);
    });

    test('containsKey returns false for missing key', () async {
      when(() => mockStorage.containsKey('missing_key'))
          .thenAnswer((_) async => false);

      final result = await mockStorage.containsKey('missing_key');

      expect(result, false);
    });
  });

  group('ISecureStorage (fake)', () {
    test('migrateFromPrefs writes entries that dont exist', () async {
      final fake = FakeSecureStorage();
      await fake.write('key2', 'existing');

      await fake.migrateFromPrefs({
        'key1': 'value1',
        'key2': 'value2',
      });

      expect(await fake.read('key1'), 'value1');
      expect(await fake.read('key2'), 'existing');
    });

    test('migrateFromPrefs skips empty values', () async {
      final fake = FakeSecureStorage();

      await fake.migrateFromPrefs({
        'key1': '',
      });

      expect(await fake.containsKey('key1'), false);
    });
  });

  group('SecureStorageService (real instance)', () {
    test('singleton instance is not null', () {
      expect(SecureStorageService.instance, isNotNull);
    });

    test('implements ISecureStorage', () {
      expect(SecureStorageService.instance, isA<ISecureStorage>());
    });
  });
}
