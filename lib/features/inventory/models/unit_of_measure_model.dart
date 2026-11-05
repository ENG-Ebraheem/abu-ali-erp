/// Unit of Measurement model (Base or additional unit).
class UnitOfMeasureModel {
  final String id;
  final String organizationId;
  final String code;
  final String nameAr;
  final String? symbol;
  final bool isActive;
  final String createdAt;

  const UnitOfMeasureModel({
    required this.id,
    required this.organizationId,
    required this.code,
    required this.nameAr,
    this.symbol,
    this.isActive = true,
    required this.createdAt,
  });

  factory UnitOfMeasureModel.fromMap(Map<String, dynamic> map) {
    return UnitOfMeasureModel(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      code: map['code'] as String,
      nameAr: map['name_ar'] as String,
      symbol: map['symbol'] as String?,
      isActive: (map['is_active'] as num?)?.toInt() == 1,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'code': code,
      'name_ar': nameAr,
      'symbol': symbol,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
    };
  }

  UnitOfMeasureModel copyWith({
    String? id,
    String? organizationId,
    String? code,
    String? nameAr,
    String? symbol,
    bool? isActive,
    String? createdAt,
  }) {
    return UnitOfMeasureModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      code: code ?? this.code,
      nameAr: nameAr ?? this.nameAr,
      symbol: symbol ?? this.symbol,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

