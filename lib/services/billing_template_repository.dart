import 'package:flutter/foundation.dart' show debugPrint;
import 'package:uuid/uuid.dart';
import '../models/billing_template_model.dart';
import 'database_helper.dart';

class BillingTemplateRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  /// 全テンプレート取得
  Future<List<BillingTemplate>> getAllTemplates() async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'billing_templates',
        orderBy: 'is_default DESC, created_at DESC',
      );

      return maps.map((map) => BillingTemplate.fromMap(map)).toList();
    } catch (e) {
      debugPrint('[BillingTemplateRepo] getAllTemplates error: $e');
      rethrow;
    }
  }

  /// デフォルトテンプレート取得
  Future<BillingTemplate?> getDefaultTemplate() async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'billing_templates',
        where: 'is_default = 1',
        limit: 1,
      );

      if (maps.isEmpty) return null;
      return BillingTemplate.fromMap(maps.first);
    } catch (e) {
      debugPrint('[BillingTemplateRepo] getDefaultTemplate error: $e');
      return null;
    }
  }

  /// IDでテンプレート取得
  Future<BillingTemplate?> getTemplateById(String id) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'billing_templates',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) return null;
      return BillingTemplate.fromMap(maps.first);
    } catch (e) {
      debugPrint('[BillingTemplateRepo] getTemplateById error: $e');
      return null;
    }
  }

  /// テンプレート保存
  Future<void> saveTemplate(BillingTemplate template) async {
    try {
      final db = await _dbHelper.database;

      // デフォルトテンプレートの処理
      if (template.isDefault) {
        await db.update(
          'billing_templates',
          {'is_default': 0},
          where: 'is_default = 1',
        );
      }

      final existing = await db.query(
        'billing_templates',
        where: 'id = ?',
        whereArgs: [template.id],
        limit: 1,
      );

      if (existing.isEmpty) {
        // 新規作成
        await db.insert('billing_templates', template.toMap());
      } else {
        // 更新
        await db.update(
          'billing_templates',
          template.copyWith(updatedAt: DateTime.now()).toMap(),
          where: 'id = ?',
          whereArgs: [template.id],
        );
      }
    } catch (e) {
      debugPrint('[BillingTemplateRepo] saveTemplate error: $e');
      rethrow;
    }
  }

  /// テンプレート削除
  Future<void> deleteTemplate(String id) async {
    try {
      final db = await _dbHelper.database;

      // デフォルトテンプレートは削除不可
      final template = await getTemplateById(id);
      if (template?.isDefault == true) {
        throw Exception('デフォルトテンプレートは削除できません');
      }

      // 使用中の案件があるかチェック
      final projects = await db.query(
        'projects',
        where: 'billing_template_id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (projects.isNotEmpty) {
        throw Exception('このテンプレートを使用中の案件があるため削除できません');
      }

      await db.delete(
        'billing_templates',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('[BillingTemplateRepo] deleteTemplate error: $e');
      rethrow;
    }
  }

  /// デフォルトテンプレート設定
  Future<void> setDefaultTemplate(String id) async {
    try {
      final db = await _dbHelper.database;

      await db.transaction((txn) async {
        // 全てのデフォルトを解除
        await txn.update(
          'billing_templates',
          {'is_default': 0},
        );

        // 指定テンプレートをデフォルトに
        await txn.update(
          'billing_templates',
          {'is_default': 1, 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [id],
        );
      });
    } catch (e) {
      debugPrint('[BillingTemplateRepo] setDefaultTemplate error: $e');
      rethrow;
    }
  }

  /// 新規テンプレート作成（デフォルト設定付き）
  Future<BillingTemplate> createTemplate({
    required String name,
    String? description,
    ClosingDateType closingDateType = ClosingDateType.monthly,
    int? closingDay = 99,
    ClosingMonthType closingMonthType = ClosingMonthType.everyMonth,
    PaymentTerm paymentTerm = PaymentTerm.endOfMonth,
    int? paymentDays = 0,
    InvoiceTiming invoiceTiming = InvoiceTiming.onClosingDate,
    bool autoGenerateInvoice = false,
    bool autoSendEmail = false,
    bool attachArReport = false,
    String? emailBcc,
    String? emailReplyTo,
    bool includeDeliveryDetails = true,
    bool groupByProject = true,
    String? invoiceNotes,
    bool isDefault = false,
  }) async {
    final now = DateTime.now();
    final template = BillingTemplate(
      id: _uuid.v4(),
      name: name,
      description: description,
      closingDateType: closingDateType,
      closingDay: closingDay,
      closingMonthType: closingMonthType,
      paymentTerm: paymentTerm,
      paymentDays: paymentDays,
      invoiceTiming: invoiceTiming,
      autoGenerateInvoice: autoGenerateInvoice,
      autoSendEmail: autoSendEmail,
      attachArReport: attachArReport,
      emailBcc: emailBcc,
      emailReplyTo: emailReplyTo,
      includeDeliveryDetails: includeDeliveryDetails,
      groupByProject: groupByProject,
      invoiceNotes: invoiceNotes,
      createdAt: now,
      updatedAt: now,
      isDefault: isDefault,
    );

    await saveTemplate(template);
    return template;
  }

  /// 初期デフォルトテンプレート作成（初回起動時）
  Future<void> initializeDefaultTemplate() async {
    try {
      final existing = await getDefaultTemplate();
      if (existing != null) return; // 既に存在

      await createTemplate(
        name: 'デフォルト請求テンプレート',
        description: '標準的な請求条件（月末締め、翌月末払い）',
        closingDateType: ClosingDateType.monthly,
        closingDay: 99, // 月末
        closingMonthType: ClosingMonthType.everyMonth,
        paymentTerm: PaymentTerm.endOfNextMonth,
        paymentDays: 0,
        invoiceTiming: InvoiceTiming.onClosingDate,
        autoGenerateInvoice: false,
        autoSendEmail: false,
        attachArReport: false,
        includeDeliveryDetails: true,
        groupByProject: true,
        isDefault: true,
      );
    } catch (e) {
      debugPrint('[BillingTemplateRepo] initializeDefaultTemplate error: $e');
    }
  }
}
