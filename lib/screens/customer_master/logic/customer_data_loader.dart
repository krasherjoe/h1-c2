import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/customer_model.dart';
import '../../../models/custom_field_model.dart';
import '../../../services/customer_repository.dart';
import '../../../services/custom_field_repository.dart';
import '../../../services/business_profile_repository.dart';
import '../../../services/sys_logger.dart';

Future<void> loadCustomers({
  required CustomerRepository customerRepo,
  required bool showHidden,
  required bool mounted,
  required ValueChanged<List<Customer>> onData,
  required VoidCallback onLoadingDone,
}) async {
  try {
    final customers = await customerRepo.getAllCustomers(includeHidden: showHidden);
    if (!mounted) return;
    onData(customers);
    onLoadingDone();
  } catch (e) {
    SysLogger.instance.logError('C1', e);
    if (!mounted) return;
    onLoadingDone();
  }
}

Future<void> loadCustomFields({
  required BusinessProfileRepository businessProfileRepo,
  required CustomFieldRepository customFieldRepo,
  required bool mounted,
  required ValueChanged<List<CustomField>> onFields,
}) async {
  try {
    final profile = await businessProfileRepo.getCurrentProfile();
    final fields = await customFieldRepo.getActiveFieldsByBusinessProfile(profile.id);
    if (!mounted) return;
    onFields(fields);
  } catch (e) {
    SysLogger.instance.logError('C1', e);
    if (!mounted) return;
    onFields([]);
  }
}

Future<Map<String, String>> loadUserKanaMap() async {
  final prefs = await SharedPreferences.getInstance();
  final json = prefs.getString('customKanaMap');
  if (json != null && json.isNotEmpty) {
    try {
      final Map<String, dynamic> decoded = jsonDecode(json);
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (e) {
      debugPrint('[CustomerMaster] _loadUserKanaMap error: $e');
    }
  }
  return {};
}
