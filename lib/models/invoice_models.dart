import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart' show Colors, Color, ColorScheme;
import 'package:intl/intl.dart';
import 'customer_model.dart';
import 'payment_schedule_model.dart' show PaymentStatus;

class InvoiceItem {
  final String? id;
  final String? productId; // 追加
  String description;
  int quantity;
  int unitPrice;
  int? discountAmount; // 値引き額
  double? discountRate; // 値引き率

  InvoiceItem({
    this.id,
    this.productId, // 追加
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.discountAmount,
    this.discountRate,
  });

  int get subtotal {
    int base = quantity * unitPrice;
    if (discountAmount != null && discountAmount! > 0) {
      return base - discountAmount!;
    }
    if (discountRate != null && discountRate! > 0) {
      return (base * (1 - discountRate!)).round();
    }
    return base;
  }

  Map<String, dynamic> toMap(String invoiceId) {
    return {
      'id': id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      'invoice_id': invoiceId,
      'product_id': productId, // 追加
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount_amount': discountAmount,
      'discount_rate': discountRate,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id'],
      productId: map['product_id'], // 追加
      description: map['description'],
      quantity: map['quantity'],
      unitPrice: map['unit_price'],
      discountAmount: map['discount_amount'] as int?,
      discountRate: map['discount_rate'] as double?,
    );
  }

  InvoiceItem copyWith({
    String? id, // Added this to be complete
    String? description,
    int? quantity,
    int? unitPrice,
    String? productId,
    int? discountAmount,
    double? discountRate,
  }) {
    return InvoiceItem(
      id: id ?? this.id, // Added this to be complete
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      productId: productId ?? this.productId,
      discountAmount: discountAmount ?? this.discountAmount,
      discountRate: discountRate ?? this.discountRate,
    );
  }

  /// 赤伝用: 数量をマイナスに反転したコピーを返す（単価はそのまま）
  InvoiceItem negate() {
    return InvoiceItem(
      id: null,
      productId: productId,
      description: description,
      quantity: -quantity,
      unitPrice: unitPrice,
      discountAmount: discountAmount,
      discountRate: discountRate,
    );
  }
}

enum DocumentType {
  estimation, // 見積
  order, // 受注
  delivery, // 納品
  invoice, // 請求
  receipt, // 領収
}

enum OrderStatus { draft, confirmed, fulfilled }

extension OrderStatusLabel on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.draft:
        return '下書き';
      case OrderStatus.confirmed:
        return '確定';
      case OrderStatus.fulfilled:
        return '完了';
    }
  }
}

class Invoice {
  static const String lockStatement =
      '正式発行ボタン押下時にこの伝票はロックされ、以後の編集・削除はできません。ロック状態はハッシュチェーンで保護されます。';
  static const String hashDescription =
      'metaJson = JSON.stringify({id, invoiceNumber, customer, date, total, documentType, hash, lockStatement, companySnapshot, companySealHash, items:[{productId, productName, quantity, unitPrice, subtotal, taxRate}]}); metaHash = SHA-256(metaJson).';
  final String id;
  final Customer customer;
  final DateTime date;
  final List<InvoiceItem> items;
  final String? notes;
  final String? filePath;
  final double taxRate;
  final DocumentType documentType; // 追加
  final OrderStatus orderStatus;
  final DateTime? promisedDate;
  final DateTime? fulfilledDate;
  final String? sourceDocumentId;
  final String? linkedDeliveryId;
  final String? linkedInvoiceId;
  final String? customerFormalNameSnapshot;
  final String? odooId;
  final bool isSynced;
  final DateTime updatedAt;
  final double? latitude; // 追加
  final double? longitude; // 追加
  final String terminalId; // 追加: 端末識別子
  final bool isDraft; // 追加: 下書きフラグ
  final String? subject; // 追加: 案件名
  final bool isLocked; // 追加: ロック
  final int? contactVersionId; // 追加: 連絡先バージョン
  final String? contactEmailSnapshot;
  final String? contactTelSnapshot;
  final String? contactAddressSnapshot;
  final String? companySnapshot; // 追加: 発行時会社情報スナップショット
  final String? companySealHash; // 追加: 角印画像ハッシュ
  final String? metaJson;
  final String? metaHash;
  final int? totalDiscountAmount; // 合計値引き額
  final double? totalDiscountRate; // 合計値引き率
  final bool isReceiptIssued; // 領収証発行済みフラグ
  final DateTime? receiptIssuedAt; // 領収証発行日時
  final PaymentStatus paymentStatus; // 入金ステータス
  final int receivedAmount; // 入金済み金額
  final bool includeTax; // 税込みフラグ
  final bool isTaxInclusiveMode; // 税込みモード（単価が税込、消費税を逆算）
  final String? priceAdjustmentType; // 価格調整タイプ: 'round_down', 'round_up', 'round_nearest'
  final int? priceAdjustmentUnit; // 価格調整単位: 1, 10, 100, 1000
  final String? bankAccount; // 銀行口座情報（請求書用）
  final String? projectId; // 案件ID（任意紐づけ）
  bool isTestDocument; // テスト用伝票フラグ（案件名にテスト/TEST/testが含まれる場合true）
  final String? printedAt; // 印刷日時
  final String? emailSentAt; // メール送信日時（Gmail API 経由）
  final String? emailSentTo; // 送信先メールアドレス
  final int version; // HASHスタック：バージョン番号
  final bool isCurrent; // HASHスタック：現行フラグ
  final String? previousHash; // HASHスタック：前バージョンのcontent_hash

  int get remainingAmount {
    if (totalAmount <= 0) return 0;
    return (totalAmount - receivedAmount).clamp(0, totalAmount);
  }

  Invoice({
    String? id,
    required this.customer,
    required this.date,
    required this.items,
    this.notes,
    this.filePath,
    this.taxRate = 0.10,
    this.documentType = DocumentType.invoice, // デフォルト請求書
    this.orderStatus = OrderStatus.draft,
    this.promisedDate,
    this.fulfilledDate,
    this.sourceDocumentId,
    this.linkedDeliveryId,
    this.linkedInvoiceId,
    this.customerFormalNameSnapshot,
    this.odooId,
    this.isSynced = false,
    DateTime? updatedAt,
    this.latitude, // 追加
    this.longitude, // 追加
    String? terminalId, // 追加
    this.isDraft = false, // 追加: デフォルトは通常
    this.subject, // 追加: 案件
    this.isLocked = false,
    this.contactVersionId,
    this.contactEmailSnapshot,
    this.contactTelSnapshot,
    this.contactAddressSnapshot,
    this.companySnapshot,
    this.companySealHash,
    this.metaJson,
    this.metaHash,
    this.totalDiscountAmount,
    this.totalDiscountRate,
    this.isReceiptIssued = false,
    this.receiptIssuedAt,
    this.paymentStatus = PaymentStatus.unpaid,
    this.receivedAmount = 0,
    this.includeTax = false,
    this.isTaxInclusiveMode = false,
    this.priceAdjustmentType,
    this.priceAdjustmentUnit,
    this.bankAccount,
    this.projectId,
    this.isTestDocument = false,
    this.printedAt,
    this.emailSentAt,
    this.emailSentTo,
    this.version = 1,
    this.isCurrent = true,
    this.previousHash,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       terminalId = terminalId ?? "T1", // デフォルト端末ID
       updatedAt = updatedAt ?? DateTime.now() {
    // 案件名にテスト文字列が含まれる場合、テスト用伝票としてマーク
    // 大文字小文字・全角半角を区別せず判定
    final normalizedSubject = _normalizeForTestCheck(subject ?? '');
    isTestDocument = normalizedSubject.contains('test');
  }

  /// テスト判定用の文字列正規化（全角半角・大文字小文字を統一）
  static String _normalizeForTestCheck(String input) {
    // 全角カタカナ「テスト」を「test」に変換
    final katakanaToRomaji = input.replaceAll('テスト', 'test');
    // 全角英字を半角に変換
    final halfWidth = katakanaToRomaji
        .replaceAll('Ｔ', 'T')
        .replaceAll('Ｅ', 'E')
        .replaceAll('Ｓ', 'T')
        .replaceAll('ｔ', 't')
        .replaceAll('ｅ', 'e')
        .replaceAll('ｓ', 't');
    // 小文字に統一
    return halfWidth.toLowerCase();
  }

  /// 伝票内容から決定論的なハッシュを生成する (SHA256の一部)
  /// テスト用伝票の場合は特殊なハッシュを返し、ハッシュチェーンから除外
  String get contentHash {
    if (isTestDocument) {
      // テスト用伝票はハッシュチェーンに含めない（固定値）
      return "TEST_DOCUMENT_EXCLUDED_FROM_HASH_CHAIN";
    }
    final input =
        "$id|$terminalId|${date.toIso8601String()}|${customer.id}|$totalAmount|${subject ?? ""}|${items.map((e) => "${e.description}${e.quantity}${e.unitPrice}").join()}";
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString().toUpperCase();
  }

  String get documentTypeName {
    switch (documentType) {
      case DocumentType.estimation:
        return "見積書";
      case DocumentType.order:
        return "受注伝票";
      case DocumentType.delivery:
        return "納品書";
      case DocumentType.invoice:
        return "請求書";
      case DocumentType.receipt:
        return "領収書";
    }
  }

  static const Map<DocumentType, String> _docTypeShortLabel = {
    DocumentType.estimation: '見積',
    DocumentType.order: '受注',
    DocumentType.delivery: '納品',
    DocumentType.invoice: '請求',
    DocumentType.receipt: '領収',
  };

  String get invoiceNumberPrefix {
    switch (documentType) {
      case DocumentType.estimation:
        return "EST";
      case DocumentType.order:
        return "ORD";
      case DocumentType.delivery:
        return "DEL";
      case DocumentType.invoice:
        return "INV";
      case DocumentType.receipt:
        return "REC";
    }
  }

  bool get isOrder => documentType == DocumentType.order;
  bool get isOrderConfirmed => isOrder && orderStatus == OrderStatus.confirmed;

  String get invoiceNumber =>
      "$invoiceNumberPrefix-$terminalId-${DateFormat('yyyyMMdd').format(date)}-${id.substring(id.length > 4 ? id.length - 4 : 0)}";

  // 表示用の宛名（スナップショットがあれば優先）。必ず敬称を付与。
  String get customerNameForDisplay {
    final base = customer.displayName;
    final hasHonorific = RegExp(r'(様|御中|殿)$').hasMatch(base);
    return hasHonorific ? base : '$base ${HonorificCode.toName(customer.title)}';
  }

  int get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);
  
  /// 価格調整値引きを計算
  int get priceAdjustmentDiscount {
    if (priceAdjustmentType == null || priceAdjustmentUnit == null) {
      return 0;
    }

    // 手動入力モードの場合はpriceAdjustmentUnitをそのまま値引き額として返す
    if (priceAdjustmentType == 'manual') {
      return priceAdjustmentUnit!;
    }

    final unit = priceAdjustmentUnit!;
    final baseAmount = subtotal - _regularDiscount;

    int totalBeforeAdjustment;
    if (isTaxInclusiveMode) {
      // 税込みモード: baseAmountは税込なのでそのまま合計
      totalBeforeAdjustment = baseAmount;
    } else {
      final taxAmount = includeTax ? (baseAmount * taxRate).floor() : 0;
      totalBeforeAdjustment = baseAmount + taxAmount;
    }

    int adjustedTotal;
    switch (priceAdjustmentType) {
      case 'round_down':
        // 切り捨て
        adjustedTotal = (totalBeforeAdjustment ~/ unit) * unit;
        break;
      case 'round_up':
        // 切り上げ
        adjustedTotal = ((totalBeforeAdjustment + unit - 1) ~/ unit) * unit;
        break;
      case 'round_nearest':
        // 四捨五入
        adjustedTotal = ((totalBeforeAdjustment + unit ~/ 2) ~/ unit) * unit;
        break;
      default:
        return 0;
    }

    final discount = totalBeforeAdjustment - adjustedTotal;
    return discount;
  }
  
  /// 通常の値引き額（明細単位 + 伝票全体）
  int get _regularDiscount {
    int itemDiscount = items.fold(0, (sum, item) {
      if (item.discountAmount != null && item.discountAmount! > 0) {
        return sum + item.discountAmount!;
      }
      if (item.discountRate != null && item.discountRate! > 0) {
        int base = item.quantity * item.unitPrice;
        return sum + (base * item.discountRate!).round();
      }
      return sum;
    });

    if (totalDiscountAmount != null && totalDiscountAmount! > 0) {
      return totalDiscountAmount!;
    }
    if (totalDiscountRate != null && totalDiscountRate! > 0) {
      return (subtotal * totalDiscountRate!).round();
    }

    return itemDiscount;
  }

  int get discountAmount => _regularDiscount + priceAdjustmentDiscount;

  int get taxableAmount {
    if (isTaxInclusiveMode) {
      // 税込みモード: 小計は税込、税抜金額を逆算
      final taxInclusiveTotal = subtotal - discountAmount;
      final tax = (taxInclusiveTotal * taxRate / (1 + taxRate)).round();
      return taxInclusiveTotal - tax;
    }
    return subtotal - discountAmount;
  }

  int get tax {
    if (!includeTax) return 0;
    if (isTaxInclusiveMode) {
      // 税込みモード: 合計から消費税を逆算
      final taxInclusiveTotal = subtotal - discountAmount;
      return (taxInclusiveTotal * taxRate / (1 + taxRate)).round();
    }
    return (taxableAmount * taxRate).floor();
  }

  int get totalAmount {
    if (isTaxInclusiveMode) {
      // 税込みモード: 合計 = 税込小計（税抜金額 + 消費税）
      return subtotal - discountAmount;
    }
    return taxableAmount + tax;
  }

  /// 赤伝かどうか（元伝票への取消しで、合計金額がマイナス）
  bool get isRedInvoice => sourceDocumentId != null && totalAmount < 0;

  /// 入金ステータスの表示用文字列
  String get paymentStatusDisplay {
    switch (paymentStatus) {
      case PaymentStatus.unpaid:
        return '未入金';
      case PaymentStatus.partial:
        return '一部入金（\u00a5${NumberFormat('#,###').format(receivedAmount)} / \u00a5${NumberFormat('#,###').format(totalAmount)}）';
      case PaymentStatus.paid:
        return '入金済み';
      case PaymentStatus.overdue:
        return '延滞（\u00a5${NumberFormat('#,###').format(receivedAmount)} / \u00a5${NumberFormat('#,###').format(totalAmount)}）';
      case PaymentStatus.cancelled:
        return '取消';
    }
  }

  /// 入金ステータスに応じた色
  Color getPaymentStatusColor(ColorScheme cs) {
    switch (paymentStatus) {
      case PaymentStatus.unpaid:
        return cs.secondary;
      case PaymentStatus.partial:
        return cs.secondary;
      case PaymentStatus.paid:
        return cs.tertiary;
      case PaymentStatus.overdue:
        return cs.error;
      case PaymentStatus.cancelled:
        return cs.outline;
    }
  }

  String get _projectLabel {
    if (subject != null && subject!.trim().isNotEmpty) {
      return subject!.trim();
    }
    if (items.isNotEmpty) {
      final first = items.first.description.trim();
      return items.length > 1 ? '$first他' : first;
    }
    return '';
  }

  String get mailTitleCore {
    final dateStr = DateFormat('yyyyMMdd').format(date);
    final docLabel =
        _docTypeShortLabel[documentType] ??
        documentTypeName.replaceAll('書', '');
    final customerCompact = customerNameForDisplay.replaceAll(
      RegExp(r'\s+'),
      '',
    );
    final amountStr = NumberFormat('#,###').format(totalAmount);
    final buffer = StringBuffer()
      ..write(dateStr)
      ..write('($docLabel)')
      ..write(_projectLabel)
      ..write('@')
      ..write(customerCompact)
      ..write('_')
      ..write(amountStr)
      ..write('円');
    final raw = buffer.toString();
    return _sanitizeForFile(raw);
  }

  String get mailAttachmentFileName => '$mailTitleCore.pdf';

  String get mailBodyText {
    final docName = documentTypeName.replaceAll('書', '');
    return '$docNameをお送りします。ご確認ください。\n※このメールはシステムにより自動送信されています。';
  }

  static String _sanitizeForFile(String input) {
    var sanitized = input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    sanitized = sanitized.replaceAll(RegExp(r'[\r\n]+'), '');
    sanitized = sanitized.replaceAll('　', '');
    sanitized = sanitized.replaceAll(' ', '');
    return sanitized;
  }

  Map<String, dynamic> metaPayload() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'customer': customerNameForDisplay,
      'date': date.toIso8601String(),
      'total': totalAmount,
      'documentType': documentType.name,
      'hash': contentHash,
      'lockStatement': lockStatement,
      'hashDescription': hashDescription,
      'companySnapshot': companySnapshot,
      'companySealHash': companySealHash,
      'items': items.map((e) => {
        'id': e.id,
        'productId': e.productId,
        'productName': e.description,
        'quantity': e.quantity,
        'unitPrice': e.unitPrice,
        'subtotal': e.subtotal,
        'discountAmount': e.discountAmount,
        'discountRate': e.discountRate,
      }).toList(),
    };
  }

  String get metaJsonValue => metaJson ?? jsonEncode(metaPayload());

  String get metaHashValue =>
      metaHash ?? sha256.convert(utf8.encode(metaJsonValue)).toString();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'version': version,
      'is_current': isCurrent ? 1 : 0,
      'previous_hash': previousHash,
      'customer_id': customer.id,
      'date': date.toIso8601String(),
      'notes': notes,
      'file_path': filePath,
      'total_amount': totalAmount,
      'tax_rate': taxRate,
      'document_type': documentType.name, // 追加
      'order_status': orderStatus.name,
      'promised_date': promisedDate?.millisecondsSinceEpoch,
      'fulfilled_date': fulfilledDate?.millisecondsSinceEpoch,
      'source_document_id': sourceDocumentId,
      'linked_delivery_id': linkedDeliveryId,
      'linked_invoice_id': linkedInvoiceId,
      'customer_formal_name': customerFormalNameSnapshot ?? customer.formalName,
      'odoo_id': odooId,
      'is_synced': isSynced ? 1 : 0,
      'updated_at': updatedAt.toIso8601String(),
      'latitude': latitude, // 追加
      'longitude': longitude, // 追加
      'terminal_id': terminalId, // 追加
      'content_hash': contentHash, // 追加
      'is_draft': isDraft ? 1 : 0, // 追加
      'subject': subject, // 追加
      'is_locked': isLocked ? 1 : 0,
      'contact_version_id': contactVersionId,
      'contact_email_snapshot': contactEmailSnapshot,
      'contact_tel_snapshot': contactTelSnapshot,
      'contact_address_snapshot': contactAddressSnapshot,
      'company_snapshot': companySnapshot,
      'company_seal_hash': companySealHash,
      'meta_json': metaJsonValue,
      'meta_hash': metaHashValue,
      'is_receipt_issued': isReceiptIssued ? 1 : 0,
      'receipt_issued_at': receiptIssuedAt?.toIso8601String(),
      'payment_status': paymentStatus.name,
      'received_amount': receivedAmount,
      'total_discount_amount': totalDiscountAmount,
      'total_discount_rate': totalDiscountRate,
      'price_adjustment_type': priceAdjustmentType,
      'price_adjustment_unit': priceAdjustmentUnit,
      'bank_account': bankAccount,
      'project_id': projectId,
      'include_tax': includeTax ? 1 : 0,
      'is_tax_inclusive_mode': isTaxInclusiveMode ? 1 : 0,
      'is_test_document': isTestDocument ? 1 : 0,
      'printed_at': printedAt,
      'email_sent_at': emailSentAt,
      'email_sent_to': emailSentTo,
    };
  }

  Invoice copyWith({
    String? id,
    Customer? customer,
    DateTime? date,
    List<InvoiceItem>? items,
    String? notes,
    String? filePath,
    double? taxRate,
    DocumentType? documentType,
    OrderStatus? orderStatus,
    DateTime? promisedDate,
    DateTime? fulfilledDate,
    String? sourceDocumentId,
    String? linkedDeliveryId,
    String? linkedInvoiceId,
    String? customerFormalNameSnapshot,
    String? odooId,
    bool? isSynced,
    DateTime? updatedAt,
    double? latitude,
    double? longitude,
    String? terminalId,
    bool? isDraft,
    String? subject,
    bool? isLocked,
    int? contactVersionId,
    String? contactEmailSnapshot,
    String? contactTelSnapshot,
    String? contactAddressSnapshot,
    String? companySnapshot,
    String? companySealHash,
    String? metaJson,
    String? metaHash,
    int? totalDiscountAmount,
    double? totalDiscountRate,
    bool? isReceiptIssued,
    DateTime? receiptIssuedAt,
    PaymentStatus? paymentStatus,
    int? receivedAmount,
    bool? includeTax,
    bool? isTaxInclusiveMode,
    String? priceAdjustmentType,
    int? priceAdjustmentUnit,
    String? bankAccount,
    String? projectId,
    bool? isTestDocument,
    String? printedAt,
    String? emailSentAt,
    String? emailSentTo,
    int? version,
    bool? isCurrent,
    String? previousHash,
  }) {
    return Invoice(
      id: id ?? this.id,
      customer: customer ?? this.customer,
      date: date ?? this.date,
      items: items ?? List.from(this.items),
      notes: notes ?? this.notes,
      filePath: filePath ?? this.filePath,
      taxRate: taxRate ?? this.taxRate,
      documentType: documentType ?? this.documentType,
      orderStatus: orderStatus ?? this.orderStatus,
      promisedDate: promisedDate ?? this.promisedDate,
      fulfilledDate: fulfilledDate ?? this.fulfilledDate,
      sourceDocumentId: sourceDocumentId ?? this.sourceDocumentId,
      linkedDeliveryId: linkedDeliveryId ?? this.linkedDeliveryId,
      linkedInvoiceId: linkedInvoiceId ?? this.linkedInvoiceId,
      customerFormalNameSnapshot:
          customerFormalNameSnapshot ?? this.customerFormalNameSnapshot,
      odooId: odooId ?? this.odooId,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      terminalId: terminalId ?? this.terminalId,
      isDraft: isDraft ?? this.isDraft,
      subject: subject ?? this.subject,
      isLocked: isLocked ?? this.isLocked,
      contactVersionId: contactVersionId ?? this.contactVersionId,
      contactEmailSnapshot: contactEmailSnapshot ?? this.contactEmailSnapshot,
      contactTelSnapshot: contactTelSnapshot ?? this.contactTelSnapshot,
      contactAddressSnapshot:
          contactAddressSnapshot ?? this.contactAddressSnapshot,
      companySnapshot: companySnapshot ?? this.companySnapshot,
      companySealHash: companySealHash ?? this.companySealHash,
      metaJson: metaJson ?? this.metaJson,
      metaHash: metaHash ?? this.metaHash,
      totalDiscountAmount: totalDiscountAmount ?? this.totalDiscountAmount,
      totalDiscountRate: totalDiscountRate ?? this.totalDiscountRate,
      isReceiptIssued: isReceiptIssued ?? this.isReceiptIssued,
      receiptIssuedAt: receiptIssuedAt ?? this.receiptIssuedAt,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      receivedAmount: receivedAmount ?? this.receivedAmount,
      includeTax: includeTax ?? this.includeTax,
      isTaxInclusiveMode: isTaxInclusiveMode ?? this.isTaxInclusiveMode,
      priceAdjustmentType: priceAdjustmentType ?? this.priceAdjustmentType,
      priceAdjustmentUnit: priceAdjustmentUnit ?? this.priceAdjustmentUnit,
      bankAccount: bankAccount ?? this.bankAccount,
      projectId: projectId ?? this.projectId,
      isTestDocument: isTestDocument ?? this.isTestDocument,
      printedAt: printedAt ?? this.printedAt,
      emailSentAt: emailSentAt ?? this.emailSentAt,
      emailSentTo: emailSentTo ?? this.emailSentTo,
      version: version ?? this.version,
      isCurrent: isCurrent ?? this.isCurrent,
      previousHash: previousHash ?? this.previousHash,
    );
  }
}
