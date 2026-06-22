import 'package:flutter/material.dart';
import 'tracking_list_screen.dart';
import 'shipping_label_screen.dart';
import 'shipping_address_screen.dart';
import 'shipping_stats_screen.dart';

class ShippingMainScreen extends StatefulWidget {
  const ShippingMainScreen({super.key});

  @override
  State<ShippingMainScreen> createState() => _ShippingMainScreenState();
}

class _ShippingMainScreenState extends State<ShippingMainScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('配送管理'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.local_shipping), text: '追跡一覧'),
            Tab(icon: Icon(Icons.print), text: '送り状'),
            Tab(icon: Icon(Icons.location_on), text: '送付先'),
            Tab(icon: Icon(Icons.bar_chart), text: '統計'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          TrackingListScreen(),
          ShippingLabelScreen(),
          ShippingAddressScreen(),
          ShippingStatsScreen(),
        ],
      ),
    );
  }
}
