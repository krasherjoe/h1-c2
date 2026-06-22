import 'dart:convert';

/// ワークフローステップ
enum WorkflowStep {
  delivery,       // 📦 納品書発行
  cashCollection, // 💰 現金回収
  waitForClosing, // ⏳ 締め日待機
  generateInvoice,// 📄 請求書生成
  sendEmail,      // 📧 メール送信
  complete,       // ✅ 完了
}

extension WorkflowStepX on WorkflowStep {
  String get displayName {
    switch (this) {
      case WorkflowStep.delivery:
        return '納品書発行';
      case WorkflowStep.cashCollection:
        return '現金回収';
      case WorkflowStep.waitForClosing:
        return '締め日待機';
      case WorkflowStep.generateInvoice:
        return '請求書生成';
      case WorkflowStep.sendEmail:
        return 'メール送信';
      case WorkflowStep.complete:
        return '完了';
    }
  }

  String get emoji {
    switch (this) {
      case WorkflowStep.delivery:
        return '📦';
      case WorkflowStep.cashCollection:
        return '💰';
      case WorkflowStep.waitForClosing:
        return '⏳';
      case WorkflowStep.generateInvoice:
        return '📄';
      case WorkflowStep.sendEmail:
        return '📧';
      case WorkflowStep.complete:
        return '✅';
    }
  }
}

/// 請求テンプレートモデル
/// 案件ごとの請求・回収条件を管理
class BillingTemplate {
  final String id;
  final String name;
  final String? description;

  // ワークフロー（おじいちゃん用シンプル設定）
  final List<WorkflowStep> workflowSteps;

  // 締め日設定
  final ClosingDateType closingDateType;
  final int? closingDay; // 締め日（1-31、月末は99）
  final ClosingMonthType closingMonthType; // 毎月、隔月、四半期

  // 支払い条件
  final PaymentTerm paymentTerm;
  final int? paymentDays; // 支払い期限日数（例：月末払い=0、納品後30日=30）

  // 請求書発行タイミング
  final InvoiceTiming invoiceTiming;
  final bool autoGenerateInvoice; // 自動請求書発行ON/OFF

  // メール設定
  final bool autoSendEmail; // 自動メール送信ON/OFF
  final bool attachArReport; // 売掛レポート添付有無
  final String? emailBcc; // BCCアドレス
  final String? emailReplyTo; // 返信先アドレス

  // 請求書内容
  final bool includeDeliveryDetails; // 納品明細を含むか
  final bool groupByProject; // 案件別にグループ化
  final String? invoiceNotes; // 請求書備考

  // メタデータ
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDefault; // デフォルトテンプレート

  const BillingTemplate({
    required this.id,
    required this.name,
    this.description,
    this.workflowSteps = const [WorkflowStep.delivery, WorkflowStep.waitForClosing, WorkflowStep.generateInvoice, WorkflowStep.sendEmail, WorkflowStep.complete],
    this.closingDateType = ClosingDateType.monthly,
    this.closingDay = 99, // デフォルト月末
    this.closingMonthType = ClosingMonthType.everyMonth,
    this.paymentTerm = PaymentTerm.endOfMonth,
    this.paymentDays = 0,
    this.invoiceTiming = InvoiceTiming.onClosingDate,
    this.autoGenerateInvoice = false,
    this.autoSendEmail = false,
    this.attachArReport = false,
    this.emailBcc,
    this.emailReplyTo,
    this.includeDeliveryDetails = true,
    this.groupByProject = true,
    this.invoiceNotes,
    required this.createdAt,
    required this.updatedAt,
    this.isDefault = false,
  });

  /// 締め日を計算
  DateTime calculateClosingDate(DateTime baseDate) {
    int year = baseDate.year;
    int month = baseDate.month;

    // 隔月・四半期の調整
    switch (closingMonthType) {
      case ClosingMonthType.everyMonth:
        break;
      case ClosingMonthType.everyTwoMonths:
        if (month % 2 != 0) month--; // 奇数月は前月に
        break;
      case ClosingMonthType.quarterly:
        month = ((month - 1) ~/ 3) * 3 + 1; // 四半期の最初の月
        break;
    }

    // 締め日
    int day = closingDay ?? 99;
    if (day == 99) {
      // 月末
      return DateTime(year, month + 1, 0);
    } else {
      // 指定日
      final lastDay = DateTime(year, month + 1, 0).day;
      day = day.clamp(1, lastDay);
      return DateTime(year, month, day);
    }
  }

  /// 支払い期限を計算
  DateTime calculatePaymentDueDate(DateTime invoiceDate) {
    switch (paymentTerm) {
      case PaymentTerm.endOfMonth:
        // 当月末
        return DateTime(invoiceDate.year, invoiceDate.month + 1, 0);
      case PaymentTerm.daysAfterInvoice:
        // 請求書発行後N日
        return invoiceDate.add(Duration(days: paymentDays ?? 30));
      case PaymentTerm.daysAfterDelivery:
        // 納品後N日（請求日から計算）
        return invoiceDate.add(Duration(days: paymentDays ?? 30));
      case PaymentTerm.endOfNextMonth:
        // 翌月末
        return DateTime(invoiceDate.year, invoiceDate.month + 2, 0);
    }
  }

  /// 次回締め日を取得
  DateTime getNextClosingDate() {
    final now = DateTime.now();
    var closingDate = calculateClosingDate(now);

    // 今月の締め日が過ぎている場合は翌月
    if (closingDate.isBefore(now)) {
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      closingDate = calculateClosingDate(nextMonth);
    }

    return closingDate;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'workflow_steps': jsonEncode(workflowSteps.map((s) => s.name).toList()),
      'closing_date_type': closingDateType.name,
      'closing_day': closingDay,
      'closing_month_type': closingMonthType.name,
      'payment_term': paymentTerm.name,
      'payment_days': paymentDays,
      'invoice_timing': invoiceTiming.name,
      'auto_generate_invoice': autoGenerateInvoice ? 1 : 0,
      'auto_send_email': autoSendEmail ? 1 : 0,
      'attach_ar_report': attachArReport ? 1 : 0,
      'email_bcc': emailBcc,
      'email_reply_to': emailReplyTo,
      'include_delivery_details': includeDeliveryDetails ? 1 : 0,
      'group_by_project': groupByProject ? 1 : 0,
      'invoice_notes': invoiceNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_default': isDefault ? 1 : 0,
    };
  }

  factory BillingTemplate.fromMap(Map<String, dynamic> map) {
    // workflow_stepsのデシリアライズ
    List<WorkflowStep> workflowSteps = const [
      WorkflowStep.delivery,
      WorkflowStep.waitForClosing,
      WorkflowStep.generateInvoice,
      WorkflowStep.sendEmail,
      WorkflowStep.complete,
    ];
    if (map['workflow_steps'] != null) {
      try {
        final stepsJson = map['workflow_steps'] as String;
        final stepsList = jsonDecode(stepsJson) as List<dynamic>;
        workflowSteps = stepsList.map((s) => WorkflowStep.values.firstWhere(
          (e) => e.name == s,
          orElse: () => WorkflowStep.delivery,
        )).toList();
      } catch (_) {
        // エラー時はデフォルト
      }
    }

    return BillingTemplate(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      workflowSteps: workflowSteps,
      closingDateType: ClosingDateType.values.firstWhere(
        (e) => e.name == map['closing_date_type'],
        orElse: () => ClosingDateType.monthly,
      ),
      closingDay: map['closing_day'] as int?,
      closingMonthType: ClosingMonthType.values.firstWhere(
        (e) => e.name == map['closing_month_type'],
        orElse: () => ClosingMonthType.everyMonth,
      ),
      paymentTerm: PaymentTerm.values.firstWhere(
        (e) => e.name == map['payment_term'],
        orElse: () => PaymentTerm.endOfMonth,
      ),
      paymentDays: map['payment_days'] as int?,
      invoiceTiming: InvoiceTiming.values.firstWhere(
        (e) => e.name == map['invoice_timing'],
        orElse: () => InvoiceTiming.onClosingDate,
      ),
      autoGenerateInvoice: (map['auto_generate_invoice'] as int? ?? 0) == 1,
      autoSendEmail: (map['auto_send_email'] as int? ?? 0) == 1,
      attachArReport: (map['attach_ar_report'] as int? ?? 0) == 1,
      emailBcc: map['email_bcc'] as String?,
      emailReplyTo: map['email_reply_to'] as String?,
      includeDeliveryDetails: (map['include_delivery_details'] as int? ?? 1) == 1,
      groupByProject: (map['group_by_project'] as int? ?? 1) == 1,
      invoiceNotes: map['invoice_notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isDefault: (map['is_default'] as int? ?? 0) == 1,
    );
  }

  BillingTemplate copyWith({
    String? id,
    String? name,
    String? description,
    List<WorkflowStep>? workflowSteps,
    ClosingDateType? closingDateType,
    int? closingDay,
    ClosingMonthType? closingMonthType,
    PaymentTerm? paymentTerm,
    int? paymentDays,
    InvoiceTiming? invoiceTiming,
    bool? autoGenerateInvoice,
    bool? autoSendEmail,
    bool? attachArReport,
    String? emailBcc,
    String? emailReplyTo,
    bool? includeDeliveryDetails,
    bool? groupByProject,
    String? invoiceNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDefault,
  }) {
    return BillingTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      workflowSteps: workflowSteps ?? this.workflowSteps,
      closingDateType: closingDateType ?? this.closingDateType,
      closingDay: closingDay ?? this.closingDay,
      closingMonthType: closingMonthType ?? this.closingMonthType,
      paymentTerm: paymentTerm ?? this.paymentTerm,
      paymentDays: paymentDays ?? this.paymentDays,
      invoiceTiming: invoiceTiming ?? this.invoiceTiming,
      autoGenerateInvoice: autoGenerateInvoice ?? this.autoGenerateInvoice,
      autoSendEmail: autoSendEmail ?? this.autoSendEmail,
      attachArReport: attachArReport ?? this.attachArReport,
      emailBcc: emailBcc ?? this.emailBcc,
      emailReplyTo: emailReplyTo ?? this.emailReplyTo,
      includeDeliveryDetails: includeDeliveryDetails ?? this.includeDeliveryDetails,
      groupByProject: groupByProject ?? this.groupByProject,
      invoiceNotes: invoiceNotes ?? this.invoiceNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

/// 締め日タイプ
enum ClosingDateType {
  monthly, // 毎月
  custom, // カスタム
}

extension ClosingDateTypeX on ClosingDateType {
  String get displayName {
    switch (this) {
      case ClosingDateType.monthly:
        return '毎月';
      case ClosingDateType.custom:
        return 'カスタム';
    }
  }
}

/// 締め月タイプ
enum ClosingMonthType {
  everyMonth, // 毎月
  everyTwoMonths, // 隔月
  quarterly, // 四半期
}

extension ClosingMonthTypeX on ClosingMonthType {
  String get displayName {
    switch (this) {
      case ClosingMonthType.everyMonth:
        return '毎月';
      case ClosingMonthType.everyTwoMonths:
        return '隔月';
      case ClosingMonthType.quarterly:
        return '四半期';
    }
  }
}

/// 支払い条件
enum PaymentTerm {
  endOfMonth, // 月末払い
  daysAfterInvoice, // 請求書発行後N日
  daysAfterDelivery, // 納品後N日
  endOfNextMonth, // 翌月末払い
}

extension PaymentTermX on PaymentTerm {
  String get displayName {
    switch (this) {
      case PaymentTerm.endOfMonth:
        return '月末払い';
      case PaymentTerm.daysAfterInvoice:
        return '請求書発行後';
      case PaymentTerm.daysAfterDelivery:
        return '納品後';
      case PaymentTerm.endOfNextMonth:
        return '翌月末払い';
    }
  }
}

/// 請求書発行タイミング
enum InvoiceTiming {
  onDelivery, // 納品ごと
  onClosingDate, // 締め日一括
  onCompletion, // 案件完了時
}

extension InvoiceTimingX on InvoiceTiming {
  String get displayName {
    switch (this) {
      case InvoiceTiming.onDelivery:
        return '納品ごと';
      case InvoiceTiming.onClosingDate:
        return '締め日一括';
      case InvoiceTiming.onCompletion:
        return '案件完了時';
    }
  }
}
