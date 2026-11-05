import 'package:abu_ali/core/constants/database_constants.dart';

/// Stock Movement ledger record for physical inventory tracking.
class StockMovementModel {
  final String id;
  final String organizationId;
  final String itemId;
  final String warehouseId;
  final String documentId;
  final String? documentLineId;
  final String documentNumber;
  final String movementType; // OPENING, RECEIPT, ISSUE, TRANSFER_OUT, TRANSFER_IN, ADJUSTMENT_IN, ADJUSTMENT_OUT
  final String movementDate;
  final int quantityIn; // Scaled 10^3
  final int quantityOut; // Scaled 10^3
  final int unitCost; // Minor units (scaled 10^2)
  final int totalCost; // Minor units (scaled 10^2)
  final String? notes;
  final String createdAt;

  // Joined presentation fields
  final String? itemNameAr;
  final String? itemCode;
  final String? warehouseName;
  final String? unitSymbol;
  final int runningQuantity; // Computed running balance (scaled 10^3)
  final int runningValue; // Computed running balance value (scaled 10^2)

  const StockMovementModel({
    required this.id,
    required this.organizationId,
    required this.itemId,
    required this.warehouseId,
    required this.documentId,
    this.documentLineId,
    required this.documentNumber,
    required this.movementType,
    required this.movementDate,
    this.quantityIn = 0,
    this.quantityOut = 0,
    this.unitCost = 0,
    this.totalCost = 0,
    this.notes,
    required this.createdAt,
    this.itemNameAr,
    this.itemCode,
    this.warehouseName,
    this.unitSymbol,
    this.runningQuantity = 0,
    this.runningValue = 0,
  });

  String get movementTypeLabelAr {
    switch (movementType) {
      case StockMovementType.opening:
        return 'رصيد افتتاحي';
      case StockMovementType.receipt:
        return 'إدخال مخزني';
      case StockMovementType.issue:
        return 'إخراج مخزني';
      case StockMovementType.transferOut:
        return 'مناقلة (صادر)';
      case StockMovementType.transferIn:
        return 'مناقلة (وارد)';
      case StockMovementType.adjustmentIn:
        return 'تسوية جردية (فائض)';
      case StockMovementType.adjustmentOut:
        return 'تسوية جردية (عجز)';
      default:
        return movementType;
    }
  }

  factory StockMovementModel.fromMap(Map<String, dynamic> map) {
    return StockMovementModel(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      itemId: map['item_id'] as String,
      warehouseId: map['warehouse_id'] as String,
      documentId: map['document_id'] as String,
      documentLineId: map['document_line_id'] as String?,
      documentNumber: map['document_number'] as String,
      movementType: map['movement_type'] as String,
      movementDate: map['movement_date'] as String,
      quantityIn: (map['quantity_in'] as num?)?.toInt() ?? 0,
      quantityOut: (map['quantity_out'] as num?)?.toInt() ?? 0,
      unitCost: (map['unit_cost'] as num?)?.toInt() ?? 0,
      totalCost: (map['total_cost'] as num?)?.toInt() ?? 0,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
      itemNameAr: map['item_name_ar'] as String?,
      itemCode: map['item_code'] as String?,
      warehouseName: map['warehouse_name'] as String?,
      unitSymbol: map['unit_symbol'] as String?,
      runningQuantity: (map['running_quantity'] as num?)?.toInt() ?? 0,
      runningValue: (map['running_value'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'item_id': itemId,
      'warehouse_id': warehouseId,
      'document_id': documentId,
      'document_line_id': documentLineId,
      'document_number': documentNumber,
      'movement_type': movementType,
      'movement_date': movementDate,
      'quantity_in': quantityIn,
      'quantity_out': quantityOut,
      'unit_cost': unitCost,
      'total_cost': totalCost,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  StockMovementModel copyWith({
    String? id,
    String? organizationId,
    String? itemId,
    String? warehouseId,
    String? documentId,
    String? documentLineId,
    String? documentNumber,
    String? movementType,
    String? movementDate,
    int? quantityIn,
    int? quantityOut,
    int? unitCost,
    int? totalCost,
    String? notes,
    String? createdAt,
    String? itemNameAr,
    String? itemCode,
    String? warehouseName,
    String? unitSymbol,
    int? runningQuantity,
    int? runningValue,
  }) {
    return StockMovementModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      itemId: itemId ?? this.itemId,
      warehouseId: warehouseId ?? this.warehouseId,
      documentId: documentId ?? this.documentId,
      documentLineId: documentLineId ?? this.documentLineId,
      documentNumber: documentNumber ?? this.documentNumber,
      movementType: movementType ?? this.movementType,
      movementDate: movementDate ?? this.movementDate,
      quantityIn: quantityIn ?? this.quantityIn,
      quantityOut: quantityOut ?? this.quantityOut,
      unitCost: unitCost ?? this.unitCost,
      totalCost: totalCost ?? this.totalCost,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      itemNameAr: itemNameAr ?? this.itemNameAr,
      itemCode: itemCode ?? this.itemCode,
      warehouseName: warehouseName ?? this.warehouseName,
      unitSymbol: unitSymbol ?? this.unitSymbol,
      runningQuantity: runningQuantity ?? this.runningQuantity,
      runningValue: runningValue ?? this.runningValue,
    );
  }
}
