import 'package:flutter/material.dart';
import '../models/tracking_model.dart';
import '../services/tracking_repository.dart';
import '../widgets/tracking_add_dialog.dart';
import 'tracking_detail_screen.dart';

class TrackingListScreen extends StatefulWidget {
  const TrackingListScreen({super.key});

  @override
  State<TrackingListScreen> createState() => _TrackingListScreenState();
}

class _TrackingListScreenState extends State<TrackingListScreen> {
  final TrackingRepository _trackingRepo = TrackingRepository();
  List<Tracking> _trackings = [];
  List<Tracking> _filteredTrackings = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  
  // フィルタ
  TrackingStatus? _filterStatus;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  bool _showFilterPanel = false;

  @override
  void initState() {
    super.initState();
    _loadTrackings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrackings() async {
    setState(() => _isLoading = true);
    try {
      final trackings = await _trackingRepo.getAll();
      setState(() {
        _trackings = trackings;
        _filteredTrackings = trackings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('追跡情報の読み込みに失敗しました: $e')),
        );
      }
    }
  }

  void _filterTrackings(String query) {
    setState(() {
      if (query.isEmpty && _filterStatus == null && _filterStartDate == null && _filterEndDate == null) {
        _filteredTrackings = _trackings;
      } else {
        _filteredTrackings = _trackings.where((tracking) {
          // テキスト検索
          final matchesText = query.isEmpty ||
              tracking.trackingNumber.toLowerCase().contains(query.toLowerCase()) ||
              (tracking.entityName?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
              tracking.carrier.displayName.toLowerCase().contains(query.toLowerCase());
          
          // ステータスフィルタ
          final matchesStatus = _filterStatus == null || tracking.status == _filterStatus;
          
          // 日付範囲フィルタ
          final matchesDate = (_filterStartDate == null || (tracking.shippedAt != null && tracking.shippedAt!.isAfter(_filterStartDate!))) &&
                            (_filterEndDate == null || (tracking.shippedAt != null && tracking.shippedAt!.isBefore(_filterEndDate!.add(const Duration(days: 1)))));
          
          return matchesText && matchesStatus && matchesDate;
        }).toList();
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _filterStatus = null;
      _filterStartDate = null;
      _filterEndDate = null;
      _showFilterPanel = false;
    });
    _filterTrackings(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_trackings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_shipping, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('追跡番号がありません'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _showAddTrackingDialog,
              icon: const Icon(Icons.add),
              label: const Text('追跡番号を追加'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: '追跡番号、紐付け先、宅配便会社で検索',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _filterTrackings,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(_showFilterPanel ? Icons.filter_list_off : Icons.filter_list),
                  tooltip: 'フィルタ',
                  onPressed: () {
                    setState(() => _showFilterPanel = !_showFilterPanel);
                  },
                ),
              ],
            ),
          ),
          // フィルタパネル
          if (_showFilterPanel) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('フィルタ', style: TextStyle(fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: _clearFilters,
                            child: const Text('クリア'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<TrackingStatus>(
                        initialValue: _filterStatus,
                        decoration: const InputDecoration(
                          labelText: 'ステータス',
                          border: OutlineInputBorder(),
                        ),
                        items: [null, ...TrackingStatus.values].map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(status?.displayName ?? 'すべて'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _filterStatus = value);
                          _filterTrackings(_searchController.text);
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                labelText: '開始日',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.calendar_today),
                                  onPressed: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: _filterStartDate ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (date != null) {
                                      setState(() => _filterStartDate = date);
                                      _filterTrackings(_searchController.text);
                                    }
                                  },
                                ),
                              ),
                              readOnly: true,
                              controller: TextEditingController(
                                text: _filterStartDate != null
                                    ? '${_filterStartDate!.year}/${_filterStartDate!.month}/${_filterStartDate!.day}'
                                    : '',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                labelText: '終了日',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.calendar_today),
                                  onPressed: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: _filterEndDate ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (date != null) {
                                      setState(() => _filterEndDate = date);
                                      _filterTrackings(_searchController.text);
                                    }
                                  },
                                ),
                              ),
                              readOnly: true,
                              controller: TextEditingController(
                                text: _filterEndDate != null
                                    ? '${_filterEndDate!.year}/${_filterEndDate!.month}/${_filterEndDate!.day}'
                                    : '',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: ListView.builder(
              itemCount: _filteredTrackings.length,
              itemBuilder: (context, index) {
                final tracking = _filteredTrackings[index];
                return ListTile(
                  leading: _getCarrierIcon(tracking.carrier),
                  title: Text(tracking.entityName ?? tracking.trackingNumber),
                  subtitle: Text('${tracking.carrier.displayName} ${tracking.direction.displayName}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(tracking.status.displayName),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 100,
                        child: LinearProgressIndicator(
                          value: tracking.status.progress / 100,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _showTrackingDetail(tracking),
                  onLongPress: () => _showTrackingMenu(tracking),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTrackingDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _getCarrierIcon(Carrier carrier) {
    switch (carrier) {
      case Carrier.yamato:
        return const Icon(Icons.local_shipping, color: Colors.blue);
      case Carrier.sagawa:
        return const Icon(Icons.local_shipping, color: Colors.green);
      case Carrier.jpPost:
        return const Icon(Icons.local_shipping, color: Colors.red);
      default:
        return const Icon(Icons.local_shipping, color: Colors.grey);
    }
  }

  void _showAddTrackingDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const TrackingAddDialog(),
    );
    if (result == true) {
      await _loadTrackings();
    }
  }

  void _showTrackingDetail(Tracking tracking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackingDetailScreen(tracking: tracking),
      ),
    ).then((_) => _loadTrackings());
  }

  void _showTrackingMenu(Tracking tracking) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('編集'),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(tracking);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('削除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteTracking(tracking);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(Tracking tracking) {
    showDialog(
      context: context,
      builder: (context) => TrackingAddDialog(
        initialTracking: tracking,
        onSaved: () => _loadTrackings(),
      ),
    );
  }

  Future<void> _deleteTracking(Tracking tracking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('追跡番号「${tracking.trackingNumber}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await _trackingRepo.delete(tracking.id);
        await _loadTrackings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('削除しました')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('削除に失敗しました: $e')),
          );
        }
      }
    }
  }
}