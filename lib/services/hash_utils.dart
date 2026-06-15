import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;

class HashUtils {
  static String calculateSha256(String input) {
    final bytes = utf8.encode(input);
    final digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }

  static String calculateCustomerHash({
    required String id,
    required String displayName,
    required String formalName,
    required int title,
    String? department,
    String? address,
    String? tel,
    String? email,
    String? email2,
    String? email3,
    int? contactVersionId,
    String? odooId,
    bool isLocked = false,
    bool isHidden = false,
    String? headChar1,
    String? headChar2,
    DateTime? validFrom,
    DateTime? validTo,
    bool isCurrentFlag = true,
    int version = 1,
    String? previousHash,
  }) {
    final input = [
      id,
      displayName,
      formalName,
      title.toString(),
      department ?? '',
      address ?? '',
      tel ?? '',
      email ?? '',
      email2 ?? '',
      email3 ?? '',
      contactVersionId?.toString() ?? '',
      odooId ?? '',
      isLocked ? '1' : '0',
      isHidden ? '1' : '0',
      headChar1 ?? '',
      headChar2 ?? '',
      validFrom?.toIso8601String() ?? '',
      validTo?.toIso8601String() ?? '',
      isCurrentFlag ? '1' : '0',
      version.toString(),
      previousHash ?? '',
    ].join('|');

    return calculateSha256(input);
  }

  static String calculateProductHash({
    required String id,
    required String name,
    required int defaultUnitPrice,
    required int wholesalePrice,
    String? barcode,
    String? category,
    String? categoryId,
    int? stockQuantity,
    String? odooId,
    bool isLocked = false,
    bool isHidden = false,
    DateTime? validFrom,
    DateTime? validTo,
    bool isCurrentFlag = true,
    int version = 1,
    String? previousHash,
  }) {
    final input = [
      id,
      name,
      defaultUnitPrice.toString(),
      wholesalePrice.toString(),
      barcode ?? '',
      category ?? '',
      categoryId ?? '',
      stockQuantity?.toString() ?? '',
      odooId ?? '',
      isLocked ? '1' : '0',
      isHidden ? '1' : '0',
      validFrom?.toIso8601String() ?? '',
      validTo?.toIso8601String() ?? '',
      isCurrentFlag ? '1' : '0',
      version.toString(),
      previousHash ?? '',
    ].join('|');

    return calculateSha256(input);
  }

  static String calculateDocumentHash({
    required String id,
    required String documentType,
    required String customerId,
    required String customerName,
    required String documentNumber,
    required String date,
    required int total,
    required String status,
    String? subject,
    required bool includeTax,
    required double taxRate,
    List<Map<String, dynamic>>? items,
    bool isLocked = false,
    int version = 1,
    String? previousHash,
  }) {
    final input = [
      id,
      documentType,
      customerId,
      customerName,
      documentNumber,
      date,
      total.toString(),
      status,
      subject ?? '',
      includeTax ? '1' : '0',
      taxRate.toStringAsFixed(4),
      items?.map((e) =>
        '${e['productId']}|${e['productName']}|${e['maker']}|${e['productCode']}|${e['quantity']}|${e['unitPrice']}|${e['discountAmount']}|${e['discountRate']}|${e['notes']}')
        .join(';') ?? '',
      isLocked ? '1' : '0',
      version.toString(),
      previousHash ?? '',
    ].join('|');
    return calculateSha256(input);
  }

  static bool verifyHashChain({
    required String currentHash,
    required String currentInput,
    String? actualPreviousHash,
    String? expectedPreviousHash,
  }) {
    final calculatedHash = calculateSha256(currentInput);
    if (calculatedHash != currentHash) {
      return false;
    }
    if (expectedPreviousHash != null) {
      return actualPreviousHash == expectedPreviousHash;
    } else {
      return actualPreviousHash == null || actualPreviousHash.isEmpty;
    }
  }

  static bool verifyCustomerIntegrity({
    required String contentHash,
    required String id,
    required String displayName,
    required String formalName,
    required int title,
    String? department,
    String? address,
    String? tel,
    String? email,
    int? contactVersionId,
    String? odooId,
    bool isLocked = false,
    bool isHidden = false,
    String? headChar1,
    String? headChar2,
    DateTime? validFrom,
    DateTime? validTo,
    bool isCurrentFlag = true,
    int version = 1,
    String? previousHash,
  }) {
    final expectedHash = calculateCustomerHash(
      id: id,
      displayName: displayName,
      formalName: formalName,
      title: title,
      department: department,
      address: address,
      tel: tel,
      email: email,
      contactVersionId: contactVersionId,
      odooId: odooId,
      isLocked: isLocked,
      isHidden: isHidden,
      headChar1: headChar1,
      headChar2: headChar2,
      validFrom: validFrom,
      validTo: validTo,
      isCurrentFlag: isCurrentFlag,
      version: version,
      previousHash: previousHash,
    );
    return contentHash == expectedHash;
  }

  static bool verifyProductIntegrity({
    required String contentHash,
    required String id,
    required String name,
    required int defaultUnitPrice,
    required int wholesalePrice,
    String? barcode,
    String? category,
    String? categoryId,
    int? stockQuantity,
    String? odooId,
    bool isLocked = false,
    bool isHidden = false,
    DateTime? validFrom,
    DateTime? validTo,
    bool isCurrentFlag = true,
    int version = 1,
    String? previousHash,
  }) {
    final expectedHash = calculateProductHash(
      id: id,
      name: name,
      defaultUnitPrice: defaultUnitPrice,
      wholesalePrice: wholesalePrice,
      barcode: barcode,
      category: category,
      categoryId: categoryId,
      stockQuantity: stockQuantity,
      odooId: odooId,
      isLocked: isLocked,
      isHidden: isHidden,
      validFrom: validFrom,
      validTo: validTo,
      isCurrentFlag: isCurrentFlag,
      version: version,
      previousHash: previousHash,
    );
    return contentHash == expectedHash;
  }
}
