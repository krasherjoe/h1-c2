import 'package:flutter/material.dart';
import '../services/accounting_repository.dart';
import '../../../services/customer_repository.dart';
import '../../../models/customer_model.dart';
import '../../../widgets/h1_text_field.dart';

class PaymentRegisterScreen extends StatefulWidget {
  const PaymentRegisterScreen({super.key});

  @override
  State<PaymentRegisterScreen> createState() => _PaymentRegisterScreenState();
}

class _PaymentRegisterScreenState extends State<PaymentRegisterScreen> {
  final _repo = AccountingRepository();
  final _customerRepo = CustomerRepository();
  String _customerId = '';
  String _customerName = '';
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  final _noteController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectCustomer() async {
    final result = await showSearch<String>(
      context: context,
      delegate: _CustomerSearchDelegate(repo: _customerRepo),
    );
    if (result != null && mounted) {
      final customer = await _customerRepo.getById(result);
      if (customer != null && mounted) {
        setState(() {
          _customerId = customer.id;
          _customerName = customer.displayName.isNotEmpty ? customer.displayName : customer.formalName;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_customerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('顧客を選択してください')),
      );
      return;
    }
    final amount = int.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('金額を入力してください')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _repo.savePayment({
        'id': _repo.generateId(),
        'type': 'received',
        'customer_id': _customerId,
        'document_id': null,
        'amount': amount,
        'date': _selectedDate.toIso8601String().substring(0, 10),
        'note': _noteController.text.isNotEmpty ? _noteController.text : null,
        'created_at': DateTime.now().toIso8601String(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('入金を登録しました')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存エラー: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('入金登録')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InkWell(
            onTap: _selectCustomer,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: '顧客',
                suffixIcon: Icon(Icons.search),
              ),
              child: Text(_customerName.isNotEmpty ? _customerName : 'タップして選択'),
            ),
          ),
          const SizedBox(height: 12),
          H1TextField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: '入金額',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null && mounted) {
                setState(() => _selectedDate = picked);
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: '日付',
                suffixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(
                '${_selectedDate.year}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.day.toString().padLeft(2, '0')}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          H1TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: '備考',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: _isSaving
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    icon: const Icon(Icons.save),
                    tooltip: '保存',
                    onPressed: _save,
                  ),
          ),
        ],
      ),
    );
  }
}

class _CustomerSearchDelegate extends SearchDelegate<String> {
  final CustomerRepository repo;

  _CustomerSearchDelegate({required this.repo});

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, ''),
  );

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults(context);

  Widget _buildSearchResults(BuildContext context) {
    if (query.isEmpty) return const Center(child: Text('顧客名を入力してください'));
    return FutureBuilder<List>(
      future: repo.searchCustomers(query),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('エラー: ${snapshot.error}'));
        }
        final customers = snapshot.data ?? [];
        if (customers.isEmpty) return const Center(child: Text('見つかりませんでした'));
        return ListView.builder(
          itemCount: customers.length,
          itemBuilder: (ctx, i) {
            final c = customers[i] as Customer;
            return ListTile(
              title: Text(c.displayName.isNotEmpty ? c.displayName : c.formalName),
              subtitle: Text(c.id),
              onTap: () => close(context, c.id),
            );
          },
        );
      },
    );
  }
}
