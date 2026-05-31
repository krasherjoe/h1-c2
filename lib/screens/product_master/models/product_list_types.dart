import '../../../models/product_model.dart';

const categoryAliases = {
  'pc': 'パソコン',
  'pcs': 'パソコン',
  'note': 'ノートPC',
  'notebook': 'ノートPC',
  'laptop': 'ノートPC',
  'ﾉｰﾄpc': 'ノートPC',
  'desktop': 'デスクトップ',
  'ﾃﾞｽｸﾄｯﾌﾟ': 'デスクトップ',
  'tablet': 'タブレット',
  'ﾀﾌﾞﾚｯﾄ': 'タブレット',
  'monitor': 'モニター',
  'display': 'モニター',
  'ﾓﾆﾀｰ': 'モニター',
  'printer': 'プリンター',
  'ﾌﾟﾘﾝﾀｰ': 'プリンター',
  'keyboard': 'キーボード',
  'kb': 'キーボード',
  'ﾏｳｽ': 'マウス',
  'mouse': 'マウス',
  'cable': 'ケーブル',
  'ｹｰﾌﾞﾙ': 'ケーブル',
  'ｱｸｾｻﾘ': 'アクセサリ',
  'accessory': 'アクセサリ',
};

String normalizeCategory(String? cat) {
  if (cat == null || cat.isEmpty) return cat ?? '';
  final key = cat.trim().toLowerCase();
  return categoryAliases[key] ?? cat.trim();
}

class ProductSnapshot {
  final Product? before;
  final Product? after;
  ProductSnapshot({this.before, this.after});
}

class BatchUndoEntry {
  final String type;
  final List<ProductSnapshot> snapshots;
  BatchUndoEntry({required this.type, required this.snapshots});
}

typedef TreeItem = ({String type, String id, Product? product, bool isVariant, int depth});
