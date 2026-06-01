import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../../plugin_system/plugin_registry.dart';
import '../models/company_profile.dart';
import '../services/company_repository.dart';

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
  bool _isLoading = true;

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

  Database get _db => PluginRegistry.instance.getContext()!.database;

  Future<void> _loadProfile() async {
    final repo = CompanyRepository(_db);
    final profile = await repo.loadProfile();
    if (profile != null) {
      _nameController.text = profile.name;
      _postalController.text = profile.postalCode;
      _addressController.text = profile.address;
      _telController.text = profile.tel;
      _faxController.text = profile.fax;
      _emailController.text = profile.email;
    }
    setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = CompanyProfile(
      name: _nameController.text.trim(),
      postalCode: _postalController.text.trim(),
      address: _addressController.text.trim(),
      tel: _telController.text.trim(),
      fax: _faxController.text.trim(),
      email: _emailController.text.trim(),
    );
    final repo = CompanyRepository(_db);
    await repo.saveProfile(profile);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('保存しました')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('自社情報')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '会社名',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? '必須です' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _postalController,
                    decoration: const InputDecoration(
                      labelText: '郵便番号',
                      hintText: '000-0000',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: '住所',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _telController,
                    decoration: const InputDecoration(
                      labelText: '電話番号',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _faxController,
                    decoration: const InputDecoration(
                      labelText: 'FAX',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'メールアドレス',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
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
}
