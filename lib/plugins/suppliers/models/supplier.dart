class Supplier {
  final String id;
  final String displayName;
  final String formalName;
  final String title;
  final String? department;
  final String? address;
  final String? tel;
  final String? email;
  final String? contactPerson;
  final String? paymentTerms;
  final String? bankAccount;
  final int closingDay;
  final int paymentSiteDays;
  final String? notes;
  final bool isLocked;
  final bool isHidden;
  final DateTime updatedAt;

  String get invoiceName => '$formalName $title';

  const Supplier({
    required this.id,
    required this.displayName,
    required this.formalName,
    this.title = '様',
    this.department,
    this.address,
    this.tel,
    this.email,
    this.contactPerson,
    this.paymentTerms,
    this.bankAccount,
    this.closingDay = 99,
    this.paymentSiteDays = 30,
    this.notes,
    this.isLocked = false,
    this.isHidden = false,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'display_name': displayName,
    'formal_name': formalName,
    'title': title,
    'department': department,
    'address': address,
    'tel': tel,
    'email': email,
    'contact_person': contactPerson,
    'payment_terms': paymentTerms,
    'bank_account': bankAccount,
    'closing_day': closingDay,
    'payment_site_days': paymentSiteDays,
    'notes': notes,
    'is_locked': isLocked ? 1 : 0,
    'is_hidden': isHidden ? 1 : 0,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Supplier.fromMap(Map<String, dynamic> map) => Supplier(
    id: map['id'] as String,
    displayName: map['display_name'] as String? ?? '',
    formalName: map['formal_name'] as String? ?? '',
    title: map['title'] as String? ?? '様',
    department: map['department'] as String?,
    address: map['address'] as String?,
    tel: map['tel'] as String?,
    email: map['email'] as String?,
    contactPerson: map['contact_person'] as String?,
    paymentTerms: map['payment_terms'] as String?,
    bankAccount: map['bank_account'] as String?,
    closingDay: map['closing_day'] as int? ?? 99,
    paymentSiteDays: map['payment_site_days'] as int? ?? 30,
    notes: map['notes'] as String?,
    isLocked: map['is_locked'] == 1,
    isHidden: map['is_hidden'] == 1,
    updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
  );

  Supplier copyWith({
    String? id,
    String? displayName,
    String? formalName,
    String? title,
    String? department,
    String? address,
    String? tel,
    String? email,
    String? contactPerson,
    String? paymentTerms,
    String? bankAccount,
    int? closingDay,
    int? paymentSiteDays,
    String? notes,
    bool? isLocked,
    bool? isHidden,
    DateTime? updatedAt,
  }) => Supplier(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    formalName: formalName ?? this.formalName,
    title: title ?? this.title,
    department: department ?? this.department,
    address: address ?? this.address,
    tel: tel ?? this.tel,
    email: email ?? this.email,
    contactPerson: contactPerson ?? this.contactPerson,
    paymentTerms: paymentTerms ?? this.paymentTerms,
    bankAccount: bankAccount ?? this.bankAccount,
    closingDay: closingDay ?? this.closingDay,
    paymentSiteDays: paymentSiteDays ?? this.paymentSiteDays,
    notes: notes ?? this.notes,
    isLocked: isLocked ?? this.isLocked,
    isHidden: isHidden ?? this.isHidden,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
