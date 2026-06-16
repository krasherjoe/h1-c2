import 'package:flutter/material.dart';
import '../services/payment_schedule_repository.dart';
import '../models/ar_models.dart';
import '../../../constants/screen_ids.dart';

class PaymentScheduleScreen extends StatefulWidget {
  const PaymentScheduleScreen({super.key});
  @override
  State<PaymentScheduleScreen> createState() => _PaymentScheduleScreenState();
}

class _PaymentScheduleScreenState extends State<PaymentScheduleScreen> {
  final PaymentScheduleRepository _repo = PaymentScheduleRepository();
  List<PaymentSchedule> _allSchedules = [];
  List<PaymentSchedule> _filtered = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final schedules = await _repo.getAllSchedules();
      if (!mounted) return;
      setState(() {
        _allSchedules = schedules;
        _applyFilter();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('読込失敗: $e')),
      );
    }
  }

  void _applyFilter() {
    switch (_filter) {
      case 'unpaid':
        _filtered = _allSchedules.where((s) => s.status == PaymentStatus.unpaid).toList();
        break;
      case 'overdue':
        _filtered = _allSchedules.where((s) => s.isOverdue).toList();
        break;
      case 'due_soon':
        _filtered = _allSchedules.where((s) => s.isDueSoon).toList();
        break;
      case 'paid':
        _filtered = _allSchedules.where((s) => s.status == PaymentStatus.paid).toList();
        break;
      default:
        _filtered = List.from(_allSchedules);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('${S.py}:支払予定'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) {
              setState(() {
                _filter = v;
                _applyFilter();
              });
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem(value: 'all', checked: _filter == 'all', child: const Text('全て')),
              CheckedPopupMenuItem(value: 'unpaid', checked: _filter == 'unpaid', child: const Text('未払')),
              CheckedPopupMenuItem(value: 'overdue', checked: _filter == 'overdue', child: const Text('延滞')),
              CheckedPopupMenuItem(value: 'due_soon', checked: _filter == 'due_soon', child: const Text('期日近')),
              CheckedPopupMenuItem(value: 'paid', checked: _filter == 'paid', child: const Text('支払済')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.payment, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      const Text('支払予定がありません'),
                      const SizedBox(height: 8),
                      Text('仕入データを登録すると支払予定が自動生成されます',
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final schedule = _filtered[i];
                    final statusColor = schedule.getStatusColor(cs);
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () => _showDetail(schedule),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(schedule.displayTitle,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(schedule.displaySubtitle,
                                            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(schedule.statusDisplayName,
                                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(schedule.displayAmount,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _markAsPaidFirstUnpaid(),
        child: const Icon(Icons.check_circle),
      ),
    );
  }

  void _showDetail(PaymentSchedule schedule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(schedule.displayTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('支払金額: ${schedule.displayAmount}'),
            Text('支払期日: ${schedule.dueDate.year}/${schedule.dueDate.month}/${schedule.dueDate.day}'),
            Text('ステータス: ${schedule.statusDisplayName}'),
            if (schedule.paidDate != null)
              Text('支払日: ${schedule.paidDate!.year}/${schedule.paidDate!.month}/${schedule.paidDate!.day}'),
            if (schedule.daysUntilDue >= 0)
              Text('期日まで: ${schedule.daysUntilDue}日')
            else
              Text('延滞日数: ${-schedule.daysUntilDue}日', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 8),
            Text('仕入伝票: ${schedule.documentNumber}'),
            Text('仕入先: ${schedule.supplierName}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる')),
          if (schedule.status == PaymentStatus.unpaid)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _markAsPaid(schedule);
              },
              child: const Text('支払済にする'),
            ),
        ],
      ),
    );
  }

  Future<void> _markAsPaid(PaymentSchedule schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: Text('${schedule.displayTitle}を支払済にしますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('支払済にする')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _repo.updateScheduleStatus(schedule.id, PaymentStatus.paid);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('支払済にしました')));
        await _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新に失敗しました: $e')));
      }
    }
  }

  Future<void> _markAsPaidFirstUnpaid() async {
    final unpaid = _allSchedules.where((s) => s.status == PaymentStatus.unpaid).toList();
    if (unpaid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未払いの支払予定はありません')),
      );
      return;
    }
    _markAsPaid(unpaid.first);
  }
}
