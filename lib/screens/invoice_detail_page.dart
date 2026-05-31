import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'invoice_input_screen.dart';
import '../models/invoice_models.dart';
import '../models/payment_schedule_model.dart' show PaymentStatus;
import '../services/pdf_generator.dart';
import '../services/invoice_repository.dart';
import '../services/customer_repository.dart';
import '../models/customer_model.dart' show HonorificCode;
import '../services/company_repository.dart';
import '../services/edit_log_repository.dart';
import 'product_picker_modal.dart';
import '../models/company_info.dart';
import '../utils/theme_utils.dart';
import '../widgets/keyboard_inset_wrapper.dart';
import '../services/app_settings_repository.dart';
import '../widgets/draft_badge.dart';
import 'invoice_detail/detail_snapshot.dart';
import 'invoice_detail/invoice_table_cells.dart';
import 'receipt_processing_screen.dart';
import 'invoice_preview_page.dart';

List<InvoiceItem> _cloneItemsDetail(List<InvoiceItem> source) {
  return source
      .map(
        (e) => InvoiceItem(
          id: e.id,
          productId: e.productId,
          description: e.description,
          quantity: e.quantity,
          unitPrice: e.unitPrice,
        ),
      )
      .toList(growable: true);
}

class InvoiceDetailPage extends StatefulWidget {
  final Invoice invoice;
  final bool editable;
  final bool isUnlocked;

  const InvoiceDetailPage({
    super.key,
    required this.invoice,
    this.editable = true,
    this.isUnlocked = true,
  });

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  late TextEditingController _formalNameController;
  late TextEditingController _notesController;
  late List<InvoiceItem> _items;
  late bool _isEditing;
  late Invoice _currentInvoice;
  late double _taxRate; // 追加
  late bool _includeTax; // 追加
  String? _currentFilePath;
  final InvoiceRepository _invoiceRepo = InvoiceRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  final CompanyRepository _companyRepo = CompanyRepository();
  final AppSettingsRepository _settingsRepo = AppSettingsRepository(); // 追加
  CompanyInfo? _companyInfo;
  bool _showFormalWarning = true;
  final List<InvoiceDetailSnapshot> _undoStack = [];
  final List<InvoiceDetailSnapshot> _redoStack = [];
  bool _isApplyingSnapshot = false;
  bool _summaryIsBlue = false; // デフォルトは白
  bool _titleBarFlash = false; // タイトルバータップエフェクト用
  bool _showCopyBadge = false; // コピーボタンエフェクト用
  final EditLogRepository _editLogRepo = EditLogRepository();

  String _documentTypeLabel(DocumentType type) {
    switch (type) {
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


  @override
  void initState() {
    super.initState();
    _currentInvoice = widget.invoice;
    _currentFilePath = widget.invoice.filePath;
    _formalNameController = TextEditingController(
      text: _currentInvoice.customer.formalName,
    );
    _notesController = TextEditingController(text: _currentInvoice.notes ?? "");
    _items = List.from(_currentInvoice.items);
    _taxRate = _currentInvoice.taxRate; // 初期化
    _includeTax = _currentInvoice.taxRate > 0; // 初期化
    _isEditing = false;
    _loadCompanyInfo();
    _loadSummaryTheme();
  }

  Future<void> _loadSummaryTheme() async {
    final saved = await _settingsRepo.getSummaryTheme();
    if (!mounted) return;
    setState(() => _summaryIsBlue = saved == 'blue');
  }

  Future<void> _loadCompanyInfo() async {
    final info = await _companyRepo.getCompanyInfo();
    setState(() => _companyInfo = info);
  }

  @override
  void dispose() {
    _formalNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add(InvoiceItem(description: "新項目", quantity: 1, unitPrice: 0));
    });
    _pushHistory();
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
    _pushHistory();
  }

  void _pickFromMaster() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: ProductPickerModal(
          onItemSelected: (item) {
            setState(() {
              _items.add(item);
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    final String formalName = _formalNameController.text.trim();
    if (formalName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('取引先の正式名称を入力してください')));
      return;
    }

    // 顧客情報を更新
    final updatedCustomer = _currentInvoice.customer.copyWith(
      formalName: formalName,
    );

    final updatedInvoice = _currentInvoice.copyWith(
      customer: updatedCustomer,
      items: _items,
      notes: _notesController.text,
      taxRate: _includeTax ? _taxRate : 0.0, // 更新
    );

    // データベースに保存
    await _invoiceRepo.saveInvoice(updatedInvoice);

    // 顧客の正式名称が変更されている可能性があるため、マスターも更新
    if (updatedCustomer.formalName != widget.invoice.customer.formalName) {
      await _customerRepo.saveCustomer(updatedCustomer);
    }

    setState(() => _isEditing = false);
    _undoStack.clear();
    _redoStack.clear();

    final pdfBytes = await generateInvoicePdf(updatedInvoice);
    if (pdfBytes.isNotEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/invoice_${updatedInvoice.id}.pdf');
      await file.writeAsBytes(pdfBytes);
      final filePath = file.path;
      final finalInvoice = updatedInvoice.copyWith(filePath: filePath);
      await _invoiceRepo.saveInvoice(finalInvoice);
      if (!mounted) return;

      setState(() {
        _currentInvoice = finalInvoice;
        _currentFilePath = filePath;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('データベースとPDFを更新しました')));
    }
  }

  void _exportCsv() {
    // TODO: toCsv()メソッドの修正が必要（コア版ではCSV共有を無効化）
  }

  Future<void> _pickSummaryColor() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.palette, color: Theme.of(context).colorScheme.primary),
              title: const Text('インディゴ'),
              onTap: () => Navigator.pop(context, 'blue'),
            ),
            ListTile(
              leading: Icon(Icons.palette, color: Theme.of(context).colorScheme.onSurfaceVariant),
              title: const Text('白'),
              onTap: () => Navigator.pop(context, 'white'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    setState(() => _summaryIsBlue = selected == 'blue');
    await _settingsRepo.setSummaryTheme(selected);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat("#,###");
    final isDraft = _currentInvoice.isDraft;
    final docTypeName = _currentInvoice.documentTypeName;
    final themeColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final locked = _currentInvoice.isLocked;
    final appBarBg = documentTypeColor(_currentInvoice.documentType, cs, isDark);
    final appBarFg = appBarForeground(appBarBg);

    return Scaffold(
      backgroundColor: themeColor,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: const BackButton(), // 常に表示
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: appBarFg),
        title: GestureDetector(
          onTap: () async {
            // タップエフェクト
            setState(() => _titleBarFlash = true);
            await Future.delayed(const Duration(milliseconds: 150));
            setState(() => _titleBarFlash = false);
            _showDocumentTypeChangeDialog();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _titleBarFlash
                  ? appBarFg.withValues(alpha: 0.25)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "A3: ${_documentTypeLabel(_currentInvoice.documentType)}",
            ),
          ),
        ),
        actions: [
          if (locked)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Chip(
                label: Text(
                  "編集不可",
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                ),
                avatar: Icon(Icons.lock, size: 16, color: Theme.of(context).colorScheme.onPrimary),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          if (!_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.grid_on),
              onPressed: _exportCsv,
              tooltip: "CSV出力",
            ),
            if (widget.isUnlocked && !locked)
              IconButton(
                icon: AnimatedScale(
                  scale: _showCopyBadge ? 1.3 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.all(_showCopyBadge ? 8 : 0),
                    decoration: BoxDecoration(
                      color: _showCopyBadge
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: _showCopyBadge
                          ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                          : null,
                    ),
                    child: Icon(
                      _showCopyBadge ? Icons.check : Icons.copy,
                      color: _showCopyBadge ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
                ),
                tooltip: "コピーして新規作成",
                onPressed: () async {
                  // コピーエフェクト（派手に）
                  setState(() => _showCopyBadge = true);
                  await Future.delayed(const Duration(milliseconds: 500));
                  setState(() => _showCopyBadge = false);
                  // 複製元の伝票にも編集ログを記録
                  final editLogRepo = EditLogRepository();
                  await editLogRepo.addLog(_currentInvoice.id!, "伝票をコピーしました");

                  final newId = DateTime.now().millisecondsSinceEpoch
                      .toString();

                  // 案件名（subject）に「複写」接頭辞を追加
                  String? newSubject;
                  if (_currentInvoice.subject != null &&
                      _currentInvoice.subject!.isNotEmpty) {
                    newSubject = '[複写]${_currentInvoice.subject}';
                  } else {
                    // 空白の場合は「複写」のみ設定
                    newSubject = '[複写]';
                  }

                  final duplicateInvoice = _currentInvoice.copyWith(
                    id: newId,
                    date: DateTime.now(),
                    isDraft: true,
                    subject: newSubject,
                  );

                  if (!context.mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InvoiceInputForm(
                        onInvoiceGenerated: (inv, path) {},
                        existingInvoice: duplicateInvoice,
                      ),
                    ),
                  );

                  // 複製先にも初期編集ログを追加
                  await editLogRepo.addLog(newId, "伝票をコピーして新規作成しました");
                },
              ),
            IconButton(
              icon: Icon(Icons.edit_note, color: Theme.of(context).colorScheme.onPrimary),
              tooltip: locked
                  ? "編集不可"
                  : (widget.isUnlocked ? "詳細編集" : "アンロックして編集"),
              onPressed: (locked || !widget.isUnlocked)
                  ? null
                  : () async {
                      _pushHistory(clearRedo: true);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InvoiceInputForm(
                            onInvoiceGenerated: (inv, path) {},
                            existingInvoice: _currentInvoice,
                          ),
                        ),
                      );
                      final repo = InvoiceRepository();
                      final customerRepo = CustomerRepository();
                      final customers = await customerRepo.getAllCustomers();
                      final updated = (await repo.getAllInvoices(customers))
                          .firstWhere(
                            (i) => i.id == _currentInvoice.id,
                            orElse: () => _currentInvoice,
                          );
                      setState(() => _currentInvoice = updated);
                    },
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: _undoStack.isNotEmpty ? _undo : null,
              tooltip: "元に戻す",
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              onPressed: _redoStack.isNotEmpty ? _redo : null,
              tooltip: "やり直す",
            ),
            IconButton(icon: const Icon(Icons.save), onPressed: _saveChanges),
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: () => setState(() => _isEditing = false),
            ),
          ],
        ],
      ),
      body: KeyboardInsetWrapper(
        basePadding: const EdgeInsets.all(16.0),
        extraBottom: 48,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDraft)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary, // 合計金額と同じカラー
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.primaryContainer),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit_note, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "未確定・PDFは正式発行で確定",
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          "下書$docTypeName",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              _buildHeaderSection(textColor),
              if (_isEditing) ...[
                const SizedBox(height: 16),
                _buildDraftToggleEdit(), // 編集用トグル
                const SizedBox(height: 16),
                _buildExperimentalSection(isDraft),
              ],
              Divider(height: 32, color: Theme.of(context).colorScheme.outlineVariant),
              Text(
                "明細一覧",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              _buildItemTable(fmt, textColor, isDraft),
              if (_isEditing)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add),
                        label: const Text("空の行を追加"),
                      ),
                      ElevatedButton.icon(
                        onPressed: _pickFromMaster,
                        icon: const Icon(Icons.list_alt),
                        label: const Text("マスターから選択"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.tertiary,
                          foregroundColor: Theme.of(context).colorScheme.onTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              _buildSummarySection(fmt, textColor, isDraft),
              if (_currentInvoice.documentType == DocumentType.invoice && !_isEditing) ...[
                const SizedBox(height: 16),
                _buildReceiptAction(),
                const SizedBox(height: 8),
                _buildPaymentAction(),
              ],
              if (_currentInvoice.documentType == DocumentType.estimation && !_isEditing) ...[
                const SizedBox(height: 16),
                _buildDocConvert(DocumentType.delivery, Icons.local_shipping, '納品書を生成'),
                const SizedBox(height: 8),
                _buildDocConvert(DocumentType.invoice, Icons.receipt_long, '請求書を生成'),
              ],
              if (_currentInvoice.documentType == DocumentType.delivery && !_isEditing) ...[
                const SizedBox(height: 16),
                _buildDocConvert(DocumentType.invoice, Icons.receipt_long, '請求書を生成'),
              ],
              const SizedBox(height: 24),
              _buildFooterActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isEditing) ...[
          TextField(
            controller: _formalNameController,
            onChanged: (_) => _pushHistory(),
            decoration: const InputDecoration(
              labelText: "取引先 正式名称",
              border: OutlineInputBorder(),
            ),
            style: TextStyle(color: textColor),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            onChanged: (_) => _pushHistory(),
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: "備考",
              border: OutlineInputBorder(),
            ),
            style: TextStyle(color: textColor),
          ),
        ] else ...[
          GestureDetector(
            onTap: _showDocumentTypeChangeDialog,
            child: Row(
              children: [
                Text(
                  "伝票番号：${_currentInvoice.invoiceNumber}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _documentTypeLabel(_currentInvoice.documentType),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "伝票番号: ${_currentInvoice.invoiceNumber}",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "日付: ${DateFormat('yyyy/MM/dd').format(_currentInvoice.date)}",
            style: TextStyle(color: textColor.withAlpha((0.8 * 255).round())),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "取引先",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${_currentInvoice.customerNameForDisplay} ${HonorificCode.toName(_currentInvoice.customer.title)}",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                if (_currentInvoice.subject?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 8),
                  Text(
                    "件名",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    _currentInvoice.subject!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_currentInvoice.customer.department != null &&
                          _currentInvoice.customer.department!.isNotEmpty)
                        Text(
                          _currentInvoice.customer.department!,
                          style: TextStyle(fontSize: 14, color: textColor),
                        ),
                      if ((_currentInvoice.contactEmailSnapshot ??
                              _currentInvoice.customer.email) !=
                          null)
                        Text(
                          "メール: ${_currentInvoice.contactEmailSnapshot ?? _currentInvoice.customer.email}",
                          style: TextStyle(color: textColor),
                        ),
                      if (_currentInvoice.notes?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 6),
                        Text(
                          "備考: ${_currentInvoice.notes}",
                          style: TextStyle(
                            color: textColor.withAlpha((0.9 * 255).round()),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildItemTable(
    NumberFormat formatter,
    Color textColor,
    bool isDraft,
  ) {
    return Table(
      border: TableBorder.all(
        color: isDraft ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24) : Theme.of(context).colorScheme.outlineVariant,
      ),
      columnWidths: const {
        0: FlexColumnWidth(4),
        1: FixedColumnWidth(50),
        2: FixedColumnWidth(80),
        3: FlexColumnWidth(2),
        4: FixedColumnWidth(40),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: isDraft ? Theme.of(context).colorScheme.surfaceVariant : Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          children: [
            InvoiceTableCell("品名", textColor: textColor),
            InvoiceTableCell("数量", textColor: textColor),
            InvoiceTableCell("単価", textColor: textColor),
            InvoiceTableCell("金額", textColor: textColor),
            const InvoiceTableCell(""),
          ],
        ),
        ..._items.asMap().entries.map((entry) {
          int idx = entry.key;
          InvoiceItem item = entry.value;
          if (_isEditing) {
            return TableRow(
              children: [
                InvoiceEditableCell(
                  initialValue: item.description,
                  textColor: textColor,
                  onChanged: (val) {
                    setState(() => item.description = val);
                    _pushHistory();
                  },
                ),
                InvoiceEditableCell(
                  initialValue: item.quantity.toString(),
                  textColor: textColor,
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    setState(() => item.quantity = int.tryParse(val) ?? 0);
                    _pushHistory();
                  },
                ),
                InvoiceEditableCell(
                  initialValue: item.unitPrice.toString(),
                  textColor: textColor,
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    setState(() => item.unitPrice = int.tryParse(val) ?? 0);
                    _pushHistory();
                  },
                ),
                InvoiceTableCell(
                  formatter.format(item.subtotal),
                  textColor: textColor,
                ),
                IconButton(
                  icon: Icon(Icons.delete, size: 20, color: Theme.of(context).colorScheme.error),
                  onPressed: () => _removeItem(idx),
                ),
              ],
            );
          } else {
            return TableRow(
              children: [
                InvoiceTableCell(item.description, textColor: textColor),
                InvoiceTableCell(item.quantity.toString(), textColor: textColor),
                InvoiceTableCell(
                  formatter.format(item.unitPrice),
                  textColor: textColor,
                ),
                InvoiceTableCell(
                  formatter.format(item.subtotal),
                  textColor: textColor,
                ),
                const SizedBox(),
              ],
            );
          }
        }),
      ],
    );
  }

  Widget _buildSummarySection(
    NumberFormat formatter,
    Color textColor,
    bool isDraft,
  ) {
    final double currentTaxRate = _isEditing
        ? (_includeTax ? _taxRate : 0.0)
        : _currentInvoice.taxRate;
    final int subtotal = _isEditing
        ? _calculateCurrentSubtotal()
        : _currentInvoice.subtotal;
    final int tax = (subtotal * currentTaxRate).floor();
    final int total = subtotal + tax;
    final String taxMode = _companyInfo?.taxDisplayMode?.isNotEmpty == true
        ? _companyInfo!.taxDisplayMode
        : 'normal';

    final bool useBlue = _summaryIsBlue;
    final Color bgColor = useBlue ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface;
    final Color borderColor = useBlue
        ? Colors.transparent
        : Theme.of(context).colorScheme.outlineVariant;
    final Color labelColor = useBlue ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface;
    final Color totalColor = useBlue ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface;
    final Color dividerColor = useBlue ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.24) : Theme.of(context).colorScheme.outlineVariant;

    return GestureDetector(
      onLongPress: _pickSummaryColor,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryRow(
              "小計",
              "￥${formatter.format(subtotal)}",
              labelColor,
            ),
            if (currentTaxRate > 0 && taxMode != 'hidden') ...[
              Divider(color: dividerColor),
              if (taxMode == 'normal')
                _buildSummaryRow(
                  "消費税 (${(currentTaxRate * 100).toInt()}%)",
                  "￥${formatter.format(tax)}",
                  labelColor,
                ),
              if (taxMode == 'text_only')
                _buildSummaryRow("消費税", "（税別）", labelColor),
            ],
            Divider(color: dividerColor),
            _buildSummaryRow(
              currentTaxRate > 0 ? "合計金額 (税込)" : "合計金額",
              "￥${formatter.format(total)}",
              totalColor,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    Color textColor, {
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 22 : 16,
              fontWeight: FontWeight.bold,
              color: isTotal ? Theme.of(context).colorScheme.onPrimary : textColor,
            ),
          ),
        ],
      ),
    );
  }

  int _calculateCurrentSubtotal() {
    return _items.fold(
      0,
      (sum, item) => sum + (item.quantity * item.unitPrice),
    );
  }

  void _pushHistory({bool clearRedo = false}) {
    if (!_isEditing || _isApplyingSnapshot) return;
    if (_undoStack.length >= 30) _undoStack.removeAt(0);
    _undoStack.add(
      InvoiceDetailSnapshot(
        formalName: _formalNameController.text,
        notes: _notesController.text,
        items: _cloneItemsDetail(_items),
        taxRate: _taxRate,
        includeTax: _includeTax,
        isDraft: _currentInvoice.isDraft,
      ),
    );
    if (clearRedo) _redoStack.clear();
    setState(() {});
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final snapshot = _undoStack.removeLast();
    _redoStack.add(
      InvoiceDetailSnapshot(
        formalName: _formalNameController.text,
        notes: _notesController.text,
        items: _cloneItemsDetail(_items),
        taxRate: _taxRate,
        includeTax: _includeTax,
        isDraft: _currentInvoice.isDraft,
      ),
    );
    _applySnapshot(snapshot);
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final snapshot = _redoStack.removeLast();
    _undoStack.add(
      InvoiceDetailSnapshot(
        formalName: _formalNameController.text,
        notes: _notesController.text,
        items: _cloneItemsDetail(_items),
        taxRate: _taxRate,
        includeTax: _includeTax,
        isDraft: _currentInvoice.isDraft,
      ),
    );
    _applySnapshot(snapshot);
  }

  void _applySnapshot(InvoiceDetailSnapshot snapshot) {
    _isApplyingSnapshot = true;
    setState(() {
      _formalNameController.text = snapshot.formalName;
      _notesController.text = snapshot.notes;
      _items = _cloneItemsDetail(snapshot.items);
      _taxRate = snapshot.taxRate;
      _includeTax = snapshot.includeTax;
    });
    _isApplyingSnapshot = false;
  }

  Future<void> _showDocumentTypeChangeDialog() async {
    if (_currentInvoice.isLocked || !_currentInvoice.isDraft) return;

    final currentType = _currentInvoice.documentType;

    // 全種類（現在のタイプを除く）
    const allTypes = [
      DocumentType.estimation,
      DocumentType.order,
      DocumentType.delivery,
      DocumentType.invoice,
      DocumentType.receipt,
    ];
    final options = allTypes.where((t) => t != currentType).toList();

    final selected = await showModalBottomSheet<DocumentType>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '現在: ${_documentTypeLabel(currentType)}  →  変更先を選択',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            ...options.map(
              (type) => ListTile(
                leading: Icon(Icons.swap_horiz, color: Theme.of(context).colorScheme.primary),
                title: Text(_documentTypeLabel(type)),
                onTap: () => Navigator.pop(context, type),
              ),
            ),
          ],
        ),
      ),
    );

    if (selected == null) return;
    final newType = selected;

    final updatedInvoice = _currentInvoice.copyWith(documentType: newType);

    // データベースに保存
    await _invoiceRepo.saveInvoice(updatedInvoice);

    setState(() {
      _currentInvoice = updatedInvoice;
    });

    // 編集ログに記録
    await _editLogRepo.addLog(
      _currentInvoice.id!,
      'ドキュメントタイプを「${_documentTypeLabel(newType)}」に変更しました',
    );
  }

  Widget _buildExperimentalSection(bool isDraft) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDraft ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.secondary, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "税率設定 (編集用)",
            style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                "消費税: ",
                style: TextStyle(
                  color: isDraft ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              ChoiceChip(
                label: const Text("10%"),
                selected: _taxRate == 0.10,
                onSelected: (val) => setState(() => _taxRate = 0.10),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text("8%"),
                selected: _taxRate == 0.08,
                onSelected: (val) => setState(() => _taxRate = 0.08),
              ),
              const Spacer(),
              Switch(
                value: _includeTax,
                onChanged: (val) => setState(() => _includeTax = val),
              ),
              Text(_includeTax ? "税込表示" : "非課税"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentAction() {
    final inv = _currentInvoice;
    if (inv.paymentStatus == PaymentStatus.paid) return const SizedBox.shrink();
    final remaining = inv.totalAmount - inv.receivedAmount;
    return ElevatedButton.icon(
      onPressed: () async {
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => ReceiptProcessingScreen(initialInvoice: inv),
        ));
        if (!mounted) return;
        setState(() {});
      },
      icon: const Icon(Icons.payments),
      label: Text('入金登録（残高 ${NumberFormat('#,###').format(remaining)}）'),
      style: ElevatedButton.styleFrom(
        backgroundColor: inv.paymentStatus == PaymentStatus.partial ? Colors.orange : Theme.of(context).colorScheme.error,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }

  Widget _buildDocConvert(DocumentType targetType, IconData icon, String label) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _convertToDocType(targetType),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.primary.withValues(alpha: 0.4)),
        ),
      ),
    );
  }

  Future<void> _convertToDocType(DocumentType targetType) async {
    final newDoc = _currentInvoice.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      documentType: targetType,
      isDraft: true,
      isLocked: false,
      date: DateTime.now(),
      filePath: null,
      metaJson: null,
      metaHash: null,
    );
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => InvoiceInputForm(
        existingInvoice: newDoc,
        onInvoiceGenerated: (_, __) {},
      ),
    ));
  }

  Widget _buildReceiptAction() {
    return FutureBuilder<Invoice?>(
      future: _invoiceRepo.getReceiptBySourceDocumentId(_currentInvoice.id),
      builder: (context, snapshot) {
        final hasReceipt = snapshot.data != null;
        return ElevatedButton.icon(
          onPressed: () async {
            if (hasReceipt && snapshot.data != null) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InvoiceDetailPage(
                    invoice: snapshot.data!,
                    isUnlocked: widget.isUnlocked,
                  ),
                ),
              );
            } else {
              await _createReceiptFromInvoice();
            }
          },
          icon: Icon(hasReceipt ? Icons.receipt : Icons.receipt_long),
          label: Text(hasReceipt ? "領収書を確認" : "領収書を作成"),
          style: ElevatedButton.styleFrom(
            backgroundColor: hasReceipt
                ? Theme.of(context).colorScheme.tertiary
                : Theme.of(context).colorScheme.primary,
            foregroundColor: hasReceipt
                ? Theme.of(context).colorScheme.onTertiary
                : Theme.of(context).colorScheme.onPrimary,
            minimumSize: const Size(double.infinity, 48),
          ),
        );
      },
    );
  }

  Future<void> _createReceiptFromInvoice() async {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final receipt = _currentInvoice.copyWith(
      id: newId,
      documentType: DocumentType.receipt,
      sourceDocumentId: _currentInvoice.id,
      date: DateTime.now(),
      isDraft: true,
      isLocked: false,
      subject: _currentInvoice.subject,
    );

    final result = await Navigator.push<Invoice>(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceInputForm(
          onInvoiceGenerated: (inv, path) {},
          existingInvoice: receipt,
        ),
      ),
    );

    if (!mounted) return;
    if (result != null) {
      // 元請求書の領収書発行済みフラグを更新
      final updatedInvoice = _currentInvoice.copyWith(
        isReceiptIssued: true,
        receiptIssuedAt: DateTime.now(),
      );
      await _invoiceRepo.saveInvoice(updatedInvoice);
      setState(() => _currentInvoice = updatedInvoice);
    }
  }

  Widget _buildFooterActions() {
    if (_isEditing) return const SizedBox();
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _previewPdf,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text("PDFプレビュー"),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _currentFilePath != null ? _openPdf : null,
            icon: const Icon(Icons.launch),
            label: const Text("PDFを開く"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.onSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _currentFilePath != null ? _sharePdf : null,
            icon: const Icon(Icons.share),
            label: const Text("共有"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showPromoteDialog() async {
    bool showWarning = _showFormalWarning;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("正式発行"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    DraftBadge(),
                    SizedBox(width: 8),
                    Expanded(child: Text("この伝票を「確定」として正式に発行しますか？")),
                  ],
                ),
                const SizedBox(height: 8),
                if (showWarning)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).colorScheme.error, width: 1),
                    ),
                    child: Text(
                      "確定すると暗号チェーンシステムに組み込まれ、二度と編集できません。内容を最終確認のうえ実行してください。",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("警告文を表示"),
                  value: showWarning,
                  onChanged: (val) {
                    setStateDialog(() => showWarning = val);
                    setState(() => _showFormalWarning = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("キャンセル"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondary),
                child: const Text("正式発行する"),
              ),
            ],
          );
        },
      ),
    );

    if (confirm == true) {
      final promoted = _currentInvoice.copyWith(isDraft: false);
      await _invoiceRepo.updateInvoice(promoted);
      setState(() {
        _currentInvoice = promoted;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("伝票を正式発行しました")));
      }
    }
  }

  Widget _buildDraftToggleEdit() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _currentInvoice.isDraft ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.secondary, width: 2),
      ),
      child: Row(
        children: [
          Icon(Icons.drafts, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 12),
          const Expanded(
            child: Row(
              children: [
                DraftBadge(),
                SizedBox(width: 8),
                Text("状態として保持", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Switch(
            value: _currentInvoice.isDraft,
            onChanged: (val) {
              setState(() {
                _currentInvoice = _currentInvoice.copyWith(isDraft: val);
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openPdf() async {
    if (_currentFilePath != null) {
      // コア版では外部ファイル表示を無効化
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDFプレビュー機能を使用してください')),
      );
    }
  }

  Future<void> _sharePdf() async {
    // コア版では共有機能を無効化
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('共有機能はコア版では利用できません')),
    );
  }

  Future<void> _previewPdf() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoicePdfPreviewPage(
          invoice: _currentInvoice,
          isUnlocked: widget.isUnlocked,
          isLocked: _currentInvoice.isLocked,
          allowFormalIssue: true,
          onFormalIssue: () async {
            await _showPromoteDialog();
          },
          showShare: true,
          showEmail: true,
          showPrint: true,
        ),
      ),
    );
  }
}

