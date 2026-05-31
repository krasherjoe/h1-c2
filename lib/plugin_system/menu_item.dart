import 'package:flutter/material.dart';

class MenuItem {
  final String id;
  final String title;
  final String route;
  final String category;
  final IconData icon;
  final String? description;

  const MenuItem({
    required this.id,
    required this.title,
    required this.route,
    required this.category,
    required this.icon,
    this.description,
  });
}
