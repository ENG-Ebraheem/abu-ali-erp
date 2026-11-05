import 'journal_entry_line_model.dart';

/// Model representing a double-entry general ledger journal entry header.
class JournalEntryModel {
  final String id;
  final String organizationId;
  final String entryNumber;
  final String fiscalPeriodId;
  final String entryDate; // YYYY-MM-DD
  final String
      entryType; // 'GENERAL', 'OPENING', 'SALES', 'PURCHASE', 'RECEIPT', 'PAYMENT', 'REVALUATION', 'CLOSING'
  final String status; // 'DRAFT', 'POSTED', 'VOIDED'
  final String? reference;
  final String narration;
  final int totalBaseDebit; // Minor units (scale 100)
  final int totalBaseCredit; // Minor units (scale 100)
  final String? postedAt;
  final String createdAt;
  final String updatedAt;
  final List<JournalEntryLineModel> lines;

  const JournalEntryModel({
    required this.id,
    required this.organizationId,
    required this.entryNumber,
    required this.fiscalPeriodId,
    required this.entryDate,
    this.entryType = 'GENERAL',
    this.status = 'DRAFT',
    this.reference,
    required this.narration,
    this.totalBaseDebit = 0,
    this.totalBaseCredit = 0,
    this.postedAt,
    this.createdAt = '',
    this.updatedAt = '',
    this.lines = const [],
  });

  bool get isPosted => status == 'POSTED';
  bool get isDraft => status == 'DRAFT';
  bool get isVoided => status == 'VOIDED';

  bool get isBalanced =>
      totalBaseDebit == totalBaseCredit && totalBaseDebit > 0;

  double get totalBaseDebitDouble => totalBaseDebit / 100.0;
  double get totalBaseCreditDouble => totalBaseCredit / 100.0;

  String get typeLabel {
    switch (entryType) {
      case 'GENERAL':
        return 'قيد يومية عام';
      case 'OPENING':
        return 'قيد افتتاحي';
      case 'SALES':
        return 'قيد مبيعات';
      case 'PURCHASE':
        return 'قيد مشتريات';
      case 'RECEIPT':
        return 'سند قبض';
      case 'PAYMENT':
        return 'سند صرف';
      case 'REVALUATION':
        return 'إعادة تقييم عملات';
      case 'CLOSING':
        return 'قيد إقفال سنوي';
      default:
        return entryType;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'POSTED':
        return 'مرحّل';
      case 'DRAFT':
        return 'مسودة';
      case 'VOIDED':
        return 'ملغي / معكوس';
      default:
        return status;
    }
  }

  factory JournalEntryModel.fromMap(
    Map<String, dynamic> map, {
    List<JournalEntryLineModel> lines = const [],
  }) {
    return JournalEntryModel(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      entryNumber: map['entry_number'] as String,
      fiscalPeriodId: map['fiscal_period_id'] as String,
      entryDate: map['entry_date'] as String,
      entryType: map['entry_type'] as String? ?? 'GENERAL',
      status: map['status'] as String? ?? 'DRAFT',
      reference: map['reference'] as String?,
      narration: map['narration'] as String,
      totalBaseDebit: (map['total_base_debit'] as num?)?.toInt() ?? 0,
      totalBaseCredit: (map['total_base_credit'] as num?)?.toInt() ?? 0,
      postedAt: map['posted_at'] as String?,
      createdAt: map['created_at'] as String? ?? '',
      updatedAt: map['updated_at'] as String? ?? '',
      lines: lines,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'entry_number': entryNumber,
      'fiscal_period_id': fiscalPeriodId,
      'entry_date': entryDate,
      'entry_type': entryType,
      'status': status,
      'reference': reference,
      'narration': narration,
      'total_base_debit': totalBaseDebit,
      'total_base_credit': totalBaseCredit,
      'posted_at': postedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  JournalEntryModel copyWith({
    String? id,
    String? organizationId,
    String? entryNumber,
    String? fiscalPeriodId,
    String? entryDate,
    String? entryType,
    String? status,
    String? reference,
    String? narration,
    int? totalBaseDebit,
    int? totalBaseCredit,
    String? postedAt,
    String? createdAt,
    String? updatedAt,
    List<JournalEntryLineModel>? lines,
  }) {
    return JournalEntryModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      entryNumber: entryNumber ?? this.entryNumber,
      fiscalPeriodId: fiscalPeriodId ?? this.fiscalPeriodId,
      entryDate: entryDate ?? this.entryDate,
      entryType: entryType ?? this.entryType,
      status: status ?? this.status,
      reference: reference ?? this.reference,
      narration: narration ?? this.narration,
      totalBaseDebit: totalBaseDebit ?? this.totalBaseDebit,
      totalBaseCredit: totalBaseCredit ?? this.totalBaseCredit,
      postedAt: postedAt ?? this.postedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lines: lines ?? this.lines,
    );
  }
}
