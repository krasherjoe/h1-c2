import 'dart:math';
import 'package:flutter/material.dart';
import '../models/case_model.dart';
import '../../purchase/models/purchase_model.dart';

enum TimelineEventType { caseEvent, purchaseOrder, purchaseReceipt, delivery, tracking }

extension TimelineEventTypeMeta on TimelineEventType {
  String get label {
    return switch (this) {
      TimelineEventType.caseEvent => '案件',
      TimelineEventType.purchaseOrder => '発注',
      TimelineEventType.purchaseReceipt => '入荷',
      TimelineEventType.delivery => '配送',
      TimelineEventType.tracking => '追跡',
    };
  }

  IconData get icon {
    return switch (this) {
      TimelineEventType.caseEvent => Icons.assignment,
      TimelineEventType.purchaseOrder => Icons.shopping_cart,
      TimelineEventType.purchaseReceipt => Icons.inventory_2,
      TimelineEventType.delivery => Icons.local_shipping,
      TimelineEventType.tracking => Icons.track_changes,
    };
  }

  Color color(ThemeData theme) {
    final cs = theme.colorScheme;
    return switch (this) {
      TimelineEventType.caseEvent => cs.primary,
      TimelineEventType.purchaseOrder => cs.tertiary,
      TimelineEventType.purchaseReceipt => Colors.green,
      TimelineEventType.delivery => Colors.orange,
      TimelineEventType.tracking => Colors.blue,
    };
  }
}

class GanttChartItem {
  final String id;
  final String title;
  final DateTime startDate;
  final DateTime? endDate;
  final int status;
  final String type;
  final String? assignee;
  final TimelineEventType eventType;
  final String? courier;
  final String? trackingNumber;
  final String? supplierName;

  GanttChartItem({
    required this.id,
    required this.title,
    required this.startDate,
    this.endDate,
    this.status = 0,
    this.type = '',
    this.assignee,
    this.eventType = TimelineEventType.caseEvent,
    this.courier,
    this.trackingNumber,
    this.supplierName,
  });

  factory GanttChartItem.fromCase(CaseModel c) => GanttChartItem(
    id: c.id,
    title: c.title,
    startDate: c.createdAt,
    endDate: c.dueDate,
    status: c.status,
    type: c.type,
    assignee: c.assignee,
    eventType: TimelineEventType.caseEvent,
  );

  factory GanttChartItem.fromPurchase(PurchaseModel p) {
    final isOrder = p.purchaseType == PurchaseType.order;
    return GanttChartItem(
      id: 'purchase_${p.id}',
      title: isOrder ? '発注: ${p.supplierName}' : '入荷: ${p.supplierName}',
      startDate: p.date,
      endDate: isOrder ? (p.expectedArrivalDate ?? p.date.add(const Duration(days: 14))) : p.date,
      status: p.isConfirmed ? 3 : 1,
      type: p.purchaseType.name,
      assignee: null,
      eventType: isOrder ? TimelineEventType.purchaseOrder : TimelineEventType.purchaseReceipt,
      courier: p.courier,
      trackingNumber: p.trackingNumber,
      supplierName: p.supplierName,
    );
  }

  bool get isActive => status < 99;
  String get statusLabel {
    return switch (status) {
      0 => 'draft',
      >= 1 && < 3 => 'active',
      >= 3 => 'done',
      _ => 'unknown',
    };
  }
}

enum GanttFilter { all, assignee, type }

class GanttChartWidget extends StatefulWidget {
  final List<GanttChartItem> items;
  final String? highlightId;
  final GanttFilter initialFilter;
  final void Function(String caseId)? onItemTap;
  final Future<void> Function(String caseId, DateTime newDueDate)? onDueDateChange;

  const GanttChartWidget({
    super.key,
    required this.items,
    this.highlightId,
    this.initialFilter = GanttFilter.all,
    this.onItemTap,
    this.onDueDateChange,
  });

  @override
  State<GanttChartWidget> createState() => _GanttChartWidgetState();
}

class _GanttChartWidgetState extends State<GanttChartWidget> {
  static const double _dayWidth = 28;
  static const double _rowHeight = 36;
  static const double _headerHeight = 30;
  static const double _leftWidth = 130;
  static const double _barHeight = 24;
  static const double _barRadius = 6;

  final _hScroll = ScrollController();
  String? _draggingId;
  DateTime? _dragStartDue;

  List<GanttChartItem> get _filtered {
    final f = widget.items.where((i) => i.status < 99).toList();
    return f;
  }

  DateTime get _minDate {
    if (_filtered.isEmpty) return DateTime.now().subtract(const Duration(days: 7));
    final dates = _filtered.map((i) => i.startDate);
    return dates.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  DateTime get _maxDate {
    if (_filtered.isEmpty) return DateTime.now().add(const Duration(days: 30));
    final dates = _filtered
        .map((i) => i.endDate ?? i.startDate.add(const Duration(days: 30)))
        .followedBy([DateTime.now().add(const Duration(days: 14))]);
    return dates.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  int get _totalDays => _maxDate.difference(_minDate).inDays + 14;
  double get _timelineWidth => max(300, _totalDays * _dayWidth);
  double get _totalHeight => _headerHeight + _filtered.length * _rowHeight + 16;

  double _dayToX(DateTime d) {
    return d.difference(_minDate).inDays * _dayWidth;
  }

  double _barStartX(GanttChartItem item) => _dayToX(item.startDate);

  double _barWidth(GanttChartItem item) {
    final end = item.endDate ?? item.startDate.add(const Duration(days: 7));
    final days = max(1, end.difference(item.startDate).inDays);
    return days * _dayWidth;
  }

  Color _itemColor(GanttChartItem item) {
    final base = item.eventType.color(Theme.of(context));
    if (item.statusLabel == 'done') return base.withValues(alpha: 0.5);
    return base;
  }

  void _startDrag(String id) {
    final item = _filtered.firstWhere((i) => i.id == id);
    _draggingId = id;
    _dragStartDue = item.endDate ?? item.startDate.add(const Duration(days: 7));
  }

  void _updateDrag(Offset delta) {
    if (_draggingId == null || _dragStartDue == null) return;
    final dayDelta = (delta.dx / _dayWidth).round();
    final newDue = _dragStartDue!.add(Duration(days: dayDelta));
    final now = DateTime.now();
    final clamped = newDue.isBefore(now) ? now : newDue;
    setState(() {
      final idx = _filtered.indexWhere((i) => i.id == _draggingId);
      if (idx >= 0) {
        final old = _filtered[idx];
        _filtered[idx] = GanttChartItem(
          id: old.id,
          title: old.title,
          startDate: old.startDate,
          endDate: clamped,
          status: old.status,
          type: old.type,
          assignee: old.assignee,
          eventType: old.eventType,
          courier: old.courier,
          trackingNumber: old.trackingNumber,
          supplierName: old.supplierName,
        );
      }
    });
  }

  void _endDrag() async {
    final id = _draggingId;
    final due = _dragStartDue;
    _draggingId = null;
    _dragStartDue = null;
    if (id == null || due == null) return;
    final original = widget.items.firstWhere((i) => i.id == id);
    final finalDue = original.endDate ?? original.startDate.add(const Duration(days: 7));
    if (finalDue != due) {
      await widget.onDueDateChange?.call(id, finalDue);
    }
  }

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    try {
      return _build(context);
    } catch (e, st) {
      print('GanttChartWidget error: $e\n$st');
      return SizedBox(
        height: 60,
        child: Center(
          child: Text('Gantt: $e', style: const TextStyle(color: Colors.red, fontSize: 11)),
        ),
      );
    }
  }

  Widget _build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.surface;
    final gridColor = cs.outlineVariant.withValues(alpha: 0.3);

    if (_filtered.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text('タイムラインに表示する案件がありません', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      return SizedBox(
        height: _totalHeight + 8,
        child: ClipRect(
          child: Stack(
            children: [
              // Scrollable timeline
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _hScroll,
                child: SizedBox(
                  width: _leftWidth + _timelineWidth,
                  height: _totalHeight,
                  child: Stack(
                    children: [
                      // Grid + header + bar shapes + titles (all in paint)
                      CustomPaint(
                        size: Size(_leftWidth + _timelineWidth, _totalHeight),
                        painter: _GanttPainter(
                          items: _filtered,
                          highlightId: widget.highlightId,
                          minDate: _minDate,
                          dayWidth: _dayWidth,
                          rowHeight: _rowHeight,
                          headerHeight: _headerHeight,
                          leftWidth: _leftWidth,
                          barHeight: _barHeight,
                          barRadius: _barRadius,
                          itemColorFn: _itemColor,
                          bgColor: bg,
                          gridColor: gridColor,
                          todayX: _dayToX(DateTime.now()),
                        ),
                      ),
                      // GestureDetectors per bar
                      for (int i = 0; i < _filtered.length; i++)
                        Positioned(
                          left: _leftWidth + _barStartX(_filtered[i]),
                          top: _headerHeight + i * _rowHeight + (_rowHeight - _barHeight) / 2,
                          width: _barWidth(_filtered[i]),
                          height: _barHeight,
                          child: GestureDetector(
                            onTap: () => widget.onItemTap?.call(_filtered[i].id),
                            onLongPressStart: (_) => _startDrag(_filtered[i].id),
                            onLongPressMoveUpdate: (d) => _updateDrag(d.offsetFromOrigin),
                            onLongPressEnd: (_) => _endDrag(),
                            behavior: HitTestBehavior.opaque,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Fixed left column overlay (titles)
              Positioned(
                left: 0,
                top: 0,
                width: _leftWidth,
                height: _totalHeight,
                child: IgnorePointer(
                  child: Container(
                    color: bg,
                    child: Column(
                      children: [
                        SizedBox(
                          height: _headerHeight,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text('イベント', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                            ),
                          ),
                        ),
                        for (int i = 0; i < _filtered.length; i++)
                          SizedBox(
                            height: _rowHeight,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8, right: 4),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _filtered[i].title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _filtered[i].id == widget.highlightId ? cs.primary : cs.onSurface,
                                    fontWeight: _filtered[i].id == widget.highlightId ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _GanttPainter extends CustomPainter {
  final List<GanttChartItem> items;
  final String? highlightId;
  final DateTime minDate;
  final double dayWidth;
  final double rowHeight;
  final double headerHeight;
  final double leftWidth;
  final double barHeight;
  final double barRadius;
  final Color Function(GanttChartItem) itemColorFn;
  final Color bgColor;
  final Color gridColor;
  final double todayX;

  _GanttPainter({
    required this.items,
    required this.highlightId,
    required this.minDate,
    required this.dayWidth,
    required this.rowHeight,
    required this.headerHeight,
    required this.leftWidth,
    required this.barHeight,
    required this.barRadius,
    required this.itemColorFn,
    required this.bgColor,
    required this.gridColor,
    required this.todayX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final totalDays = (size.width - leftWidth) / dayWidth;
    if (totalDays <= 0) return;

    _drawGrid(canvas, size, totalDays);
    _drawHeader(canvas, size, totalDays);
    _drawBars(canvas, size);
    _drawTodayLine(canvas, size);
    _drawLeftEdgeShadow(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size, double totalDays) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    // Vertical lines (per day, only draw week start bolds)
    final weekPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.15)
      ..strokeWidth = 0.5;

    for (int d = 0; d < totalDays.toInt(); d++) {
      final x = leftWidth + d * dayWidth;
      final date = minDate.add(Duration(days: d));
      if (date.weekday == 1) {
        canvas.drawLine(Offset(x, headerHeight), Offset(x, size.height), weekPaint);
      } else {
        canvas.drawLine(Offset(x, headerHeight), Offset(x, size.height), gridPaint);
      }
    }

    // Horizontal lines
    final hLinePaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;
    for (int i = 0; i <= items.length; i++) {
      final y = headerHeight + i * rowHeight;
      canvas.drawLine(Offset(leftWidth, y), Offset(size.width, y), hLinePaint);
    }
  }

  void _drawHeader(Canvas canvas, Size size, double totalDays) {
    final textStyle = TextStyle(color: Colors.grey[600], fontSize: 9, fontWeight: FontWeight.w500);
    final todayStyle = TextStyle(color: Colors.grey[800], fontSize: 9, fontWeight: FontWeight.w600);

    // Header background
    final headerBgPaint = Paint()..color = bgColor;
    canvas.drawRect(Rect.fromLTWH(leftWidth, 0, size.width - leftWidth, headerHeight), headerBgPaint);

    // Bottom border
    final borderPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(Offset(leftWidth, headerHeight), Offset(size.width, headerHeight), borderPaint);

    // Date labels
    int? lastMonth;
    for (int d = 0; d < totalDays.toInt(); d++) {
      final x = leftWidth + d * dayWidth;
      final date = minDate.add(Duration(days: d));
      final month = date.month;
      final day = date.day;

      if (month != lastMonth || day == 1) {
        lastMonth = month;
        final label = day == 1 ? '${date.month}/${date.day}' : '${date.day}';
        final tp = TextPainter(
          text: TextSpan(text: label, style: day == 1 ? todayStyle : textStyle),
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(x + 2, headerHeight - 12));
      }
    }
  }

  void _drawBars(Canvas canvas, Size size) {
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final barX = leftWidth + item.startDate.difference(minDate).inDays * dayWidth;
      final barY = headerHeight + i * rowHeight + (rowHeight - barHeight) / 2;

      final end = item.endDate ?? item.startDate.add(const Duration(days: 7));
      final days = max(1, end.difference(item.startDate).inDays);
      final barW = days * dayWidth;

      if (barX + barW < leftWidth || barX > size.width) continue;

      final color = itemColorFn(item);
      final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(barX, barY, barW, barHeight), Radius.circular(barRadius));

      // Bar shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawRRect(rrect.shift(const Offset(0, 1)), shadowPaint);

      // Bar gradient fill
      final gradient = LinearGradient(
        colors: [color.withValues(alpha: 0.85), color],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );
      final fillPaint = Paint()..shader = gradient.createShader(rrect.outerRect);
      canvas.drawRRect(rrect, fillPaint);

      // Bar outline
      final outlinePaint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      canvas.drawRRect(rrect, outlinePaint);

      // Progress indicator (thin line at bottom)
      final progress = item.status >= 99 ? 1.0 : min(1.0, item.status / 3 * 0.8);
      if (progress > 0) {
        final progRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(barX + 1, barY + barHeight - 3, max(2, (barW - 2) * progress), 2.5),
          Radius.circular(1),
        );
        final progPaint = Paint()..color = Colors.white.withValues(alpha: 0.6);
        canvas.drawRRect(progRect, progPaint);
      }

      // Drag handle (small triangle on right edge)
      if (item.status < 99) {
        final handlePaint = Paint()..color = Colors.white.withValues(alpha: 0.4);
        final hx = barX + barW - 1;
        final hy = barY + barHeight / 2;
        final path = Path()
          ..moveTo(hx - 4, hy - 4)
          ..lineTo(hx, hy)
          ..lineTo(hx - 4, hy + 4)
          ..close();
        canvas.drawPath(path, handlePaint);
      }

      // Highlight glow for current item
      if (item.id == highlightId) {
        final glowPaint = Paint()
          ..color = Colors.blue.withValues(alpha: 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawRRect(rrect.inflate(3), glowPaint);
      }
    }
  }

  void _drawTodayLine(Canvas canvas, Size size) {
    final x = leftWidth + todayX;
    if (x < leftWidth || x > size.width) return;

    final dashPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.6)
      ..strokeWidth = 1.5;

    // Draw dashed line
    const dash = 4.0;
    const gap = 3.0;
    double y = headerHeight;
    while (y < size.height) {
      canvas.drawLine(Offset(x, y), Offset(x, min(y + dash, size.height)), dashPaint);
      y += dash + gap;
    }

    // "Today" label
    final tp = TextPainter(
      text: TextSpan(text: 'Today', style: TextStyle(color: Colors.red[700], fontSize: 8, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(x - tp.width / 2, headerHeight - 14));
  }

  void _drawLeftEdgeShadow(Canvas canvas, Size size) {
    final gradient = Paint()
      ..shader = LinearGradient(
        colors: [bgColor, bgColor.withValues(alpha: 0)],
        stops: const [0, 1],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(leftWidth, 0, 12, size.height));
    canvas.drawRect(Rect.fromLTWH(leftWidth, 0, 12, size.height), gradient);
  }

  @override
  bool shouldRepaint(_GanttPainter old) => true;
}
