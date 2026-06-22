import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:h_1_core/services/error_log_service.dart';
import '../models/tracking_model.dart';
import '../services/tracking_repository.dart';
import '../screens/tracking_scanner_screen.dart';

class TrackingAddDialog extends StatefulWidget {
  final Tracking? initialTracking;
  final VoidCallback? onSaved;

  const TrackingAddDialog({super.key, this.initialTracking, this.onSaved});

  @override
  State<TrackingAddDialog> createState() => _TrackingAddDialogState();
}

class _TrackingAddDialogState extends State<TrackingAddDialog> {
  final _formKey = GlobalKey<FormState>();
  final _trackingNumberController = TextEditingController();
  final _notesController = TextEditingController();
  final _entityNameController = TextEditingController();
  
  Carrier _selectedCarrier = Carrier.yamato;
  TrackingDirection _selectedDirection = TrackingDirection.outbound;
  TrackingStatus _selectedStatus = TrackingStatus.notShipped;
  
  final TrackingRepository _trackingRepo = TrackingRepository();

  @override
  void initState() {
    super.initState();
    if (widget.initialTracking != null) {
      _trackingNumberController.text = widget.initialTracking!.trackingNumber;
      _entityNameController.text = widget.initialTracking!.entityName ?? '';
      _notesController.text = widget.initialTracking!.notes ?? '';
      _selectedCarrier = widget.initialTracking!.carrier;
      _selectedDirection = widget.initialTracking!.direction;
      _selectedStatus = widget.initialTracking!.status;
    }
  }

  @override
  void dispose() {
    _trackingNumberController.dispose();
    _notesController.dispose();
    _entityNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final tracking = Tracking(
        id: widget.initialTracking?.id ?? const Uuid().v4(),
        trackingNumber: _trackingNumberController.text.trim(),
        carrier: _selectedCarrier,
        direction: _selectedDirection,
        status: _selectedStatus,
        shippedAt: widget.initialTracking?.shippedAt ?? (_selectedStatus != TrackingStatus.notShipped ? DateTime.now() : null),
        deliveredAt: widget.initialTracking?.deliveredAt,
        trackingUpdatedAt: DateTime.now(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        entityName: _entityNameController.text.trim().isEmpty ? null : _entityNameController.text.trim(),
        entityType: widget.initialTracking?.entityType,
        entityId: widget.initialTracking?.entityId,
      );

      await _trackingRepo.save(tracking);
      
      if (mounted) {
        Navigator.pop(context, true);
        widget.onSaved?.call();
      }
    } catch (e, stackTrace) {
      ErrorLogService.instance.logError(
        '追跡番号保存エラー: $e',
        stackTrace: stackTrace.toString(),
        screen: 'TrackingAddDialog',
        context: '追跡番号保存',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _scanBarcode() async {
    try {
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const TrackingScannerScreen()),
      );
      if (result != null && mounted) {
        _trackingNumberController.text = result;
      }
    } catch (e, stackTrace) {
      ErrorLogService.instance.logError(
        'バーコードスキャン起動エラー: $e',
        stackTrace: stackTrace.toString(),
        screen: 'TrackingAddDialog',
        context: 'バーコードスキャン起動',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('スキャン起動に失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialTracking != null ? '追跡番号を編集' : '追跡番号を追加'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _trackingNumberController,
                decoration: InputDecoration(
                  labelText: '追跡番号',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
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
              const SizedBox(height: 16),
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
                  setState(() => _selectedCarrier = value!);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TrackingDirection>(
                initialValue: _selectedDirection,
                decoration: const InputDecoration(
                  labelText: '送信/受信',
                  border: OutlineInputBorder(),
                ),
                items: TrackingDirection.values.map((direction) {
                  return DropdownMenuItem(
                    value: direction,
                    child: Text(direction.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedDirection = value!);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TrackingStatus>(
                initialValue: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'ステータス',
                  border: OutlineInputBorder(),
                ),
                items: TrackingStatus.values.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(status.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedStatus = value!);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _entityNameController,
                decoration: const InputDecoration(
                  labelText: '紐付け先名（任意）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'メモ（任意）',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
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
