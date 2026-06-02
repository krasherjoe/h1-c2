import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/customer_model.dart';
import '../models/invoice_models.dart';
import '../services/invoice_repository.dart';
import '../services/customer_repository.dart';
import 'invoice_preview_page.dart';
import '../services/gps_service.dart';
import '../services/sales_repository.dart';
import '../models/product_model.dart';
import '../services/product_repository.dart';
import '../services/app_settings_repository.dart';
import '../services/company_repository.dart';
import '../models/company_info.dart';
import '../services/company_profile_service.dart';
import '../services/edit_log_repository.dart';
import '../services/permission_service.dart';
import '../models/project_model.dart';
import '../services/project_repository.dart';
import '../services/sys_logger.dart';
import '../services/error_reporter.dart';
import '../widgets/document_card.dart';
import 'invoice_input/widgets/invoice_body_content.dart';
import 'invoice_input/widgets/invoice_saving_overlay.dart';
import 'invoice_input/invoice_snapshot.dart';
import 'invoice_input/widgets/variant_picker_sheet.dart';
import 'invoice_input/models/invoice_section_data.dart';
import 'invoice_input/widgets/invoice_bottom_bar.dart';
import 'invoice_input/widgets/invoice_app_bar.dart';
import 'invoice_input/logic/invoice_document_importer.dart';
import 'invoice_input/logic/invoice_initial_loader.dart';
import 'invoice_input/logic/invoice_hash_chain_helper.dart';
import 'invoice_input/logic/invoice_receipt_creator.dart';
import 'invoice_input/logic/invoice_red_invoice_creator.dart';
import 'invoice_input/logic/invoice_saver.dart';
import 'invoice_input/logic/invoice_source_viewer.dart';
import 'invoice_input/widgets/invoice_discard_dialog.dart';
import 'invoice_input/logic/invoice_calculator.dart';
import 'invoice_input/logic/invoice_state_helpers.dart';
import 'invoice_input/logic/invoice_customer_ops.dart';
import 'invoice_input/widgets/invoice_document_type_dialog.dart';
import 'invoice_input/widgets/invoice_preview_shower.dart';

class InvoiceInputForm extends StatefulWidget {
  final Function(Invoice invoice, String filePath) onInvoiceGenerated;
  final Invoice? existingInvoice;
  final DocumentType initialDocumentType;
  final bool startViewMode;
  final bool showNewBadge;
  final bool showCopyBadge;
  final Customer? preselectedCustomer;
  final bool isSalesMode;
  final String? initialSalesId;

  const InvoiceInputForm({
    super.key,
    required this.onInvoiceGenerated,
    this.existingInvoice,
    this.initialDocumentType = DocumentType.invoice,
    this.startViewMode = true,
    this.showNewBadge = false,
    this.showCopyBadge = false,
    this.preselectedCustomer,
    this.isSalesMode = false,
    this.initialSalesId,
  });

  @override
  State<InvoiceInputForm> createState() => _InvoiceInputFormState();
}

class _InvoiceInputFormState extends State<InvoiceInputForm> {
  final InvoiceRepository _invoiceRepo = InvoiceRepository();
  Customer? _selectedCustomer;
  final List<InvoiceItem> _items = [];
  String _stateKey = '';

  bool get _hasChanges => calcStateKey(
    customer: _selectedCustomer,
    selectedDate: _selectedDate,
    includeTax: _includeTax,
    taxRate: _taxRate,
    documentType: _documentType,
    isDraft: _isDraft,
    items: _items,
  ) != _stateKey;

  double _taxRate = 0.10;
  bool _includeTax = false;
  bool _isTaxInclusiveMode = false; // 税込みモード（単価が税込、消費税を逆算）
  DocumentType _documentType = DocumentType.invoice; // 追加
  DateTime _selectedDate = DateTime.now(); // 追加: 伝票日付
  bool _isDraft = true; // デフォルトは下書き
  final TextEditingController _subjectController = TextEditingController();
  final _savingNotifier = ValueNotifier<bool>(false);
  String? _currentId;
  Invoice? _currentInvoice;
  bool _isLocked = false;
  String? _emailSentAt;
  String? _printedAt;
  bool _isYoungestIssued = false;
  final List<InvoiceSnapshot> _undoStack = [];
  final List<InvoiceSnapshot> _redoStack = [];
  // タイトルバースワイプズーム用の状態
  final _transformationController = TransformationController();
  double _titleBarStartScale = 1.0;
  double _titleBarStartX = 0.0;
  bool _panEnabled = false;
  bool _isApplyingSnapshot = false;
  bool get _canUndo => _undoStack.length > 1;
  bool get _canRedo => _redoStack.isNotEmpty;
  bool _isViewMode = true; // デフォルトでビューワ
  bool _summaryIsBlue = false; // デフォルトは白
  final AppSettingsRepository _settingsRepo = AppSettingsRepository();
  final CompanyRepository _companyRepo = CompanyRepository();
  final ProductRepository _productRepo = ProductRepository();
  final Map<String, int> _wholesalePrices = {};
  int _grossProfit = 0;
  bool _showNewBadge = false;
  bool _showCopyBadge = false;
  bool _titleBarFlash = false; // タイトルバータップエフェクト用
  final EditLogRepository _editLogRepo = EditLogRepository();
  List<EditLogEntry> _editLogs = [];
  final FocusNode _subjectFocusNode = FocusNode();
  String _lastLoggedSubject = "";
  bool _hasRedInvoice = false;
  List<CompanyBankAccount> _companyBankAccounts = [];
  int _selectedBankIndex = -1;
  final ProjectRepository _projectRepo = ProjectRepository();
  String? _selectedProjectId;
  String? _selectedProjectName;
  List<Project> _customerProjects = [];
  bool get _isSalesMode => widget.isSalesMode || widget.initialSalesId != null;
  final SalesRepository _salesRepo = SalesRepository();
  DateTime? _salesPaymentDueDate;
  String _salesPaymentMethod = '現金';
  DocumentStatus _salesStatus = DocumentStatus.confirmed;


  void _showDocumentTypeChangeDialog() async {
    final selected = await showDocumentTypeChangeDialog(
      context,
      currentType: _documentType,
      isLocked: _isLocked,
      isDraft: _isDraft,
    );
    if (selected == null) return;
    setState(() {
      _documentType = selected;
    });
    await _editLogRepo.addLog(
      _currentId!,
      'ドキュメントタイプを「${documentTypeLabel(selected)}」に変更しました',
    );
  }

  void _copyAsNew() async {
    if (widget.existingInvoice == null && _currentId == null) return;

    // 複製元の編集ログに記録
    final originalId = _currentId;
    if (originalId != null) {
      await _editLogRepo.addLog(originalId, "伝票をコピーしました");
    }

    final clonedItems = cloneItems(_items, resetIds: true);
    // 案件名に「複写」接頭辞を追加
    final originalSubject = _subjectController.text;
    final newSubject = originalSubject.isNotEmpty
        ? '[複写]$originalSubject'
        : '[複写]';

    setState(() {
      _currentId = DateTime.now().millisecondsSinceEpoch.toString();
      _isDraft = true;
      _isLocked = false;
      _emailSentAt = null;
      _printedAt = null;
      _isYoungestIssued = false;
      _selectedDate = DateTime.now();
      _items
        ..clear()
        ..addAll(clonedItems);
      _subjectController.text = newSubject;
      _isViewMode = false;
      _showCopyBadge = true;
      _showNewBadge = false;
      _pushHistory(clearRedo: true);
      _editLogs.clear();
    });

    // 複製先の編集ログに記録
    if (_currentId != null) {
      await _editLogRepo.addLog(_currentId!, "伝票をコピーして新規作成しました");
    }
  }

  @override
  void initState() {
    super.initState();
    // 初期フレームで正しいDocType色を表示するため非同期ロード前に設定
    _documentType =
        widget.existingInvoice?.documentType ?? widget.initialDocumentType;
    _subjectController.addListener(_onSubjectChanged); // ← 1回だけ登録
      _subjectFocusNode.addListener(() async {
        if (_subjectFocusNode.hasFocus) {
          // フォーカス取得時: [複写]接頭辞を削除（編集開始時のクリーンアップ）
          if (_subjectController.text.startsWith('[複写]')) {
            final cleaned = _subjectController.text.replaceFirst(RegExp(r'^\[複写\]'), '');
            _subjectController.text = cleaned;
            _subjectController.selection = TextSelection.collapsed(offset: 0);
          }
        } else {
          final current = _subjectController.text;
          if (current != _lastLoggedSubject) {
            final id = _currentId ??= DateTime.now().millisecondsSinceEpoch.toString();
            final msg = "件名を『$current』に更新しました";
            await _editLogRepo.addLog(id, msg);
            _loadEditLogs();
            _lastLoggedSubject = current;
          }
        }
      });
    // ※ _subjectController.addListener(_onSubjectChanged) の重複登録を削除済み
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final data = await loadInitialInvoiceData(
      invoiceRepo: _invoiceRepo,
      companyRepo: _companyRepo,
      productRepo: _productRepo,
      settingsRepo: _settingsRepo,
      projectRepo: _projectRepo,
      existingInvoice: widget.existingInvoice,
      initialSalesId: widget.initialSalesId,
      isSalesMode: _isSalesMode,
      initialDocumentType: widget.initialDocumentType,
      preselectedCustomer: widget.preselectedCustomer,
    );

    if (data['salesMode'] as bool) {
      if (data['salesFound'] as bool) {
        setState(() {
          _selectedCustomer = data['customer'] as Customer?;
          _items.clear();
          _items.addAll(data['items'] as List<InvoiceItem>);
          _selectedDate = data['selectedDate'] as DateTime;
          _taxRate = data['taxRate'] as double;
          _includeTax = data['includeTax'] as bool;
          _currentId = data['currentId'] as String?;
          _subjectController.text = data['subject'] as String;
          _salesPaymentDueDate = data['salesPaymentDueDate'] as DateTime?;
          _salesPaymentMethod = data['salesPaymentMethod'] as String;
          _salesStatus = data['salesStatus'] as DocumentStatus;
          _selectedProjectId = data['selectedProjectId'] as String?;
        });
        _grossProfit = calculateGrossProfit(_items, _wholesalePrices);
        _stateKey = calcStateKey(customer: _selectedCustomer, selectedDate: _selectedDate, includeTax: _includeTax, taxRate: _taxRate, documentType: _documentType, isDraft: _isDraft, items: _items);
        _pushHistory(clearRedo: true);
        _isViewMode = widget.startViewMode;
        return;
      }
      _isDraft = true;
      _taxRate = 0.10;
      _includeTax = true;
      _documentType = DocumentType.invoice;
      _currentId = null;
      _stateKey = calcStateKey(customer: _selectedCustomer, selectedDate: _selectedDate, includeTax: _includeTax, taxRate: _taxRate, documentType: _documentType, isDraft: _isDraft, items: _items);
      _isViewMode = false;
      if (widget.preselectedCustomer != null) {
        _selectedCustomer = widget.preselectedCustomer;
      }
      return;
    }

    _summaryIsBlue = data['summaryIsBlue'] as bool;
    final bankAccounts = data['companyBankAccounts'] as List<CompanyBankAccount>;
    final defaultTaxRate = data['defaultTaxRate'] as double;
    final defaultBankIdx = data['defaultBankIdx'] as int;
    final youngestCheck = data['youngestCheck'] as bool;
    final wholesalePrices = data['wholesalePrices'] as Map<String, int>;
    _wholesalePrices
      ..clear()
      ..addAll(wholesalePrices);

    setState(() {
      _companyBankAccounts = bankAccounts;
      if (widget.existingInvoice != null) {
        final inv = widget.existingInvoice!;
        _selectedCustomer = inv.customer;
        _items.addAll(inv.items);
        _grossProfit = calculateGrossProfit(_items, _wholesalePrices);
        if (inv.isLocked) {
          _taxRate = inv.taxRate;
          _includeTax = inv.taxRate > 0 || inv.includeTax;
          _isTaxInclusiveMode = inv.isTaxInclusiveMode;
        } else {
          _taxRate = inv.includeTax ? (inv.taxRate > 0 ? inv.taxRate : defaultTaxRate) : 0.0;
          _includeTax = inv.includeTax;
          _isTaxInclusiveMode = inv.isTaxInclusiveMode;
        }
        _documentType = inv.documentType;
        _selectedDate = inv.date;
        _isDraft = inv.isDraft;
        _currentId = inv.id;
        _isLocked = inv.isLocked;
        _emailSentAt = inv.emailSentAt;
        _printedAt = inv.printedAt;
        _isYoungestIssued = youngestCheck;
        if (inv.subject != null) _subjectController.text = inv.subject!;
        _currentInvoice = inv;
        _selectedProjectId = inv.projectId;
        if (inv.bankAccount != null && inv.bankAccount!.isNotEmpty) {
          _selectedBankIndex = _companyBankAccounts.indexWhere(
            (a) => _accountKey(a) == inv.bankAccount,
          );
        } else {
          _selectedBankIndex = defaultBankIdx < bankAccounts.length ? defaultBankIdx : -1;
        }
      } else {
        _taxRate = defaultTaxRate > 0 ? defaultTaxRate : 0.10;
        _includeTax = true;
        _isDraft = true;
        _documentType = widget.initialDocumentType;
        _currentId = null;
        _isLocked = false;
        _emailSentAt = null;
        _printedAt = null;
        _currentInvoice = null;
        _selectedBankIndex = defaultBankIdx < bankAccounts.length ? defaultBankIdx : -1;
      }
      if (widget.preselectedCustomer != null) {
        _selectedCustomer = widget.preselectedCustomer;
      }
    });
    _stateKey = calcStateKey(customer: _selectedCustomer, selectedDate: _selectedDate, includeTax: _includeTax, taxRate: _taxRate, documentType: _documentType, isDraft: _isDraft, items: _items);
    _isViewMode = widget.startViewMode;
    _showNewBadge = widget.showNewBadge;
    _showCopyBadge = widget.showCopyBadge;
    _pushHistory(clearRedo: true);

    if (_currentId != null) {
      if (mounted) {
        final has = await _invoiceRepo.hasRedInvoice(_currentId!);
        if (mounted) setState(() => _hasRedInvoice = has);
      }
    }
    _lastLoggedSubject = _subjectController.text;
    if (_currentId != null) {
      _loadEditLogs();
    }
    final existingCustomer = widget.existingInvoice?.customer;
    if (existingCustomer != null) {
      await _loadProjectsForCustomer(existingCustomer.id);
      if (!mounted) return;
      final pid = widget.existingInvoice?.projectId;
      if (pid != null) {
        final proj = _customerProjects.where((p) => p.id == pid).firstOrNull;
        if (proj != null && mounted) {
          setState(() => _selectedProjectName = proj.name);
        }
      }
    }
  }

  @override
  void dispose() {
    _subjectFocusNode.dispose();
    _savingNotifier.dispose();
    _subjectController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadEditLogs() async {
    if (_currentId == null) return;
    final logs = await _editLogRepo.getLogs(_currentId!);
    if (!mounted) return;
    setState(() => _editLogs = logs);
  }

  Future<void> _loadProjectsForCustomer(String customerId) async {
    final projects = await _projectRepo.getProjectsByCustomer(customerId);
    if (!mounted) return;
    setState(() => _customerProjects = projects);
  }

  void _onSubjectChanged() {
    if (_isApplyingSnapshot) return;
    _pushHistory();
  }

  Future<void> _saveInvoice({bool generatePdf = true}) async {
    if (!await guardWrite(context, AppFeature.invoice)) return;
    if (!mounted) return;
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("取引先を選択してください")));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("明細を1件以上入力してください")));
      return;
    }
    if (!_hasChanges && _currentId != null) {
      Navigator.pop(context, true);
      return;
    }

    _savingNotifier.value = true;

    final gpsService = GpsService();
    final pos = await gpsService.getCurrentLocation();
    if (pos != null) {
      await gpsService.logLocation();
    }

    final invoiceId = _currentId ??= DateTime.now().millisecondsSinceEpoch.toString();

    try {
      if (_isSalesMode) {
        await saveAsSalesInvoice(
          salesRepo: _salesRepo,
          projectRepo: _projectRepo,
          editLogRepo: _editLogRepo,
          invoiceId: invoiceId,
          selectedCustomer: _selectedCustomer!,
          items: _items,
          selectedDate: _selectedDate,
          taxRate: _taxRate,
          includeTax: _includeTax,
          salesStatus: _salesStatus,
          salesPaymentDueDate: _salesPaymentDueDate,
          salesPaymentMethod: _salesPaymentMethod,
          selectedProjectId: _selectedProjectId,
        );
        _currentId = invoiceId;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("売上伝票を保存しました")),
          );
        }
        _stateKey = calcStateKey(customer: _selectedCustomer, selectedDate: _selectedDate, includeTax: _includeTax, taxRate: _taxRate, documentType: _documentType, isDraft: _isDraft, items: _items);
        if (mounted) setState(() => _isViewMode = true);
        return;
      }

      final savedInvoice = await saveInvoice(
        context,
        invoiceRepo: _invoiceRepo,
        editLogRepo: _editLogRepo,
        projectRepo: _projectRepo,
        selectedCustomer: _selectedCustomer!,
        items: _items,
        selectedDate: _selectedDate,
        taxRate: _taxRate,
        documentType: _documentType,
        subject: _subjectController.text.isNotEmpty ? _subjectController.text : null,
        isDraft: _isDraft,
        includeTax: _includeTax,
        isTaxInclusiveMode: _isTaxInclusiveMode,
        priceAdjustmentType: _currentInvoice?.priceAdjustmentType,
        priceAdjustmentUnit: _currentInvoice?.priceAdjustmentUnit,
        bankAccount: _selectedBankIndex >= 0 && _selectedBankIndex < _companyBankAccounts.length
            ? _accountKey(_companyBankAccounts[_selectedBankIndex])
            : null,
        projectId: _selectedProjectId,
        currentId: _currentId,
        latitude: pos?.latitude,
        longitude: pos?.longitude,
        generatePdf: generatePdf,
      );

      _currentId = savedInvoice.id;
      if (mounted) {
        widget.onInvoiceGenerated(savedInvoice, savedInvoice.filePath ?? '');
        if (generatePdf && savedInvoice.filePath != null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("伝票を保存し、PDFを生成しました")));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("伝票を保存しました（PDF未生成）")));
        }
      }
      await _editLogRepo.addLog(_currentId!, "伝票を保存しました");
      await _loadEditLogs();
      _stateKey = calcStateKey(customer: _selectedCustomer, selectedDate: _selectedDate, includeTax: _includeTax, taxRate: _taxRate, documentType: _documentType, isDraft: _isDraft, items: _items);
      if (mounted) setState(() => _isViewMode = true);
    } catch (e, st) {
      SysLogger.instance.logError('InvIn', e);
      ErrorReporter.sendError(
        message: '保存失敗: $e',
        screenId: '/invoice/input',
        stackTrace: st,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      }
    } finally {
      if (mounted) _savingNotifier.value = false;
    }
  }

  Future<void> _showPreview() async {
    if (_selectedCustomer == null) return;
    final blankItems = _items.where((it) => it.description.isEmpty).toList();
    if (blankItems.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${blankItems.length}件の明細に商品名がありません'),
        backgroundColor: Colors.red.shade700,
      ));
      return;
    }
    final id = _currentId ??= DateTime.now().millisecondsSinceEpoch.toString();
    final invoice = Invoice(
      id: id,
      customer: _selectedCustomer!,
      date: _selectedDate,
      items: _items,
      taxRate: _includeTax ? _taxRate : 0.0,
      documentType: _documentType,
      customerFormalNameSnapshot: _selectedCustomer!.formalName,
      subject: _subjectController.text.isNotEmpty ? _subjectController.text : null,
      notes: null,
      isDraft: _isDraft,
      isLocked: _isLocked,
      includeTax: _includeTax,
      isTaxInclusiveMode: _isTaxInclusiveMode,
      bankAccount: _selectedBankIndex >= 0 && _selectedBankIndex < _companyBankAccounts.length
          ? _accountKey(_companyBankAccounts[_selectedBankIndex])
          : null,
      promisedDate: _documentType == DocumentType.estimation
          ? _selectedDate.add(const Duration(days: 14))
          : null,
      priceAdjustmentType: _currentInvoice?.priceAdjustmentType,
      priceAdjustmentUnit: _currentInvoice?.priceAdjustmentUnit,
    );

    final result = await showInvoicePreview(
      context,
      invoice: invoice,
      invoiceRepo: _invoiceRepo,
      editLogRepo: _editLogRepo,
      currentId: id,
    );

    if (result != null && mounted) {
      setState(() {
        _isDraft = result.isDraft;
        _isLocked = result.isLocked;
      });
    }
  }

  void _pushHistory({bool clearRedo = false}) {
    setState(() {
      _grossProfit = calculateGrossProfit(_items, _wholesalePrices);
      if (_undoStack.length >= 30) _undoStack.removeAt(0);
      _undoStack.add(buildSnapshot(
        customer: _selectedCustomer,
        items: _items,
        taxRate: _taxRate,
        includeTax: _includeTax,
        isTaxInclusiveMode: _isTaxInclusiveMode,
        documentType: _documentType,
        date: _selectedDate,
        isDraft: _isDraft,
        subject: _subjectController.text,
      ));
      if (clearRedo) _redoStack.clear();
    });
  }

  void _undo() {
    if (_undoStack.length <= 1) return;
    setState(() {
      _redoStack.add(buildSnapshot(
        customer: _selectedCustomer,
        items: _items,
        taxRate: _taxRate,
        includeTax: _includeTax,
        isTaxInclusiveMode: _isTaxInclusiveMode,
        documentType: _documentType,
        date: _selectedDate,
        isDraft: _isDraft,
        subject: _subjectController.text,
      ));
      _undoStack.removeLast();
      final snapshot = _undoStack.last;
      _isApplyingSnapshot = true;
      _selectedCustomer = snapshot.customer;
      _items
        ..clear()
        ..addAll(cloneItems(snapshot.items));
      _taxRate = snapshot.taxRate;
      _includeTax = snapshot.includeTax;
      _isTaxInclusiveMode = snapshot.isTaxInclusiveMode;
      _documentType = snapshot.documentType;
      _selectedDate = snapshot.date;
      _isDraft = snapshot.isDraft;
      _subjectController.text = snapshot.subject;
      _isApplyingSnapshot = false;
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(buildSnapshot(
        customer: _selectedCustomer,
        items: _items,
        taxRate: _taxRate,
        includeTax: _includeTax,
        isTaxInclusiveMode: _isTaxInclusiveMode,
        documentType: _documentType,
        date: _selectedDate,
        isDraft: _isDraft,
        subject: _subjectController.text,
      ));
      final snapshot = _redoStack.removeLast();
      _isApplyingSnapshot = true;
      _selectedCustomer = snapshot.customer;
      _items
        ..clear()
        ..addAll(cloneItems(snapshot.items));
      _taxRate = snapshot.taxRate;
      _includeTax = snapshot.includeTax;
      _isTaxInclusiveMode = snapshot.isTaxInclusiveMode;
      _documentType = snapshot.documentType;
      _selectedDate = snapshot.date;
      _isDraft = snapshot.isDraft;
      _subjectController.text = snapshot.subject;
      _isApplyingSnapshot = false;
    });
  }

  Future<void> _onImportFromDocuments() async {
    final result = await importItemsFromDocuments(context);
    if (result == null || !mounted) return;
    final newItems = result['items'] as List<InvoiceItem>;
    final firstCustomerId = result['customerId'] as String?;
    final firstSubject = result['subject'] as String?;
    final selectedCount = result['selectedCount'] as int;
    if (_selectedCustomer == null && firstCustomerId != null) {
      try {
        final customers = await CustomerRepository().getAllCustomers();
        final found = customers.where((c) => c.id == firstCustomerId).toList();
        if (found.isNotEmpty && mounted) {
          setState(() => _selectedCustomer = found.first);
        }
      } catch (_) {}
    }
    if (_subjectController.text.isEmpty && firstSubject != null) {
      _subjectController.text = firstSubject;
    }
    if (!mounted) return;
    setState(() => _items.addAll(newItems));
    _pushHistory();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$selectedCount件の伝票から${newItems.length}件の明細を取り込みました'),
      ),
    );
  }

  Future<void> _onDocumentTypeChangeTap() async {
    setState(() => _titleBarFlash = true);
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    setState(() => _titleBarFlash = false);
    _showDocumentTypeChangeDialog();
  }

  Future<void> _onDateTap() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _pushHistory();
    }
  }

  Future<void> _onCreateReceipt() async {
    if (_currentInvoice == null) return;
    final receipt = await createReceiptFromInvoice(
      context: context,
      invoiceRepo: _invoiceRepo,
      originalInvoice: _currentInvoice!,
      isRedInvoice: _hasRedInvoice,
    );
    if (receipt == null || !mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceInputForm(
          existingInvoice: receipt,
          onInvoiceGenerated: (inv, path) {},
          initialDocumentType: DocumentType.receipt,
        ),
      ),
    );
  }

  Future<void> _onViewSourceInvoice() async {
    final sourceInvoice = await loadSourceInvoice(
      _currentInvoice?.sourceDocumentId,
      currentDocumentType: _documentType,
    );
    if (sourceInvoice == null || !mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceInputForm(
          onInvoiceGenerated: (inv, path) {},
          existingInvoice: sourceInvoice,
          startViewMode: true,
        ),
      ),
    );
  }

  Future<void> _onRevertFormalIssue() async {
    final ok = await confirmAndRevertFormalIssue(
      context,
      invoiceRepo: _invoiceRepo,
      currentId: _currentId ?? '',
      isLocked: _isLocked,
      emailSentAt: _emailSentAt,
      printedAt: _printedAt,
    );
    if (ok && mounted) {
      setState(() {
        _isDraft = true;
        _isLocked = false;
        _isViewMode = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat("#,###");
    final themeColor = Color.alphaBlend(
      Colors.black.withValues(alpha: 0.08),
      Theme.of(context).scaffoldBackgroundColor,
    );
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    final appBar = InvoiceAppBar(
      documentType: _documentType,
      isSalesMode: _isSalesMode,
      isViewMode: _isViewMode,
      isDraft: _isDraft,
      isLocked: _isLocked,
      showCopyBadge: _showCopyBadge,
      titleBarFlash: _titleBarFlash,
      currentInvoice: _currentInvoice,
      canUndo: _canUndo,
      canRedo: _canRedo,
      saving: _savingNotifier.value,
      onCopyAsNew: () async {
        setState(() => _showCopyBadge = true);
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        setState(() => _showCopyBadge = false);
        _copyAsNew();
      },
      onUndo: _undo,
      onRedo: _redo,
      onImportFromDocuments: _onImportFromDocuments,
      onSave: () => _saveInvoice(generatePdf: false),
      onToggleEditMode: () => setState(() => _isViewMode = false),
      onDocumentTypeChangeTap: _onDocumentTypeChangeTap,
    );

    final content = Scaffold(
      backgroundColor: themeColor,
      resizeToAvoidBottomInset: false,
      body: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16, 16, 16, keyboardInset + 140),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: InvoiceBodyContent(
                      selectedDate: _selectedDate,
                      showNewBadge: _showNewBadge,
                      showCopyBadge: _showCopyBadge,
                      isViewMode: _isViewMode,
                      isLocked: _isLocked,
                      hasRedInvoice: _hasRedInvoice,
                      isRedInvoice: _currentInvoice?.isRedInvoice == true,
                      documentType: _documentType,
                      selectedCustomer: _selectedCustomer,
                      currentInvoice: _currentInvoice,
                      items: _items,
                      subjectController: _subjectController,
                      subjectFocusNode: _subjectFocusNode,
                      currentId: _currentId,
                      editLogs: _editLogs,
                      isSalesMode: _isSalesMode,
                      salesPaymentMethod: _salesPaymentMethod,
                      salesPaymentDueDate: _salesPaymentDueDate,
                      salesStatus: _salesStatus,
                      customerProjects: _customerProjects,
                      selectedProjectId: _selectedProjectId,
                      selectedProjectName: _selectedProjectName,
                      summaryIsBlue: _summaryIsBlue,
                      taxRate: _taxRate,
                      includeTax: _includeTax,
                      isTaxInclusiveMode: _isTaxInclusiveMode,
                      grossProfit: _grossProfit,
                      format: fmt,
                      productRepo: _productRepo,
                      editLogRepo: _editLogRepo,
                      settingsRepo: _settingsRepo,
                      customerForPricing: _selectedCustomer,
                      onItemsChanged: (items) => setState(() => _items..clear()..addAll(items)),
                      onCurrentInvoiceChanged: (inv) {
                        if (!mounted) return;
                        setState(() => _currentInvoice = inv);
                      },
                      onTaxRateChanged: (taxRate, includeTax, isTaxInclusiveMode) {
                        if (!mounted) return;
                        setState(() {
                          _taxRate = taxRate;
                          _includeTax = includeTax;
                          _isTaxInclusiveMode = isTaxInclusiveMode;
                        });
                      },
                      onPushHistory: _pushHistory,
                      onLoadEditLogs: _loadEditLogs,
                      onDateTap: _isViewMode ? null : _onDateTap,
                      onCreateReceipt: _onCreateReceipt,
                      onSelectCustomer: _onSelectCustomer,
                      onProjectTap: _customerProjects.isNotEmpty ? _showProjectPicker : null,
                      onDeleteItem: _onDeleteInvoiceItem,
                      onReorder: _onReorderInvoiceItems,
                      onDecrementQuantity: _onDecrementQuantity,
                      onSetQuantity: _onSetQuantity,
                      onIncrementQuantity: _onIncrementQuantity,
                      onCreateRedInvoice: _createRedInvoice,
                      onViewSourceInvoice: _onViewSourceInvoice,
                      onPaymentMethodChanged: (v) {
                        setState(() { _salesPaymentMethod = v; _pushHistory(); });
                      },
                      onPaymentDueDateChanged: (picked) {
                        if (picked != null && mounted) {
                          setState(() => _salesPaymentDueDate = picked);
                          _pushHistory();
                        }
                      },
                      onSalesStatusToggle: () => setState(() {
                        _salesStatus = _salesStatus == DocumentStatus.draft
                            ? DocumentStatus.confirmed
                            : DocumentStatus.draft;
                      }),
                      onSummaryThemeChanged: (isBlue) {
                        if (mounted) setState(() => _summaryIsBlue = isBlue);
                      },
                      resolveVariant: _resolveVariant,
                    ),
                  ),
                ),
                InvoiceBottomBar(
                  isSalesMode: _isSalesMode,
                  isViewMode: _isViewMode,
                  isLocked: _isLocked,
                  hasItems: _items.isNotEmpty,
                  emailSentAtNull: _emailSentAt == null,
                  printedAtNull: _printedAt == null,
                  currentInvoice: _currentInvoice,
                  isYoungestEntry: isYoungestHashChainEntry(_currentId, _isYoungestIssued),
                  onPreview: _items.isEmpty ? null : _showPreview,
                  onEdit: () => setState(() => _isViewMode = false),
                  onSave: () => _saveInvoice(generatePdf: false),
                  onRevertFormalIssue: _onRevertFormalIssue,
                ),
              ],
            ),
            InvoiceSavingOverlay(savingNotifier: _savingNotifier),
          ],
        ),
      ),
    );

    final sensorAppBar = PreferredSize(
      preferredSize: appBar.preferredSize,
      child: GestureDetector(
        onHorizontalDragStart: (details) {
          _titleBarStartScale = _transformationController.value.getMaxScaleOnAxis();
          _titleBarStartX = details.globalPosition.dx;
        },
        onHorizontalDragUpdate: (details) {
          final deltaX = details.globalPosition.dx - _titleBarStartX;
          final scaleChange = deltaX / 50 * 0.1;
          final newScale = (_titleBarStartScale + scaleChange).clamp(1.0, 2.0);
          _transformationController.value = Matrix4.identity()..scale(newScale);
          final shouldPan = newScale > 1.01;
          if (shouldPan != _panEnabled) {
            setState(() => _panEnabled = shouldPan);
          }
        },
        onHorizontalDragEnd: (details) {
          _titleBarStartScale = _transformationController.value.getMaxScaleOnAxis();
        },
        behavior: HitTestBehavior.translucent,
        child: appBar,
      ),
    );

    return PopScope(
      canPop: _isViewMode,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final shouldPop = await showDiscardConfirmDialog(context);
        if (!mounted) return;
        if (shouldPop) nav.pop();
      },
      child: Scaffold(
        appBar: sensorAppBar,
        backgroundColor: themeColor,
        resizeToAvoidBottomInset: false,
        body: _isViewMode
            ? InteractiveViewer(
                transformationController: _transformationController,
                minScale: 1.0,
                maxScale: 2.0,
                boundaryMargin: const EdgeInsets.all(100),
                constrained: true,
                panEnabled: _panEnabled,
                child: content.body!,
              )
            : content.body!,
      ),
    );
  }



  Future<void> _onSelectCustomer() async {
    final picked = await selectCustomer(
      context,
      currentCustomer: _selectedCustomer,
      items: _items,
      productRepo: _productRepo,
      onItemsRecalculated: (newItems) {
        if (!mounted) return;
        setState(() {
          _items
            ..clear()
            ..addAll(newItems);
        });
      },
    );
    if (picked == null || !mounted) return;

    setState(() {
      _selectedCustomer = picked;
      _selectedProjectId = null;
      _selectedProjectName = null;
      _customerProjects = [];
    });
    _pushHistory();
    _loadProjectsForCustomer(picked.id);
  }


  void _showProjectPicker() {
    showProjectPicker(
      context,
      customerProjects: _customerProjects,
      selectedProjectId: _selectedProjectId,
      selectedProjectName: _selectedProjectName,
      selectedCustomer: _selectedCustomer,
      initialSubject: _subjectController.text,
      projectRepo: _projectRepo,
      onProjectSelected: (id) {
        if (!mounted) return;
        setState(() {
          _selectedProjectId = id;
          _selectedProjectName = id != null
              ? _customerProjects.where((p) => p.id == id).firstOrNull?.name
              : null;
        });
      },
      onProjectCreated: (newProject) {
        if (!mounted) return;
        setState(() {
          _customerProjects.add(newProject);
          _selectedProjectId = newProject.id;
          _selectedProjectName = newProject.name;
        });
      },
    );
  }

  Future<Product> _resolveVariant(Product product) async {
    final groups = await _productRepo.getOptionGroups(product.id);
    if (groups.isEmpty) return product;

    final allValues = <ProductOptionGroup, List<ProductOptionValue>>{};
    for (final g in groups) {
      allValues[g] = await _productRepo.getOptionValues(g.id);
    }
    if (!mounted) return product;

    // デフォルト値周りの選択状態を管理
    final selected = <String, ProductOptionValue?>{}; // groupId → value
    for (final g in groups) {
      final vals = allValues[g] ?? [];
      selected[g.id] = vals.isNotEmpty ? vals.first : null;
    }

    final result = await showModalBottomSheet<Product?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return VariantPickerSheet(
          parent: product,
          groups: groups,
          allValues: allValues,
          selected: selected,
        );
      },
    );

    return result ?? product;
  }

  void _onReorderInvoiceItems(int oldIndex, int newIndex) {
    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
    _pushHistory();
    final id = _currentId ??= DateTime.now().millisecondsSinceEpoch.toString();
    final item = _items[newIndex];
    final msg =
        "明細を並べ替えました: ${item.description} を ${oldIndex + 1} → ${newIndex + 1}";
    _editLogRepo.addLog(id, msg);
    _loadEditLogs();
  }

  void _onDeleteInvoiceItem(int idx) {
    final removed = _items[idx];
    setState(() => _items.removeAt(idx));
    _pushHistory();
    final id = _currentId ??= DateTime.now().millisecondsSinceEpoch.toString();
    final msg = "商品「${removed.description}」を削除しました";
    _editLogRepo.addLog(id, msg);
    _loadEditLogs();
  }

  void _onDecrementQuantity(int idx) {
    final item = _items[idx];
    if (item.quantity <= 1) return;
    setState(() => _items[idx] = item.copyWith(quantity: item.quantity - 1));
    _pushHistory();
    final id = _currentId ??= DateTime.now().millisecondsSinceEpoch.toString();
    _editLogRepo.addLog(id, '${item.description} の数量を ${item.quantity - 1} に変更しました');
    _loadEditLogs();
  }

  void _onSetQuantity(int idx, int quantity) {
    final item = _items[idx];
    setState(() => _items[idx] = item.copyWith(quantity: quantity));
    _pushHistory();
    final id = _currentId ??= DateTime.now().millisecondsSinceEpoch.toString();
    _editLogRepo.addLog(id, '${item.description} の数量を $quantity に変更しました');
    _loadEditLogs();
  }

  void _onIncrementQuantity(int idx) {
    final item = _items[idx];
    setState(() => _items[idx] = item.copyWith(quantity: item.quantity + 1));
    _pushHistory();
    final id = _currentId ??= DateTime.now().millisecondsSinceEpoch.toString();
    _editLogRepo.addLog(id, '${item.description} の数量を ${item.quantity + 1} に変更しました');
    _loadEditLogs();
  }





  String _accountKey(CompanyBankAccount a) {
    return '${a.bankName}|${a.branchName}|${a.accountType}|${a.accountNumber}|${a.holderName}';
  }






  Future<void> _createRedInvoice() async {
    if (_selectedCustomer == null || _currentInvoice == null) return;
    if (!mounted) return;

    _savingNotifier.value = true;

    try {
      final redInvoice = await createRedInvoice(
        context,
        selectedCustomer: _selectedCustomer!,
        currentInvoice: _currentInvoice!,
        items: _items,
        documentType: _documentType,
        taxRate: _taxRate,
        subject: _subjectController.text,
        includeTax: _includeTax,
        isTaxInclusiveMode: _isTaxInclusiveMode,
        currentId: _currentId,
        invoiceRepo: _invoiceRepo,
        bankAccount: _currentInvoice?.bankAccount,
        priceAdjustmentType: _currentInvoice?.priceAdjustmentType,
        priceAdjustmentUnit: _currentInvoice?.priceAdjustmentUnit,
        terminalId: _currentInvoice?.terminalId,
      );

      if (redInvoice == null) {
        _savingNotifier.value = false;
        return;
      }

      await _editLogRepo.addLog(redInvoice.id, '赤伝を起票しました（元：${_currentInvoice!.invoiceNumber}）');
      setState(() {
        _hasRedInvoice = true;
      });

      await trySendRedInvoiceEmail(
        context: context,
        redInvoice: redInvoice,
        customerEmail: _selectedCustomer?.email,
      );

      if (!mounted) return;
      _savingNotifier.value = false;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InvoicePdfPreviewPage(
            invoice: redInvoice,
            isUnlocked: false,
            isLocked: true,
            allowFormalIssue: false,
            showShare: true,
            showEmail: true,
            showPrint: true,
            onShare: () => _editLogRepo.addLog(redInvoice.id, "PDFを共有しました"),
            onEmail: () => _editLogRepo.addLog(redInvoice.id, "メール送信しました"),
            onPrint: () => _editLogRepo.addLog(redInvoice.id, "印刷しました"),
          ),
        ),
      );
    } catch (e) {
      SysLogger.instance.logError('InvIn', e);
      _savingNotifier.value = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('赤伝起票に失敗しました: $e')),
        );
      }
    }
  }

  // 価格調整ダイアログ
}

