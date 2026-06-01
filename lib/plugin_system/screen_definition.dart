import 'package:flutter/material.dart';

class ScreenDefinition {
  final String id;
  final String title;
  final String route;
  final WidgetBuilder builder;

  const ScreenDefinition({
    required this.id,
    required this.title,
    required this.route,
    required this.builder,
  });
}
