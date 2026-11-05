import 'package:abu_ali/core/constants/database_constants.dart';

/// Item / Product / Material model.
class ItemModel {
  final String id;
  final String organizationId;
  final String itemCode;
  final String? barcode;
  final String nameAr;
  final String? nameEn;
  final String? description;
  final String? categoryId;
  final String itemType; // MERCHANDISE, RAW_MATERIAL, FINISHED_PRODUCT, SEMI_FINISHED, CONSUMABLE, SERVICE
  final String baseUnitId;
  final int purchasePrice; // Minor units (scaled 10^2)
  final int sellingPrice; // Minor units (scaled 10^2)
  final int minStockLevel; // Scaled 10^3
  final int? maxStockLevel; // Scaled 10^3
  final int reorderLevel; // Scaled 10^3
  final bool trackInventory;
  final bool isActive;
  final String? imagePath;
  final String? defaultWarehouseId;
  final String valuationMethod; // WEIGHTED_AVERAGE, FIFO
  final String createdAt;
  final String? updatedAt;

  // Joined presentation fields
  final String? categoryNameAr;
  final String? baseUnitNameAr;
  final String? baseUnitSymbol;
  final String? defaultWarehouseName;
  final int currentStock; // Scaled 10^3 (Across all warehouses or selected)
  final int currentAverageCost; // Minor units (scaled 10^2)
  final int totalStockValue; // Minor units (scaled 10^2)

  const ItemModel({
    required this.id,
    required this.organizationId,
    required this.itemCode,
    this.barcode,
    required this.nameAr,
    this.nameEn,
    this.description,
    this.categoryId,
    required this.itemType,
    required this.baseUnitId,
    this.purchasePrice = 0,
    this.sellingPrice = 0,
    this.minStockLevel = 0,
    this.maxStockLevel,
    this.reorderLevel = 0,
    this.trackInventory = true,
    this.isActive = true,
    this.imagePath,
    this.defaultWarehouseId,
    this.valuationMethod = 'WEIGHTED_AVERAGE',
    required this.createdAt,
    this.updatedAt,
    this.categoryNameAr,
    this.baseUnitNameAr,
    this.baseUnitSymbol,
    this.defaultWarehouseName,
    this.currentStock = 0,
    this.currentAverageCost = 0,
    this.totalStockValue = 0,
  });

  bool get isService => itemType == ItemType.service;
  bool get isLowStock =>
      trackInventory &&
      !isService &&
      reorderLevel > 0 &&
      currentStock <= reorderLevel;
  bool get isOutOfStock =>
      trackInventory && !isService && currentStock <= 0;

  String get itemTypeLabelAr {
    switch (itemType) {
      case ItemType.merchandise:
        return 'بضاعة تجارية';
      case ItemType.rawMaterial:
        return 'مواد خام';
      case ItemType.finishedProduct:
        return 'منتج تام الصنع';
      case ItemType.semiFinished:
        return 'نصف مصنع';
      case ItemType.consumable:
        return 'مواد استهلاكية';
      case ItemType.service:
        return 'خدمة (غير مخزنية)';
      default:
        return itemType;
    }
  }

  factory ItemModel.fromMap(Map<String, dynamic> map) {
    return ItemModel(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      itemCode: map['item_code'] as String,
      barcode: map['barcode'] as String?,
      nameAr: map['name_ar'] as String,
      nameEn: map['name_en'] as String?,
      description: map['description'] as String?,
      categoryId: map['category_id'] as String?,
      itemType: map['item_type'] as String,
      baseUnitId: map['base_unit_id'] as String,
      purchasePrice: (map['purchase_price'] as num?)?.toInt() ?? 0,
      sellingPrice: (map['selling_price'] as num?)?.toInt() ?? 0,
      minStockLevel: (map['min_stock_level'] as num?)?.toInt() ?? 0,
      maxStockLevel: (map['max_stock_level'] as num?)?.toInt(),
      reorderLevel: (map['reorder_level'] as num?)?.toInt() ?? 0,
      trackInventory: (map['track_inventory'] as num?)?.toInt() == 1,
      isActive: (map['is_active'] as num?)?.toInt() == 1,
      imagePath: map['image_path'] as String?,
      defaultWarehouseId: map['default_warehouse_id'] as String?,
      valuationMethod:
          (map['valuation_method'] as String?) ?? 'WEIGHTED_AVERAGE',
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String?,
      categoryNameAr: map['category_name_ar'] as String?,
      baseUnitNameAr: map['base_unit_name_ar'] as String?,
      baseUnitSymbol: map['base_unit_symbol'] as String?,
      defaultWarehouseName: map['default_warehouse_name'] as String?,
      currentStock: (map['current_stock'] as num?)?.toInt() ?? 0,
      currentAverageCost:
          (map['current_average_cost'] as num?)?.toInt() ?? 0,
      totalStockValue: (map['total_stock_value'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'item_code': itemCode,
      'barcode': barcode,
      'name_ar': nameAr,
      'name_en': nameEn,
      'description': description,
      'category_id': categoryId,
      'item_type': itemType,
      'base_unit_id': baseUnitId,
      'purchase_price': purchasePrice,
      'selling_price': sellingPrice,
      'min_stock_level': minStockLevel,
      'max_stock_level': maxStockLevel,
      'reorder_level': reorderLevel,
      'track_inventory': trackInventory ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'image_path': imagePath,
      'default_warehouse_id': defaultWarehouseId,
      'valuation_method': valuationMethod,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  ItemModel copyWith({
    String? id,
    String? organizationId,
    String? itemCode,
    String? barcode,
    String? nameAr,
    String? nameEn,
    String? description,
    String? categoryId,
    String? itemType,
    String? baseUnitId,
    int? purchasePrice,
    int? sellingPrice,
    int? minStockLevel,
    int? maxStockLevel,
    int? reorderLevel,
    bool? trackInventory,
    bool? isActive,
    String? imagePath,
    String? defaultWarehouseId,
    String? valuationMethod,
    String? createdAt,
    String? updatedAt,
    String? categoryNameAr,
    String? baseUnitNameAr,
    String? baseUnitSymbol,
    String? defaultWarehouseName,
    int? currentStock,
    int? currentAverageCost,
    int? totalStockValue,
  }) {
    return ItemModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      itemCode: itemCode ?? this.itemCode,
      barcode: barcode ?? this.barcode,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      itemType: itemType ?? this.itemType,
      baseUnitId: baseUnitId ?? this.baseUnitId,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      maxStockLevel: maxStockLevel ?? this.maxStockLevel,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      trackInventory: trackInventory ?? this.trackInventory,
      isActive: isActive ?? this.isActive,
      imagePath: imagePath ?? this.imagePath,
      defaultWarehouseId: defaultWarehouseId ?? this.defaultWarehouseId,
      valuationMethod: valuationMethod ?? this.valuationMethod,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      categoryNameAr: categoryNameAr ?? this.categoryNameAr,
      baseUnitNameAr: baseUnitNameAr ?? this.baseUnitNameAr,
      baseUnitSymbol: baseUnitSymbol ?? this.baseUnitSymbol,
      defaultWarehouseName: defaultWarehouseName ?? this.defaultWarehouseName,
      currentStock: currentStock ?? this.currentStock,
      currentAverageCost: currentAverageCost ?? this.currentAverageCost,
      totalStockValue: totalStockValue ?? this.totalStockValue,
    );
  }
}
