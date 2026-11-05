import 'package:abu_ali/core/constants/database_constants.dart';
import 'stock_document_line_model.dart';

/// Stock Document Header model (Receipt, Issue, Transfer, Adjustment, Opening).
class StockDocumentModel {
  final String id;
  final String organizationId;
  final String documentNumber;
  final String documentType; // OPENING, RECEIPT, ISSUE, TRANSFER, ADJUSTMENT
  final String documentDate;
  final String? sourceWarehouseId;
  final String? destinationWarehouseId;
  final String? partyId;
  final String? referenceNumber;
  final String status; // DRAFT, POSTED, CANCELLED
  final String? notes;
  final int totalCost; // Minor units (scaled 10^2)
  final String? journalEntryId;
  final String createdAt;
  final String? postedAt;
  final String? postedBy;

  // Joined presentation fields
  final String? sourceWarehouseName;
  final String? destinationWarehouseName;
  final String? partyNameAr;
  final List<StockDocumentLineModel> lines;

  const StockDocumentModel({
    required this.id,
    required this.organizationId,
    required this.documentNumber,
    required this.documentType,
    required this.documentDate,
    this.sourceWarehouseId,
    this.destinationWarehouseId,
    this.partyId,
    this.referenceNumber,
    this.status = 'DRAFT',
    this.notes,
    this.totalCost = 0,
    this.journalEntryId,
    required this.createdAt,
    this.postedAt,
    this.postedBy,
    this.sourceWarehouseName,
    this.destinationWarehouseName,
    this.partyNameAr,
    this.lines = const [],
  });

  bool get isPosted => status == StockDocumentStatus.posted;
  bool get isDraft => status == StockDocumentStatus.draft;
  bool get isCancelled => status == StockDocumentStatus.cancelled;

  String get documentTypeLabelAr {
    switch (documentType) {
      case StockDocumentType.opening:
        return 'رصيد افتتاحي';
      case StockDocumentType.receipt:
        return 'سند إدخال مخزني';
      case StockDocumentType.issue:
        return 'سند إخراج مخزني';
      case StockDocumentType.transfer:
        return 'مناقلة مستودعات';
      case StockDocumentType.adjustment:
        return 'تسوية جردية';
      default:
        return documentType;
    }
  }

  String get statusLabelAr {
    switch (status) {
      case StockDocumentStatus.draft:
        return 'مسودة';
      case StockDocumentStatus.posted:
        return 'مرحّل';
      case StockDocumentStatus.cancelled:
        return 'ملغي';
      default:
        return status;
    }
  }

  factory StockDocumentModel.fromMap(
    Map<String, dynamic> map, {
    List<StockDocumentLineModel> lines = const [],
  }) {
    return StockDocumentModel(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      documentNumber: map['document_number'] as String,
      documentType: map['document_type'] as String,
      documentDate: map['document_date'] as String,
      sourceWarehouseId: map['source_warehouse_id'] as String?,
      destinationWarehouseId: map['destination_warehouse_id'] as String?,
      partyId: map['party_id'] as String?,
      referenceNumber: map['reference_number'] as String?,
      status: map['status'] as String? ?? 'DRAFT',
      notes: map['notes'] as String?,
      totalCost: (map['total_cost'] as num?)?.toInt() ?? 0,
      journalEntryId: map['journal_entry_id'] as String?,
      createdAt: map['created_at'] as String,
      postedAt: map['posted_at'] as String?,
      postedBy: map['posted_by'] as String?,
      sourceWarehouseName: map['source_warehouse_name'] as String?,
      destinationWarehouseName: map['destination_warehouse_name'] as String?,
      partyNameAr: map['party_name_ar'] as String?,
      lines: lines,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'document_number': documentNumber,
      'document_type': documentType,
      'document_date': documentDate,
      'source_warehouse_id': sourceWarehouseId,
      'destination_warehouse_id': destinationWarehouseId,
      'party_id': partyId,
      'reference_number': referenceNumber,
      'status': status,
      'notes': notes,
      'total_cost': totalCost,
      'journal_entry_id': journalEntryId,
      'created_at': createdAt,
      'posted_at': postedAt,
      'posted_by': postedBy,
    };
  }

  StockDocumentModel copyWith({
    String? id,
    String? organizationId,
    String? documentNumber,
    String? documentType,
    String? documentDate,
    String? sourceWarehouseId,
    String? destinationWarehouseId,
    String? partyId,
    String? referenceNumber,
    String? status,
    String? notes,
    int? totalCost,
    String? journalEntryId,
    String? createdAt,
    String? postedAt,
    String? postedBy,
    String? sourceWarehouseName,
    String? destinationWarehouseName,
    String? partyNameAr,
    List<StockDocumentLineModel>? lines,
  }) {
    return StockDocumentModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      documentNumber: documentNumber ?? this.documentNumber,
      documentType: documentType ?? this.documentType,
      documentDate: documentDate ?? this.documentDate,
      sourceWarehouseId: sourceWarehouseId ?? this.sourceWarehouseId,
      destinationWarehouseId:
          destinationWarehouseId ?? this.destinationWarehouseId,
      partyId: partyId ?? this.partyId,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      totalCost: totalCost ?? this.totalCost,
      journalEntryId: journalEntryId ?? this.journalEntryId,
      createdAt: createdAt ?? this.createdAt,
      postedAt: postedAt ?? this.postedAt,
      postedBy: postedBy ?? this.postedBy,
      sourceWarehouseName: sourceWarehouseName ?? this.sourceWarehouseName,
      destinationWarehouseName:
          destinationWarehouseName ?? this.destinationWarehouseName,
      partyNameAr: partyNameAr ?? this.partyNameAr,
      lines: lines ?? this.lines,
    );
  }
}
