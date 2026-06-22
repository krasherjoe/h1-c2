import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/shipping_address_model.dart';
import '../services/tracking_repository.dart';

class ShippingAddressAddDialog extends StatefulWidget {
  final ShippingAddress? address;

  const ShippingAddressAddDialog({super.key, this.address});

  @override
  State<ShippingAddressAddDialog> createState() => _ShippingAddressAddDialogState();
}

class _ShippingAddressAddDialogState extends State<ShippingAddressAddDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _zipController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _isDefault = false;
  
  final ShippingAddressRepository _addressRepo = ShippingAddressRepository();

  @override
  void initState() {
    super.initState();
    if (widget.address != null) {
      _nameController.text = widget.address!.name;
      _companyController.text = widget.address!.company;
      _zipController.text = widget.address!.zip;
      _addressController.text = widget.address!.address;
      _phoneController.text = widget.address!.phone;
      _isDefault = widget.address!.isDefault;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _zipController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final address = ShippingAddress(
      id: widget.address?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      company: _companyController.text.trim(),
      zip: _zipController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      isDefault: _isDefault,
    );

    await _addressRepo.save(address);
    
    if (_isDefault) {
      await _addressRepo.setDefault(address.id);
    }
    
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.address == null ? '送付先を追加' : '送付先を編集'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '名前',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '名前を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _companyController,
                decoration: const InputDecoration(
                  labelText: '会社名（任意）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _zipController,
                decoration: const InputDecoration(
                  labelText: '郵便番号',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '郵便番号を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: '住所',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '住所を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: '電話番号',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '電話番号を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('デフォルト送付先'),
                value: _isDefault,
                onChanged: (value) {
                  setState(() => _isDefault = value ?? false);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
