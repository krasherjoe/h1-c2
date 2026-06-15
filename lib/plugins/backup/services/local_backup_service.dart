import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart' as crypto;

import '../../../services/database_helper.dart';

class LocalBackupService {
  static const _backupPrefix = 'backup_';
  static const _backupHashSuffix = '.sha256';
  static const _retentionDays = 365 * 7;
  static const _dailyBackupKey = 'backup_date_today';

  Future<String> _getBackupDirectory() async {
    try {
      if (Platform.isAndroid) {
        try {
          final backupDir = Directory('/storage/emulated/0/Download');
          if (await backupDir.exists()) {
            return backupDir.path;
          }
        } catch (_) {}
      } else if (Platform.isIOS) {
        final dir = await getApplicationDocumentsDirectory();
        final backupDir = Directory(path.join(dir.path, 'backups'));
        if (!await backupDir.exists()) {
          await backupDir.create(recursive: true);
        }
        return backupDir.path;
      }
    } catch (e) {
      debugPrint('[Backup] _getBackupDirectory error: $e');
    }
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(path.join(dir.path, 'backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir.path;
  }

  Future<bool> _isTodayBackedUp(String companyName) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T').first;
    final backedUpDate = prefs.getString('${_dailyBackupKey}_$companyName');
    return backedUpDate == today;
  }

  Future<void> _setTodayBackedUp(String companyName) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T').first;
    await prefs.setString('${_dailyBackupKey}_$companyName', today);
  }

  Future<String?> createAutoBackup(String databasePath) async {
    final companyName = path.basenameWithoutExtension(databasePath);
    if (await _isTodayBackedUp(companyName)) {
      return null;
    }

    try {
      final backupDir = await _getBackupDirectory();
      final backupDirObj = Directory(backupDir);
      if (!await backupDirObj.exists()) {
        await backupDirObj.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupPath = path.join(backupDir, '$_backupPrefix${companyName}_$timestamp.db');

      final dbFile = File(databasePath);
      if (!await dbFile.exists()) {
        debugPrint('[BackupService] データベースが見つかりません: $databasePath');
        return null;
      }

      await dbFile.copy(backupPath);

      final backupBytes = await File(backupPath).readAsBytes();
      final backupHash = crypto.sha256.convert(backupBytes).toString();
      final hashPath = '$backupPath$_backupHashSuffix';
      final hashMeta = jsonEncode({
        'hash': backupHash,
        'createdAt': DateTime.now().toIso8601String(),
      });
      await File(hashPath).writeAsString(hashMeta);

      debugPrint('[BackupService] バックアップ作成: $backupPath (hash=$backupHash)');

      await _setTodayBackedUp(companyName);

      return backupPath;
    } catch (e) {
      debugPrint('[BackupService] バックアップ作成失敗: $e');
      return null;
    }
  }

  Future<bool> restoreBackup(String backupPath) async {
    if (kIsWeb) return false;
    try {
      final dbPath = await DatabaseHelper().getDatabasePath();
      await DatabaseHelper.closeAndReset();
      await File(backupPath).copy(dbPath);
      return true;
    } catch (e) {
      debugPrint('[BackupService] リストア失敗: $e');
      return false;
    }
  }

  Future<List<BackupEntry>> listBackups() async {
    final backupDir = await _getBackupDirectory();
    final dir = Directory(backupDir);
    if (!await dir.exists()) return [];

    final entries = <BackupEntry>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.db')) {
        final hashFile = File('${entity.path}.sha256');
        String? hash;
        DateTime? createdAt;
        if (await hashFile.exists()) {
          try {
            final meta = jsonDecode(await hashFile.readAsString());
            hash = meta['hash'] as String?;
            createdAt = DateTime.tryParse(meta['createdAt'] as String? ?? '');
          } catch (_) {}
        }
        entries.add(BackupEntry(
          path: entity.path,
          filename: path.basename(entity.path),
          sizeBytes: await entity.length(),
          createdAt: createdAt ?? (await entity.stat()).modified,
          hash: hash,
        ));
      }
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final backupDir = await _getBackupDirectory();
      final dir = Directory(backupDir);
      if (!await dir.exists()) {
        return {'sizeBytes': 0, 'sizeReadable': '0 B', 'fileCount': 0};
      }

      int totalBytes = 0;
      int fileCount = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          totalBytes += await entity.length();
          fileCount++;
        }
      }

      String readable;
      if (totalBytes < 1024) {
        readable = '$totalBytes B';
      } else if (totalBytes < 1024 * 1024) {
        readable = '${(totalBytes / 1024).toStringAsFixed(1)} KB';
      } else if (totalBytes < 1024 * 1024 * 1024) {
        readable = '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      } else {
        readable = '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
      }

      return {'sizeBytes': totalBytes, 'sizeReadable': readable, 'fileCount': fileCount};
    } catch (e) {
      debugPrint('[BackupService] 容量情報取得失敗: $e');
      return {'sizeBytes': 0, 'sizeReadable': '不明', 'fileCount': 0};
    }
  }
}

class BackupEntry {
  final String path;
  final String filename;
  final int sizeBytes;
  final DateTime createdAt;
  final String? hash;

  const BackupEntry({
    required this.path,
    required this.filename,
    required this.sizeBytes,
    required this.createdAt,
    this.hash,
  });
}
