import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/company_info.dart';
import '../../../services/company_repository.dart';
import '../../../services/company_service.dart';
import '../../../services/database_helper.dart';
import '../../../widgets/h1_form_field.dart';
import 'seal_contrast_dialog.dart';
import 'seal_camera_screen.dart';
import 'seal_offset_adjust_page.dart';
import '../../../constants/screen_ids.dart';
import '../../../utils/theme_utils.dart' show cardDecoration;

class CompanyProfileScreen extends StatefulWidget {
  const CompanyProfileScreen({super.key});
  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _postalController;
  late TextEditingController _addressController;
  late TextEditingController _telController;
  late TextEditingController _faxController;
  late TextEditingController _emailController;
  CompanyInfo? _info;
  bool _isLoading = true;
  final _companyRepo = CompanyRepository();
  List<CompanyBankAccount> _bankAccounts = List.generate(
    3, (_) => const CompanyBankAccount(),
  );
  final _regNumberCtrl = TextEditingController();
  bool _isExempt = false;
  int _fiscalYearStart = 4;
  int _closingDay = 20;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _postalController = TextEditingController();
    _addressController = TextEditingController();
    _telController = TextEditingController();
    _faxController = TextEditingController();
    _emailController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _postalController.dispose();
    _addressController.dispose();
    _telController.dispose();
    _faxController.dispose();
    _emailController.dispose();
    _regNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final info = await _companyRepo.getCompanyInfo();
    if (info != null) {
      _nameController.text = info.name;
      _postalController.text = info.zipCode ?? '';
      _addressController.text = info.address ?? '';
      _telController.text = info.tel ?? '';
      _faxController.text = info.fax ?? '';
      _emailController.text = info.email ?? '';
      _bankAccounts = _parseBankAccounts(info.bankAccounts);
      _regNumberCtrl.text = info.registrationNumber ?? '';
      _isExempt = info.isExemptTaxpayer;
      _fiscalYearStart = info.fiscalYearStart;
      _closingDay = info.closingDay;
    }
    setState(() {
      _info = info;
      _isLoading = false;
    });
  }

  List<CompanyBankAccount> _parseBankAccounts(String? json) {
    if (json == null || json.isEmpty) {
      return List.generate(3, (_) => const CompanyBankAccount());
    }
    try {
      final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
      final accounts = list.map((e) => CompanyBankAccount.fromJson(e)).toList();
      while (accounts.length < 3) {
        accounts.add(const CompanyBankAccount());
      }
      return accounts.take(3).toList();
    } catch (_) {
      return List.generate(3, (_) => const CompanyBankAccount());
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final bankJson = jsonEncode(_bankAccounts.map((a) => a.toJson()).toList());
    final regNum = _regNumberCtrl.text.trim();
    final newName = _nameController.text.trim();
    final info = (_info ?? CompanyInfo(name: '')).copyWith(
      name: newName,
      zipCode: _postalController.text.trim().isEmpty ? null : _postalController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      tel: _telController.text.trim().isEmpty ? null : _telController.text.trim(),
      fax: _faxController.text.trim().isEmpty ? null : _faxController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      bankAccounts: bankJson,
      registrationNumber: regNum.isEmpty ? null : regNum,
      isExemptTaxpayer: _isExempt,
      taxDisplayMode: _isExempt ? 'hidden' : 'normal',
      fiscalYearStart: _fiscalYearStart,
      closingDay: _closingDay,
    );
    await _companyRepo.saveCompanyInfo(info);

    // 会社名が変わったらDBファイル名も変更
    final currentName = await CompanyService.getCurrentCompany();
    if (currentName != null && currentName != newName && currentName != 'default') {
      final dir = await CompanyService.getCompanyDirectory();
      final oldPath = '${dir.path}/$currentName.db';
      final newPath = '${dir.path}/$newName.db';
      if (await File(oldPath).exists() && !await File(newPath).exists()) {
        await DatabaseHelper.closeAndReset();
        await File(oldPath).rename(newPath);
        await CompanyService.setCurrentCompany(newName);
      }
    } else if (currentName == 'default' && newName.isNotEmpty) {
      // default.db を新しい会社名に改名
      final dir = await CompanyService.getCompanyDirectory();
      final defaultPath = '${dir.path}/default.db';
      final newPath = '${dir.path}/$newName.db';
      if (await File(defaultPath).exists() && !await File(newPath).exists()) {
        await DatabaseHelper.closeAndReset();
        await File(defaultPath).rename(newPath);
        await CompanyService.setCurrentCompany(newName);
      }
    }

    setState(() => _info = info);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('保存しました')),
    );
    Navigator.pop(context);
  }

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => SealContrastDialog(imagePath: image.path),
    );
    if (saved != null && mounted) {
      setState(() {
        _info = (_info ?? CompanyInfo(name: '')).copyWith(sealPath: saved);
      });
    }
  }

  Future<void> _takeSealPhoto() async {
    if (!mounted) return;
    final saved = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const SealCameraScreen()),
    );
    if (saved != null && mounted) {
      final adjusted = await showDialog<String>(
        context: context,
        builder: (ctx) => SealContrastDialog(imagePath: saved),
      );
      if (adjusted != null && mounted) {
        setState(() {
          _info = (_info ?? CompanyInfo(name: '')).copyWith(sealPath: adjusted);
        });
      }
    }
  }

  Future<void> _deleteSeal() async {
    setState(() {
      _info = (_info ?? CompanyInfo(name: '')).copyWith(sealPath: null);
    });
  }

  Future<void> _adjustContrast() async {
    if (_info?.sealPath == null) return;
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => SealContrastDialog(imagePath: _info!.sealPath!),
    );
    if (saved != null && mounted) {
      setState(() {
        _info = _info!.copyWith(sealPath: saved);
      });
    }
  }

  Future<void> _adjustOffset() async {
    if (_info?.sealPath == null) return;
    final result = await Navigator.push<Map<String, double>>(
      context,
      MaterialPageRoute(
        builder: (_) => SealOffsetAdjustPage(
          sealPath: _info!.sealPath!,
          initialOffsetX: _info!.sealOffsetX,
          initialOffsetY: _info!.sealOffsetY,
          companyInfo: _info!,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _info = _info!.copyWith(
          sealOffsetX: result['x'],
          sealOffsetY: result['y'],
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('${S.ci}:自社情報')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  H1FormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '会社名',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? '必須です' : null,
                  ),
                  const SizedBox(height: 12),
                  H1FormField(
                    controller: _postalController,
                    decoration: const InputDecoration(
                      labelText: '郵便番号',
                      hintText: '000-0000',
                    ),
                  ),
                  const SizedBox(height: 12),
                  H1FormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: '住所',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  H1FormField(
                    controller: _telController,
                    decoration: const InputDecoration(
                      labelText: '電話番号',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  H1FormField(
                    controller: _faxController,
                    decoration: const InputDecoration(
                      labelText: 'FAX',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  H1FormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'メールアドレス',
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),
                  _buildTaxSection(),
                  const SizedBox(height: 24),
                  _buildBankSection(),
                  const SizedBox(height: 24),
                  _buildFiscalYearSection(),
                  const SizedBox(height: 24),

                  // 角印管理セクション
                  _buildSealSection(),
                  const SizedBox(height: 24),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('保存'),
                      onPressed: _save,
                    ),
                  ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('透明度', style: TextStyle(fontSize: 13)),
                Expanded(
                  child: Slider(
                    value: _info?.sealOpacity ?? 1.0,
                    min: 0.1, max: 1.0, divisions: 9,
                    onChanged: (v) => setState(() {
                      _info = _info!.copyWith(sealOpacity: v);
                    }),
                  ),
                ),
                Text('${((_info?.sealOpacity ?? 1.0) * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
              ),
            ),
    );
  }

  Widget _buildTaxSection() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: cardDecoration(cs, radius: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.calculate, color: cs.primary, size: 24),
            const SizedBox(width: 12),
            Text('消費税設定',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.primary)),
          ]),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _isExempt,
            onChanged: (v) => setState(() => _isExempt = v ?? false),
            title: const Text('課税売上高が1,000万円以下', style: TextStyle(fontSize: 14)),
            subtitle: const Text('免税事業者の場合、伝票に消費税を表示しません', style: TextStyle(fontSize: 11)),
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (!_isExempt) ...[
            const SizedBox(height: 8),
            H1FormField(
              controller: _regNumberCtrl,
              decoration: const InputDecoration(
                labelText: '適格請求書発行事業者登録番号（T番号）',
                hintText: 'T1234567890123',
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text('免税事業者の場合、適格請求書は発行できません',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildBankSection() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: cardDecoration(cs, radius: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance, color: cs.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                '振込先口座',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < 3; i++) _buildBankSlot(i, cs),
        ],
      ),
    );
  }

  Widget _buildBankSlot(int index, ColorScheme cs) {
    final account = _bankAccounts[index];
    return Padding(
      padding: EdgeInsets.only(top: index > 0 ? 16 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(account.isActive ? Icons.check_box : Icons.check_box_outline_blank,
                size: 20, color: account.isActive ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Text('口座${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              SizedBox(
                height: 28,
                child: Switch(
                  value: account.isActive,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) {
                    setState(() {
                      _bankAccounts[index] = account.copyWith(isActive: v);
                    });
                  },
                ),
              ),
            ],
          ),
          if (account.isActive) ...[
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: '銀行名', isDense: true,
              ),
              controller: TextEditingController(text: account.bankName)
                ..selection = TextSelection.collapsed(offset: account.bankName.length),
              onChanged: (v) => _bankAccounts[index] = account.copyWith(bankName: v),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: '支店名', isDense: true,
              ),
              controller: TextEditingController(text: account.branchName)
                ..selection = TextSelection.collapsed(offset: account.branchName.length),
              onChanged: (v) => _bankAccounts[index] = account.copyWith(branchName: v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: account.accountType,
                    decoration: const InputDecoration(
                      labelText: '口座種別', isDense: true,
                    ),
                    items: ['普通', '当座', 'その他']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 14))))
                      .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _bankAccounts[index] = account.copyWith(accountType: v));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: '口座番号', isDense: true,
                    ),
                    controller: TextEditingController(text: account.accountNumber)
                      ..selection = TextSelection.collapsed(offset: account.accountNumber.length),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _bankAccounts[index] = account.copyWith(accountNumber: v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
            decoration: const InputDecoration(
              labelText: '口座名義', isDense: true,
            ),
              controller: TextEditingController(text: account.holderName)
                ..selection = TextSelection.collapsed(offset: account.holderName.length),
              onChanged: (v) => _bankAccounts[index] = account.copyWith(holderName: v),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFiscalYearSection() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: cardDecoration(cs, radius: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.calendar_month, color: cs.primary, size: 24),
            const SizedBox(width: 12),
            Text('年度設定',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.primary)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('決算月', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                DropdownButtonFormField<int>(
                  value: _fiscalYearStart,
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  items: List.generate(12, (i) => i + 1).map((m) =>
                    DropdownMenuItem(value: m, child: Text('${m}月'))).toList(),
                  onChanged: (v) { if (v != null) setState(() => _fiscalYearStart = v); },
                ),
              ],
            )),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('決算日', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                DropdownButtonFormField<int>(
                  value: _closingDay,
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  items: [1, 5, 10, 15, 20, 25, 28, 31].map((d) =>
                    DropdownMenuItem(value: d, child: Text('${d}日'))).toList(),
                  onChanged: (v) { if (v != null) setState(() => _closingDay = v); },
                ),
              ],
            )),
          ]),
          const SizedBox(height: 8),
          Text('決算日より前の日付の確定伝票は編集できなくなります',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildSealSection() {
    final hasSeal = _info?.sealPath != null;
    final cs3 = Theme.of(context).colorScheme;
    return Container(
      decoration: cardDecoration(cs3, radius: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.image, color: Theme.of(context).colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                '印影（角印）',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasSeal) ...[
            Center(
              child: Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Transform.rotate(
                    angle: -(_info?.sealRotation ?? 0) * 3.14159265359 / 180,
                    child: Opacity(
                      opacity: _info?.sealOpacity ?? 1.0,
                      child: Image.file(File(_info!.sealPath!), fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _sealButton(
                icon: Icons.camera_alt,
                label: '撮影',
                onPressed: _takeSealPhoto,
              ),
              _sealButton(
                icon: Icons.photo_library,
                label: '選択',
                onPressed: _pickImageFromGallery,
              ),
              if (hasSeal)
                _sealButton(
                  icon: Icons.delete,
                  label: '削除',
                  onPressed: _deleteSeal,
                  isDestructive: true,
                ),
            ],
          ),
          if (hasSeal) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _sealButton(
                  icon: Icons.tune,
                  label: 'コントラスト調整',
                  onPressed: _adjustContrast,
                ),
                _sealButton(
                  icon: Icons.tune,
                  label: '位置調整',
                  onPressed: _adjustOffset,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: '左回転',
                  icon: const Icon(Icons.rotate_left),
                  onPressed: () {
                    setState(() {
                      _info = _info!.copyWith(
                        sealRotation: (_info?.sealRotation ?? 0) + 1.0,
                      );
                    });
                  },
                ),
                Text(
                  '${(_info?.sealRotation ?? 0).toStringAsFixed(0)}\u00b0',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  tooltip: '右回転',
                  icon: const Icon(Icons.rotate_right),
                  onPressed: () {
                    setState(() {
                      _info = _info!.copyWith(
                        sealRotation: (_info?.sealRotation ?? 0) - 1.0,
                      );
                    });
                  },
                ),
                TextButton(
                  onPressed: (_info?.sealRotation ?? 0) == 0.0
                      ? null
                      : () {
                          setState(() {
                            _info = _info!.copyWith(sealRotation: 0.0);
                          });
                        },
                  child: const Text('リセット'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            hasSeal
                ? '撮影または選択した画像を角印として使用します'
                : 'カメラで撮影するか、ギャラリーから画像を選択してください',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _sealButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Theme.of(context).colorScheme.error : null;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: color),
      label: Text(label, style: color != null ? TextStyle(color: color) : null),
      style: color != null
          ? OutlinedButton.styleFrom(side: BorderSide(color: color))
          : null,
    );
  }
}
