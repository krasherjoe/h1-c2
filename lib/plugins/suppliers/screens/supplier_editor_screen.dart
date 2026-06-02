import 'package:flutter/material.dart';
import '../../../services/error_reporter.dart';
import '../../../widgets/h1_text_field.dart';
import '../models/supplier.dart';
import '../services/supplier_repository.dart';

class SupplierEditorScreen extends StatefulWidget {
  final Supplier? supplier;

  const SupplierEditorScreen({super.key, this.supplier});

  @override
  State<SupplierEditorScreen> createState() => _SupplierEditorScreenState();
}

class _SupplierEditorScreenState extends State<SupplierEditorScreen> {
  final _repo = SupplierRepository();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _displayNameCtl;
  late final TextEditingController _formalNameCtl;
  late final TextEditingController _departmentCtl;
  late final TextEditingController _addressCtl;
  late final TextEditingController _telCtl;
  late final TextEditingController _emailCtl;
  late final TextEditingController _contactPersonCtl;
  late final TextEditingController _paymentTermsCtl;
  late final TextEditingController _bankAccountCtl;
  late final TextEditingController _paymentSiteDaysCtl;
  late final TextEditingController _notesCtl;

  late String _title;
  late int _closingDay;

  bool get _isEdit => widget.supplier != null;

  static const _titleOptions = ['様', '御中', '殿'];
  static const _closingDayOptions = [10, 15, 20, 25, 99];

  String _closingDayLabel(int day) {
    if (day == 99) return '末日';
    return '$day日';
  }

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    _displayNameCtl = TextEditingController(text: s?.displayName ?? '');
    _formalNameCtl = TextEditingController(text: s?.formalName ?? '');
    _departmentCtl = TextEditingController(text: s?.department ?? '');
    _addressCtl = TextEditingController(text: s?.address ?? '');
    _telCtl = TextEditingController(text: s?.tel ?? '');
    _emailCtl = TextEditingController(text: s?.email ?? '');
    _contactPersonCtl = TextEditingController(text: s?.contactPerson ?? '');
    _paymentTermsCtl = TextEditingController(text: s?.paymentTerms ?? '');
    _bankAccountCtl = TextEditingController(text: s?.bankAccount ?? '');
    _paymentSiteDaysCtl = TextEditingController(text: (s?.paymentSiteDays ?? 30).toString());
    _notesCtl = TextEditingController(text: s?.notes ?? '');
    _title = s?.title ?? '様';
    _closingDay = s?.closingDay ?? 99;
  }

  @override
  void dispose() {
    _displayNameCtl.dispose();
    _formalNameCtl.dispose();
    _departmentCtl.dispose();
    _addressCtl.dispose();
    _telCtl.dispose();
    _emailCtl.dispose();
    _contactPersonCtl.dispose();
    _paymentTermsCtl.dispose();
    _bankAccountCtl.dispose();
    _paymentSiteDaysCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final now = DateTime.now();
      final supplier = Supplier(
        id: widget.supplier?.id ?? _repo.generateId(),
        displayName: _displayNameCtl.text.trim(),
        formalName: _formalNameCtl.text.trim(),
        title: _title,
        department: _departmentCtl.text.trim().isEmpty ? null : _departmentCtl.text.trim(),
        address: _addressCtl.text.trim().isEmpty ? null : _addressCtl.text.trim(),
        tel: _telCtl.text.trim().isEmpty ? null : _telCtl.text.trim(),
        email: _emailCtl.text.trim().isEmpty ? null : _emailCtl.text.trim(),
        contactPerson: _contactPersonCtl.text.trim().isEmpty ? null : _contactPersonCtl.text.trim(),
        paymentTerms: _paymentTermsCtl.text.trim().isEmpty ? null : _paymentTermsCtl.text.trim(),
        bankAccount: _bankAccountCtl.text.trim().isEmpty ? null : _bankAccountCtl.text.trim(),
        closingDay: _closingDay,
        paymentSiteDays: int.tryParse(_paymentSiteDaysCtl.text) ?? 30,
        notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
        isLocked: widget.supplier?.isLocked ?? false,
        isHidden: widget.supplier?.isHidden ?? false,
        updatedAt: now,
      );
      await _repo.save(supplier);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e, st) {
      ErrorReporter.sendError(
        message: '仕入先保存失敗: $e',
        screenId: 'SE',
        stackTrace: st,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存エラー: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('SE:${_isEdit ? '仕入先編集' : '新規仕入先'}'),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader(theme, Icons.business, '基本情報'),
            const SizedBox(height: 8),
            _buildCard([
              H1TextField(
                controller: _displayNameCtl,
                decoration: const InputDecoration(
                  labelText: '表示名 *',
                  prefixIcon: Icon(Icons.short_text),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              H1TextField(
                controller: _formalNameCtl,
                decoration: const InputDecoration(
                  labelText: '正式名称 *',
                  prefixIcon: Icon(Icons.text_fields),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _title,
                decoration: const InputDecoration(
                  labelText: '敬称',
                  prefixIcon: Icon(Icons.title),
                ),
                items: _titleOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _title = v);
                },
              ),
              const SizedBox(height: 14),
              H1TextField(
                controller: _departmentCtl,
                decoration: const InputDecoration(
                  labelText: '部署名',
                  prefixIcon: Icon(Icons.corporate_fare),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            _buildSectionHeader(theme, Icons.contact_mail, '連絡先'),
            const SizedBox(height: 8),
            _buildCard([
              H1TextField(
                controller: _addressCtl,
                decoration: const InputDecoration(
                  labelText: '住所',
                  prefixIcon: Icon(Icons.location_on),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              H1TextField(
                controller: _telCtl,
                decoration: const InputDecoration(
                  labelText: '電話番号',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),
              H1TextField(
                controller: _emailCtl,
                decoration: const InputDecoration(
                  labelText: 'メールアドレス',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              H1TextField(
                controller: _contactPersonCtl,
                decoration: const InputDecoration(
                  labelText: '担当者',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            _buildSectionHeader(theme, Icons.account_balance, '支払条件'),
            const SizedBox(height: 8),
            _buildCard([
              H1TextField(
                controller: _paymentTermsCtl,
                decoration: const InputDecoration(
                  labelText: '支払条件',
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 14),
              H1TextField(
                controller: _bankAccountCtl,
                decoration: const InputDecoration(
                  labelText: '銀行口座',
                  prefixIcon: Icon(Icons.account_balance),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                value: _closingDay,
                decoration: const InputDecoration(
                  labelText: '締日',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                items: _closingDayOptions.map((d) =>
                  DropdownMenuItem(value: d, child: Text(_closingDayLabel(d)))).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _closingDay = v);
                },
              ),
              const SizedBox(height: 14),
              H1TextField(
                controller: _paymentSiteDaysCtl,
                decoration: const InputDecoration(
                  labelText: '支払サイト日数',
                  prefixIcon: Icon(Icons.timer),
                ),
                keyboardType: TextInputType.number,
              ),
            ]),
            const SizedBox(height: 20),
            _buildSectionHeader(theme, Icons.notes, '備考'),
            const SizedBox(height: 8),
            _buildCard([
              H1TextField(
                controller: _notesCtl,
                decoration: const InputDecoration(
                  labelText: '備考',
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
              ),
            ]),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(
                _isEdit ? '変更を保存' : '仕入先を登録',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        )),
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }
}
