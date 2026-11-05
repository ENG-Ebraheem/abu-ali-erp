/// Domain model representing a ledger account in the Chart of Accounts (COA).
class AccountModel {
  final String id;
  final String organizationId;
  final String accountCode;
  final String accountNameAr;
  final String? accountNameEn;
  final String accountType; // ASSET, LIABILITY, EQUITY, REVENUE, EXPENSE
  final String accountNature; // DEBIT, CREDIT
  final String? parentId;
  final String? currencyCode;
  final bool isCashBank;
  final bool isReconcilable;
  final bool isActive;
  final bool isSystem;
  final DateTime createdAt;

  // Runtime computed balances from posted journal lines
  final int baseBalance;
  final int totalDebit;
  final int totalCredit;
  final int foreignBalance;
  final List<AccountModel> children;

  const AccountModel({
    required this.id,
    required this.organizationId,
    required this.accountCode,
    required this.accountNameAr,
    this.accountNameEn,
    required this.accountType,
    required this.accountNature,
    this.parentId,
    this.currencyCode,
    this.isCashBank = false,
    this.isReconcilable = false,
    this.isActive = true,
    this.isSystem = false,
    required this.createdAt,
    this.baseBalance = 0,
    this.totalDebit = 0,
    this.totalCredit = 0,
    this.foreignBalance = 0,
    this.children = const [],
  });

  AccountModel copyWith({
    String? id,
    String? organizationId,
    String? accountCode,
    String? accountNameAr,
    String? accountNameEn,
    String? accountType,
    String? accountNature,
    String? parentId,
    String? currencyCode,
    bool? isCashBank,
    bool? isReconcilable,
    bool? isActive,
    bool? isSystem,
    DateTime? createdAt,
    int? baseBalance,
    int? totalDebit,
    int? totalCredit,
    int? foreignBalance,
    List<AccountModel>? children,
  }) {
    return AccountModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      accountCode: accountCode ?? this.accountCode,
      accountNameAr: accountNameAr ?? this.accountNameAr,
      accountNameEn: accountNameEn ?? this.accountNameEn,
      accountType: accountType ?? this.accountType,
      accountNature: accountNature ?? this.accountNature,
      parentId: parentId ?? this.parentId,
      currencyCode: currencyCode ?? this.currencyCode,
      isCashBank: isCashBank ?? this.isCashBank,
      isReconcilable: isReconcilable ?? this.isReconcilable,
      isActive: isActive ?? this.isActive,
      isSystem: isSystem ?? this.isSystem,
      createdAt: createdAt ?? this.createdAt,
      baseBalance: baseBalance ?? this.baseBalance,
      totalDebit: totalDebit ?? this.totalDebit,
      totalCredit: totalCredit ?? this.totalCredit,
      foreignBalance: foreignBalance ?? this.foreignBalance,
      children: children ?? this.children,
    );
  }

  factory AccountModel.fromMap(
    Map<String, dynamic> map, {
    int baseBalance = 0,
    int totalDebit = 0,
    int totalCredit = 0,
    int foreignBalance = 0,
    List<AccountModel> children = const [],
  }) {
    return AccountModel(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      accountCode: map['account_code'] as String,
      accountNameAr: map['account_name_ar'] as String,
      accountNameEn: map['account_name_en'] as String?,
      accountType: map['account_type'] as String,
      accountNature: map['account_nature'] as String,
      parentId: map['parent_id'] as String?,
      currencyCode: map['currency_code'] as String?,
      isCashBank: (map['is_cash_bank'] as int? ?? 0) == 1,
      isReconcilable: (map['is_reconcilable'] as int? ?? 0) == 1,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      isSystem: (map['is_system'] as int? ?? 0) == 1,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      baseBalance: baseBalance,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      foreignBalance: foreignBalance,
      children: children,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'account_code': accountCode,
      'account_name_ar': accountNameAr,
      'account_name_en': accountNameEn,
      'account_type': accountType,
      'account_nature': accountNature,
      'parent_id': parentId,
      'currency_code': currencyCode,
      'is_cash_bank': isCashBank ? 1 : 0,
      'is_reconcilable': isReconcilable ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'is_system': isSystem ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Localized Arabic name for the primary account classification.
  String get typeNameAr {
    switch (accountType) {
      case 'ASSET':
        return 'أصول';
      case 'LIABILITY':
        return 'خصوم (التزامات)';
      case 'EQUITY':
        return 'حقوق الملكية';
      case 'REVENUE':
        return 'إيرادات';
      case 'EXPENSE':
        return 'مصروفات';
      default:
        return accountType;
    }
  }

  /// Localized Arabic nature (DEBIT / CREDIT).
  String get natureNameAr => accountNature == 'DEBIT' ? 'مدين' : 'دائن';

  /// Whether this account can have child subaccounts (typically parent if code length <= 3).
  bool get isHeaderAccount => children.isNotEmpty || accountCode.length <= 2;
}

/// Model representing a single transaction in an account's ledger activity.
class AccountLedgerEntryModel {
  final String lineId;
  final String journalEntryId;
  final String entryNumber;
  final String entryDate;
  final String entryType;
  final String? reference;
  final String narration;
  final String? lineDescription;
  final String? partyId;
  final String? partyNameAr;
  final int baseDebit;
  final int baseCredit;
  final int foreignDebit;
  final int foreignCredit;
  final String currencyCode;
  final int exchangeRateScaled;
  final int runningBalance;

  const AccountLedgerEntryModel({
    required this.lineId,
    required this.journalEntryId,
    required this.entryNumber,
    required this.entryDate,
    required this.entryType,
    this.reference,
    required this.narration,
    this.lineDescription,
    this.partyId,
    this.partyNameAr,
    required this.baseDebit,
    required this.baseCredit,
    required this.foreignDebit,
    required this.foreignCredit,
    required this.currencyCode,
    required this.exchangeRateScaled,
    required this.runningBalance,
  });

  double get baseDebitDouble => baseDebit / 100.0;
  double get baseCreditDouble => baseCredit / 100.0;
  double get runningBalanceDouble => runningBalance / 100.0;

  String get entryTypeLabel {
    switch (entryType) {
      case 'OPENING':
        return 'رصيد افتتاحي';
      case 'GENERAL':
        return 'قيد يومية';
      case 'SALES':
        return 'فاتورة مبيعات';
      case 'PURCHASE':
        return 'فاتورة مشتريات';
      case 'RECEIPT':
        return 'سند قبض';
      case 'PAYMENT':
        return 'سند صرف';
      case 'REVALUATION':
        return 'فروق عملة';
      case 'CLOSING':
        return 'قيد إقفال';
      default:
        return entryType;
    }
  }
}
