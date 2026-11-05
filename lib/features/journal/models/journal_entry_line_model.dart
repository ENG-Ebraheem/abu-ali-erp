/// Model representing a single line in a general ledger journal entry.
class JournalEntryLineModel {
  final String id;
  final String organizationId;
  final String journalEntryId;
  final int lineNumber;
  final String accountId;
  final String? partyId;
  final String? description;
  final String currencyCode;
  final int exchangeRateScaled; // Scale 1,000,000 = 1.000000
  final int foreignDebit; // Minor units (scale 100)
  final int foreignCredit; // Minor units (scale 100)
  final int baseDebit; // Minor units (scale 100)
  final int baseCredit; // Minor units (scale 100)
  final String createdAt;

  // Joined display fields
  final String? accountCode;
  final String? accountNameAr;
  final String? partyNameAr;

  const JournalEntryLineModel({
    required this.id,
    required this.organizationId,
    required this.journalEntryId,
    required this.lineNumber,
    required this.accountId,
    this.partyId,
    this.description,
    required this.currencyCode,
    required this.exchangeRateScaled,
    this.foreignDebit = 0,
    this.foreignCredit = 0,
    this.baseDebit = 0,
    this.baseCredit = 0,
    this.createdAt = '',
    this.accountCode,
    this.accountNameAr,
    this.partyNameAr,
  });

  bool get isDebit => baseDebit > 0 || foreignDebit > 0;
  bool get isCredit => baseCredit > 0 || foreignCredit > 0;

  double get foreignDebitDouble => foreignDebit / 100.0;
  double get foreignCreditDouble => foreignCredit / 100.0;
  double get baseDebitDouble => baseDebit / 100.0;
  double get baseCreditDouble => baseCredit / 100.0;
  double get exchangeRateDouble => exchangeRateScaled / 1000000.0;

  factory JournalEntryLineModel.fromMap(Map<String, dynamic> map) {
    return JournalEntryLineModel(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      journalEntryId: map['journal_entry_id'] as String,
      lineNumber: (map['line_number'] as num).toInt(),
      accountId: map['account_id'] as String,
      partyId: map['party_id'] as String?,
      description: map['description'] as String?,
      currencyCode: map['currency_code'] as String,
      exchangeRateScaled: (map['exchange_rate_scaled'] as num).toInt(),
      foreignDebit: (map['foreign_debit'] as num?)?.toInt() ?? 0,
      foreignCredit: (map['foreign_credit'] as num?)?.toInt() ?? 0,
      baseDebit: (map['base_debit'] as num?)?.toInt() ?? 0,
      baseCredit: (map['base_credit'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] as String? ?? '',
      accountCode: map['account_code'] as String?,
      accountNameAr: map['account_name_ar'] as String?,
      partyNameAr: map['party_name_ar'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'journal_entry_id': journalEntryId,
      'line_number': lineNumber,
      'account_id': accountId,
      'party_id': partyId,
      'description': description,
      'currency_code': currencyCode,
      'exchange_rate_scaled': exchangeRateScaled,
      'foreign_debit': foreignDebit,
      'foreign_credit': foreignCredit,
      'base_debit': baseDebit,
      'base_credit': baseCredit,
      'created_at': createdAt,
    };
  }

  JournalEntryLineModel copyWith({
    String? id,
    String? organizationId,
    String? journalEntryId,
    int? lineNumber,
    String? accountId,
    String? partyId,
    String? description,
    String? currencyCode,
    int? exchangeRateScaled,
    int? foreignDebit,
    int? foreignCredit,
    int? baseDebit,
    int? baseCredit,
    String? createdAt,
    String? accountCode,
    String? accountNameAr,
    String? partyNameAr,
  }) {
    return JournalEntryLineModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      journalEntryId: journalEntryId ?? this.journalEntryId,
      lineNumber: lineNumber ?? this.lineNumber,
      accountId: accountId ?? this.accountId,
      partyId: partyId ?? this.partyId,
      description: description ?? this.description,
      currencyCode: currencyCode ?? this.currencyCode,
      exchangeRateScaled: exchangeRateScaled ?? this.exchangeRateScaled,
      foreignDebit: foreignDebit ?? this.foreignDebit,
      foreignCredit: foreignCredit ?? this.foreignCredit,
      baseDebit: baseDebit ?? this.baseDebit,
      baseCredit: baseCredit ?? this.baseCredit,
      createdAt: createdAt ?? this.createdAt,
      accountCode: accountCode ?? this.accountCode,
      accountNameAr: accountNameAr ?? this.accountNameAr,
      partyNameAr: partyNameAr ?? this.partyNameAr,
    );
  }
}
