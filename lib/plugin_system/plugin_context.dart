import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../services/invoice_repository.dart';
import '../services/customer_repository.dart';
import '../services/product_repository.dart';

class PluginContext {
  final Database? database;
  final SharedPreferences preferences;

  PluginContext({
    this.database,
    required this.preferences,
  });

  InvoiceRepository get invoiceRepository => InvoiceRepository();
  CustomerRepository get customerRepository => CustomerRepository();
  ProductRepository get productRepository => ProductRepository();

  static final Map<String, dynamic> _services = {};

  void registerService<T>(String name, T service) {
    _services[name] = service;
    debugPrint('[PluginContext] Service registered: $name ($T)');
  }

  T getService<T>(String name) {
    final service = _services[name];
    if (service == null) {
      throw Exception('Service not found: $name');
    }
    return service as T;
  }
}
