import '../../../models/product_category_model.dart';

/// 循環参照を検出する関数。
/// movingId を newParentId の下に移動したとき、循環が発生するかどうかを返す。
bool wouldCreateCycle({
  required String movingId,
  required String? newParentId,
  required Map<String, String?> parentOf,
}) {
  String? cur = newParentId;
  final visited = <String>{};
  while (cur != null) {
    if (cur == movingId) return true; // 循環を発見
    if (!visited.add(cur)) return true; // 既存の循環（異常状態）
    cur = parentOf[cur];
  }
  return false;
}
