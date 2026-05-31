import 'package:flutter/material.dart';
import '../models/customer_model.dart';
import '../widgets/screen_id_title.dart';

class CustomerEditScreen extends StatefulWidget {
  final Customer? customer;
  const CustomerEditScreen({super.key, this.customer});
  @override
  State<CustomerEditScreen> createState() => _CustomerEditScreenState();
}

class _CustomerEditScreenState extends State<CustomerEditScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const ScreenAppBarTitle(screenId: 'C1', title: '顧客編集')),
      body: const Center(child: Text('顧客編集 - コア版では未実装')),
    );
  }
}
