import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const _kOwner = 'krasherjoe';
  static const _kRepo = 'h1-core';
  static const _kApiUrl = 'https://api.github.com/repos/$_kOwner/$_kRepo/releases/latest';

  String? latestVersion;
  String? latestApkUrl;
  String? latestNotes;
  String? _downloadedPath;
  double _downloadProgress = 0;

  String? get downloadedPath => _downloadedPath;
  double get downloadProgress => _downloadProgress;

  bool get hasUpdate => latestVersion != null;

  Future<String?> checkForUpdate() async {
    try {
      final res = await http.get(
        Uri.parse(_kApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json', 'User-Agent': 'h1-core'},
      );
      if (res.statusCode != 200) return 'GitHub API error: ${res.statusCode}';
      final data = jsonDecode(res.body);
      latestVersion = (data['tag_name'] as String).replaceFirst('v', '');
      latestNotes = data['body'] as String?;

      final assets = data['assets'] as List;
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          latestApkUrl = asset['browser_download_url'] as String?;
          break;
        }
      }
      return null;
    } catch (e) {
      return '更新確認失敗: $e';
    }
  }

  Future<String?> downloadApk() async {
    if (latestApkUrl == null) return 'APKのURLが見つかりません';
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/h1-core-${latestVersion ?? 'latest'}.apk');

      final res = await http.Client().send(http.Request('GET', Uri.parse(latestApkUrl!)));
      final total = res.contentLength ?? 0;
      var received = 0;
      final sink = file.openWrite(mode: FileMode.write);

      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) _downloadProgress = received / total;
      }
      await sink.close();

      _downloadedPath = file.path;
      return null;
    } catch (e) {
      return 'ダウンロード失敗: $e';
    }
  }

  Future<void> openReleasesPage() async {
    final url = 'https://github.com/$_kOwner/$_kRepo/releases';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> openDownloadUrl() async {
    if (latestApkUrl == null) return;
    final uri = Uri.parse(latestApkUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
