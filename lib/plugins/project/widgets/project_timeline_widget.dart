import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../models/project_model.dart';
import '../../../utils/app_theme.dart';
import '../models/gantt_preset.dart';

class ProjectTimelineWidget extends StatefulWidget {
  final Project project;
  final List<Map<String, dynamic>> linkedDocs;
  final Function(GanttPreset)? onPresetChanged;
  final Function(GanttPreset)? onTaskDateChanged;
  const ProjectTimelineWidget({super.key, required this.project, required this.linkedDocs, this.onPresetChanged, this.onTaskDateChanged});

  @override
  State<ProjectTimelineWidget> createState() => _ProjectTimelineWidgetState();
}

class _ProjectTimelineWidgetState extends State<ProjectTimelineWidget> {
  late GanttPreset _currentPreset;

  @override
  void initState() {
    super.initState();
    _currentPreset = _loadPreset();
  }

  GanttPreset _loadPreset() {
    try {
      if (widget.project.ganttConfig != null && widget.project.ganttConfig!.isNotEmpty) {
        return GanttPreset.fromJson(
          jsonDecode(widget.project.ganttConfig!) as Map<String, dynamic>,
        );
      }
    } catch (_) {}
    return GanttPreset.standard;
  }

  void _showPresetDialog(BuildContext context, ColorScheme cs) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ガントチャートプリセット'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: GanttPreset.allPresets.map((preset) {
            final isSelected = preset.id == _currentPreset.id;
            return ListTile(
              title: Text(preset.name),
              trailing: isSelected ? Icon(Icons.check, color: cs.primary) : null,
              onTap: () async {
                setState(() => _currentPreset = preset);
                widget.onPresetChanged?.call(preset);
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final start = widget.project.startDate;
    final end = widget.project.endDate;
    final hasDates = start != null;

    final months = widget.project.contractMonths ?? 1;
    final totalDays = hasDates && end != null
        ? end.difference(start).inDays
        : (hasDates ? months * 30 : 1);
    final now = DateTime.now();
    final elapsed = hasDates ? now.difference(start).inDays.clamp(0, totalDays) : 0;
    final progress = hasDates && totalDays > 0 ? elapsed / totalDays : 0.0;
    final overdue = hasDates && widget.project.isOverdue;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [
          // 上と左の明るい影（凹んだ感）
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.15),
            offset: const Offset(-1, -1),
            blurRadius: 2,
          ),
          // 下と右の暗い影（凹んだ感）
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.25),
            offset: const Offset(1, 1),
            blurRadius: 3,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.timeline, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Text('タイムライン', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.settings, size: 18, color: cs.onSurfaceVariant),
              onPressed: () => _showPresetDialog(context, cs),
              tooltip: 'プリセット選択',
            ),
          ]),
          const SizedBox(height: 16),
          if (!hasDates)
            _buildNoDates(cs)
          else ...[
            _buildDateLabels(start, end, cs),
            const SizedBox(height: 8),
            _buildGanttChart(cs, start, end, _currentPreset, widget.linkedDocs, progress, overdue, widget.onTaskDateChanged),
            const SizedBox(height: 8),
            _buildProgressInfo(cs, progress, overdue, months),
          ],
        ],
      ),
    );
  }

  Widget _buildNoDates(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.primaryContainer, width: 1),
      ),
      child: Column(children: [
        Icon(Icons.date_range, size: 32, color: cs.primary.withValues(alpha: 0.6)),
        const SizedBox(height: 8),
        Text('開始日・契約期間を設定すると',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        Text('タイムラインが表示されます',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
      ]),
    );
  }

  Widget _buildDateLabels(DateTime start, DateTime? end, ColorScheme cs) {
    return Row(children: [
      Text(_fmt(start), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      const Spacer(),
      if (end != null)
        Text('${_fmt(start)} 〜 ${_fmt(end)}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
    ]);
  }

  Widget _buildGanttChart(
    ColorScheme cs,
    DateTime start,
    DateTime? end,
    GanttPreset preset,
    List<Map<String, dynamic>> linkedDocs,
    double progress,
    bool overdue,
    Function(GanttPreset)? onTaskDateChanged,
  ) {
    final isDark = cs.brightness == Brightness.dark;
    final totalDays = end != null ? end.difference(start).inDays : (widget.project.contractMonths ?? 1) * 30;

    return Column(
      children: preset.tasks.asMap().entries.map((entry) {
        final task = entry.value;

        return GestureDetector(
          onTap: () => _showTaskDatePicker(context, task, preset, onTaskDateChanged),
          child: Container(
            height: 32,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    task.label,
                    style: TextStyle(fontSize: 11, color: cs.onSurface),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return CustomPaint(
                        size: Size(constraints.maxWidth, 32),
                        painter: GanttTaskBarPainter(
                          start: start,
                          end: end,
                          totalDays: totalDays,
                          task: task,
                          barColor: isDark ? AppTheme.timelineBarDark : AppTheme.timelineBarLight,
                          surfaceColor: isDark ? AppTheme.timelineBgDark : AppTheme.timelineBgLight,
                        ),
                      );
                    },
                  ),
                ),
                if (task.date != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      _fmt(DateTime.parse(task.date!)),
                      style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _showTaskDatePicker(
    BuildContext context,
    GanttTask task,
    GanttPreset preset,
    Function(GanttPreset)? onTaskDateChanged,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: task.date != null ? DateTime.parse(task.date!) : widget.project.startDate ?? DateTime.now(),
      firstDate: widget.project.startDate ?? DateTime.now().subtract(const Duration(days: 365)),
      lastDate: widget.project.endDate ?? DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      final updatedTasks = preset.tasks.map((t) {
        if (t.id == task.id) {
          return t.copyWith(date: picked.toIso8601String());
        }
        return t;
      }).toList();
      final updatedPreset = preset.copyWith(tasks: updatedTasks);
      onTaskDateChanged?.call(updatedPreset);
    }
  }

  Widget _buildProgressInfo(ColorScheme cs, double progress, bool overdue, int months) {
    return Row(children: [
      Text('${(progress * 100).toInt()}% 経過',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: overdue ? Colors.red : cs.onSurface,
        )),
      const Spacer(),
      if (widget.project.contractMonths != null && widget.project.contractMonths! > 0)
        Text('${widget.project.elapsedMonths}/$monthsヶ月',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
    ]);
  }

  String _fmt(DateTime d) => '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
}

class TimelineBarPainter extends CustomPainter {
  final double progress;
  final bool overdue;
  final Color barColor;
  final Color overdueColor;
  final Color surfaceColor;
  final Color markerColor;
  final int monthCount;

  TimelineBarPainter({
    required this.progress,
    required this.overdue,
    required this.barColor,
    required this.overdueColor,
    required this.surfaceColor,
    required this.markerColor,
    this.monthCount = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    final barH = 16.0;
    final barY = (h - barH) / 2;

    // 背景バー（四角）
    final bgPaint = Paint()..color = surfaceColor;
    canvas.drawRect(Rect.fromLTWH(0, barY, w, barH), bgPaint);

    // 進捗バー（四角）
    if (progress > 0) {
      final color = overdue ? overdueColor : barColor;
      final fgPaint = Paint()..color = color;
      final fw = w * progress;
      canvas.drawRect(Rect.fromLTWH(0, barY, fw, barH), fgPaint);
    }

    // 赤丸マーカー（現在位置：0進捗でも表示）
    final markerX = w * progress.clamp(0.0, 0.99);
    final markerPaint = Paint()..color = markerColor;
    final markerRadius = 3.0;
    canvas.drawCircle(Offset(markerX, h / 2), markerRadius, markerPaint);
  }

  @override
  bool shouldRepaint(TimelineBarPainter old) =>
      old.progress != progress || old.overdue != overdue || old.monthCount != monthCount;
}

class GanttTaskBarPainter extends CustomPainter {
  final DateTime start;
  final DateTime? end;
  final int totalDays;
  final GanttTask task;
  final Color barColor;
  final Color surfaceColor;

  GanttTaskBarPainter({
    required this.start,
    required this.end,
    required this.totalDays,
    required this.task,
    required this.barColor,
    required this.surfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    final barH = 16.0;
    final barY = (h - barH) / 2;

    // 背景バー
    final bgPaint = Paint()..color = surfaceColor;
    canvas.drawRect(Rect.fromLTWH(0, barY, w, barH), bgPaint);

    // タスクバー
    if (task.date != null) {
      final taskDate = DateTime.parse(task.date!);
      final daysFromStart = taskDate.difference(start).inDays;
      if (daysFromStart >= 0 && daysFromStart <= totalDays) {
        final x = (daysFromStart / totalDays) * w;
        final barW = w * 0.15; // バー幅は固定
        final fgPaint = Paint()..color = barColor;
        canvas.drawRect(Rect.fromLTWH(x, barY, barW, barH), fgPaint);
      }
    }
  }

  @override
  bool shouldRepaint(GanttTaskBarPainter old) =>
      old.task.date != task.date || old.totalDays != totalDays;
}
