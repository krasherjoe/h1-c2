class CompanyProfile {
  final String name;
  final String postalCode;
  final String address;
  final String tel;
  final String fax;
  final String email;
  final String? sealImagePath;
  final int defaultTaxRate;

  const CompanyProfile({
    this.name = '',
    this.postalCode = '',
    this.address = '',
    this.tel = '',
    this.fax = '',
    this.email = '',
    this.sealImagePath,
    this.defaultTaxRate = 10,
  });

  CompanyProfile copyWith({
    String? name,
    String? postalCode,
    String? address,
    String? tel,
    String? fax,
    String? email,
    String? sealImagePath,
    int? defaultTaxRate,
  }) {
    return CompanyProfile(
      name: name ?? this.name,
      postalCode: postalCode ?? this.postalCode,
      address: address ?? this.address,
      tel: tel ?? this.tel,
      fax: fax ?? this.fax,
      email: email ?? this.email,
      sealImagePath: sealImagePath ?? this.sealImagePath,
      defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'postalCode': postalCode,
    'address': address,
    'tel': tel,
    'fax': fax,
    'email': email,
    'sealImagePath': sealImagePath,
    'defaultTaxRate': defaultTaxRate,
  };

  factory CompanyProfile.fromJson(Map<String, dynamic> json) {
    return CompanyProfile(
      name: json['name'] as String? ?? '',
      postalCode: json['postalCode'] as String? ?? '',
      address: json['address'] as String? ?? '',
      tel: json['tel'] as String? ?? '',
      fax: json['fax'] as String? ?? '',
      email: json['email'] as String? ?? '',
      sealImagePath: json['sealImagePath'] as String?,
      defaultTaxRate: json['defaultTaxRate'] as int? ?? 10,
    );
  }
}
