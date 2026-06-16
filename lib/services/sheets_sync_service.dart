import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'google_auth_service.dart';
import 'product_repository.dart';
import '../models/product_model.dart';
import 'database_helper.dart';
import '../plugins/accounting2/services/account_repository.dart';
import '../plugins/accounting2/models/account.dart';
import '../plugins/accounting2/models/journal_entry.dart';
import '../plugins/documents/models/document_model.dart';

const _kGeminiAnalysisPrompt = '''
# 販売アシスト1号core 売上分析

あなたは売上分析アシスタントです。各シートのデータを分析し、以下の形式で出力してください。

## 分析対象シート
- 「📊 月次売上」: 月別の売上推移（種別ごと）
- 「📈 商品別売上」: 商品ごとの販売数量・金額
- 「📉 顧客別売上」: 顧客ごとの取引回数・金額
- 「📋 売掛金エイジング」: 未回収請求書の状況

## 出力形式
1. **エグゼクティブサマリー**: 3行程度で全体像
2. **注目すべき傾向**: 箇条書き（3〜5項目）
3. **アクション推奨事項**: 箇条書き（3〜5項目）

## 出力先
このシート（「🤖 Gemini分析依頼」）の2行目以降に結果を書き出してください。
''';

class SheetsSyncService {
  static final SheetsSyncService instance = SheetsSyncService._();
  SheetsSyncService._();

  Future<sheets.SheetsApi?> _getApi() async {
    final client = await GoogleAuthService.instance.getAuthenticatedClient();
    if (client == null) return null;
    return sheets.SheetsApi(client);
  }

  Future<String?> ensureSpreadsheet({String title = '販売アシスト１号core 連携データ'}) async {
    final api = await _getApi();
    if (api == null) return null;
    try {
      final ss = await api.spreadsheets.create(sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(title: title),
        sheets: [
          _sheet('商品取込', ['メーカー', '商品名', 'バーコード', '単価']),
          _sheet('試算表', ['科目コード', '科目名', '借方合計', '貸方合計']),
        ],
      ));
      return ss.spreadsheetUrl;
    } catch (e) {
      debugPrint('[Sheets] create failed: $e');
      return null;
    }
  }

  sheets.Sheet _sheet(String title, List<String> headers) {
    return sheets.Sheet(
      properties: sheets.SheetProperties(title: title),
      data: [sheets.GridData(rowData: [
        sheets.RowData(values: headers.map((h) => sheets.CellData(userEnteredValue: sheets.ExtendedValue(stringValue: h))).toList())
      ])],
    );
  }

  Future<bool> openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> exportProducts(String spreadsheetId) async {
    final api = await _getApi();
    if (api == null) return false;
    try {
      final repo = ProductRepository();
      final products = await repo.getAllProducts();
      final rows = [
        ['メーカー', '商品名', 'バーコード', '単価'],
        for (final p in products)
          [p.manufacturer ?? '', p.name, p.barcode ?? '', p.defaultUnitPrice.toString()],
      ];
      await api.spreadsheets.values.update(
        sheets.ValueRange(values: rows),
        spreadsheetId,
        '商品取込!A1',
        valueInputOption: 'USER_ENTERED',
      );
      return true;
    } catch (e) {
      debugPrint('[Sheets] exportProducts error: $e');
      return false;
    }
  }

  Future<int> importProducts(String spreadsheetId) async {
    final api = await _getApi();
    if (api == null) return 0;
    try {
      final result = await api.spreadsheets.values.get(spreadsheetId, '商品取込!A:D');
      if (result.values == null || result.values!.length <= 1) return 0;
      final repo = ProductRepository();
      int count = 0;
      for (int i = 1; i < result.values!.length; i++) {
        final row = result.values![i];
        final manufacturer = (row.length > 0 ? row[0]?.toString() ?? '' : '').trim();
        final name = (row.length > 1 ? row[1]?.toString() ?? '' : '').trim();
        final barcode = (row.length > 2 ? row[2]?.toString() ?? '' : '').trim();
        final price = int.tryParse((row.length > 3 ? row[3]?.toString() ?? '' : '').trim()) ?? 0;
        if (name.isEmpty) continue;
        try {
          await repo.saveProduct(Product(
            id: const Uuid().v4(),
            name: name,
            manufacturer: manufacturer.isNotEmpty ? manufacturer : null,
            barcode: barcode.isNotEmpty ? barcode : null,
            defaultUnitPrice: price,
          ));
          count++;
        } catch (_) {}
      }
      return count;
    } catch (e) {
      debugPrint('[Sheets] importProducts error: $e');
      return 0;
    }
  }

  Future<bool> exportTrialBalance(String spreadsheetId) async {
    final api = await _getApi();
    if (api == null) return false;
    try {
      final accRepo = AccountRepository();
      final accounts = await accRepo.fetchAll();
      final db = await DatabaseHelper().database;
      final entries = await db.query('journal_entries');
      final journalEntries = entries.map(JournalEntry.fromMap).toList();
      final rows = <List<Object?>>[
        ['科目コード', '科目名', '借方合計', '貸方合計'],
      ];
      for (final a in accounts) {
        if (a.id == null) continue;
        final d = journalEntries.where((e) => e.debitAccountId == a.id).fold<int>(0, (s, e) => s + e.amount);
        final c = journalEntries.where((e) => e.creditAccountId == a.id).fold<int>(0, (s, e) => s + e.amount);
        if (d != 0 || c != 0) {
          rows.add([a.code, a.name, d > 0 ? '¥$d' : '', c > 0 ? '¥$c' : '']);
        }
      }
      await api.spreadsheets.values.update(
        sheets.ValueRange(values: rows),
        spreadsheetId,
        '試算表!A1',
        valueInputOption: 'USER_ENTERED',
      );
      return true;
    } catch (e) {
      debugPrint('[Sheets] exportTrialBalance error: $e');
      return false;
    }
  }

  Future<String?> ensureAnalysisSpreadsheet() async {
    final api = await _getApi();
    if (api == null) return null;
    try {
      final ss = await api.spreadsheets.create(sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(title: '販売アシスト１号core 売上分析'),
        sheets: [
          _sheet('📊 月次売上', ['年月', '伝票種別', '件数', '合計金額']),
          _sheet('📈 商品別売上', ['商品名', '販売数量', '販売金額', '平均単価']),
          _sheet('📉 顧客別売上', ['顧客名', '取引回数', '合計金額', '平均金額']),
          _sheet('📋 売掛金エイジング', ['顧客名', '請求番号', '請求金額', '未回収額', '経過日数', 'ステータス']),
          _sheet('🤖 Gemini分析依頼', ['分析依頼内容']),
        ],
      ));
      await exportAnalysisData(ss.spreadsheetId!);
      return ss.spreadsheetUrl;
    } catch (e) {
      debugPrint('[Sheets] create analysis failed: $e');
      return null;
    }
  }

  Future<void> exportAnalysisData(String ssId) async {
    final api = await _getApi();
    if (api == null) return;
    try {
      final db = await DatabaseHelper().database;
      final docs = await db.rawQuery(
        "SELECT * FROM documents WHERE status = 'confirmed' ORDER BY date");
      final items = await db.rawQuery(
        'SELECT di.*, d.date, d.customer_name FROM document_items di '
        'JOIN documents d ON d.id = di.document_id WHERE d.status = ? ORDER BY d.date',
        ['confirmed']);

      // 月次売上
      final monthly = <String, int>{};
      final monthlyCount = <String, int>{};
      for (final d in docs) {
        final m = (d['date'] as String?)?.substring(0, 7) ?? '';
        final t = d['total'] as int? ?? 0;
        monthly[m] = (monthly[m] ?? 0) + t;
        monthlyCount[m] = (monthlyCount[m] ?? 0) + 1;
      }
      final monthlyRows = <List<Object?>>[['年月', '伝票種別', '件数', '合計金額']];
      final sortedMonths = monthly.keys.toList()..sort();
      for (final m in sortedMonths) {
        monthlyRows.add([m, '全種別', monthlyCount[m] ?? 0, monthly[m] ?? 0]);
      }
      await api.spreadsheets.values.update(
        sheets.ValueRange(values: monthlyRows), ssId, '📊 月次売上!A1',
        valueInputOption: 'USER_ENTERED');

      // 商品別売上
      final prodSales = <String, Map<String, num>>{};
      for (final i in items) {
        final name = i['product_name'] as String? ?? '不明';
        final data = prodSales.putIfAbsent(name, () => <String, num>{'qty': 0, 'amt': 0});
        data['qty'] = (data['qty'] as num) + ((i['quantity'] as num?)?.toDouble() ?? 0);
        data['amt'] = (data['amt'] as num) + ((i['unit_price'] as int? ?? 0) * ((i['quantity'] as num?)?.toDouble() ?? 0));
      }
      final prodRows = <List<Object?>>[['商品名', '販売数量', '販売金額', '平均単価']];
      final sortedProd = prodSales.entries.toList()..sort((a, b) => (b.value['amt'] as num).compareTo(a.value['amt'] as num));
      for (final e in sortedProd) {
        final avg = (e.value['qty'] as num) > 0 ? ((e.value['amt'] as num) / (e.value['qty'] as num)).round() : 0;
        prodRows.add([e.key, e.value['qty'], e.value['amt'], avg]);
      }
      await api.spreadsheets.values.update(
        sheets.ValueRange(values: prodRows), ssId, '📈 商品別売上!A1',
        valueInputOption: 'USER_ENTERED');

      // 顧客別売上
      final custSales = <String, Map<String, num>>{};
      for (final d in docs) {
        final name = d['customer_name'] as String? ?? '不明';
        final data = custSales.putIfAbsent(name, () => <String, num>{'cnt': 0, 'amt': 0});
        data['cnt'] = (data['cnt'] as num) + 1;
        data['amt'] = (data['amt'] as num) + (d['total'] as int? ?? 0);
      }
      final custRows = <List<Object?>>[['顧客名', '取引回数', '合計金額', '平均金額']];
      final sortedCust = custSales.entries.toList()..sort((a, b) => (b.value['amt'] as num).compareTo(a.value['amt'] as num));
      for (final e in sortedCust) {
        final avg = (e.value['cnt'] as num) > 0 ? ((e.value['amt'] as num) / (e.value['cnt'] as num)).round() : 0;
        custRows.add([e.key, e.value['cnt'], e.value['amt'], avg]);
      }
      await api.spreadsheets.values.update(
        sheets.ValueRange(values: custRows), ssId, '📉 顧客別売上!A1',
        valueInputOption: 'USER_ENTERED');

      // 売掛金エイジング
      final agingRows = <List<Object?>>[['顧客名', '請求番号', '請求金額', '未回収額', '経過日数', 'ステータス']];
      final now = DateTime.now();
      for (final d in docs) {
        final days = now.difference(DateTime.tryParse(d['date'] as String? ?? '') ?? now).inDays;
        agingRows.add([
          d['customer_name'] ?? '', d['document_number'] ?? '', d['total'] ?? 0, d['total'] ?? 0,
          days, days > 60 ? '要注意' : days > 30 ? '注意' : '正常',
        ]);
      }
      await api.spreadsheets.values.update(
        sheets.ValueRange(values: agingRows), ssId, '📋 売掛金エイジング!A1',
        valueInputOption: 'USER_ENTERED');

      // Geminiプロンプト
      await api.spreadsheets.values.update(
        sheets.ValueRange(values: [[_kGeminiAnalysisPrompt]]), ssId, '🤖 Gemini分析依頼!A1',
        valueInputOption: 'USER_ENTERED');

    } catch (e) {
      debugPrint('[Sheets] exportAnalysisData error: $e');
    }
  }
}
