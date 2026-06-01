import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/customer_model.dart';
import '../services/permission_service.dart';
import '../widgets/customer_rank_badge.dart';
import '../widgets/screen_id_title.dart';

class CustomerEditScreen extends StatefulWidget {
  final Customer? customer;

  const CustomerEditScreen({super.key, this.customer});

  @override
  State<CustomerEditScreen> createState() => _CustomerEditScreenState();
}

class _CustomerEditScreenState extends State<CustomerEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _displayNameCtl;
  late final TextEditingController _formalNameCtl;
  late final TextEditingController _departmentCtl;
  late final TextEditingController _addressCtl;
  late final TextEditingController _telCtl;
  late final TextEditingController _emailCtl;
  late final TextEditingController _head1Ctl;
  late final TextEditingController _head2Ctl;

  late int _selectedTitle;
  late bool _isCompany;
  late int? _closingDay;
  late int? _paymentDay;
  late CustomerRank _rank;
  late int? _rankDiscountRate;
  late final TextEditingController _rankDiscountCtl;
  Customer? _customer;
  bool get _isEdit => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _customer = c;
    _displayNameCtl = TextEditingController(text: c?.displayName ?? '');
    _formalNameCtl = TextEditingController(text: c?.formalName ?? '');
    _departmentCtl = TextEditingController(text: c?.department ?? '');
    _addressCtl = TextEditingController(text: c?.address ?? '');
    _telCtl = TextEditingController(text: c?.tel ?? '');
    _emailCtl = TextEditingController(text: c?.email ?? '');
    _selectedTitle = c?.title ?? HonorificCode.san;
    _isCompany =
        _selectedTitle == HonorificCode.onchu ||
        _selectedTitle == HonorificCode.kisha;
    _closingDay = c?.closingDay;
    _paymentDay = c?.paymentDay;
    _rank = c?.rank ?? CustomerRank.none;
    _rankDiscountRate = c?.rankDiscountRate;
    _rankDiscountCtl = TextEditingController(
      text: _rankDiscountRate?.toString() ?? '',
    );
    _head1Ctl = TextEditingController(
      text: c?.headChar1 ?? _headKana(_displayNameCtl.text),
    );
    _head2Ctl = TextEditingController(text: c?.headChar2 ?? '');
  }

  @override
  void dispose() {
    _displayNameCtl.dispose();
    _formalNameCtl.dispose();
    _departmentCtl.dispose();
    _addressCtl.dispose();
    _telCtl.dispose();
    _emailCtl.dispose();
    _head1Ctl.dispose();
    _head2Ctl.dispose();
    _rankDiscountCtl.dispose();
    super.dispose();
  }

  String _stripHonorific(String name) {
    return name.replaceAll(RegExp(r'[\s\u3000]*(様|御中|殿|先生)$'), '').trim();
  }

  String _headKana(String name) {
    var n = name.replaceAll(RegExp(r'\s+|\u3000'), '');
    for (final token in [
      '株式会社',
      '（株）',
      '(株)',
      '有限会社',
      '（有）',
      '(有)',
      '合同会社',
      '（同）',
      '(同)',
    ]) {
      if (n.startsWith(token)) n = n.substring(token.length);
    }
    if (n.isEmpty) return '';
    final first = n.characters.first;
    final kanaMap = {
      '安': 'あ',
      '阿': 'あ',
      '浅': 'あ',
      '佐': 'さ',
      '田': 'た',
      '中': 'な',
      '林': 'は',
      '松': 'ま',
      '山': 'や',
      '渡': 'わ',
    };
    return kanaMap[first] ?? first;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final isLocked = widget.customer?.isLocked ?? false;
    final newId = isLocked ? Uuid().v4() : (widget.customer?.id ?? Uuid().v4());
    final newCustomer = Customer(
      id: newId,
      displayName: _stripHonorific(_displayNameCtl.text.trim()),
      formalName: _stripHonorific(_formalNameCtl.text.trim()),
      title: _selectedTitle,
      department: _departmentCtl.text.trim().isEmpty
          ? null
          : _departmentCtl.text.trim(),
      address: _addressCtl.text.trim().isEmpty ? null : _addressCtl.text.trim(),
      tel: _telCtl.text.trim().isEmpty ? null : _telCtl.text.trim(),
      email: _emailCtl.text.trim().isEmpty ? null : _emailCtl.text.trim(),
      headChar1: _head1Ctl.text.trim().isEmpty ? null : _head1Ctl.text.trim(),
      headChar2: _head2Ctl.text.trim().isEmpty ? null : _head2Ctl.text.trim(),
      closingDay: _closingDay,
      paymentDay: _paymentDay,
      rank: _rank,
      rankDiscountRate: _rankDiscountRate,
      lat: _customer?.lat,
      lng: _customer?.lng,
      isLocked: false,
    );
    Navigator.pop(context, newCustomer);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: ScreenAppBarTitle(
          screenId: _isEdit ? 'C2' : 'C3',
          title: _isEdit ? '顧客を編集' : '顧客を新規登録',
        ),
        actions: [
          TextButton.icon(
            onPressed: () async { if (await guardWrite(context, AppFeature.masterEdit)) _save(); },
            icon: Icon(Icons.check, color: Theme.of(context).colorScheme.onPrimary),
            label: Text(
              '保存',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: _isCompany
                          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                          : Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                      child: Icon(
                        _isCompany ? Icons.business : Icons.person,
                        size: 36,
                        color: _isCompany ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isEdit ? '顧客情報を編集' : '新しい顧客を登録',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '必須項目（*）を入力してください',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            _SectionHeader(icon: Icons.badge, title: '基本情報'),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _displayNameCtl,
                      decoration: const InputDecoration(
                        labelText: '表示名（略称）*',
                        hintText: '例: 佐々木製作所',
                        prefixIcon: Icon(Icons.short_text),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '表示名は必須です' : null,
                      onChanged: (v) {
                        if (_head1Ctl.text.isEmpty) {
                          _head1Ctl.text = _headKana(v);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _formalNameCtl,
                      decoration: const InputDecoration(
                        labelText: '正式名称 *',
                        hintText: '例: 株式会社 佐々木製作所',
                        prefixIcon: Icon(Icons.text_fields),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '正式名称は必須です' : null,
                    ),
                    const SizedBox(height: 14),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.business),
                          label: Text('会社'),
                        ),
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.person),
                          label: Text('個人'),
                        ),
                      ],
                      selected: {_isCompany},
                      onSelectionChanged: (values) {
                        if (values.isEmpty) return;
                        setState(() {
                          _isCompany = values.first;
                          _selectedTitle = _isCompany
                              ? HonorificCode.onchu
                              : HonorificCode.san;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int>(
                      key: ValueKey('title_$_isCompany'),
                      initialValue: _selectedTitle,
                      decoration: const InputDecoration(
                        labelText: '敬称',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: HonorificCode.san,
                          child: Text('様'),
                        ),
                        DropdownMenuItem(
                          value: HonorificCode.onchu,
                          child: Text('御中'),
                        ),
                        DropdownMenuItem(
                          value: HonorificCode.dono,
                          child: Text('殿'),
                        ),
                        DropdownMenuItem(
                          value: HonorificCode.kisha,
                          child: Text('貴社'),
                        ),
                      ],
                      onChanged: (val) => setState(() {
                        _selectedTitle = val ?? HonorificCode.san;
                        _isCompany =
                            _selectedTitle == HonorificCode.onchu ||
                            _selectedTitle == HonorificCode.kisha;
                      }),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _departmentCtl,
                      decoration: const InputDecoration(
                        labelText: '部署名',
                        hintText: '例: 営業部',
                        prefixIcon: Icon(Icons.corporate_fare),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            _SectionHeader(icon: Icons.contact_mail, title: '連絡先'),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _addressCtl,
                      decoration: const InputDecoration(
                        labelText: '住所',
                        hintText: '例: 東京都千代田区...',
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _telCtl,
                      decoration: const InputDecoration(
                        labelText: '電話番号',
                        hintText: '例: 03-1234-5678',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailCtl,
                      decoration: const InputDecoration(
                        labelText: 'メールアドレス',
                        hintText: '例: info@example.com',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            _SectionHeader(icon: Icons.account_balance, title: '決済情報'),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: _closingDay,
                      decoration: const InputDecoration(
                        labelText: '締日（月末以外の場合）',
                        hintText: '未設定の場合は空欄',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(28, (i) => i + 1)
                          .map((day) => DropdownMenuItem(
                                value: day,
                                child: Text('$day日'),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => _closingDay = val),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int>(
                      initialValue: _paymentDay,
                      decoration: const InputDecoration(
                        labelText: '支払日（月末以外の場合）',
                        hintText: '未設定の場合は空欄',
                        prefixIcon: Icon(Icons.payment),
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(28, (i) => i + 1)
                          .map((day) => DropdownMenuItem(
                                value: day,
                                child: Text('$day日'),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => _paymentDay = val),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            _SectionHeader(icon: Icons.workspace_premium, title: '顧客ランク'),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '伝票発行時にランクに応じた値引きが自動適用されます',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: CustomerRank.values.map((r) {
                        final selected = _rank == r;
                        return ChoiceChip(
                          selected: selected,
                          label: Text(r.label),
                          avatar: Icon(
                            CustomerRankBadge.iconFor(r),
                            size: 16,
                            color: selected
                                ? theme.colorScheme.onPrimary
                                : null,
                          ),
                          onSelected: (_) => setState(() {
                            _rank = r;
                            _rankDiscountRate = null;
                            _rankDiscountCtl.text = '';
                          }),
                        );
                      }).toList(),
                    ),
                    if (_rank != CustomerRank.none) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _rankDiscountCtl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: '値引率（％） 上書き',
                                hintText:
                                    '空欄で${_rank.defaultDiscountRate}%（${_rank.label}既定値）',
                                prefixIcon: const Icon(Icons.percent),
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (v) {
                                final parsed = int.tryParse(v.trim());
                                setState(() => _rankDiscountRate = parsed);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '実効: ${_rankDiscountRate ?? _rank.defaultDiscountRate}%',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            _SectionHeader(icon: Icons.sort_by_alpha, title: 'インデックス（50音順）'),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _head1Ctl,
                        maxLength: 1,
                        decoration: const InputDecoration(
                          labelText: 'インデックス1',
                          hintText: 'あ',
                          prefixIcon: Icon(Icons.looks_one),
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _head2Ctl,
                        maxLength: 1,
                        decoration: const InputDecoration(
                          labelText: 'インデックス2（任意）',
                          hintText: '',
                          prefixIcon: Icon(Icons.looks_two),
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            FilledButton.icon(
              onPressed: () async { if (await guardWrite(context, AppFeature.masterEdit)) _save(); },
              icon: const Icon(Icons.check),
              label: Text(
                _isEdit ? '変更を保存' : '顧客を登録',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
