class CompanyBankAccount {
  final String bankName;
  final String branchName;
  final String accountType;
  final String accountNumber;
  final String holderName;
  final bool isActive;

  const CompanyBankAccount({
    this.bankName = '',
    this.branchName = '',
    this.accountType = '普通',
    this.accountNumber = '',
    this.holderName = '',
    this.isActive = false,
  });

  CompanyBankAccount copyWith({
    String? bankName,
    String? branchName,
    String? accountType,
    String? accountNumber,
    String? holderName,
    bool? isActive,
  }) {
    return CompanyBankAccount(
      bankName: bankName ?? this.bankName,
      branchName: branchName ?? this.branchName,
      accountType: accountType ?? this.accountType,
      accountNumber: accountNumber ?? this.accountNumber,
      holderName: holderName ?? this.holderName,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => {
        'bankName': bankName,
        'branchName': branchName,
        'accountType': accountType,
        'accountNumber': accountNumber,
        'holderName': holderName,
        'isActive': isActive,
      };

  factory CompanyBankAccount.fromJson(Map<String, dynamic> json) {
    return CompanyBankAccount(
      bankName: json['bankName'] as String? ?? '',
      branchName: json['branchName'] as String? ?? '',
      accountType: json['accountType'] as String? ?? '普通',
      accountNumber: json['accountNumber'] as String? ?? '',
      holderName: json['holderName'] as String? ?? '',
      isActive: (json['isActive'] as bool?) ?? false,
    );
  }
}

class CompanyInfo {
  final String name;
  final String? zipCode;
  final String? address;
  final String? address2;
  final String? tel;
  final String? fax;
  final String? email;
  final String? url;
  final double defaultTaxRate;
  final String? sealPath;
  final double sealOffsetX;
  final double sealOffsetY;
  final double sealRotation;
  final String taxDisplayMode;
  final String? registrationNumber;
  final String? bankAccounts;
  final int defaultBankAccountIndex;
  final int fiscalYearStart;
  final int closingDay;
  final bool isExemptTaxpayer;

  CompanyInfo({
    required this.name,
    this.zipCode,
    this.address,
    this.address2,
    this.tel,
    this.fax,
    this.email,
    this.url,
    this.defaultTaxRate = 0.10,
    this.sealPath,
    this.sealOffsetX = 10.0,
    this.sealOffsetY = 50.0,
    this.sealRotation = 0.0,
    this.taxDisplayMode = 'normal',
    this.registrationNumber,
    this.bankAccounts,
    this.defaultBankAccountIndex = 0,
    this.fiscalYearStart = 4,
    this.closingDay = 20,
    this.isExemptTaxpayer = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'name': name,
      'zip_code': zipCode,
      'address': address,
      'address2': address2,
      'tel': tel,
      'fax': fax,
      'email': email,
      'url': url,
      'default_tax_rate': defaultTaxRate,
      'seal_path': sealPath,
      'seal_offset_x': sealOffsetX,
      'seal_offset_y': sealOffsetY,
      'seal_rotation': sealRotation,
      'tax_display_mode': taxDisplayMode,
      'registration_number': registrationNumber,
      'bank_accounts': bankAccounts,
      'default_bank_account_index': defaultBankAccountIndex,
      'fiscal_year_start': fiscalYearStart,
      'closing_day': closingDay,
      'is_exempt_taxpayer': isExemptTaxpayer ? 1 : 0,
    };
  }

  factory CompanyInfo.fromMap(Map<String, dynamic> map) {
    return CompanyInfo(
      name: map['name'] ?? "",
      zipCode: map['zip_code'],
      address: map['address'],
      address2: map['address2'],
      tel: map['tel'],
      fax: map['fax'],
      email: map['email'],
      url: map['url'],
      defaultTaxRate: (map['default_tax_rate'] ?? 0.10).toDouble(),
      sealPath: map['seal_path'],
      sealOffsetX: (map['seal_offset_x'] as num?)?.toDouble() ?? 10.0,
      sealOffsetY: (map['seal_offset_y'] as num?)?.toDouble() ?? 50.0,
      sealRotation: (map['seal_rotation'] as num?)?.toDouble() ?? 0.0,
      taxDisplayMode: map['tax_display_mode'] ?? 'normal',
      registrationNumber: map['registration_number'],
      bankAccounts: map['bank_accounts'],
      defaultBankAccountIndex: (map['default_bank_account_index'] as num?)?.toInt() ?? 0,
      fiscalYearStart: (map['fiscal_year_start'] as num?)?.toInt() ?? 4,
      closingDay: (map['closing_day'] as num?)?.toInt() ?? 20,
      isExemptTaxpayer: (map['is_exempt_taxpayer'] as int? ?? 0) == 1,
    );
  }

  CompanyInfo copyWith({
    String? name,
    String? zipCode,
    String? address,
    String? address2,
    String? tel,
    String? fax,
    String? email,
    String? url,
    double? defaultTaxRate,
    String? sealPath,
    double? sealOffsetX,
    double? sealOffsetY,
    double? sealRotation,
    String? taxDisplayMode,
    String? registrationNumber,
    String? bankAccounts,
    int? defaultBankAccountIndex,
    int? fiscalYearStart,
    int? closingDay,
    bool? isExemptTaxpayer,
  }) {
    return CompanyInfo(
      name: name ?? this.name,
      zipCode: zipCode ?? this.zipCode,
      address: address ?? this.address,
      address2: address2 ?? this.address2,
      tel: tel ?? this.tel,
      fax: fax ?? this.fax,
      email: email ?? this.email,
      url: url ?? this.url,
      defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
      sealPath: sealPath ?? this.sealPath,
      sealOffsetX: sealOffsetX ?? this.sealOffsetX,
      sealOffsetY: sealOffsetY ?? this.sealOffsetY,
      sealRotation: sealRotation ?? this.sealRotation,
      taxDisplayMode: taxDisplayMode ?? this.taxDisplayMode,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      bankAccounts: bankAccounts ?? this.bankAccounts,
      defaultBankAccountIndex: defaultBankAccountIndex ?? this.defaultBankAccountIndex,
      fiscalYearStart: fiscalYearStart ?? this.fiscalYearStart,
      closingDay: closingDay ?? this.closingDay,
      isExemptTaxpayer: isExemptTaxpayer ?? this.isExemptTaxpayer,
    );
  }
}
