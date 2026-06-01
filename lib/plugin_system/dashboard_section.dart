import 'package:flutter/material.dart';

class DashboardSection {
  final String id;
  final String title;
  final String? description;
  final int priority;
  final WidgetBuilder builder;
  final bool collapsible;

  const DashboardSection({
    required this.id,
    required this.title,
    this.description,
    required this.priority,
    required this.builder,
    this.collapsible = false,
  });
}
