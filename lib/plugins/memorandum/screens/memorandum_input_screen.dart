import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../models/customer_model.dart';
import '../../../services/customer_repository.dart';
import '../models/memorandum_model.dart';
import '../services/memorandum_repository.dart';
import 'memorandum_preview_screen.dart';

class MemorandumInputScreen extends StatefulWidget {
  final Memorandum? memorandum;
  final String? estimateId;
  final int? prefillAmount;
  final String? projectId;
  final String? customerId;
  final String? customerName;

  const MemorandumInputScreen({
    super.key,
    this.memorandum,
    this.estimateId,
    this.prefillAmount,
    this.projectId,
    this.customerId,
    this.customerName,
  });

  @override
  State<MemorandumInputScreen> createState() => _MemorandumInputScreenState();
}

class _MemorandumInputScreenState extends State<MemorandumInputScreen> {
  final _repo = MemorandumRepository();
  final _formKey = GlobalKey<FormState>();
  final _df = DateFormat('yyyy/M/d');
  final _serviceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _monthsCtrl = TextEditingController();

  String _customerId = '';
  String _customerName = '';
  DateTime _contractDate = DateTime.now();
  DateTime _startDate = DateTime.now();
  int _contractMonths = 60;
  MonthlyPlan _monthlyPlan = MonthlyPlan.plan5000;
  int _customAmount = 0;
  String _serviceTemplate = '';
  bool _saving = false;
  String? _savedId;
  String? _savedDocNumber;

  @override
  void initState() {
    super.initState();
    if (widget.memorandum != null) {
      final m = widget.memorandum!;
      _customerId = m.customerId;
      _customerName = m.customerName;
      _contractDate = m.contractDate;
      _startDate = m.startDate;
      _contractMonths = m.contractMonths;
      _monthlyPlan = m.monthlyPlan;
      _customAmount = m.customAmount ?? 0;
      _serviceCtrl.text = m.serviceContent;
      if (m.serviceContent.contains('保守サービス')) {
        _serviceTemplate = '保守サービス';
      }
      _notesCtrl.text = m.notes ?? '';
      _monthsCtrl.text = m.contractMonths.toString();
    } else {
      _monthsCtrl.text = _contractMonths.toString();
      if (widget.customerId != null && widget.customerName != null) {
        _customerId = widget.customerId!;
        _customerName = widget.customerName!;
      }
      if (widget.prefillAmount != null) {
        if (widget.prefillAmount == 3000) {
          _monthlyPlan = MonthlyPlan.plan3000;
        } else if (widget.prefillAmount == 5000) {
          _monthlyPlan = MonthlyPlan.plan5000;
        } else if (widget.prefillAmount == 8000) {
          _monthlyPlan = MonthlyPlan.plan8000;
        }
      }
    }
  }

  @override
  void dispose() {
    _serviceCtrl.dispose();
    _notesCtrl.dispose();
    _monthsCtrl.dispose();
    super.dispose();
  }

  int get _totalAmount {
    final monthly = _monthlyPlan == MonthlyPlan.planCustom ? _customAmount : _monthlyPlan.amount(null);
    return monthly * _contractMonths;
  }

  DateTime get _endDate {
    final targetMonth = _startDate.month + _contractMonths;
    final y = _startDate.year + (targetMonth - 1) ~/ 12;
    final m = (targetMonth - 1) % 12 + 1;
    final lastDay = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, _startDate.day > lastDay ? lastDay : _startDate.day);
  }

  Future<void> _pickCustomer() async {
    final customers = await CustomerRepository().getAllCustomers();
    if (!mounted) return;
    final selected = await showDialog<Customer>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('得意先選択'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: customers.length,
            itemBuilder: (_, i) {
              final c = customers[i];
              return ListTile(
                title: Text(c.displayName),
                subtitle: c.formalName.isNotEmpty ? Text(c.formalName) : null,
                onTap: () => Navigator.pop(ctx, c),
              );
            },
          ),
        ),
      ),
    );
    if (selected != null) {
      setState(() {
        _customerId = selected.id;
        _customerName = selected.displayName;
      });
    }
  }

  Future<void> _save({bool andPop = true}) async {
    if (_customerName.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('得意先を入力してください')),
      );
      return;
    }
    if (_serviceCtrl.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('サービス内容を入力してください')),
      );
      return;
    }
    if (_savedId != null) {
      if (andPop) { if (mounted) Navigator.pop(context, true); }
      return;
    }
    setState(() => _saving = true);
    try {
      final m = Memorandum(
        id: widget.memorandum?.id ?? (_savedId ?? const Uuid().v4()),
        documentNumber: widget.memorandum?.documentNumber ?? (_savedDocNumber ?? await _generateDocNumber()),
        customerId: _customerId,
        customerName: _customerName,
        contractDate: _contractDate,
        startDate: _startDate,
        endDate: _endDate,
        contractMonths: _contractMonths,
        monthlyPlan: _monthlyPlan,
        customAmount: _monthlyPlan == MonthlyPlan.planCustom ? _customAmount : null,
        serviceContent: _serviceCtrl.text,
        totalAmount: _totalAmount,
        notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        projectId: widget.projectId ?? widget.memorandum?.projectId,
        estimateId: widget.estimateId ?? widget.memorandum?.estimateId,
        status: widget.memorandum?.status ?? MemorandumStatus.draft,
        createdAt: widget.memorandum?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _repo.save(m);
      _savedId = m.id;
      _savedDocNumber = m.documentNumber;
      if (!mounted) return;
      if (andPop) {
        Navigator.pop(context, true);
      } else {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => MemorandumPreviewScreen(memorandum: m),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存エラー: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String> _generateDocNumber() async {
    final items = await _repo.getAll();
    final projectCount = widget.projectId != null
        ? items.where((m) => m.projectId == widget.projectId).length
        : items.length;
    final year = DateTime.now().year;
    return 'M-$year-${(projectCount + 1).toString().padLeft(4, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('覚書 入力'),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(icon: const Icon(Icons.save), onPressed: () => _save()),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: _pickCustomer,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '得意先',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _customerName.isEmpty ? 'タップして選択' : _customerName,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _contractDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null && mounted) {
                    setState(() => _contractDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '契約日',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(_df.format(_contractDate)),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null && mounted) {
                    setState(() => _startDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '開始日',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(_df.format(_startDate)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _monthsCtrl,
                decoration: const InputDecoration(
                  labelText: '契約月数',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final parsed = int.tryParse(v);
                  if (parsed != null && parsed > 0) {
                    setState(() => _contractMonths = parsed);
                  }
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [12, 24, 36, 60]
                    .map((months) => ChoiceChip(
                          label: Text('$monthsヶ月'),
                          selected: _contractMonths == months,
                          onSelected: (_) {
                            setState(() {
                              _contractMonths = months;
                              _monthsCtrl.text = months.toString();
                            });
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    '契約終了日: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(_df.format(_endDate)),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '月額料金',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SegmentedButton<MonthlyPlan>(
                segments: const [
                  ButtonSegment(
                    value: MonthlyPlan.plan3000,
                    label: Text('3,000円'),
                  ),
                  ButtonSegment(
                    value: MonthlyPlan.plan5000,
                    label: Text('5,000円'),
                  ),
                  ButtonSegment(
                    value: MonthlyPlan.plan8000,
                    label: Text('8,000円'),
                  ),
                  ButtonSegment(
                    value: MonthlyPlan.planCustom,
                    label: Text('カスタム'),
                  ),
                ],
                selected: {_monthlyPlan},
                onSelectionChanged: (s) =>
                    setState(() => _monthlyPlan = s.first),
              ),
              if (_monthlyPlan == MonthlyPlan.planCustom)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: '月額（円）',
                      border: OutlineInputBorder(),
                      prefixText: '¥ ',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final parsed = int.tryParse(v);
                      if (parsed != null && parsed > 0) {
                        setState(() => _customAmount = parsed);
                      }
                    },
                  ),
                ),
              const SizedBox(height: 16),
              Card(
                color: cs.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '月額 ${_monthlyPlan.label(_monthlyPlan == MonthlyPlan.planCustom ? _customAmount : null)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            '$_contractMonthsヶ月',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      Text(
                        '合計 ${NumberFormat('#,###').format(_totalAmount)}円',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _serviceTemplate.isEmpty ? null : _serviceTemplate,
                decoration: const InputDecoration(
                  labelText: 'サービス種別',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: '保守サービス', child: Text('保守サービス')),
                  DropdownMenuItem(value: 'その他', child: Text('その他')),
                ],
                onChanged: (v) {
                  setState(() {
                    _serviceTemplate = v ?? '';
                    if (v == '保守サービス') {
                      _serviceCtrl.text = 'サーバー・ネットワーク機器類の保守管理業務\n'
                          '・システム稼働状況の監視\n'
                          '・障害対応及び復旧作業\n'
                          '・定期的なバックアップ確認\n'
                          '・セキュリティパッチ適用';
                    }
                  });
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _serviceCtrl,
                decoration: const InputDecoration(
                  labelText: 'サービス内容（編集可）',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: '特記事項（任意）',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : () => _save(andPop: false),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf),
                  label: const Text('保存してプレビュー'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
