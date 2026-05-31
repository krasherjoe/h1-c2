import 'package:flutter/material.dart';
import 'customer_model.dart';

/// 伝票ステータス
enum DocumentStatus {
  draft,      // 下書き
  confirmed,  // 確定
  cancelled,  // キャンセル
}

/// 基本伝票モデル
/// すべての伝票（見積・受注・売上・請求）に共通する基底クラス
abstract class BaseDocument {
  final String id;
  final String documentNumber;      // 伝票番号
  final DateTime date;              // 伝票日付
  final Customer? customer;         // 顧客
  List<DocumentItem> items;         // 明細
  final int subtotal;               // 小計
  final int taxAmount;              // 消費税額
  final int total;                  // 合計
  final double taxRate;             // 税率
  final String? notes;              // 備考
  final String? subject;            // 件名
  final DocumentStatus status;      // ステータス
  final DateTime createdAt;         // 作成日時
  final DateTime updatedAt;         // 更新日時

  BaseDocument({
    required this.id,
    required this.documentNumber,
    required this.date,
    this.customer,
    required this.items,
    required this.subtotal,
    required this.taxAmount,
    required this.total,
    required this.taxRate,
    this.notes,
    this.subject,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 表示用タイトルを取得
  String getDisplayTitle() {
    return customer?.displayName ?? '一般客';
  }

  /// サブタイトルを取得
  String getDisplaySubtitle() {
    return subject ?? '';
  }

  /// 金額表示を取得
  String getDisplayAmount() {
    return '¥${total.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }

  /// ステータスカラーを取得
  Color getStatusColor(ColorScheme cs);

  /// テーマカラーを取得（伝票種類ごとに異なる）
  Color getThemeColor(ColorScheme cs);

  /// Map形式に変換
  Map<String, dynamic> toMap();

  /// 伝票タイプ名を取得
  String getDocumentTypeName();
}

/// 伝票明細
class DocumentItem {
  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final int unitPrice;
  final int subtotal;
  final double taxRate;
  final String? notes;

  DocumentItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.taxRate,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'subtotal': subtotal,
      'tax_rate': taxRate,
      'notes': notes,
    };
  }

  factory DocumentItem.fromMap(Map<String, dynamic> map) {
    return DocumentItem(
      id: map['id'] as String? ?? '',
      productId: map['product_id'] as String? ?? '',
      productName: map['product_name'] as String? ?? '',
      quantity: map['quantity'] as int? ?? 0,
      unitPrice: map['unit_price'] as int? ?? 0,
      subtotal: map['subtotal'] as int? ?? 0,
      taxRate: (map['tax_rate'] as num).toDouble(),
      notes: map['notes'] as String?,
    );
  }

  DocumentItem copyWith({
    String? id,
    String? productId,
    String? productName,
    int? quantity,
    int? unitPrice,
    int? subtotal,
    double? taxRate,
    String? notes,
  }) {
    return DocumentItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      subtotal: subtotal ?? this.subtotal,
      taxRate: taxRate ?? this.taxRate,
      notes: notes ?? this.notes,
    );
  }
}
