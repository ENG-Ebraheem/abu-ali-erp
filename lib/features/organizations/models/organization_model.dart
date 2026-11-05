/// Represents an independent organization entity within the accounting system.
class Organization {
  final String id;
  final String name;
  final String code;
  final String baseCurrencyCode;
  final String? businessType;
  final String? phone;
  final String? address;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Organization({
    required this.id,
    required this.name,
    required this.code,
    required this.baseCurrencyCode,
    this.businessType,
    this.phone,
    this.address,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a copy of this organization with given fields replaced.
  Organization copyWith({
    String? id,
    String? name,
    String? code,
    String? baseCurrencyCode,
    String? businessType,
    String? phone,
    String? address,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Organization(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      baseCurrencyCode: baseCurrencyCode ?? this.baseCurrencyCode,
      businessType: businessType ?? this.businessType,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Maps an SQLite row map to an [Organization] object.
  factory Organization.fromMap(Map<String, dynamic> map) {
    return Organization(
      id: map['id'] as String,
      name: map['name'] as String,
      code: map['code'] as String,
      baseCurrencyCode: map['base_currency_code'] as String,
      businessType: map['tax_number'] as String?,
      phone: map['phone'] as String?,
      notes: map['email'] as String?,
      address: map['address'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  /// Converts this [Organization] to an SQLite row map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'base_currency_code': baseCurrencyCode,
      'tax_number': businessType,
      'phone': phone,
      'email': notes,
      'address': address,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Formatted localized label for the base currency.
  String get currencyLabel {
    switch (baseCurrencyCode) {
      case 'YER':
        return 'ريال يمني (YER)';
      case 'USD':
        return 'دولار أمريكي (USD)';
      case 'SAR':
        return 'ريال سعودي (SAR)';
      default:
        return baseCurrencyCode;
    }
  }

  /// Short symbol for the currency.
  String get currencySymbol {
    switch (baseCurrencyCode) {
      case 'YER':
        return 'ر.ي';
      case 'USD':
        return '\$';
      case 'SAR':
        return 'ر.س';
      default:
        return baseCurrencyCode;
    }
  }
}
