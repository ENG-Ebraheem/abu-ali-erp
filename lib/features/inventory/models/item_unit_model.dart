/// Multi-unit measurement conversion for an item.
class ItemUnitModel {
  final String id;
  final String organizationId;
  final String itemId;
  final String unitId;
  final int conversionFactor; // Scaled 10^3 (e.g. 1 carton = 12 pcs => 12000)
  final int? purchasePrice; // Minor units (scaled 10^2)
  final int? sellingPrice; // Minor units (scaled 10^2)
  final String? barcode;
  final String createdAt;

  // Joined presentation fields
  final String? unitNameAr;
  final String? unitSymbol;
  final String? baseUnitSymbol;

  const ItemUnitModel({
    required this.id,
    required this.organizationId,
    required this.itemId,
    required this.unitId,
    required this.conversionFactor,
    this.purchasePrice,
    this.sellingPrice,
    this.barcode,
    required this.createdAt,
    this.unitNameAr,
    this.unitSymbol,
    this.baseUnitSymbol,
  });

  /// Conversion multiplier to base unit (e.g. 12.0)
  double get multiplier => conversionFactor / 1000.0;

  factory ItemUnitModel.fromMap(Map<String, dynamic> map) {
    return ItemUnitModel(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      itemId: map['item_id'] as String,
      unitId: map['unit_id'] as String,
      conversionFactor: (map['conversion_factor'] as num).toInt(),
      purchasePrice: (map['purchase_price'] as num?)?.toInt(),
      sellingPrice: (map['selling_price'] as num?)?.toInt(),
      barcode: map['barcode'] as String?,
      createdAt: map['created_at'] as String,
      unitNameAr: map['unit_name_ar'] as String?,
      unitSymbol: map['unit_symbol'] as String?,
      baseUnitSymbol: map['base_unit_symbol'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'item_id': itemId,
      'unit_id': unitId,
      'conversion_factor': conversionFactor,
      'purchase_price': purchasePrice,
      'selling_price': sellingPrice,
      'barcode': barcode,
      'created_at': createdAt,
    };
  }
}

