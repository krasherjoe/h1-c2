import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../models/billing_template_model.dart';
import '../../../services/billing_template_repository.dart';
import '../../../utils/theme_utils.dart' show cardBoxShadow;

class BillingTemplateScreen extends StatefulWidget {
  final String? templateId;
  final bool isEditing;

  const BillingTemplateScreen({
    super.key,
    this.templateId,
    this.isEditing = false,
  });

  @override
  State<BillingTemplateScreen> createState() => _BillingTemplateScreenState();
}

class _BillingTemplateScreenState extends State<BillingTemplateScreen> {
  final _repo = BillingTemplateRepository();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  final _emailBccController = TextEditingController();
  final _emailReplyToController = TextEditingController();

  BillingTemplate? _template;
  bool _loading = true;
  bool _saving = false;

  // 締め日設定
  ClosingDateType _closingDateType = ClosingDateType.monthly;
  int? _closingDay = 99; // 月末
  ClosingMonthType _closingMonthType = ClosingMonthType.everyMonth;

  // 支払い条件
  PaymentTerm _paymentTerm = PaymentTerm.endOfNextMonth;
  int? _paymentDays = 0;

  // 請求書発行タイミング
  InvoiceTiming _invoiceTiming = InvoiceTiming.onClosingDate;

  // 自動化設定
  bool _autoGenerateInvoice = false;
  bool _autoSendEmail = false;
  bool _attachArReport = false;

  // 請求書内容
  bool _includeDeliveryDetails = true;
  bool _groupByProject = true;

  // ワークフロー（おじいちゃん用）
  List<WorkflowStep> _workflowSteps = [
    WorkflowStep.delivery,
    WorkflowStep.waitForClosing,
    WorkflowStep.generateInvoice,
    WorkflowStep.sendEmail,
    WorkflowStep.complete,
  ];

  // Undo/Redo
  final List<List<WorkflowStep>> _undoStack = [];
  final List<List<WorkflowStep>> _redoStack = [];
  static const int _maxUndo = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _emailBccController.dispose();
    _emailReplyToController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.templateId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final template = await _repo.getTemplateById(widget.templateId!);
      if (template != null && mounted) {
        setState(() {
          _template = template;
          _nameController.text = template.name;
          _descriptionController.text = template.description ?? '';
          _notesController.text = template.invoiceNotes ?? '';
          _emailBccController.text = template.emailBcc ?? '';
          _emailReplyToController.text = template.emailReplyTo ?? '';
          _closingDateType = template.closingDateType;
          _closingDay = template.closingDay;
          _closingMonthType = template.closingMonthType;
          _paymentTerm = template.paymentTerm;
          _paymentDays = template.paymentDays;
          _invoiceTiming = template.invoiceTiming;
          _autoGenerateInvoice = template.autoGenerateInvoice;
          _autoSendEmail = template.autoSendEmail;
          _attachArReport = template.attachArReport;
          _includeDeliveryDetails = template.includeDeliveryDetails;
          _groupByProject = template.groupByProject;
          _workflowSteps = List.from(template.workflowSteps);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('読み込みエラー: $e')),
        );
      }
    }
  }

  void _saveState() {
    _undoStack.add(List.from(_workflowSteps));
    if (_undoStack.length > _maxUndo) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(List.from(_workflowSteps));
    setState(() {
      _workflowSteps = List.from(_undoStack.last);
      _undoStack.removeLast();
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _saveState();
    setState(() {
      _workflowSteps = List.from(_redoStack.last);
      _redoStack.removeLast();
    });
  }

  void _addStep(WorkflowStep step) {
    _saveState();
    setState(() {
      _workflowSteps.add(step);
    });
  }

  void _removeStep(int index) {
    _saveState();
    setState(() {
      _workflowSteps.removeAt(index);
    });
  }

  void _reorderSteps(int oldIndex, int newIndex) {
    _saveState();
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final step = _workflowSteps.removeAt(oldIndex);
      _workflowSteps.insert(newIndex, step);
    });
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('テンプレート名を入力してください')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final template = BillingTemplate(
        id: _template?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        workflowSteps: _workflowSteps,
        closingDateType: _closingDateType,
        closingDay: _closingDay,
        closingMonthType: _closingMonthType,
        paymentTerm: _paymentTerm,
        paymentDays: _paymentDays,
        invoiceTiming: _invoiceTiming,
        autoGenerateInvoice: _autoGenerateInvoice,
        autoSendEmail: _autoSendEmail,
        attachArReport: _attachArReport,
        emailBcc: _emailBccController.text.trim().isEmpty
            ? null
            : _emailBccController.text.trim(),
        emailReplyTo: _emailReplyToController.text.trim().isEmpty
            ? null
            : _emailReplyToController.text.trim(),
        includeDeliveryDetails: _includeDeliveryDetails,
        groupByProject: _groupByProject,
        invoiceNotes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        createdAt: _template?.createdAt ?? now,
        updatedAt: now,
        isDefault: _template?.isDefault ?? false,
      );

      await _repo.saveTemplate(template);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存エラー: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '請求テンプレート編集' : '請求テンプレート作成'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _undoStack.isEmpty ? null : _undo,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: _redoStack.isEmpty ? null : _redo,
          ),
          if (_saving)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _save,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildBasicInfoSection(cs),
                const SizedBox(height: 16),
                _buildWorkflowSection(cs),
                const SizedBox(height: 16),
                _buildClosingDateSection(cs),
                const SizedBox(height: 16),
                _buildPaymentTermSection(cs),
                const SizedBox(height: 16),
                _buildInvoiceTimingSection(cs),
                const SizedBox(height: 16),
                _buildAutomationSection(cs),
                const SizedBox(height: 16),
                _buildInvoiceContentSection(cs),
                const SizedBox(height: 16),
                _buildEmailSection(cs),
              ],
            ),
    );
  }

  Widget _buildBasicInfoSection(ColorScheme cs) {
    return _buildSectionCard('基本情報', cs, [
      TextFormField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: 'テンプレート名',
          hintText: '例: 標準請求テンプレート',
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _descriptionController,
        decoration: const InputDecoration(
          labelText: '説明',
          hintText: 'テンプレートの説明',
        ),
        maxLines: 2,
      ),
    ]);
  }

  Widget _buildWorkflowSection(ColorScheme cs) {
    return _buildSectionCard('ワークフロー（アイコンを並べて仕事を組む）', cs, [
      // 利用可能なステップ
      Text('追加するステップをタップ:', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: WorkflowStep.values.map((step) =>
          _buildStepChip(step, cs, onTap: () => _addStep(step))
        ).toList(),
      ),
      const SizedBox(height: 16),
      // 現在のワークフロー
      Text('現在のワークフロー:', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          onReorder: _reorderSteps,
          children: _workflowSteps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            return ListTile(
              key: ValueKey(step),
              leading: Text(
                step.emoji,
                style: const TextStyle(fontSize: 24),
              ),
              title: Text(step.displayName),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.drag_handle),
                  IconButton(
                    icon: const Icon(Icons.remove_circle),
                    onPressed: () => _removeStep(index),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    ]);
  }

  Widget _buildStepChip(WorkflowStep step, ColorScheme cs, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(step.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 4),
            Text(step.displayName, style: TextStyle(color: cs.onPrimaryContainer)),
          ],
        ),
      ),
    );
  }

  Widget _buildClosingDateSection(ColorScheme cs) {
    return _buildSectionCard('締め日設定', cs, [
      DropdownButtonFormField<ClosingDateType>(
        value: _closingDateType,
        decoration: const InputDecoration(labelText: '締め日タイプ'),
        items: ClosingDateType.values.map((type) {
          return DropdownMenuItem(
            value: type,
            child: Text(type.displayName),
          );
        }).toList(),
        onChanged: (value) => setState(() => _closingDateType = value!),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<ClosingMonthType>(
        value: _closingMonthType,
        decoration: const InputDecoration(labelText: '締め月タイプ'),
        items: ClosingMonthType.values.map((type) {
          return DropdownMenuItem(
            value: type,
            child: Text(type.displayName),
          );
        }).toList(),
        onChanged: (value) => setState(() => _closingMonthType = value!),
      ),
      const SizedBox(height: 12),
      TextFormField(
        decoration: InputDecoration(
          labelText: '締め日',
          hintText: '99で月末',
          suffixText: '日（99=月末）',
        ),
        keyboardType: TextInputType.number,
        initialValue: _closingDay?.toString(),
        onChanged: (value) {
          final day = int.tryParse(value);
          setState(() => _closingDay = day);
        },
      ),
    ]);
  }

  Widget _buildPaymentTermSection(ColorScheme cs) {
    return _buildSectionCard('支払い条件', cs, [
      DropdownButtonFormField<PaymentTerm>(
        value: _paymentTerm,
        decoration: const InputDecoration(labelText: '支払い条件'),
        items: PaymentTerm.values.map((term) {
          return DropdownMenuItem(
            value: term,
            child: Text(term.displayName),
          );
        }).toList(),
        onChanged: (value) => setState(() => _paymentTerm = value!),
      ),
      if (_paymentTerm == PaymentTerm.daysAfterInvoice ||
          _paymentTerm == PaymentTerm.daysAfterDelivery) ...[
        const SizedBox(height: 12),
        TextFormField(
          decoration: const InputDecoration(
            labelText: '支払い期限日数',
            suffixText: '日後',
          ),
          keyboardType: TextInputType.number,
          initialValue: _paymentDays?.toString(),
          onChanged: (value) {
            final days = int.tryParse(value);
            setState(() => _paymentDays = days);
          },
        ),
      ],
    ]);
  }

  Widget _buildInvoiceTimingSection(ColorScheme cs) {
    return _buildSectionCard('請求書発行タイミング', cs, [
      DropdownButtonFormField<InvoiceTiming>(
        value: _invoiceTiming,
        decoration: const InputDecoration(labelText: '発行タイミング'),
        items: InvoiceTiming.values.map((timing) {
          return DropdownMenuItem(
            value: timing,
            child: Text(timing.displayName),
          );
        }).toList(),
        onChanged: (value) => setState(() => _invoiceTiming = value!),
      ),
    ]);
  }

  Widget _buildAutomationSection(ColorScheme cs) {
    return _buildSectionCard('自動化設定', cs, [
      SwitchListTile(
        title: const Text('自動請求書発行'),
        subtitle: const Text('締め日に自動で請求書を生成'),
        value: _autoGenerateInvoice,
        onChanged: (value) => setState(() => _autoGenerateInvoice = value),
      ),
      SwitchListTile(
        title: const Text('自動メール送信'),
        subtitle: const Text('請求書発行時に自動でメール送信'),
        value: _autoSendEmail,
        onChanged: (value) => setState(() => _autoSendEmail = value),
      ),
      SwitchListTile(
        title: const Text('売掛レポート添付'),
        subtitle: const Text('メールに売掛レポートを添付'),
        value: _attachArReport,
        onChanged: (value) => setState(() => _attachArReport = value),
      ),
    ]);
  }

  Widget _buildInvoiceContentSection(ColorScheme cs) {
    return _buildSectionCard('請求書内容', cs, [
      SwitchListTile(
        title: const Text('納品明細を含む'),
        subtitle: const Text('請求書に納品明細を詳細表示'),
        value: _includeDeliveryDetails,
        onChanged: (value) => setState(() => _includeDeliveryDetails = value),
      ),
      SwitchListTile(
        title: const Text('案件別グループ化'),
        subtitle: const Text('案件ごとに明細をグループ化'),
        value: _groupByProject,
        onChanged: (value) => setState(() => _groupByProject = value),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _notesController,
        decoration: const InputDecoration(
          labelText: '請求書備考',
          hintText: '請求書に表示する備考',
        ),
        maxLines: 3,
      ),
    ]);
  }

  Widget _buildEmailSection(ColorScheme cs) {
    return _buildSectionCard('メール設定', cs, [
      TextFormField(
        controller: _emailBccController,
        decoration: const InputDecoration(
          labelText: 'BCC',
          hintText: 'BCCアドレス',
        ),
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _emailReplyToController,
        decoration: const InputDecoration(
          labelText: '返信先',
          hintText: 'Reply-Toアドレス',
        ),
        keyboardType: TextInputType.emailAddress,
      ),
    ]);
  }

  Widget _buildSectionCard(String title, ColorScheme cs, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        boxShadow: cardBoxShadow(cs),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }
}
