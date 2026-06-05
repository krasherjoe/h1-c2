import 'package:flutter/material.dart';

class ScreenDefinition {
  final String id;
  final String title;
  final String route;
  final WidgetBuilder builder;
  final String category;
  final IconData icon;
  final String? description;

  const ScreenDefinition({
    required this.id,
    required this.title,
    required this.route,
    required this.builder,
    required this.category,
    required this.icon,
    this.description,
  });
}
