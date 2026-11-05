import '../../../core/constants/database_constants.dart';

/// Represents an Opening Balance header record for an organization and fiscal year.
class OpeningBalanceModel {
  final String id;
  final String organizationId;
  final String fiscalYearId;
  final String? journalEntryId;
  final String asOfDate;
  final String status; // 'DRAFT', 'POSTED'
  final String? notes;
  final String createdAt;
  final String updatedAt;

  const OpeningBalanceModel({
    required this.id,
    required this.organizationId,
    required this.fiscalYearId,
    this.journalEntryId,
    required this.asOfDate,
    this.status = 'DRAFT',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPosted => status == 'POSTED';
  bool get isDraft => status == 'DRAFT';

  factory OpeningBalanceModel.fromMap(Map<String, dynamic> map) {
    return OpeningBalanceModel(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      fiscalYearId: map['fiscal_year_id'] as String,
      journalEntryId: map['journal_entry_id'] as String?,
      asOfDate: map['as_of_date'] as String,
      status: map['status'] as String? ?? 'DRAFT',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String? ?? '',
      updatedAt: map['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'fiscal_year_id': fiscalYearId,
      'journal_entry_id': journalEntryId,
      'as_of_date': asOfDate,
      'status': status,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  OpeningBalanceModel copyWith({
    String? id,
    String? organizationId,
    String? fiscalYearId,
    String? journalEntryId,
    String? asOfDate,
    String? status,
    String? notes,
    String? createdAt,
    String? updatedAt,
  }) {
    return OpeningBalanceModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      fiscalYearId: fiscalYearId ?? this.fiscalYearId,
      journalEntryId: journalEntryId ?? this.journalEntryId,
      asOfDate: asOfDate ?? this.asOfDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// In-memory and draft line item for entering opening account/subledger balances.
class OpeningBalanceLineItem {
  final String id;
  final String accountId;
  final String accountCode;
  final String accountNameAr;
  final String accountType;
  final String accountNature;
  final String? partyId;
  final String? partyNameAr;
  final String currencyCode;
  final int exchangeRateScaled;
  final int foreignDebit;
  final int foreignCredit;
  final int baseDebit;
  final int baseCredit;
  final String? description;

  const OpeningBalanceLineItem({
    required this.id,
    required this.accountId,
    required this.accountCode,
    required this.accountNameAr,
    required this.accountType,
    required this.accountNature,
    this.partyId,
    this.partyNameAr,
    required this.currencyCode,
    this.exchangeRateScaled = DatabaseConstants.exchangeRateScale,
    this.foreignDebit = 0,
    this.foreignCredit = 0,
    required this.baseDebit,
    required this.baseCredit,
    this.description,
  });

  double get baseDebitDouble => baseDebit / 100.0;
  double get baseCreditDouble => baseCredit / 100.0;

  OpeningBalanceLineItem copyWith({
    String? id,
    String? accountId,
    String? accountCode,
    String? accountNameAr,
    String? accountType,
    String? accountNature,
    String? partyId,
    String? partyNameAr,
    String? currencyCode,
    int? exchangeRateScaled,
    int? foreignDebit,
    int? foreignCredit,
    int? baseDebit,
    int? baseCredit,
    String? description,
  }) {
    return OpeningBalanceLineItem(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      accountCode: accountCode ?? this.accountCode,
      accountNameAr: accountNameAr ?? this.accountNameAr,
      accountType: accountType ?? this.accountType,
      accountNature: accountNature ?? this.accountNature,
      partyId: partyId ?? this.partyId,
      partyNameAr: partyNameAr ?? this.partyNameAr,
      currencyCode: currencyCode ?? this.currencyCode,
      exchangeRateScaled: exchangeRateScaled ?? this.exchangeRateScaled,
      foreignDebit: foreignDebit ?? this.foreignDebit,
      foreignCredit: foreignCredit ?? this.foreignCredit,
      baseDebit: baseDebit ?? this.baseDebit,
      baseCredit: baseCredit ?? this.baseCredit,
      description: description ?? this.description,
    );
  }
}
