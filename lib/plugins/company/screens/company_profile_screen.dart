import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/company_info.dart';
import '../../../services/company_repository.dart';
import '../../../widgets/h1_form_field.dart';
import 'seal_contrast_dialog.dart';
import 'seal_camera_screen.dart';
import 'seal_offset_adjust_page.dart';

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
    }
    setState(() {
      _info = info;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final info = (_info ?? CompanyInfo(name: '')).copyWith(
      name: _nameController.text.trim(),
      zipCode: _postalController.text.trim().isEmpty ? null : _postalController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      tel: _telController.text.trim().isEmpty ? null : _telController.text.trim(),
      fax: _faxController.text.trim().isEmpty ? null : _faxController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
    );
    await _companyRepo.saveCompanyInfo(info);
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
      appBar: AppBar(title: const Text('CI:自社情報')),
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

                  // 角印管理セクション
                  _buildSealSection(),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('保存'),
                    onPressed: _save,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSealSection() {
    final hasSeal = _info?.sealPath != null;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.15),
      ),
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
                    child: Image.file(File(_info!.sealPath!), fit: BoxFit.contain),
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
