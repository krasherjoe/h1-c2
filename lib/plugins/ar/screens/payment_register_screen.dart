import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../services/error_reporter.dart';
import '../services/payment_repository.dart';
import '../services/payment_schedule_repository.dart';
import '../models/ar_models.dart';
import '../../../constants/screen_ids.dart';

class PaymentRegisterScreen extends StatefulWidget {
  const PaymentRegisterScreen({super.key});
  @override
  State<PaymentRegisterScreen> createState() => _PaymentRegisterScreenState();
}

class _PaymentRegisterScreenState extends State<PaymentRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _notesController = TextEditingController();

  final PaymentRepository _paymentRepo = PaymentRepository();
  final PaymentScheduleRepository _scheduleRepo = PaymentScheduleRepository();

  String? _selectedSupplierName;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.bankTransfer;
  List<PaymentSchedule> _selectedSchedules = [];
  List<PaymentSchedule> _availableSchedules = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);
    try {
      final schedules = await _scheduleRepo.getUpcomingSchedules(days: 90);
      if (!mounted) return;
      setState(() {
        _availableSchedules = schedules.where((s) => s.status == PaymentStatus.unpaid).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ErrorReporter.showError(context, message: 'PG: 支払予定の読込失敗: $e', screenId: S.pg);
    }
  }

  int get _totalSelectedAmount {
    return _selectedSchedules.fold(0, (sum, s) => sum + s.amount);
  }

  String _getPaymentMethodDisplayName(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.bankTransfer: return '銀行振込';
      case PaymentMethod.cash: return '現金';
      case PaymentMethod.creditCard: return 'クレジットカード';
      case PaymentMethod.advancePayment: return '代表者立替';
      case PaymentMethod.other: return 'その他';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('\${S.pg}:支払登録')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('支払対象', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('仕入先'),
                              Text(_selectedSupplierName ?? '(複数)',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_availableSchedules.isEmpty)
                            const Text('支払予定がありません')
                          else
                            ..._availableSchedules.map((schedule) {
                              final isSelected = _selectedSchedules.contains(schedule);
                              return CheckboxListTile(
                                dense: true,
                                title: Text(schedule.displayTitle, style: const TextStyle(fontSize: 13)),
                                subtitle: Text('${schedule.displayAmount} - ${schedule.displaySubtitle}',
                                    style: const TextStyle(fontSize: 11)),
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedSchedules.add(schedule);
                                    } else {
                                      _selectedSchedules.remove(schedule);
                                    }
                                    if (_selectedSchedules.isNotEmpty) {
                                      _amountController.text = _totalSelectedAmount.toString();
                                    }
                                    _selectedSupplierName = _selectedSchedules.isNotEmpty
                                        ? _selectedSchedules.first.supplierName
                                        : null;
                                  });
                                },
                              );
                            }),
                          if (_selectedSchedules.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text('合計: ${_totalSelectedAmount.toString().replaceAllMapped(
                                    RegExp(r'(?=(?!^)(\d{3})+$)'),
                                    (Match m) => ',',
                                  )}円', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('支払情報', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _amountController,
                            decoration: const InputDecoration(labelText: '支払金額', hintText: '0', prefixText: '¥'),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) return '金額を入力してください';
                              if (int.tryParse(value) == null) return '有効な数値を入力してください';
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<PaymentMethod>(
                            value: _selectedPaymentMethod,
                            decoration: const InputDecoration(labelText: '支払方法'),
                            items: PaymentMethod.values.map((method) {
                              return DropdownMenuItem(
                                value: method,
                                child: Text(_getPaymentMethodDisplayName(method)),
                              );
                            }).toList(),
                            onChanged: (method) {
                              setState(() => _selectedPaymentMethod = method!);
                            },
                          ),
                          if (_selectedPaymentMethod == PaymentMethod.bankTransfer) ...[
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _bankAccountController,
                              decoration: const InputDecoration(labelText: '振込口座', hintText: '123-456789'),
                            ),
                          ],
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _notesController,
                            decoration: const InputDecoration(labelText: '備考', hintText: '任意'),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _registerPayment,
                      child: const Text('支払を登録'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _registerPayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSchedules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('支払対象を選択してください')),
      );
      return;
    }

    try {
      final payment = Payment(
        id: const Uuid().v4(),
        paymentNumber: _paymentRepo.generatePaymentNumber(),
        paymentDate: DateTime.now(),
        supplierId: _selectedSchedules.first.purchaseId,
        supplierName: _selectedSchedules.first.supplierName,
        amount: int.parse(_amountController.text),
        paymentMethod: _selectedPaymentMethod,
        bankAccount: _bankAccountController.text.isEmpty ? null : _bankAccountController.text,
        purchaseIds: _selectedSchedules.map((s) => s.purchaseId).join(','),
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      await _paymentRepo.savePayment(payment);

      for (final schedule in _selectedSchedules) {
        await _scheduleRepo.updateScheduleStatus(
          schedule.id,
          PaymentStatus.paid,
          paymentId: payment.id,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('支払を登録しました')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ErrorReporter.showError(context, message: 'PG: 登録失敗: $e', screenId: S.pg);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _bankAccountController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
