/// Line item in a physical stocktaking session.
class StocktakingLineModel {
  final String id;
  final String organizationId;
  final String sessionId;
  final String itemId;
  final int systemQuantity; // Scaled 10^3
  final int? countedQuantity; // Scaled 10^3 (null if not yet counted)
  final int? differenceQuantity; // Scaled 10^3 = counted - system
  final int unitCost; // Minor units (scaled 10^2)
  final int? differenceValue; // Minor units (scaled 10^2) = diff * unitCost / 1000
  final String? notes;

  // Joined presentation fields
  final String? itemCode;
  final String? itemNameAr;
  final String? unitNameAr;
  final String? unitSymbol;

  const StocktakingLineModel({
    required this.id,
    required this.organizationId,
    required this.sessionId,
    required this.itemId,
    required this.systemQuantity,
    this.countedQuantity,
    this.differenceQuantity,
    this.unitCost = 0,
    this.differenceValue,
    this.notes,
    this.itemCode,
    this.itemNameAr,
    this.unitNameAr,
    this.unitSymbol,
  });

  bool get isCounted => countedQuantity != null;
  bool get hasVariance =>
      countedQuantity != null && (differenceQuantity ?? 0) != 0;

  factory StocktakingLineModel.fromMap(Map<String, dynamic> map) {
    return StocktakingLineModel(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      sessionId: map['session_id'] as String,
      itemId: map['item_id'] as String,
      systemQuantity: (map['system_quantity'] as num).toInt(),
      countedQuantity: (map['counted_quantity'] as num?)?.toInt(),
      differenceQuantity: (map['difference_quantity'] as num?)?.toInt(),
      unitCost: (map['unit_cost'] as num?)?.toInt() ?? 0,
      differenceValue: (map['difference_value'] as num?)?.toInt(),
      notes: map['notes'] as String?,
      itemCode: map['item_code'] as String?,
      itemNameAr: map['item_name_ar'] as String?,
      unitNameAr: map['unit_name_ar'] as String?,
      unitSymbol: map['unit_symbol'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'session_id': sessionId,
      'item_id': itemId,
      'system_quantity': systemQuantity,
      'counted_quantity': countedQuantity,
      'difference_quantity': differenceQuantity,
      'unit_cost': unitCost,
      'difference_value': differenceValue,
      'notes': notes,
    };
  }

  StocktakingLineModel copyWith({
    String? id,
    String? organizationId,
    String? sessionId,
    String? itemId,
    int? systemQuantity,
    int? countedQuantity,
    int? differenceQuantity,
    int? unitCost,
    int? differenceValue,
    String? notes,
    String? itemCode,
    String? itemNameAr,
    String? unitNameAr,
    String? unitSymbol,
  }) {
    return StocktakingLineModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      sessionId: sessionId ?? this.sessionId,
      itemId: itemId ?? this.itemId,
      systemQuantity: systemQuantity ?? this.systemQuantity,
      countedQuantity: countedQuantity ?? this.countedQuantity,
      differenceQuantity: differenceQuantity ?? this.differenceQuantity,
      unitCost: unitCost ?? this.unitCost,
      differenceValue: differenceValue ?? this.differenceValue,
      notes: notes ?? this.notes,
      itemCode: itemCode ?? this.itemCode,
      itemNameAr: itemNameAr ?? this.itemNameAr,
      unitNameAr: unitNameAr ?? this.unitNameAr,
      unitSymbol: unitSymbol ?? this.unitSymbol,
    );
  }
}

