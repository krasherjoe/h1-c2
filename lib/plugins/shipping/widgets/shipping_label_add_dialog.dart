import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/shipping_label_model.dart';
import '../models/tracking_model.dart';
import '../models/shipping_address_model.dart';
import '../services/tracking_repository.dart';
import '../screens/tracking_scanner_screen.dart';

class ShippingLabelAddDialog extends StatefulWidget {
  final ShippingLabel? initialLabel;
  final VoidCallback? onSaved;

  const ShippingLabelAddDialog({super.key, this.initialLabel, this.onSaved});

  @override
  State<ShippingLabelAddDialog> createState() => _ShippingLabelAddDialogState();
}

class _ShippingLabelAddDialogState extends State<ShippingLabelAddDialog> {
  final _formKey = GlobalKey<FormState>();
  final _trackingNumberController = TextEditingController();
  final _senderNameController = TextEditingController();
  final _senderZipController = TextEditingController();
  final _senderAddressController = TextEditingController();
  final _senderPhoneController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientZipController = TextEditingController();
  final _recipientAddressController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _recipientCompanyController = TextEditingController();
  final _contentsController = TextEditingController();
  final _quantityController = TextEditingController();
  final _weightController = TextEditingController();
  final _serviceTypeController = TextEditingController();
  final _codAmountController = TextEditingController();
  
  Carrier _selectedCarrier = Carrier.yamato;
  LabelType _selectedLabelType = LabelType.yamatoNeko;
  
  // 既存追跡との紐付け
  bool _linkExistingTracking = false;
  Tracking? _selectedTracking;
  List<Tracking> _availableTrackings = [];
  
  // 送付先アドレス帳からの選択
  bool _useAddressBook = false;
  ShippingAddress? _selectedAddress;
  List<ShippingAddress> _addresses = [];
  
  // 送付者アドレス帳からの選択
  bool _useSenderAddressBook = false;
  ShippingAddress? _selectedSenderAddress;
  List<ShippingAddress> _senderAddresses = [];
  
  final ShippingLabelRepository _labelRepo = ShippingLabelRepository();
  final ShippingAddressRepository _addressRepo = ShippingAddressRepository();
  final TrackingRepository _trackingRepo = TrackingRepository();
  
  @override
  void initState() {
    super.initState();
    if (widget.initialLabel != null) {
      _trackingNumberController.text = widget.initialLabel!.trackingNumber;
      _senderNameController.text = widget.initialLabel!.senderName;
      _senderZipController.text = widget.initialLabel!.senderZip;
      _senderAddressController.text = widget.initialLabel!.senderAddress;
      _senderPhoneController.text = widget.initialLabel!.senderPhone;
      _recipientNameController.text = widget.initialLabel!.recipientName;
      _recipientZipController.text = widget.initialLabel!.recipientZip;
      _recipientAddressController.text = widget.initialLabel!.recipientAddress;
      _recipientPhoneController.text = widget.initialLabel!.recipientPhone;
      _recipientCompanyController.text = widget.initialLabel!.recipientCompany ?? '';
      _contentsController.text = widget.initialLabel!.contents ?? '';
      _quantityController.text = widget.initialLabel!.quantity?.toString() ?? '';
      _weightController.text = widget.initialLabel!.weight?.toString() ?? '';
      _serviceTypeController.text = widget.initialLabel!.serviceType ?? '';
      _codAmountController.text = widget.initialLabel!.codAmount ?? '';
      _selectedCarrier = widget.initialLabel!.carrier;
      _selectedLabelType = widget.initialLabel!.labelType;
    } else {
      _loadDefaultAddress();
      _loadAvailableTrackings();
      _loadAddresses();
      _loadSenderAddresses();
    }
  }

  Future<void> _loadAvailableTrackings() async {
    final trackings = await _trackingRepo.getAll();
    // 紐付け済みの追跡は除外
    final available = trackings.where((t) => t.labelId == null).toList();
    if (mounted) {
      setState(() => _availableTrackings = available);
    }
  }

  Future<void> _loadAddresses() async {
    final addresses = await _addressRepo.getAll();
    if (mounted) {
      setState(() => _addresses = addresses);
    }
  }

  Future<void> _loadSenderAddresses() async {
    final addresses = await _addressRepo.getAll();
    if (mounted) {
      setState(() => _senderAddresses = addresses);
    }
  }

  Future<void> _loadDefaultAddress() async {
    final address = await _addressRepo.getDefault();
    if (address != null && mounted) {
      setState(() {
        _recipientNameController.text = address.name;
        _recipientCompanyController.text = address.company;
        _recipientZipController.text = address.zip;
        _recipientAddressController.text = address.address;
        _recipientPhoneController.text = address.phone;
      });
    }
  }

  @override
  void dispose() {
    _trackingNumberController.dispose();
    _senderNameController.dispose();
    _senderZipController.dispose();
    _senderAddressController.dispose();
    _senderPhoneController.dispose();
    _recipientNameController.dispose();
    _recipientZipController.dispose();
    _recipientAddressController.dispose();
    _recipientPhoneController.dispose();
    _recipientCompanyController.dispose();
    _contentsController.dispose();
    _quantityController.dispose();
    _weightController.dispose();
    _serviceTypeController.dispose();
    _codAmountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final labelId = widget.initialLabel?.id ?? const Uuid().v4();

    final label = ShippingLabel(
      id: labelId,
      carrier: _selectedCarrier,
      labelType: _selectedLabelType,
      trackingNumber: _trackingNumberController.text.trim(),
      senderName: _senderNameController.text.trim(),
      senderZip: _senderZipController.text.trim(),
      senderAddress: _senderAddressController.text.trim(),
      senderPhone: _senderPhoneController.text.trim(),
      recipientName: _recipientNameController.text.trim(),
      recipientZip: _recipientZipController.text.trim(),
      recipientAddress: _recipientAddressController.text.trim(),
      recipientPhone: _recipientPhoneController.text.trim(),
      recipientCompany: _recipientCompanyController.text.trim().isEmpty ? null : _recipientCompanyController.text.trim(),
      contents: _contentsController.text.trim().isEmpty ? null : _contentsController.text.trim(),
      quantity: int.tryParse(_quantityController.text.trim()),
      weight: int.tryParse(_weightController.text.trim()),
      serviceType: _serviceTypeController.text.trim().isEmpty ? null : _serviceTypeController.text.trim(),
      codAmount: _codAmountController.text.trim().isEmpty ? null : _codAmountController.text.trim(),
      createdAt: widget.initialLabel?.createdAt ?? DateTime.now(),
      printedAt: widget.initialLabel?.printedAt,
      entityType: widget.initialLabel?.entityType,
      entityId: widget.initialLabel?.entityId,
    );

    await _labelRepo.save(label);

    // 追跡番号との紐付け処理（新規作成時のみ）
    if (widget.initialLabel == null) {
      if (_linkExistingTracking && _selectedTracking != null) {
        // 既存追跡に labelId を設定
        final updatedTracking = _selectedTracking!.copyWith(labelId: labelId);
        await _trackingRepo.save(updatedTracking);
      } else {
        // 新規追跡を作成
        final existing = await _trackingRepo.getByLabelId(labelId);
        if (existing == null) {
          final tracking = Tracking(
            id: const Uuid().v4(),
            trackingNumber: _trackingNumberController.text.trim(),
            carrier: _selectedCarrier,
            direction: TrackingDirection.outbound,
            status: TrackingStatus.notShipped,
            trackingUpdatedAt: DateTime.now(),
            entityName: _recipientNameController.text.trim(),
            labelId: labelId,
          );
          await _trackingRepo.save(tracking);
        }
      }
    }

    if (mounted) {
      Navigator.pop(context, true);
      widget.onSaved?.call();
    }
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const TrackingScannerScreen()),
    );
    if (result != null && mounted) {
      _trackingNumberController.text = result;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('送り状を作成'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<Carrier>(
                initialValue: _selectedCarrier,
                decoration: const InputDecoration(
                  labelText: '宅配便会社',
                  border: OutlineInputBorder(),
                ),
                items: Carrier.values.map((carrier) {
                  return DropdownMenuItem(
                    value: carrier,
                    child: Text(carrier.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCarrier = value!;
                    _selectedLabelType = LabelType.values.firstWhere(
                      (l) => l.carrier == value.name,
                      orElse: () => LabelType.generic,
                    );
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<LabelType>(
                initialValue: _selectedLabelType,
                decoration: const InputDecoration(
                  labelText: '送り状種別',
                  border: OutlineInputBorder(),
                ),
                items: LabelType.values.where((l) => l.carrier == _selectedCarrier.name || l.carrier == 'generic').map((labelType) {
                  return DropdownMenuItem(
                    value: labelType,
                    child: Text(labelType.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedLabelType = value!);
                },
              ),
              const SizedBox(height: 16),
              // 既存追跡との紐付け（新規作成時のみ）
              if (widget.initialLabel == null) ...[
                CheckboxListTile(
                  title: const Text('既存の追跡番号と紐付ける'),
                  value: _linkExistingTracking,
                  onChanged: (value) {
                    setState(() {
                      _linkExistingTracking = value ?? false;
                      if (_linkExistingTracking) {
                        _selectedTracking = _availableTrackings.isNotEmpty ? _availableTrackings.first : null;
                        if (_selectedTracking != null) {
                          _trackingNumberController.text = _selectedTracking!.trackingNumber;
                          _selectedCarrier = _selectedTracking!.carrier;
                        }
                      } else {
                        _selectedTracking = null;
                        _trackingNumberController.clear();
                      }
                    });
                  },
                ),
                if (_linkExistingTracking) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Tracking>(
                    initialValue: _selectedTracking,
                    decoration: const InputDecoration(
                      labelText: '追跡番号を選択',
                      border: OutlineInputBorder(),
                    ),
                    items: _availableTrackings.map((tracking) {
                      return DropdownMenuItem(
                        value: tracking,
                        child: Text('${tracking.trackingNumber} (${tracking.carrier.displayName})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedTracking = value;
                        if (value != null) {
                          _trackingNumberController.text = value.trackingNumber;
                          _selectedCarrier = value.carrier;
                        }
                      });
                    },
                  ),
                ],
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _trackingNumberController,
                decoration: InputDecoration(
                  labelText: '追跡番号',
                  border: const OutlineInputBorder(),
                  enabled: !_linkExistingTracking,
                  suffixIcon: _linkExistingTracking 
                      ? null 
                      : IconButton(
                          icon: const Icon(Icons.qr_code_scanner),
                          onPressed: _scanBarcode,
                          tooltip: 'スキャン',
                        ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '追跡番号を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text('送付者情報', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              // 送付者アドレス帳からの選択（新規作成時のみ）
              if (widget.initialLabel == null) ...[
                CheckboxListTile(
                  title: const Text('アドレス帳から選択（送付者）'),
                  value: _useSenderAddressBook,
                  onChanged: (value) {
                    setState(() {
                      _useSenderAddressBook = value ?? false;
                      if (_useSenderAddressBook) {
                        _selectedSenderAddress = _senderAddresses.isNotEmpty ? _senderAddresses.first : null;
                        if (_selectedSenderAddress != null) {
                          _senderNameController.text = _selectedSenderAddress!.name;
                          _senderZipController.text = _selectedSenderAddress!.zip;
                          _senderAddressController.text = _selectedSenderAddress!.address;
                          _senderPhoneController.text = _selectedSenderAddress!.phone;
                        }
                      } else {
                        _selectedSenderAddress = null;
                        _senderNameController.clear();
                        _senderZipController.clear();
                        _senderAddressController.clear();
                        _senderPhoneController.clear();
                      }
                    });
                  },
                ),
                if (_useSenderAddressBook) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ShippingAddress>(
                    initialValue: _selectedSenderAddress,
                    decoration: const InputDecoration(
                      labelText: '送付者を選択',
                      border: OutlineInputBorder(),
                    ),
                    items: _senderAddresses.map((address) {
                      return DropdownMenuItem(
                        value: address,
                        child: Text('${address.name}（${address.company.isNotEmpty ? address.company : '個人'}）'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSenderAddress = value;
                        if (value != null) {
                          _senderNameController.text = value.name;
                          _senderZipController.text = value.zip;
                          _senderAddressController.text = value.address;
                          _senderPhoneController.text = value.phone;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ],
              TextFormField(
                controller: _senderNameController,
                decoration: InputDecoration(
                  labelText: '名前',
                  border: const OutlineInputBorder(),
                  enabled: !_useSenderAddressBook,
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
                controller: _senderZipController,
                decoration: InputDecoration(
                  labelText: '郵便番号',
                  border: const OutlineInputBorder(),
                  enabled: !_useSenderAddressBook,
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
                controller: _senderAddressController,
                decoration: InputDecoration(
                  labelText: '住所',
                  border: const OutlineInputBorder(),
                  enabled: !_useSenderAddressBook,
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
                controller: _senderPhoneController,
                decoration: InputDecoration(
                  labelText: '電話番号',
                  border: const OutlineInputBorder(),
                  enabled: !_useSenderAddressBook,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '電話番号を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text('宛先情報', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              // アドレス帳からの選択（新規作成時のみ）
              if (widget.initialLabel == null) ...[
                CheckboxListTile(
                  title: const Text('アドレス帳から選択'),
                  value: _useAddressBook,
                  onChanged: (value) {
                    setState(() {
                      _useAddressBook = value ?? false;
                      if (_useAddressBook) {
                        _selectedAddress = _addresses.isNotEmpty ? _addresses.first : null;
                        if (_selectedAddress != null) {
                          _recipientNameController.text = _selectedAddress!.name;
                          _recipientCompanyController.text = _selectedAddress!.company;
                          _recipientZipController.text = _selectedAddress!.zip;
                          _recipientAddressController.text = _selectedAddress!.address;
                          _recipientPhoneController.text = _selectedAddress!.phone;
                        }
                      } else {
                        _selectedAddress = null;
                        _recipientNameController.clear();
                        _recipientCompanyController.clear();
                        _recipientZipController.clear();
                        _recipientAddressController.clear();
                        _recipientPhoneController.clear();
                      }
                    });
                  },
                ),
                if (_useAddressBook) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ShippingAddress>(
                    initialValue: _selectedAddress,
                    decoration: const InputDecoration(
                      labelText: '送付先を選択',
                      border: OutlineInputBorder(),
                    ),
                    items: _addresses.map((address) {
                      return DropdownMenuItem(
                        value: address,
                        child: Text('${address.name}（${address.company.isNotEmpty ? address.company : '個人'}）'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedAddress = value;
                        if (value != null) {
                          _recipientNameController.text = value.name;
                          _recipientCompanyController.text = value.company;
                          _recipientZipController.text = value.zip;
                          _recipientAddressController.text = value.address;
                          _recipientPhoneController.text = value.phone;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ],
              TextFormField(
                controller: _recipientNameController,
                decoration: InputDecoration(
                  labelText: '名前',
                  border: const OutlineInputBorder(),
                  enabled: !_useAddressBook,
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
                controller: _recipientCompanyController,
                decoration: InputDecoration(
                  labelText: '会社名（任意）',
                  border: const OutlineInputBorder(),
                  enabled: !_useAddressBook,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _recipientZipController,
                decoration: InputDecoration(
                  labelText: '郵便番号',
                  border: const OutlineInputBorder(),
                  enabled: !_useAddressBook,
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
                controller: _recipientAddressController,
                decoration: InputDecoration(
                  labelText: '住所',
                  border: const OutlineInputBorder(),
                  enabled: !_useAddressBook,
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
                controller: _recipientPhoneController,
                decoration: InputDecoration(
                  labelText: '電話番号',
                  border: const OutlineInputBorder(),
                  enabled: !_useAddressBook,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '電話番号を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text('配送情報', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contentsController,
                decoration: const InputDecoration(
                  labelText: '内容品（任意）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: '個数（任意）',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      decoration: const InputDecoration(
                        labelText: '重量（g）',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _serviceTypeController,
                decoration: const InputDecoration(
                  labelText: 'サービスタイプ（任意）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codAmountController,
                decoration: const InputDecoration(
                  labelText: '代引金額（任意）',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
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
