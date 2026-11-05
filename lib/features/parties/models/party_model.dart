/// Model representing a Customer, Supplier, or Dual Party.
class PartyModel {
  final String id;
  final String organizationId;
  final String code;
  final String partyType; // 'CUSTOMER', 'SUPPLIER', 'BOTH'
  final String nameAr;
  final String? nameEn;
  final String? phone;
  final String? email;
  final String? address;
  final String? taxNumber;
  final int creditLimit; // Minor units (scale 100)
  final String? defaultCurrencyCode;
  final String? linkedAccountId;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  // Calculated fields (from GL lines or invoices)
  final int balanceBase; // Net balance in organization's base currency
  final int transactionCount;

  const PartyModel({
    required this.id,
    required this.organizationId,
    required this.code,
    required this.partyType,
    required this.nameAr,
    this.nameEn,
    this.phone,
    this.email,
    this.address,
    this.taxNumber,
    this.creditLimit = 0,
    this.defaultCurrencyCode,
    this.linkedAccountId,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.balanceBase = 0,
    this.transactionCount = 0,
  });

  bool get isCustomer => partyType == 'CUSTOMER' || partyType == 'BOTH';
  bool get isSupplier => partyType == 'SUPPLIER' || partyType == 'BOTH';

  String get typeLabel {
    switch (partyType) {
      case 'CUSTOMER':
        return 'عميل';
      case 'SUPPLIER':
        return 'مورد';
      case 'BOTH':
        return 'عميل ومورد';
      default:
        return partyType;
    }
  }

  factory PartyModel.fromMap(Map<String, dynamic> map) {
    return PartyModel(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      code: map['code'] as String,
      partyType: map['party_type'] as String,
      nameAr: map['name_ar'] as String,
      nameEn: map['name_en'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      taxNumber: map['tax_number'] as String?,
      creditLimit: (map['credit_limit'] as num?)?.toInt() ?? 0,
      defaultCurrencyCode: map['default_currency_code'] as String?,
      linkedAccountId: map['linked_account_id'] as String?,
      isActive: (map['is_active'] as int?) == 1,
      createdAt: map['created_at'] as String? ?? '',
      updatedAt: map['updated_at'] as String? ?? '',
      balanceBase: (map['calculated_balance'] as num?)?.toInt() ?? 0,
      transactionCount: (map['tx_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'code': code,
      'party_type': partyType,
      'name_ar': nameAr,
      'name_en': nameEn,
      'phone': phone,
      'email': email,
      'address': address,
      'tax_number': taxNumber,
      'credit_limit': creditLimit,
      'default_currency_code': defaultCurrencyCode,
      'linked_account_id': linkedAccountId,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  PartyModel copyWith({
    String? id,
    String? organizationId,
    String? code,
    String? partyType,
    String? nameAr,
    String? nameEn,
    String? phone,
    String? email,
    String? address,
    String? taxNumber,
    int? creditLimit,
    String? defaultCurrencyCode,
    String? linkedAccountId,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
    int? balanceBase,
    int? transactionCount,
  }) {
    return PartyModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      code: code ?? this.code,
      partyType: partyType ?? this.partyType,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      taxNumber: taxNumber ?? this.taxNumber,
      creditLimit: creditLimit ?? this.creditLimit,
      defaultCurrencyCode: defaultCurrencyCode ?? this.defaultCurrencyCode,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      balanceBase: balanceBase ?? this.balanceBase,
      transactionCount: transactionCount ?? this.transactionCount,
    );
  }
}
