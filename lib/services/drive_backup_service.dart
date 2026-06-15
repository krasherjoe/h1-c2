import 'dart:convert';
import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'google_auth_service.dart';
import 'error_reporter.dart';

class DriveBackupService {
  static const _appFolderName = 'h1-core-backups';

  Future<drive.DriveApi?> _getApi() async {
    final client = await GoogleAuthService.instance.getAuthenticatedClient();
    if (client == null) return null;
    return drive.DriveApi(client);
  }

  Future<String?> _getOrCreateAppFolder(drive.DriveApi api) async {
    final search = await api.files.list(
      q: "name='$_appFolderName' and mimeType='application/vnd.google-apps.folder' and trashed=false",
      spaces: 'drive',
    );
    if (search.files != null && search.files!.isNotEmpty) {
      return search.files!.first.id;
    }
    final folder = await api.files.create(drive.File(
      name: _appFolderName,
      mimeType: 'application/vnd.google-apps.folder',
    ));
    return folder.id;
  }

  Future<bool> uploadBackup(String filePath, {String? companyName}) async {
    try {
      final api = await _getApi();
      if (api == null) return false;
      final folderId = await _getOrCreateAppFolder(api);
      if (folderId == null) return false;

      final file = File(filePath);
      if (!await file.exists()) return false;
      final bytes = await file.readAsBytes();
      final sizeLabel = bytes.length >= 1024 * 1024
          ? '${(bytes.length / (1024 * 1024)).toStringAsFixed(1)}MB'
          : '${(bytes.length / 1024).toStringAsFixed(0)}KB';
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final company = companyName ?? 'default';
      final name = '${dateStr}_${company}_${sizeLabel}_${timeStr}.db';

      await api.files.create(
        drive.File(name: name, parents: [folderId]),
        uploadMedia: drive.Media(Stream.fromIterable([bytes]), bytes.length),
      );
      return true;
    } catch (e, st) {
      ErrorReporter.sendError(message: 'Driveバックアップ失敗: $e', stackTrace: st);
      return false;
    }
  }

  Future<List<drive.File>> listBackups() async {
    try {
      final api = await _getApi();
      if (api == null) return [];
      final search = await api.files.list(
        q: "name='$_appFolderName' and mimeType='application/vnd.google-apps.folder' and trashed=false",
        spaces: 'drive',
      );
      if (search.files == null || search.files!.isEmpty) return [];
      final folderId = search.files!.first.id;
      final result = await api.files.list(
        q: "'$folderId' in parents and trashed=false",
        orderBy: 'createdTime desc',
        pageSize: 50,
      );
      return result.files ?? [];
    } catch (e) {
      ErrorReporter.sendError(message: 'Driveバックアップ一覧取得失敗: $e');
      return [];
    }
  }

  Future<bool> downloadBackup(String fileId, String localPath) async {
    try {
      final api = await _getApi();
      if (api == null) return false;
      final response = await api.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia);
      if (response is drive.Media) {
        final chunks = await response.stream.toList();
        final bytes = chunks.expand((c) => c).toList();
        await File(localPath).writeAsBytes(bytes);
        return true;
      }
      return false;
    } catch (e, st) {
      ErrorReporter.sendError(message: 'Drive復元ダウンロード失敗: $e', stackTrace: st);
      return false;
    }
  }

  Future<bool> deleteBackup(String fileId) async {
    try {
      final api = await _getApi();
      if (api == null) return false;
      await api.files.delete(fileId);
      return true;
    } catch (e) {
      return false;
    }
  }
}
