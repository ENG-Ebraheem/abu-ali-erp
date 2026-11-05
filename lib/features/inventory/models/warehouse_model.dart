/// Model representing a storage warehouse.
class WarehouseModel {
  final String id;
  final String organizationId;
  final String code;
  final String name;
  final String? description;
  final String? location;
  final String? responsiblePerson;
  final bool isActive;
  final String createdAt;
  final String? updatedAt;

  // Joined / aggregated UI properties
  final int itemCount;
  final int totalValuation; // in minor units (scaled 10^2)

  const WarehouseModel({
    required this.id,
    required this.organizationId,
    required this.code,
    required this.name,
    this.description,
    this.location,
    this.responsiblePerson,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.itemCount = 0,
    this.totalValuation = 0,
  });

  factory WarehouseModel.fromMap(Map<String, dynamic> map) {
    return WarehouseModel(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      code: map['code'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      location: map['location'] as String?,
      responsiblePerson: map['responsible_person'] as String?,
      isActive: (map['is_active'] as num?)?.toInt() == 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String?,
      itemCount: (map['item_count'] as num?)?.toInt() ?? 0,
      totalValuation: (map['total_valuation'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'code': code,
      'name': name,
      'description': description,
      'location': location,
      'responsible_person': responsiblePerson,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  WarehouseModel copyWith({
    String? id,
    String? organizationId,
    String? code,
    String? name,
    String? description,
    String? location,
    String? responsiblePerson,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
    int? itemCount,
    int? totalValuation,
  }) {
    return WarehouseModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      responsiblePerson: responsiblePerson ?? this.responsiblePerson,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      itemCount: itemCount ?? this.itemCount,
      totalValuation: totalValuation ?? this.totalValuation,
    );
  }
}

