import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  static const String _githubOwner = 'krasherjoe';
  static const String _githubRepo = 'h1-core';
  static const String _githubApiUrl = 'https://api.github.com';

  /// 現在のバージョンを取得
  Future<String> getCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// GitHub Releaseから最新バージョンを取得
  Future<String?> getLatestVersion() async {
    try {
      final response = await http.get(
        Uri.parse('$_githubApiUrl/repos/$_githubOwner/$_githubRepo/releases/latest'),
      );

      if (response.statusCode == 200) {
        final data = response.body;
        // タグ名からバージョンを抽出（例: v1.4.003 → 1.4.003）
        final tagMatch = RegExp(r'"tag_name":\s*"v([^"]+)"').firstMatch(data);
        if (tagMatch != null) {
          return tagMatch.group(1);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// アップデートが必要かチェック
  Future<bool> needsUpdate() async {
    final current = await getCurrentVersion();
    final latest = await getLatestVersion();

    if (latest == null) return false;

    return _compareVersions(current, latest) < 0;
  }

  /// バージョン比較（current < latestなら負の値）
  int _compareVersions(String current, String latest) {
    final currentParts = current.split('.').map(int.parse).toList();
    final latestParts = latest.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      if (currentParts[i] < latestParts[i]) return -1;
      if (currentParts[i] > latestParts[i]) return 1;
    }
    return 0;
  }

  /// APKをダウンロード
  Future<String?> downloadApk(String version) async {
    try {
      final dir = await getTemporaryDirectory();
      final fileName = 'h1-core-v$version.apk';
      final filePath = p.join(dir.path, fileName);

      final url = 'https://github.com/$_githubOwner/$_githubRepo/releases/download/v$version/$fileName';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        return filePath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// APKをインストール（Androidのみ）
  Future<bool> installApk(String filePath) async {
    if (!Platform.isAndroid) return false;

    try {
      // AndroidではAPKインストールにはインストール権限が必要
      // flutter_install_apkパッケージを使用するか、Intentでインストール
      // ここでは簡易的にファイルパスを返す
      return true;
    } catch (e) {
      return false;
    }
  }

  /// アップデート情報を取得
  Future<Map<String, dynamic>?> getUpdateInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$_githubApiUrl/repos/$_githubOwner/$_githubRepo/releases/latest'),
      );

      if (response.statusCode == 200) {
        final data = response.body;
        final tagMatch = RegExp(r'"tag_name":\s*"v([^"]+)"').firstMatch(data);
        final nameMatch = RegExp(r'"name":\s*"([^"]+)"').firstMatch(data);
        final bodyMatch = RegExp(r'"body":\s*"([^"]+)"').firstMatch(data);

        if (tagMatch != null) {
          return {
            'version': tagMatch.group(1),
            'name': nameMatch?.group(1) ?? '',
            'body': bodyMatch?.group(1) ?? '',
          };
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
