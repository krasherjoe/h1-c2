class Receipt {
  final String id;
  final String invoiceId;
  final String receiptNumber;
  final String customerName;
  final int amount;
  final DateTime issuedAt;
  final String? pdfPath;

  Receipt({
    required this.id,
    required this.invoiceId,
    required this.receiptNumber,
    required this.customerName,
    required this.amount,
    required this.issuedAt,
    this.pdfPath,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'invoice_id': invoiceId,
        'receipt_number': receiptNumber,
        'customer_name': customerName,
        'amount': amount,
        'issued_at': issuedAt.toIso8601String(),
        'pdf_path': pdfPath,
      };

  factory Receipt.fromMap(Map<String, dynamic> map) => Receipt(
        id: map['id'] as String? ?? '',
        invoiceId: map['invoice_id'] as String? ?? '',
        receiptNumber: map['receipt_number'] as String? ?? '',
        customerName: map['customer_name'] as String? ?? '',
        amount: map['amount'] as int? ?? 0,
        issuedAt: DateTime.tryParse(map['issued_at'] as String? ?? '') ?? DateTime.now(),
        pdfPath: map['pdf_path'] as String?,
      );
}
