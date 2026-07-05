import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api/sync_manager.dart';

class BackgroundSyncService {
  static final BackgroundSyncService _instance = BackgroundSyncService._internal();
  factory BackgroundSyncService() => _instance;
  BackgroundSyncService._internal();

  Timer? _timer;
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  void start({Duration interval = const Duration(minutes: 5)}) {
    if (_isRunning) return;
    _isRunning = true;
    _timer = Timer.periodic(interval, (_) => _sync());
    _log('定期同期開始: ${interval.inMinutes}分間隔');
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _log('定期同期停止');
  }

  Future<void> _sync() async {
    try {
      await SyncManager().sync();
      await SyncManager().pullAndApply();
    } catch (e) {
      _log('同期エラー: $e');
    }
  }

  /// 手動で同期を実行
  Future<void> syncNow() async {
    await _sync();
  }

  void _log(String msg) {
    debugPrint('[BackgroundSync] $msg');
  }
}