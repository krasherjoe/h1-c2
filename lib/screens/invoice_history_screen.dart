import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice_models.dart';
import '../models/sales_model.dart';
import '../services/invoice_repository.dart';
import '../services/sales_repository.dart';
import '../services/customer_repository.dart';
import 'invoice_detail_page.dart';
import 'product_master/product_master_screen.dart';
import 'customer_master/customer_master_screen.dart';
import 'invoice_input_screen.dart';
import 'invoice_preview_page.dart';
import '../services/sys_logger.dart';
import '../services/app_settings_repository.dart';
import '../services/database_helper.dart';
import '../widgets/swipe_to_unlock.dart';
// InvoiceFlowScreen import removed; using inline type picker
import 'invoice_history/invoice_history_list.dart';

class InvoiceHistoryScreen extends StatefulWidget {
  final bool initialUnlocked;
  final DocumentType? initialDocType;
  final DateTime? initialDate;
  final String? initialPaymentStatus;
  final bool isPickerMode;
  const InvoiceHistoryScreen({
    super.key,
    this.initialUnlocked = false,
    this.initialDocType,
    this.initialDate,
    this.initialPaymentStatus,
    this.isPickerMode = false,
  });

  @override
  State<InvoiceHistoryScreen> createState() => _InvoiceHistoryScreenState();
}

class _InvoiceHistoryScreenState extends State<InvoiceHistoryScreen> {
  final InvoiceRepository _invoiceRepo = InvoiceRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AppSettingsRepository _settingsRepo = AppSettingsRepository();
  late final StreamSubscription<String> _homeModeSub;
  List<Invoice> _invoices = [];
  List<Invoice> _filteredInvoices = [];
  bool _isLoading = true;
  bool _isUnlocked = false; // 保護解除フラグ
  String _searchQuery = "";
  String _sortBy = "date"; // "date", "amount", "customer"
  DateTime? _startDate;
  DateTime? _endDate;
  DocumentType? _filterDocType;
  String? _filterPaymentStatus;
  bool _filterDraftOnly = false;
  bool _showSales = false;
  List<Map<String, dynamic>> _salesData = [];
  String _appVersion = "1.0.0";
  bool _useDashboardHome = false;
  bool _showInvoiceNumber = true;
  Set<String> _selectedPickerIds = {}; // ピッカーモード選択ID: "source:id"

  @override
  void initState() {
    super.initState();
    _isUnlocked = widget.initialUnlocked || widget.isPickerMode;
    _filterDocType = widget.initialDocType;
    _filterPaymentStatus = widget.initialPaymentStatus;
    if (widget.initialDate != null) {
      _startDate = widget.initialDate;
      _endDate = widget.initialDate!.add(const Duration(days: 1));
    }
    _loadData();
    _loadVersion();
    _loadHomeMode();
    _loadInvoiceNumberSetting();
    _homeModeSub = _settingsRepo.watchHomeMode().listen((mode) {
      if (!mounted) return;
      setState(() {
        _useDashboardHome = mode == 'dashboard';
        if (_useDashboardHome && widget.initialUnlocked) {
          _isUnlocked = true;
        }
      });
    });
  }

  @override
  void dispose() {
    _homeModeSub.cancel();
    super.dispose();
  }

  Future<void> _loadInvoiceNumberSetting() async {
    final v = await _settingsRepo.getShowHistoryInvoiceNumber();
    if (!mounted) return;
    setState(() => _showInvoiceNumber = v);
  }

  Future<void> _loadHomeMode() async {
    final mode = await _settingsRepo.getHomeMode();
    if (!mounted) return;
    setState(() {
      _useDashboardHome = mode == 'dashboard';
      if (_useDashboardHome && widget.initialUnlocked) {
        _isUnlocked = true;
      }
    });
  }

  Future<void> _showInvoiceActions(Invoice invoice) async {
    if (!_requireUnlock()) return;
    if (invoice.isLocked) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("ロック中の伝票は操作できません")));
      return;
    }
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text("PDFプレビュー"),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InvoicePdfPreviewPage(
                      invoice: invoice,
                      isUnlocked: _isUnlocked,
                      isLocked: invoice.isLocked,
                      allowFormalIssue: !invoice.isLocked,
                      onFormalIssue: () async {
                        final repo = InvoiceRepository();
                        final promoted = invoice.copyWith(isDraft: false);
                        await repo.updateInvoice(promoted);
                        _loadData();
                      },
                      showShare: true,
                      showEmail: true,
                      showPrint: true,
                    ),
                  ),
                );
                _loadData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text("編集"),
              onTap: _isUnlocked
                  ? () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InvoiceInputForm(
                            existingInvoice: invoice,
                            onInvoiceGenerated: (inv, path) {},
                          ),
                        ),
                      );
                      _loadData();
                    }
                  : null,
            ),
            ListTile(
              leading: Icon(
                Icons.delete,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                "削除",
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: _isUnlocked
                  ? () async {
                      Navigator.pop(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("伝票の削除"),
                          content: Text(
                            "「${invoice.customerNameForDisplay}」の伝票(${invoice.invoiceNumber})を削除しますか？\nこの操作は取り消せません。",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text("キャンセル"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(
                                "削除",
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _invoiceRepo.deleteInvoice(invoice.id);
                        _loadData();
                      }
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  bool _requireUnlock() {
    if (_isUnlocked) return true;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("スライドでロック解除してください")));
    return false;
  }

  Future<void> _loadVersion() async {
    // コア版ではパッケージ情報取得を無効化
    setState(() {
      _appVersion = "1.0.0";
    });
  }

  Set<String> _cancelledInvoiceIds = {};
  Map<String, String> _redInvoiceSourceMap = {};

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final customers = await _customerRepo.getAllCustomers();
    final invoices = await _invoiceRepo.getAllInvoices(customers);
    // 赤伝のsourceDocumentIdを収集
    final cancelledIds = <String>{};
    final sourceMap = <String, String>{};
    for (final inv in invoices) {
      if (inv.isRedInvoice && inv.sourceDocumentId != null) {
        cancelledIds.add(inv.sourceDocumentId!);
        sourceMap[inv.sourceDocumentId!] = inv.id;
      }
    }
    // 売上データ読み込み
    List<Map<String, dynamic>> salesData = [];
    try {
      final db = await _dbHelper.database;
      final exists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='sales'",
      );
      if (exists.isNotEmpty) {
        final rows = await db.query('sales', orderBy: 'date DESC');
        // 顧客名マップを作成
        final custRows = await db.query(
          'customers',
          columns: ['id', 'display_name', 'formal_name'],
        );
        final custMap = {
          for (final r in custRows)
            r['id'] as String? ?? '': r['display_name'] as String? ?? '',
        };
        // 各売上の商品名（先頭1件）を取得
        final saleIds = rows
            .map((r) => r['id'] as String? ?? '')
            .where((id) => id.isNotEmpty)
            .toList();
        final placeholders = saleIds.map((_) => '?').join(',');
        final itemRows = saleIds.isNotEmpty
            ? await db.rawQuery(
                'SELECT sales_id, product_name FROM sales_items WHERE sales_id IN ($placeholders) ORDER BY rowid',
                saleIds,
              )
            : <Map<String, dynamic>>[];
        final itemMap = <String, String>{};
        for (final r in itemRows) {
          final sid = r['sales_id'] as String? ?? '';
          if (sid.isNotEmpty && !itemMap.containsKey(sid)) {
            itemMap[sid] = r['product_name'] as String? ?? '';
          }
        }
        salesData = rows
            .map(
              (r) => {
                ...Map<String, dynamic>.from(r),
                '_customer_name': (() {
                  final cid = r['customer_id'] as String?;
                  return cid != null ? (custMap[cid] ?? '不明') : '不明';
                })(),
                '_first_product': itemMap[r['id'] as String? ?? ''] ?? '',
              },
            )
            .toList();
      }
    } catch (e) {
      SysLogger.instance.logError('IH', e);
    }
    setState(() {
      _invoices = invoices;
      _cancelledInvoiceIds = cancelledIds;
      _redInvoiceSourceMap = sourceMap;
      _salesData = salesData;
      _applyFilterAndSort();
      _isLoading = false;
    });
  }

  void _applyFilterAndSort() {
    setState(() {
      _filteredInvoices = _invoices.where((inv) {
        final query = _searchQuery.toLowerCase();
        final matchesQuery =
            inv.customerNameForDisplay.toLowerCase().contains(query) ||
            inv.invoiceNumber.toLowerCase().contains(query) ||
            (inv.notes?.toLowerCase().contains(query) ?? false);

        bool matchesDate = true;
        if (_startDate != null && inv.date.isBefore(_startDate!))
          matchesDate = false;
        if (_endDate != null &&
            inv.date.isAfter(_endDate!.add(const Duration(days: 1))))
          matchesDate = false;

        if (_filterDocType != null && inv.documentType != _filterDocType)
          return false;
        final ps = _filterPaymentStatus;
        if (ps != null) {
          if (ps.startsWith('!')) {
            if (inv.paymentStatus.name == ps.substring(1)) return false;
          } else {
            if (inv.paymentStatus.name != ps) return false;
          }
        }
        if (_filterDraftOnly && !inv.isDraft) return false;

        return matchesQuery && matchesDate;
      }).toList();

      if (_sortBy == "date") {
        _filteredInvoices.sort((a, b) => b.date.compareTo(a.date));
      } else if (_sortBy == "amount") {
        _filteredInvoices.sort(
          (a, b) => b.totalAmount.compareTo(a.totalAmount),
        );
      } else if (_sortBy == "customer") {
        _filteredInvoices.sort(
          (a, b) =>
              a.customerNameForDisplay.compareTo(b.customerNameForDisplay),
        );
      }
    });
  }

  void _confirmPickerSelection() {
    final result = _selectedPickerIds.map((key) {
      final parts = key.split(':');
      return <String, dynamic>{'_source': parts[0], 'id': parts[1]};
    }).toList();
    Navigator.pop(context, result);
  }

  void _toggleUnlock() {
    setState(() {
      _isUnlocked = !_isUnlocked;
    });
    if (!_isUnlocked) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("編集プロテクトを有効にしました")));
    }
  }

  void _toggleFilterDocType(DocumentType? type) {
    setState(() {
      _filterDocType = _filterDocType == type ? null : type;
    });
    _applyFilterAndSort();
  }

  Widget _buildSalesList(NumberFormat fmt, DateFormat df) {
    final cs = Theme.of(context).colorScheme;
    if (_salesData.isEmpty) {
      return Center(
        child: Text('売上伝票はありません', style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _salesData.length,
      itemBuilder: (_, i) {
        final s = _salesData[i];
        final id = s['id'] as String? ?? '';
        final docNum = s['document_number'] as String? ?? id.substring(0, 8);
        final dateStr = s['date'] as String? ?? '';
        final date = DateTime.tryParse(dateStr) ?? DateTime.now();
        final customerId = s['customer_id'] as String?;
        final total = (s['total'] as num?)?.toInt() ?? 0;
        final status = s['status'] as String? ?? 'draft';
        final isDraft = status == 'draft';
        final isSelected =
            widget.isPickerMode && _selectedPickerIds.contains('sales:$id');
        return Card(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: InkWell(
            onTap: widget.isPickerMode
                ? () {
                    final key = 'sales:$id';
                    setState(() {
                      if (_selectedPickerIds.contains(key)) {
                        _selectedPickerIds.remove(key);
                      } else {
                        _selectedPickerIds.add(key);
                      }
                    });
                  }
                : () async {
                    // SalesInputScreen はコア版では利用不可
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('売上入力機能はコア版では利用できません')),
                    );
                    _loadData();
                  },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.point_of_sale, color: cs.tertiary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s['_customer_name'] as String? ?? '不明',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            Icon(
                              Icons.description,
                              size: 12,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                docNum,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              df.format(date),
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        if ((s['_first_product'] as String? ?? '')
                            .isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              Icon(
                                Icons.shopping_bag,
                                size: 12,
                                color: cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  s['_first_product'] as String? ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '¥${fmt.format(total)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: cs.onSurface,
                        ),
                      ),
                      if (isDraft)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: cs.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '下書き',
                            style: TextStyle(
                              fontSize: 9,
                              color: cs.onSecondaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChips() {
    final cs = Theme.of(context).colorScheme;
    final chips = <Widget>[];
    if (_showSales) {
      chips.add(
        _chip(
          '売上伝票',
          cs,
          onRemove: () {
            setState(() => _showSales = false);
            _applyFilterAndSort();
          },
        ),
      );
    } else {
      if (_filterDocType != null) {
        final label = switch (_filterDocType!) {
          DocumentType.estimation => '見積',
          DocumentType.order => '受注',
          DocumentType.delivery => '納品書',
          DocumentType.invoice => '請求書',
          DocumentType.receipt => '領収書',
        };
        chips.add(_chip(label, cs, onRemove: () => _toggleFilterDocType(null)));
      }
      if (_filterPaymentStatus != null) {
        final label = switch (_filterPaymentStatus!) {
          '!paid' => '未回収',
          'unpaid' => '未払い',
          'partial' => '一部入金',
          'overdue' => '延滞',
          'paid' => '完了',
          _ => _filterPaymentStatus!,
        };
        chips.add(
          _chip(
            label,
            cs,
            onRemove: () {
              setState(() => _filterPaymentStatus = null);
              _applyFilterAndSort();
            },
          ),
        );
      }
      if (_filterDraftOnly) {
        chips.add(
          _chip(
            '下書き',
            cs,
            onRemove: () {
              setState(() => _filterDraftOnly = false);
              _applyFilterAndSort();
            },
          ),
        );
      }
    }
    if (_startDate != null) {
      final fmt = DateFormat('MM/dd');
      chips.add(
        _chip(
          '${fmt.format(_startDate!)}~',
          cs,
          onRemove: () {
            setState(() {
              _startDate = null;
              _endDate = null;
            });
            _applyFilterAndSort();
          },
        ),
      );
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(spacing: 6, runSpacing: 4, children: chips),
    );
  }

  Widget _chip(String label, ColorScheme cs, {VoidCallback? onRemove}) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: cs.onPrimaryContainer),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close, size: 14, color: cs.onPrimaryContainer),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amountFormatter = NumberFormat("#,###");
    final dateFormatter = DateFormat('yyyy/MM/dd');
    return Scaffold(
      resizeToAvoidBottomInset: false,
      drawer: (widget.isPickerMode || _useDashboardHome || !_isUnlocked)
          ? null
          : Drawer(
              child: SafeArea(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    DrawerHeader(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "販売アシスト1号",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "v$_appVersion",
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimary.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "クイックメニュー",
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimary.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _drawerHeading("アクション"),
                    ListTile(
                      leading: Icon(
                        Icons.add_circle_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: const Text("新しい伝票を作成"),
                      subtitle: const Text("ドキュメント種別を選択"),
                      onTap: () {
                        Navigator.pop(context);
                        _showCreateTypeMenu();
                      },
                    ),
                    _drawerHeading("マスター"),
                    ListTile(
                      leading: Icon(
                        Icons.receipt_long,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      title: const Text("伝票マスター"),
                      onTap: () => Navigator.pop(context),
                    ),
                    // ListTile(
                    //   leading: Icon(
                    //     Icons.folder_special,
                    //     color: Theme.of(context).colorScheme.secondary,
                    //   ),
                    //   title: const Text("案件管理"),
                    //   onTap: () {
                    //     Navigator.pop(context);
                    //     // ProjectListScreen はコア版では利用不可
                    //   },
                    // ),
                    ListTile(
                      leading: Icon(
                        Icons.people,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      title: const Text("顧客マスター"),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CustomerMasterScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.inventory_2,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      title: const Text("商品マスター"),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProductMasterScreen(),
                          ),
                        );
                      },
                    ),
                    _drawerHeading("システム"),
                    // ListTile(
                    //   leading: Icon(
                    //     Icons.settings,
                    //     color: Theme.of(context).colorScheme.onSurface,
                    //   ),
                    //   title: const Text("設定"),
                    //   onTap: () async {
                    //     Navigator.pop(context);
                    //     // SettingsScreen はコア版では利用不可
                    //     if (mounted) _loadInvoiceNumberSetting();
                    //   },
                    // ),
                    // ListTile(
                    //   leading: Icon(
                    //     Icons.admin_panel_settings,
                    //     color: Theme.of(context).colorScheme.onSurface,
                    //   ),
                    //   title: const Text("管理メニュー"),
                    //   onTap: () {
                    //     Navigator.pop(context);
                    //     // ManagementScreen はコア版では利用不可
                    //   },
                    // ),
                  ],
                ),
              ),
            ),
      backgroundColor: _isUnlocked
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : Theme.of(context).colorScheme.surfaceVariant,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: _useDashboardHome
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  // ScreenA1Dashboard はコア版では利用不可
                  Navigator.pop(context);
                },
              )
            : (_isUnlocked
                  ? Builder(
                      builder: (ctx) => IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                      ),
                    )
                  : null),
        title: GestureDetector(
          onLongPress: () async {
            // CompanyInfoScreen はコア版では利用不可
            _loadData();
          },
          child: Text(
            widget.isPickerMode ? "取込:伝票を選択" : "IH:履歴リスト v$_appVersion",
          ),
        ),
        actions: widget.isPickerMode
            ? [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  tooltip: "キャンセル",
                ),
                if (_selectedPickerIds.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.file_download),
                    tooltip: "選択した伝票を取り込む",
                    onPressed: _confirmPickerSelection,
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadData,
                ),
              ]
            : [
                if (_isUnlocked)
                  IconButton(
                    icon: const Icon(Icons.lock_open),
                    onPressed: _toggleUnlock,
                    tooltip: "再度プロテクトする",
                  ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () async {
                    final cs = Theme.of(context).colorScheme;
                    final val = await showMenu<String>(
                      context: context,
                      position: const RelativeRect.fromLTRB(100, 80, 0, 0),
                      items: _showSales
                          ? [
                              PopupMenuItem(
                                value: "all",
                                child: Text(
                                  "請求書一覧に戻る",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: "create_sales",
                                child: Text(
                                  "新規売上伝票",
                                  style: TextStyle(color: cs.onSurface),
                                ),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: "filter_draft",
                                child: Text(
                                  "下書きのみ",
                                  style: TextStyle(
                                    fontWeight: _filterDraftOnly
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: "date",
                                child: Text(
                                  "日付順",
                                  style: TextStyle(
                                    fontWeight: _sortBy == "date"
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: "amount",
                                child: Text(
                                  "金額順",
                                  style: TextStyle(
                                    fontWeight: _sortBy == "amount"
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: "customer",
                                child: Text(
                                  "顧客名順",
                                  style: TextStyle(
                                    fontWeight: _sortBy == "customer"
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                            ]
                          : [
                              PopupMenuItem(
                                value: "all",
                                child: Text(
                                  "すべて表示",
                                  style: TextStyle(
                                    fontWeight:
                                        _filterDocType == null &&
                                            !_filterDraftOnly
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: "filter_receipt",
                                child: Text(
                                  "領収書のみ",
                                  style: TextStyle(
                                    fontWeight:
                                        _filterDocType == DocumentType.receipt
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: "filter_sales",
                                child: Text(
                                  "売上伝票",
                                  style: TextStyle(
                                    fontWeight: _showSales
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: "ps_unpaid",
                                child: Text(
                                  "未払いのみ",
                                  style: TextStyle(
                                    fontWeight: _filterPaymentStatus == 'unpaid'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: "ps_partial",
                                child: Text(
                                  "一部入金のみ",
                                  style: TextStyle(
                                    fontWeight:
                                        _filterPaymentStatus == 'partial'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: "ps_overdue",
                                child: Text(
                                  "延滞のみ",
                                  style: TextStyle(
                                    fontWeight:
                                        _filterPaymentStatus == 'overdue'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: "ps_paid",
                                child: Text(
                                  "完了のみ",
                                  style: TextStyle(
                                    fontWeight: _filterPaymentStatus == 'paid'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: "ps_not_paid",
                                child: Text(
                                  "未回収（未払+一部+延滞）",
                                  style: TextStyle(
                                    fontWeight: _filterPaymentStatus == '!paid'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: "filter_draft",
                                child: Text(
                                  "下書きのみ",
                                  style: TextStyle(
                                    fontWeight: _filterDraftOnly
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: "date",
                                child: Text(
                                  "日付順",
                                  style: TextStyle(
                                    fontWeight: _sortBy == "date"
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: "amount",
                                child: Text(
                                  "金額順",
                                  style: TextStyle(
                                    fontWeight: _sortBy == "amount"
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: "customer",
                                child: Text(
                                  "顧客名順",
                                  style: TextStyle(
                                    fontWeight: _sortBy == "customer"
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: "project_list",
                                child: Text(
                                  "案件管理",
                                  style: TextStyle(color: cs.onSurface),
                                ),
                              ),
                            ],
                    );
                    if (val == null) return;
                    if (val == "project_list") {
                      if (!context.mounted) return;
                      // ProjectListScreen はコア版では利用不可
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('案件管理機能はコア版では利用できません')),
                      );
                      return;
                    }
                    if (val == "create_sales") {
                      if (!context.mounted) return;
                      // SalesInputScreen はコア版では利用不可
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('売上入力機能はコア版では利用できません')),
                      );
                      _loadData();
                      return;
                    }
                    if (val == "all" ||
                        val.startsWith("filter_") ||
                        val.startsWith("ps_")) {
                      switch (val) {
                        case "filter_estimation":
                          setState(
                            () => _filterDocType = DocumentType.estimation,
                          );
                        case "filter_order":
                          setState(() => _filterDocType = DocumentType.order);
                        case "filter_delivery":
                          setState(
                            () => _filterDocType = DocumentType.delivery,
                          );
                        case "filter_invoice":
                          setState(() => _filterDocType = DocumentType.invoice);
                        case "filter_receipt":
                          setState(() => _filterDocType = DocumentType.receipt);
                        case "filter_sales":
                          setState(() {
                            _showSales = !_showSales;
                            _filterDocType = null;
                            _filterDraftOnly = false;
                            _filterPaymentStatus = null;
                          });
                        case "ps_unpaid":
                          setState(
                            () => _filterPaymentStatus =
                                _filterPaymentStatus == 'unpaid'
                                ? null
                                : 'unpaid',
                          );
                        case "ps_partial":
                          setState(
                            () => _filterPaymentStatus =
                                _filterPaymentStatus == 'partial'
                                ? null
                                : 'partial',
                          );
                        case "ps_overdue":
                          setState(
                            () => _filterPaymentStatus =
                                _filterPaymentStatus == 'overdue'
                                ? null
                                : 'overdue',
                          );
                        case "ps_paid":
                          setState(
                            () => _filterPaymentStatus =
                                _filterPaymentStatus == 'paid' ? null : 'paid',
                          );
                        case "ps_not_paid":
                          setState(
                            () => _filterPaymentStatus =
                                _filterPaymentStatus == '!paid'
                                ? null
                                : '!paid',
                          );
                        case "filter_draft":
                          setState(() => _filterDraftOnly = !_filterDraftOnly);
                        case "all":
                          setState(() {
                            _filterDocType = null;
                            _filterDraftOnly = false;
                            _filterPaymentStatus = null;
                            _showSales = false;
                          });
                      }
                      _applyFilterAndSort();
                      return;
                    }
                    setState(() => _sortBy = val);
                    _applyFilterAndSort();
                  },
                  tooltip: "メニュー",
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadData,
                ),
              ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Builder(
            builder: (context) {
              final cs = Theme.of(context).colorScheme;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: cs.shadow.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    style: TextStyle(color: cs.onSurface),
                    decoration: InputDecoration(
                      hintText: "検索 (顧客名、伝票番号...)",
                      hintStyle: TextStyle(color: cs.onSurfaceVariant),
                      prefixIcon: Icon(
                        Icons.search,
                        color: cs.onSurfaceVariant,
                      ),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (val) {
                      _searchQuery = val;
                      _applyFilterAndSort();
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildFilterChips(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _showSales
                      ? _buildSalesList(amountFormatter, dateFormatter)
                      : InvoiceHistoryList(
                          invoices: _filteredInvoices,
                          isUnlocked: _isUnlocked,
                          amountFormatter: amountFormatter,
                          dateFormatter: dateFormatter,
                          showInvoiceNumber: _showInvoiceNumber,
                          cancelledInvoiceIds: _cancelledInvoiceIds,
                          redInvoiceSourceMap: _redInvoiceSourceMap,
                          isPickerMode: widget.isPickerMode,
                          selectedIds: _selectedPickerIds,
                          onTap: (invoice) {
                            if (widget.isPickerMode) {
                              final key = 'invoice:${invoice.id}';
                              setState(() {
                                if (_selectedPickerIds.contains(key)) {
                                  _selectedPickerIds.remove(key);
                                } else {
                                  _selectedPickerIds.add(key);
                                }
                              });
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => InvoiceInputForm(
                                    existingInvoice: invoice,
                                    onInvoiceGenerated: (inv, path) {},
                                  ),
                                ),
                              ).then((_) {
                                if (mounted) _loadData();
                              });
                            }
                          },
                          onLongPress: widget.isPickerMode
                              ? (_) {}
                              : (invoice) => _isUnlocked
                                    ? _showInvoiceActions(invoice)
                                    : _requireUnlock(),
                          onEdit: (invoice) async {
                            if (invoice.isLocked ||
                                !_isUnlocked ||
                                widget.isPickerMode)
                              return;
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InvoiceInputForm(
                                  existingInvoice: invoice,
                                  onInvoiceGenerated: (inv, path) {},
                                ),
                              ),
                            );
                            _loadData();
                          },
                        ),
                ),
              ],
            ),
            if (!widget.isPickerMode && !_useDashboardHome && !_isUnlocked)
              Positioned.fill(child: SwipeToUnlock(onUnlocked: _toggleUnlock)),
          ],
        ),
      ),
      floatingActionButton: widget.isPickerMode
          ? (_selectedPickerIds.isNotEmpty
                ? FloatingActionButton.extended(
                    onPressed: _confirmPickerSelection,
                    icon: const Icon(Icons.file_download),
                    label: Text("取込 (${_selectedPickerIds.length})"),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  )
                : null)
          : FloatingActionButton.extended(
              onPressed: _isUnlocked
                  ? () => _showCreateTypeMenu()
                  : _requireUnlock,
              label: const Text("新しい伝票"),
              icon: const Icon(Icons.add),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
    );
  }

  Widget _drawerHeading(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _showCreateTypeMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    '伝票選択',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                child: Icon(
                  Icons.request_quote,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: const Text(
                '見積書',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              onTap: () => _startNew(DocumentType.estimation),
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                child: Icon(
                  Icons.local_shipping,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              title: const Text(
                '納品書',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              onTap: () => _startNew(DocumentType.delivery),
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                child: Icon(
                  Icons.receipt_long,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
              title: const Text(
                '請求書',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              onTap: () => _startNew(DocumentType.invoice),
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                child: Icon(
                  Icons.task_alt,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: const Text(
                '領収書',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              onTap: () => _startNew(DocumentType.receipt),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startNew(DocumentType type) async {
    Navigator.pop(context);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceInputForm(
          onInvoiceGenerated: (inv, path) {},
          initialDocumentType: type,
          startViewMode: false,
          showNewBadge: true,
        ),
      ),
    );
    _loadData();
  }
}
