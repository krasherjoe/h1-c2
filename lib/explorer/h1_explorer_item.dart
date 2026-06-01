import 'package:flutter/material.dart';

abstract class H1ExplorerItem {
  String get id;
  String get title;
  String? get subtitle;
  String? get badge;
  IconData? get icon;
  DateTime? get updatedAt;
}
