import 'package:abu_ali/core/constants/database_constants.dart';
import 'stocktaking_line_model.dart';

/// Stocktaking session header.
class StocktakingSessionModel {
  final String id;
  final String organizationId;
  final String sessionNumber;
  final String warehouseId;
  final String? categoryId;
  final String status; // IN_PROGRESS, COMPLETED, POSTED, CANCELLED
  final String startedAt;
  final String? completedAt;
  final String? notes;
  final String? adjustmentDocumentId;
  final String createdAt;

  // Joined presentation fields
  final String? warehouseName;
  final String? categoryNameAr;
  final int totalItems;
  final int countedItems;
  final int totalDifferenceValue; // Minor units (scaled 10^2)
  final List<StocktakingLineModel> lines;

  const StocktakingSessionModel({
    required this.id,
    required this.organizationId,
    required this.sessionNumber,
    required this.warehouseId,
    this.categoryId,
    this.status = 'IN_PROGRESS',
    required this.startedAt,
    this.completedAt,
    this.notes,
    this.adjustmentDocumentId,
    required this.createdAt,
    this.warehouseName,
    this.categoryNameAr,
    this.totalItems = 0,
    this.countedItems = 0,
    this.totalDifferenceValue = 0,
    this.lines = const [],
  });

  bool get isInProgress => status == StocktakingStatus.inProgress;
  bool get isCompleted => status == StocktakingStatus.completed;
  bool get isPosted => status == StocktakingStatus.posted;
  bool get isCancelled => status == StocktakingStatus.cancelled;

  String get statusLabelAr {
    switch (status) {
      case StocktakingStatus.inProgress:
        return 'قيد الجرد';
      case StocktakingStatus.completed:
        return 'مكتمل (بانتظار الاعتماد)';
      case StocktakingStatus.posted:
        return 'مرحّل ومسوّى';
      case StocktakingStatus.cancelled:
        return 'ملغي';
      default:
        return status;
    }
  }

  factory StocktakingSessionModel.fromMap(
    Map<String, dynamic> map, {
    List<StocktakingLineModel> lines = const [],
  }) {
    return StocktakingSessionModel(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      sessionNumber: map['session_number'] as String,
      warehouseId: map['warehouse_id'] as String,
      categoryId: map['category_id'] as String?,
      status: map['status'] as String? ?? 'IN_PROGRESS',
      startedAt: map['started_at'] as String,
      completedAt: map['completed_at'] as String?,
      notes: map['notes'] as String?,
      adjustmentDocumentId: map['adjustment_document_id'] as String?,
      createdAt: map['created_at'] as String,
      warehouseName: map['warehouse_name'] as String?,
      categoryNameAr: map['category_name_ar'] as String?,
      totalItems: (map['total_items'] as num?)?.toInt() ?? 0,
      countedItems: (map['counted_items'] as num?)?.toInt() ?? 0,
      totalDifferenceValue:
          (map['total_difference_value'] as num?)?.toInt() ?? 0,
      lines: lines,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'session_number': sessionNumber,
      'warehouse_id': warehouseId,
      'category_id': categoryId,
      'status': status,
      'started_at': startedAt,
      'completed_at': completedAt,
      'notes': notes,
      'adjustment_document_id': adjustmentDocumentId,
      'created_at': createdAt,
    };
  }

  StocktakingSessionModel copyWith({
    String? id,
    String? organizationId,
    String? sessionNumber,
    String? warehouseId,
    String? categoryId,
    String? status,
    String? startedAt,
    String? completedAt,
    String? notes,
    String? adjustmentDocumentId,
    String? createdAt,
    String? warehouseName,
    String? categoryNameAr,
    int? totalItems,
    int? countedItems,
    int? totalDifferenceValue,
    List<StocktakingLineModel>? lines,
  }) {
    return StocktakingSessionModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      sessionNumber: sessionNumber ?? this.sessionNumber,
      warehouseId: warehouseId ?? this.warehouseId,
      categoryId: categoryId ?? this.categoryId,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
      adjustmentDocumentId: adjustmentDocumentId ?? this.adjustmentDocumentId,
      createdAt: createdAt ?? this.createdAt,
      warehouseName: warehouseName ?? this.warehouseName,
      categoryNameAr: categoryNameAr ?? this.categoryNameAr,
      totalItems: totalItems ?? this.totalItems,
      countedItems: countedItems ?? this.countedItems,
      totalDifferenceValue:
          totalDifferenceValue ?? this.totalDifferenceValue,
      lines: lines ?? this.lines,
    );
  }
}
