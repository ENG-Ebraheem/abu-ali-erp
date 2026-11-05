/// Hierarchical product and material categories.
class ItemCategoryModel {
  final String id;
  final String organizationId;
  final String code;
  final String nameAr;
  final String? nameEn;
  final String? parentId;
  final String? description;
  final bool isActive;
  final String createdAt;
  final String? updatedAt;

  // Joined properties
  final String? parentNameAr;
  final int productCount;

  const ItemCategoryModel({
    required this.id,
    required this.organizationId,
    required this.code,
    required this.nameAr,
    this.nameEn,
    this.parentId,
    this.description,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.parentNameAr,
    this.productCount = 0,
  });

  factory ItemCategoryModel.fromMap(Map<String, dynamic> map) {
    return ItemCategoryModel(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      code: map['code'] as String,
      nameAr: map['name_ar'] as String,
      nameEn: map['name_en'] as String?,
      parentId: map['parent_id'] as String?,
      description: map['description'] as String?,
      isActive: (map['is_active'] as num?)?.toInt() == 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String?,
      parentNameAr: map['parent_name_ar'] as String?,
      productCount: (map['product_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'code': code,
      'name_ar': nameAr,
      'name_en': nameEn,
      'parent_id': parentId,
      'description': description,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  ItemCategoryModel copyWith({
    String? id,
    String? organizationId,
    String? code,
    String? nameAr,
    String? nameEn,
    String? parentId,
    String? description,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
    String? parentNameAr,
    int? productCount,
  }) {
    return ItemCategoryModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      code: code ?? this.code,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      parentId: parentId ?? this.parentId,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      parentNameAr: parentNameAr ?? this.parentNameAr,
      productCount: productCount ?? this.productCount,
    );
  }
}

