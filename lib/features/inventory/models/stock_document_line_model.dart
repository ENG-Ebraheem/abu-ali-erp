/// Line item for a stock document (Receipt, Issue, Transfer, Adjustment, Opening).
class StockDocumentLineModel {
  final String id;
  final String organizationId;
  final String documentId;
  final int lineNumber;
  final String itemId;
  final String unitId;
  final int quantity; // Scaled 10^3 (Quantity in entered unit)
  final int conversionFactor; // Scaled 10^3 (Conversion to base unit)
  final int baseQuantity; // Scaled 10^3 (quantity * conversionFactor / 1000)
  final int unitCost; // Minor units (scaled 10^2) per base unit
  final int totalCost; // Minor units (scaled 10^2) = baseQuantity * unitCost / 1000
  final String? expenseAccountId;
  final String? notes;

  // Joined presentation fields
  final String? itemCode;
  final String? itemNameAr;
  final String? unitNameAr;
  final String? unitSymbol;
  final String? expenseAccountNameAr;

  const StockDocumentLineModel({
    required this.id,
    required this.organizationId,
    required this.documentId,
    required this.lineNumber,
    required this.itemId,
    required this.unitId,
    required this.quantity,
    this.conversionFactor = 1000,
    required this.baseQuantity,
    this.unitCost = 0,
    this.totalCost = 0,
    this.expenseAccountId,
    this.notes,
    this.itemCode,
    this.itemNameAr,
    this.unitNameAr,
    this.unitSymbol,
    this.expenseAccountNameAr,
  });

  factory StockDocumentLineModel.fromMap(Map<String, dynamic> map) {
    return StockDocumentLineModel(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      documentId: map['document_id'] as String,
      lineNumber: (map['line_number'] as num).toInt(),
      itemId: map['item_id'] as String,
      unitId: map['unit_id'] as String,
      quantity: (map['quantity'] as num).toInt(),
      conversionFactor: (map['conversion_factor'] as num?)?.toInt() ?? 1000,
      baseQuantity: (map['base_quantity'] as num).toInt(),
      unitCost: (map['unit_cost'] as num?)?.toInt() ?? 0,
      totalCost: (map['total_cost'] as num?)?.toInt() ?? 0,
      expenseAccountId: map['expense_account_id'] as String?,
      notes: map['notes'] as String?,
      itemCode: map['item_code'] as String?,
      itemNameAr: map['item_name_ar'] as String?,
      unitNameAr: map['unit_name_ar'] as String?,
      unitSymbol: map['unit_symbol'] as String?,
      expenseAccountNameAr: map['expense_account_name_ar'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'document_id': documentId,
      'line_number': lineNumber,
      'item_id': itemId,
      'unit_id': unitId,
      'quantity': quantity,
      'conversion_factor': conversionFactor,
      'base_quantity': baseQuantity,
      'unit_cost': unitCost,
      'total_cost': totalCost,
      'expense_account_id': expenseAccountId,
      'notes': notes,
    };
  }

  StockDocumentLineModel copyWith({
    String? id,
    String? organizationId,
    String? documentId,
    int? lineNumber,
    String? itemId,
    String? unitId,
    int? quantity,
    int? conversionFactor,
    int? baseQuantity,
    int? unitCost,
    int? totalCost,
    String? expenseAccountId,
    String? notes,
    String? itemCode,
    String? itemNameAr,
    String? unitNameAr,
    String? unitSymbol,
    String? expenseAccountNameAr,
  }) {
    return StockDocumentLineModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      documentId: documentId ?? this.documentId,
      lineNumber: lineNumber ?? this.lineNumber,
      itemId: itemId ?? this.itemId,
      unitId: unitId ?? this.unitId,
      quantity: quantity ?? this.quantity,
      conversionFactor: conversionFactor ?? this.conversionFactor,
      baseQuantity: baseQuantity ?? this.baseQuantity,
      unitCost: unitCost ?? this.unitCost,
      totalCost: totalCost ?? this.totalCost,
      expenseAccountId: expenseAccountId ?? this.expenseAccountId,
      notes: notes ?? this.notes,
      itemCode: itemCode ?? this.itemCode,
      itemNameAr: itemNameAr ?? this.itemNameAr,
      unitNameAr: unitNameAr ?? this.unitNameAr,
      unitSymbol: unitSymbol ?? this.unitSymbol,
      expenseAccountNameAr: expenseAccountNameAr ?? this.expenseAccountNameAr,
    );
  }
}

