import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/daily_models.dart';
import '../services/time_log_repository.dart';

class TimeTrackingScreen extends StatefulWidget {
  const TimeTrackingScreen({super.key});

  @override
  State<TimeTrackingScreen> createState() => _TimeTrackingScreenState();
}

class _TimeTrackingScreenState extends State<TimeTrackingScreen> {
  final _repo = TimeLogRepository();
  final _uuid = const Uuid();
  final _df = DateFormat('yyyy/MM/dd');
  final _nf = NumberFormat('#,##0.0');

  List<TimeLog> _logs = [];
  bool _loading = true;
  bool _timerRunning = false;
  DateTime? _timerStart;
  Timer? _timerTick;
  Duration _elapsed = Duration.zero;
  String? _selectedProjectId;
  double _totalHours = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timerTick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 1);

    final logs = await _repo.getAll(from: firstDay, to: lastDay);
    if (!mounted) return;
    double total = 0;
    for (final log in logs) {
      if (_selectedProjectId == null || log.projectId == _selectedProjectId) {
        total += log.hours;
      }
    }
    setState(() {
      _logs = logs;
      _totalHours = total;
      _loading = false;
    });
  }

  void _toggleTimer() {
    if (_timerRunning) {
      _timerTick?.cancel();
      setState(() => _timerRunning = false);
    } else {
      _timerStart = DateTime.now();
      _elapsed = Duration.zero;
      _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _elapsed = DateTime.now().difference(_timerStart!));
        }
      });
      setState(() => _timerRunning = true);
    }
  }

  String get _elapsedDisplay {
    final h = _elapsed.inHours;
    final m = _elapsed.inMinutes.remainder(60);
    final s = _elapsed.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _showAddDialog() async {
    final taskCtrl = TextEditingController();
    final hoursCtrl = TextEditingController();
    final memoCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('工数追加'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: taskCtrl,
            decoration: const InputDecoration(labelText: 'タスク名'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: hoursCtrl,
            decoration: const InputDecoration(labelText: '工数（時間）', hintText: '例: 1.5'),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: memoCtrl,
            decoration: const InputDecoration(labelText: 'メモ（任意）'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Text('日付: '),
            TextButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  selectedDate = picked;
                  (ctx as dynamic)?.setState(() {});
                }
              },
              child: Text(_df.format(selectedDate)),
            ),
          ]),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () async {
              final hours = double.tryParse(hoursCtrl.text);
              if (taskCtrl.text.isEmpty || hours == null || hours <= 0) return;
              await _repo.save(TimeLog(
                id: _uuid.v4(),
                taskId: taskCtrl.text,
                projectId: _selectedProjectId ?? '',
                date: selectedDate,
                hours: hours,
                memo: memoCtrl.text.isNotEmpty ? memoCtrl.text : null,
                createdAt: DateTime.now(),
              ));
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _load();
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _selectedProjectId == null
        ? _logs
        : _logs.where((l) => l.projectId == _selectedProjectId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('TI:工数管理'),
        actions: [
          TextButton.icon(
            onPressed: _timerRunning ? _toggleTimer : null,
            icon: const Icon(Icons.stop),
            label: Text(_elapsedDisplay,
                style:
                    const TextStyle(fontFamily: 'monospace', fontSize: 16)),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'timer',
            onPressed: _toggleTimer,
            child: Icon(_timerRunning ? Icons.stop : Icons.play_arrow),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'add',
            onPressed: _showAddDialog,
            child: const Icon(Icons.add),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_timerRunning)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.green.withValues(alpha: 0.1),
                    child: Text('計測中: $_elapsedDisplay',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                            fontFamily: 'monospace')),
                  ),
                Container(
                  padding: const EdgeInsets.all(12),
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                  child: Column(children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('今月合計: ',
                            style: const TextStyle(fontSize: 16)),
                        Text('${_nf.format(_totalHours)}h',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: cs.primary)),
                      ],
                    ),
                  ]),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('工数記録がありません'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final log = filtered[i];
                            return Dismissible(
                              key: ValueKey(log.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                color: cs.error,
                                child: const Icon(Icons.delete,
                                    color: Colors.white),
                              ),
                              onDismissed: (_) async {
                                await _repo.delete(log.id);
                                _load();
                              },
                              child: Card(
                                child: ListTile(
                                  title: Text(
                                      '${_nf.format(log.hours)}h',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                      '${_df.format(log.date)}${log.memo != null ? " / ${log.memo}" : ""}'),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
