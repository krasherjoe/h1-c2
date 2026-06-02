import 'sync_service.dart';

class SyncGarbageCollector {
  static Future<void> runAll() async {
    await SyncService.runGarbageCollection();
  }
}
