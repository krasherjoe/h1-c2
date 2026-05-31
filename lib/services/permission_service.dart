import 'package:flutter/material.dart';

enum AppFeature {
  masterEdit,
  masterDelete,
  masterCreate,
  invoice,
  invoiceEdit,
  invoiceDelete,
  invoiceCreate,
  settingEdit,
}

Future<bool> guardWrite(BuildContext context, AppFeature feature) async {
  final service = PermissionService();
  switch (feature) {
    case AppFeature.masterEdit:
    case AppFeature.masterDelete:
    case AppFeature.masterCreate:
    case AppFeature.invoice:
    case AppFeature.invoiceEdit:
    case AppFeature.invoiceDelete:
    case AppFeature.invoiceCreate:
    case AppFeature.settingEdit:
      return service.canEdit;
  }
}

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  bool hasPermission(String feature) => true;
  bool get canEdit => true;
  bool get canDelete => true;
  bool get canCreate => true;
}
