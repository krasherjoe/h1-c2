import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService instance = SecureStorageService._();
  SecureStorageService._();

  final _storage = const FlutterSecureStorage();

  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('[SecureStorage] read error ($key): $e');
      return null;
    }
  }

  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('[SecureStorage] write error ($key): $e');
    }
  }

  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('[SecureStorage] delete error ($key): $e');
    }
  }

  Future<bool> containsKey(String key) async {
    try {
      final v = await _storage.read(key: key);
      return v != null;
    } catch (e) {
      debugPrint('[SecureStorage] containsKey error ($key): $e');
      return false;
    }
  }

  /// SharedPreferences から SecureStorage へ移行（初回起動時）
  Future<void> migrateFromPrefs(Map<String, String> entries) async {
    for (final entry in entries.entries) {
      final existing = await read(entry.key);
      if (existing == null && entry.value.isNotEmpty) {
        await write(entry.key, entry.value);
      }
    }
  }
}
