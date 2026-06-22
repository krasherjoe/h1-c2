import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/foundation.dart';

enum UpdateFrequency {
  off,
  threeMinutes,
  daily,
  weekly,
  monthly,
}

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  static const String _githubOwner = 'krasherjoe';
  static const String _githubRepo = 'h1-core';
  static const String _githubApiUrl = 'https://api.github.com';
  static const String _prefKeyAutoUpdate = 'auto_update_enabled';
  static const String _prefKeyUpdateFrequency = 'update_frequency';
  static const String _prefKeyLastCheckTime = 'last_update_check_time';
  static const String _prefKeyAutoInstall = 'auto_install_enabled';

  http.Client? _downloadClient;

  /// 自動アップデートが有効かどうか
  Future<bool> isAutoUpdateEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyAutoUpdate) ?? false;
  }

  /// 自動アップデートを設定
  Future<void> setAutoUpdateEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyAutoUpdate, enabled);
  }

  /// 自動インストールが有効かどうか
  Future<bool> isAutoInstallEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyAutoInstall) ?? false;
  }

  /// 自動インストールを設定
  Future<void> setAutoInstallEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyAutoInstall, enabled);
  }

  /// アップデート頻度を取得
  Future<UpdateFrequency> getUpdateFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    final frequency = prefs.getString(_prefKeyUpdateFrequency) ?? 'off';
    return UpdateFrequency.values.firstWhere(
      (e) => e.name == frequency,
      orElse: () => UpdateFrequency.off,
    );
  }

  /// アップデート頻度を設定
  Future<void> setUpdateFrequency(UpdateFrequency frequency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyUpdateFrequency, frequency.name);
  }

  /// 最後のチェック時間を取得
  Future<DateTime?> getLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(_prefKeyLastCheckTime);
    if (timestamp != null) {
      return DateTime.tryParse(timestamp);
    }
    return null;
  }

  /// 最後のチェック時間を更新
  Future<void> _updateLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyLastCheckTime, DateTime.now().toIso8601String());
  }

  /// 自動チェックが必要かどうか
  Future<bool> shouldAutoCheck() async {
    final enabled = await isAutoUpdateEnabled();
    if (!enabled) return false;

    final frequency = await getUpdateFrequency();
    if (frequency == UpdateFrequency.off) return false;

    final lastCheck = await getLastCheckTime();
    if (lastCheck == null) return true;

    final now = DateTime.now();
    final difference = now.difference(lastCheck);

    switch (frequency) {
      case UpdateFrequency.threeMinutes:
        return difference.inMinutes >= 3;
      case UpdateFrequency.daily:
        return difference.inDays >= 1;
      case UpdateFrequency.weekly:
        return difference.inDays >= 7;
      case UpdateFrequency.monthly:
        return difference.inDays >= 30;
      case UpdateFrequency.off:
        return false;
    }
  }

  /// 自動チェックを実行
  Future<bool> performAutoCheck() async {
    if (!await shouldAutoCheck()) return false;

    final hasUpdate = await needsUpdate();
    await _updateLastCheckTime();

    if (hasUpdate && await isAutoInstallEnabled()) {
      final latest = await getLatestVersion();
      if (latest != null) {
        final apkPath = await downloadApk(latest);
        if (apkPath != null) {
          await installApk(apkPath);
        }
      }
    }

    return hasUpdate;
  }

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
  Future<String?> downloadApk(String version, {Function(double)? onProgress}) async {
    try {
      final dir = await getTemporaryDirectory();
      final fileName = 'h1-core-v$version.apk';
      final filePath = p.join(dir.path, fileName);

      final url = 'https://github.com/$_githubOwner/$_githubRepo/releases/download/v$version/$fileName';
      
      // ストリームでダウンロードしてプログレスを追跡
      _downloadClient = http.Client();
      final response = await _downloadClient!.send(http.Request('GET', Uri.parse(url)));

      if (response.statusCode == 200) {
        final contentLength = response.contentLength ?? 0;
        final file = File(filePath);
        final sink = file.openWrite();
        int downloadedBytes = 0;

        await response.stream.listen(
          (chunk) {
            sink.add(chunk);
            downloadedBytes += chunk.length;
            if (contentLength > 0 && onProgress != null) {
              onProgress(downloadedBytes / contentLength);
            }
          },
          onDone: () async {
            await sink.close();
          },
          onError: (e) {
            sink.close();
          },
          cancelOnError: true,
        ).asFuture();

        await sink.close();
        _downloadClient = null;
        return filePath;
      }
      _downloadClient = null;
      return null;
    } catch (e) {
      _downloadClient = null;
      return null;
    }
  }

  /// ダウンロードをキャンセル
  void cancelDownload() {
    _downloadClient?.close();
    _downloadClient = null;
  }

  /// APKをインストール（Androidのみ）
  Future<bool> installApk(String filePath) async {
    if (kIsWeb || !Platform.isAndroid) return false;

    try {
      final result = await OpenFilex.open(filePath);
      return result.type == ResultType.done;
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
