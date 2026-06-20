import 'package:flutter/material.dart';
import '../../../models/project_model.dart';
import '../../../utils/app_theme.dart';

class ProjectTimelineWidget extends StatelessWidget {
  final Project project;
  const ProjectTimelineWidget({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final start = project.startDate;
    final end = project.endDate;
    final hasDates = start != null;

    final months = project.contractMonths ?? 1;
    final totalDays = hasDates && end != null
        ? end.difference(start).inDays
        : (hasDates ? months * 30 : 1);
    final now = DateTime.now();
    final elapsed = hasDates ? now.difference(start).inDays.clamp(0, totalDays) : 0;
    final progress = hasDates && totalDays > 0 ? elapsed / totalDays : 0.0;
    final overdue = hasDates && project.isOverdue;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: cs.shadow.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2)),
          BoxShadow(color: cs.shadow.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
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
          ]),
          const SizedBox(height: 16),
          if (!hasDates)
            _buildNoDates(cs)
          else ...[
            _buildDateLabels(start, end, cs),
            const SizedBox(height: 8),
            _buildTimelineBar(cs, progress, overdue),
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

  Widget _buildTimelineBar(ColorScheme cs, double progress, bool overdue) {
    final months = project.contractMonths ?? 1;
    final isDark = cs.brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return SizedBox(
          height: 40,
          child: CustomPaint(
            size: Size(w, 40),
            painter: TimelineBarPainter(
              progress: progress.clamp(0.0, 1.0),
              overdue: overdue,
              barColor: isDark ? AppTheme.timelineBarDark : AppTheme.timelineBarLight,
              overdueColor: isDark ? AppTheme.timelineOverdueDark : AppTheme.timelineOverdueLight,
              surfaceColor: isDark ? AppTheme.timelineBgDark : AppTheme.timelineBgLight,
              markerColor: AppTheme.timelineMarker,
              monthCount: months,
            ),
          ),
        );
      },
    );
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
      if (project.contractMonths != null && project.contractMonths! > 0)
        Text('${project.elapsedMonths}/${months}ヶ月',
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
    final r = barH / 2;

    // 背景バー
    final bgPaint = Paint()..color = surfaceColor;
    canvas.drawRRect(RRect.fromRectAndCorners(Rect.fromLTWH(0, barY, w, barH), topLeft: Radius.circular(r), bottomLeft: Radius.circular(r), topRight: Radius.circular(r), bottomRight: Radius.circular(r)), bgPaint);

    // 進捗バー
    if (progress > 0) {
      final color = overdue ? overdueColor : barColor;
      final fgPaint = Paint()..color = color;
      final fw = w * progress;
      canvas.drawRRect(RRect.fromRectAndCorners(Rect.fromLTWH(0, barY, fw, barH), topLeft: Radius.circular(r), bottomLeft: Radius.circular(r), topRight: Radius.circular(r), bottomRight: Radius.circular(r)), fgPaint);
    }

    // 縦線マーカー（現在位置：0進捗でも表示）
    final markerX = w * progress.clamp(0.0, 0.99);
    final markerPaint = Paint()
      ..color = markerColor
      ..strokeWidth = 2;
    canvas.drawLine(Offset(markerX, 0), Offset(markerX, h), markerPaint);
  }

  @override
  bool shouldRepaint(TimelineBarPainter old) =>
      old.progress != progress || old.overdue != overdue || old.monthCount != monthCount;
}
