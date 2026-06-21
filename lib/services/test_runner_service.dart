import 'dart:io';
import 'dart:convert';

class TestRunnerService {
  static final TestRunnerService _instance = TestRunnerService._internal();
  factory TestRunnerService() => _instance;
  TestRunnerService._internal();

  String? _lastResult;
  DateTime? _lastRunTime;
  bool _isRunning = false;

  /// テストを実行（コマンドライン経由）
  Future<Map<String, dynamic>> runTest(String testFile) async {
    if (_isRunning) {
      return {
        'status': 'error',
        'message': 'テスト実行中です',
      };
    }

    _isRunning = true;
    _lastRunTime = DateTime.now();

    try {
      // integration_testを実行
      final result = await Process.run(
        'flutter',
        ['test', 'integration_test/$testFile'],
        workingDirectory: '/home/user/code/h-1-core',
      );

      _lastResult = result.stdout;
      _isRunning = false;

      return {
        'status': result.exitCode == 0 ? 'success' : 'failed',
        'exitCode': result.exitCode,
        'stdout': result.stdout,
        'stderr': result.stderr,
        'timestamp': _lastRunTime?.toIso8601String(),
      };
    } catch (e) {
      _isRunning = false;
      return {
        'status': 'error',
        'message': e.toString(),
      };
    }
  }

  /// 最後のテスト結果を取得
  Map<String, dynamic> getLastResult() {
    return {
      'isRunning': _isRunning,
      'lastRunTime': _lastRunTime?.toIso8601String(),
      'lastResult': _lastResult,
    };
  }

  /// 利用可能なテストファイル一覧
  Future<List<String>> listTestFiles() async {
    final testDir = Directory('/home/user/code/h-1-core/integration_test');
    if (!await testDir.exists()) {
      await testDir.create(recursive: true);
      return [];
    }

    final files = await testDir.list().toList();
    return files
        .where((f) => f.path.endsWith('_test.dart'))
        .map((f) => f.path.split('/').last)
        .toList();
  }
}
