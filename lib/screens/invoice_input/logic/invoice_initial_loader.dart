import 'dart:convert';

import '../../../models/invoice_models.dart';
import 'package:flutter/foundation.dart';
import '../../../models/customer_model.dart';
import '../../../widgets/document_card.dart';
import '../../../services/invoice_repository.dart';
import '../../../services/sales_repository.dart';
import '../../../services/product_repository.dart';
import '../../../services/company_repository.dart';
import '../../../services/app_settings_repository.dart';
import '../../../services/project_repository.dart';
import '../../../services/customer_repository.dart';
import '../../../services/company_profile_service.dart';
import '../../../models/company_info.dart';
import '../../../models/company_info.dart';

Future<Map<String, dynamic>> loadInitialInvoiceData({
  required InvoiceRepository invoiceRepo,
  required CompanyRepository companyRepo,
  required ProductRepository productRepo,
  required AppSettingsRepository settingsRepo,
  required ProjectRepository projectRepo,
  required Invoice? existingInvoice,
  required String? initialSalesId,
  required bool isSalesMode,
  required DocumentType initialDocumentType,
  required Customer? preselectedCustomer,
}) async {
  if (isSalesMode) {
    if (initialSalesId != null) {
      try {
        final salesRepo = SalesRepository();
        final sales = await salesRepo.getSales(initialSalesId);
        if (sales != null) {
          final items = sales.items.map((item) => InvoiceItem(
            productId: item.productId,
            description: item.productName,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
          )).toList();
          return {
            'salesMode': true,
            'salesFound': true,
            'customer': sales.customer,
            'items': items,
            'selectedDate': sales.date,
            'taxRate': sales.taxRate,
            'includeTax': sales.taxRate > 0,
            'isTaxInclusiveMode': false,
            'currentId': sales.id,
            'subject': sales.subject ?? '',
            'salesPaymentDueDate': sales.paymentDueDate,
            'salesPaymentMethod': sales.paymentMethod ?? '現金',
            'salesStatus': sales.status,
            'selectedProjectId': sales.projectId,
            'isDraft': false,
            'documentType': DocumentType.invoice,
          };
        }
      } catch (e) {
        debugPrint('[D3] sales load error: $e');
      }
    }
    return {
      'salesMode': true,
      'salesFound': false,
      'customer': preselectedCustomer,
      'items': <InvoiceItem>[],
      'selectedDate': DateTime.now(),
      'taxRate': 0.10,
      'includeTax': true,
      'isTaxInclusiveMode': false,
      'currentId': null,
      'subject': '',
      'salesPaymentDueDate': null,
      'salesPaymentMethod': '現金',
      'salesStatus': DocumentStatus.confirmed,
      'selectedProjectId': null,
      'isDraft': true,
      'documentType': DocumentType.invoice,
    };
  }

  await invoiceRepo.cleanupOrphanedPdfs();
  final customerRepo = CustomerRepository();
  await customerRepo.getAllCustomers();

  final Map<String, int> wholesalePrices = {};
  try {
    final allProducts = await productRepo.getAllProducts();
    for (final p in allProducts) {
      if (p.wholesalePrice > 0) wholesalePrices[p.id] = p.wholesalePrice;
    }
  } catch (e) {
    debugPrint('[_InvoiceInputFormState] _loadInitialData wholesalePrice error: $e');
  }

  final savedSummary = await settingsRepo.getSummaryTheme();
  final summaryIsBlue = savedSummary == 'blue';

  final company = await companyRepo.getCompanyInfo();
  final defaultTaxRate = company?.defaultTaxRate ?? 0.10;
  List<CompanyBankAccount> bankAccounts;
  try {
    if (company?.bankAccounts != null && company!.bankAccounts!.isNotEmpty) {
      final list = jsonDecode(company.bankAccounts!) as List<dynamic>;
      bankAccounts = list
          .map((e) => CompanyBankAccount.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      bankAccounts = <CompanyBankAccount>[];
    }
  } catch (e) {
    debugPrint('[_InvoiceInputFormState] decode bankAccounts error: $e');
    bankAccounts = <CompanyBankAccount>[];
  }
  final defaultBankIdx = company?.defaultBankAccountIndex ?? 0;

  final youngestCheck = existingInvoice != null
      ? await invoiceRepo.isYoungestIssuedInvoice(existingInvoice.id)
      : false;

  return {
    'salesMode': false,
    'wholesalePrices': wholesalePrices,
    'summaryIsBlue': summaryIsBlue,
    'companyBankAccounts': bankAccounts,
    'defaultTaxRate': defaultTaxRate,
    'defaultBankIdx': defaultBankIdx,
    'youngestCheck': youngestCheck,
  };
}
