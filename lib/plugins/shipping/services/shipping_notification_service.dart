import '../../../services/database_helper.dart';
import '../models/tracking_model.dart';

/// 配送通知サービス
/// ダッシュボードの sync_notifications テーブルを使って通知を管理する
class ShippingNotificationService {
  static const String _source = 'shipping';

  /// 配達完了通知を追加
  static Future<void> notifyDelivered(Tracking tracking) async {
    await _saveNotification(
      title: '配達完了',
      detail: '${tracking.entityName ?? tracking.trackingNumber}（${tracking.carrier.displayName}）が配達されました。',
    );
  }

  /// ステータス変更通知を追加
  static Future<void> notifyStatusChanged(Tracking tracking, TrackingStatus newStatus) async {
    await _saveNotification(
      title: '追跡状況が更新されました',
      detail: '${tracking.entityName ?? tracking.trackingNumber}（${tracking.carrier.displayName}）: ${newStatus.displayName}',
    );
  }

  /// バッチ更新結果通知を追加
  static Future<void> notifyBatchRefreshResult(int updatedCount, int deliveredCount) async {
    if (updatedCount == 0) return;

    final detail = deliveredCount > 0
        ? '$updatedCount件更新、うち$deliveredCount件が配達完了'
        : '$updatedCount件のステータスが更新されました';

    await _saveNotification(
      title: '追跡情報一括更新',
      detail: detail,
    );
  }

  static Future<void> _saveNotification({
    required String title,
    required String detail,
  }) async {
    final db = await DatabaseHelper().database;
    try {
      await db.insert('sync_notifications', {
        'source': _source,
        'title': title,
        'detail': detail,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // 通知保存失敗は無視
    }
  }
}
