import 'package:flutter/material.dart';
import '../../models/customer_model.dart';
import '../../models/custom_field_model.dart';
import '../../services/customer_repository.dart';
import '../../services/custom_field_repository.dart';
import '../../services/business_profile_repository.dart';
import '../../services/permission_service.dart';
import '../../widgets/screen_id_title.dart';
import '../customer_edit_screen.dart';
import 'widgets/customer_list_view.dart';
import 'widgets/customer_sort_menu.dart';
import 'logic/customer_data_loader.dart';
import 'logic/customer_search_filter.dart';
import 'logic/customer_import_export.dart';
import 'logic/customer_dialogs.dart';

class CustomerMasterScreen extends StatefulWidget {
  final bool selectionMode;
  final bool showHidden;

  const CustomerMasterScreen({
    super.key,
    this.selectionMode = false,
    this.showHidden = false,
  });

  @override
  State<CustomerMasterScreen> createState() => _CustomerMasterScreenState();
}

class _CustomerMasterScreenState extends State<CustomerMasterScreen> {
  final CustomerRepository _customerRepo = CustomerRepository();
  final CustomFieldRepository _customFieldRepo = CustomFieldRepository();
  final BusinessProfileRepository _businessProfileRepo = BusinessProfileRepository();
  final TextEditingController _searchController = TextEditingController();

  List<Customer> _customers = [];
  List<Customer> _filtered = [];
  bool _isLoading = true;
  String _sortKey = 'name_asc';
  bool _ignoreCorpPrefix = true;
  String? _selectedKanaGroup;
  String? _selectedKanaChar;
  List<CustomField> _customFields = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      await _customerRepo.ensureCustomerColumns();
      if (!mounted) return;
      await loadCustomFields(
        businessProfileRepo: _businessProfileRepo,
        customFieldRepo: _customFieldRepo,
        mounted: mounted,
        onFields: (fields) => _customFields = fields,
      );
      if (!mounted) return;
      await _loadCustomers();
    } catch (e, st) {
      debugPrint('[C1] _init error: $e\n$st');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    await loadCustomers(
      customerRepo: _customerRepo,
      showHidden: widget.showHidden,
      mounted: mounted,
      onData: (customers) => _customers = customers,
      onLoadingDone: () async {
        await _applyFilter();
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  Future<void> _applyFilter() async {
    _filtered = applyFilter(
      customers: _customers,
      query: _searchController.text.toLowerCase(),
      showHidden: widget.showHidden,
      sortKey: _sortKey,
      ignoreCorpPrefix: _ignoreCorpPrefix,
    );
    await sortCustomers(
      list: _filtered,
      sortKey: _sortKey,
      showHidden: widget.showHidden,
      ignoreCorpPrefix: _ignoreCorpPrefix,
    );
    if (mounted) setState(() {});
  }

  void _onSortChanged(String key) {
    _sortKey = key;
    _applyFilter();
  }

  void _onSearchChanged(String query) {
    _applyFilter();
  }

  Future<void> _addOrEditCustomer({Customer? customer}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerEditScreen(customer: customer),
      ),
    );
    if (saved == true && mounted) _loadCustomers();
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('手入力で新規作成'),
              onTap: () { Navigator.pop(context); _addOrEditCustomer(); },
            ),
            ListTile(
              leading: const Icon(Icons.contact_phone),
              title: const Text('電話帳から取り込む'),
              onTap: () { Navigator.pop(context); _showPhonebookImport(); },
            ),
          ],
        ),
      ),
    );
  }

  void _onCustomerTap(Customer c) {
    if (widget.selectionMode) {
      Navigator.pop(context, c);
    } else {
      _addOrEditCustomer(customer: c);
    }
  }

  void _onCustomerLongPress(Customer c) {
    showContextActions(
      context: context,
      c: c,
      customerRepo: _customerRepo,
      customFields: _customFields,
      onEdit: () => _addOrEditCustomer(customer: c),
      onContactUpdate: () => _showContactUpdate(c),
      onReload: _loadCustomers,
    );
  }

  Future<void> _showContactUpdate(Customer c) async {
    await showContactUpdateDialog(
      context: context,
      customer: c,
      customerRepo: _customerRepo,
      onComplete: _loadCustomers,
    );
  }

  Future<void> _showPhonebookImport() async {
    await showPhonebookImport(
      context: context,
      customerRepo: _customerRepo,
      onComplete: _loadCustomers,
    );
  }

  Future<void> _importFromCsv() async {
    if (!await guardWrite(context, AppFeature.masterEdit)) return;
    if (!mounted) return;
    await importCsv(context, _loadCustomers);
  }

  void _exportCsv() {
    exportCsv(_customers);
  }

  Future<void> _cleanHonorific() async {
    await cleanDuplicateHonorific(
      context: context,
      customers: _customers,
      customerRepo: _customerRepo,
      onComplete: _loadCustomers,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: const BackButton(),
        title: const ScreenAppBarTitle(screenId: 'C1', title: '得意先マスター'),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actionsPadding: const EdgeInsets.only(right: 8),
        actions: <Widget>[
          CustomerSortMenu(currentSortKey: _sortKey, onChanged: _onSortChanged),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'その他',
            onSelected: (v) {
              switch (v) {
                case 'import': _importFromCsv();
                case 'export': _exportCsv();
                case 'honorific': _cleanHonorific();
                case 'hide_hidden': setState(() {}); _applyFilter();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'import', child: ListTile(leading: Icon(Icons.file_upload), title: Text('CSV取込'), dense: true)),
              const PopupMenuItem(value: 'export', child: ListTile(leading: Icon(Icons.file_download), title: Text('CSV出力'), dense: true)),
              const PopupMenuItem(value: 'honorific', child: ListTile(leading: Icon(Icons.auto_fix_high), title: Text('敬称の重複をチェック'), dense: true)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : CustomerListView(
                    filtered: _filtered,
                    selectedKanaGroup: _selectedKanaGroup,
                    selectedKanaChar: _selectedKanaChar,
                    isLoading: _isLoading,
                    onKanaGroupChanged: (g) => setState(() => _selectedKanaGroup = g),
                    onKanaCharChanged: (c) => setState(() => _selectedKanaChar = c),
                    onCustomerTap: _onCustomerTap,
                    onCustomerLongPress: _onCustomerLongPress,
                  ),
          ),
        ],
      ),
      floatingActionButton: widget.selectionMode
          ? null
          : FloatingActionButton(
              heroTag: 'add_customer',
              onPressed: _showAddMenu,
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '顧客名で検索',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }
}
