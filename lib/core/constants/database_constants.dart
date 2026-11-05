/// Core database constants, table names, scale factors, and enumerated statuses.
class DatabaseConstants {
  DatabaseConstants._();

  /// Current database version.
  static const int databaseVersion = 4;

  /// Database file name.
  static const String databaseName = 'abu_ali.db';

  /// Scale factor for exchange rates (Fixed-point integer: 1.000000 = 1,000,000).
  ///
  /// Example:
  /// - Rate of 1.000000 is stored as 1,000,000
  /// - Rate of 250.500000 is stored as 250,500,000
  /// - Rate of 0.004000 is stored as 4,000
  static const int exchangeRateScale = 1000000;

  /// Scale factor for item quantities (Fixed-point integer: 1.000 = 1,000).
  static const int quantityScale = 1000;

  /// Default scale factor for minor monetary units (e.g. 100 fils/cents = 1 major unit).
  static const int defaultMoneyScale = 100;

  // Table Names
  static const String tableMigrations = 'schema_migrations';
  static const String tableCurrencies = 'currencies';
  static const String tableOrganizations = 'organizations';
  static const String tableExchangeRates = 'exchange_rates';
  static const String tableAppSettings = 'app_settings';
  static const String tableAuditLogs = 'audit_logs';
  static const String tableChartOfAccounts = 'chart_of_accounts';
  static const String tableFiscalYears = 'fiscal_years';
  static const String tableFiscalPeriods = 'fiscal_periods';
  static const String tableParties = 'parties';
  static const String tableJournalEntries = 'journal_entries';
  static const String tableJournalEntryLines = 'journal_entry_lines';
  static const String tableInvoices = 'invoices';
  static const String tableInvoiceLines = 'invoice_lines';
  static const String tablePayments = 'payments';
  static const String tablePaymentAllocations = 'payment_allocations';
  static const String tableOpeningBalances = 'opening_balances';
  static const String tableForexRevaluations = 'forex_revaluations';
  static const String tableForexRevaluationLines = 'forex_revaluation_lines';

  // Phase 8: Inventory & Warehouse Management Tables
  static const String tableWarehouses = 'warehouses';
  static const String tableItemCategories = 'item_categories';
  static const String tableUnitsOfMeasure = 'units_of_measure';
  static const String tableItems = 'items';
  static const String tableItemUnits = 'item_units';
  static const String tableStockDocuments = 'stock_documents';
  static const String tableStockDocumentLines = 'stock_document_lines';
  static const String tableStockMovements = 'stock_movements';
  static const String tableStocktakingSessions = 'stocktaking_sessions';
  static const String tableStocktakingLines = 'stocktaking_lines';
  static const String tableInventorySettings = 'inventory_settings';
}

/// Standard currency codes supported out of the box.
class CurrencyCodes {
  CurrencyCodes._();

  static const String yer = 'YER'; // Yemeni Rial
  static const String usd = 'USD'; // United States Dollar
  static const String sar = 'SAR'; // Saudi Riyal
}

/// Statuses for journal entries.
class JournalEntryStatus {
  JournalEntryStatus._();

  static const String draft = 'DRAFT';
  static const String posted = 'POSTED';
  static const String voided = 'VOIDED';
}

/// Types of journal entries.
class JournalEntryType {
  JournalEntryType._();

  static const String general = 'GENERAL';
  static const String opening = 'OPENING';
  static const String sales = 'SALES';
  static const String purchase = 'PURCHASE';
  static const String receipt = 'RECEIPT';
  static const String payment = 'PAYMENT';
  static const String revaluation = 'REVALUATION';
  static const String closing = 'CLOSING';
}

/// Account types according to standard accounting classifications.
class AccountType {
  AccountType._();

  static const String asset = 'ASSET';
  static const String liability = 'LIABILITY';
  static const String equity = 'EQUITY';
  static const String revenue = 'REVENUE';
  static const String expense = 'EXPENSE';
}

/// Normal balance nature of an account.
class AccountNature {
  AccountNature._();

  static const String debit = 'DEBIT';
  static const String credit = 'CREDIT';
}

/// Party classifications (Customers and Suppliers).
class PartyType {
  PartyType._();

  static const String customer = 'CUSTOMER';
  static const String supplier = 'SUPPLIER';
  static const String both = 'BOTH';
}

/// Invoice document types.
class InvoiceType {
  InvoiceType._();

  static const String sales = 'SALES';
  static const String purchase = 'PURCHASE';
  static const String salesReturn = 'SALES_RETURN';
  static const String purchaseReturn = 'PURCHASE_RETURN';
  static const String openingReceivable = 'OPENING_RECEIVABLE';
  static const String openingPayable = 'OPENING_PAYABLE';
}

/// Invoice lifecycle statuses.
class InvoiceStatus {
  InvoiceStatus._();

  static const String draft = 'DRAFT';
  static const String posted = 'POSTED';
  static const String cancelled = 'CANCELLED';
}

/// Invoice payment statuses.
class InvoicePaymentStatus {
  InvoicePaymentStatus._();

  static const String unpaid = 'UNPAID';
  static const String partiallyPaid = 'PARTIALLY_PAID';
  static const String paid = 'PAID';
}

/// Payment voucher types.
class PaymentType {
  PaymentType._();

  static const String receipt = 'RECEIPT';
  static const String payment = 'PAYMENT';
}

/// Payment voucher statuses.
class PaymentStatus {
  PaymentStatus._();

  static const String draft = 'DRAFT';
  static const String posted = 'POSTED';
  static const String voided = 'VOIDED';
}

/// Payment settlement methods.
class PaymentMethod {
  PaymentMethod._();

  static const String cash = 'CASH';
  static const String bankTransfer = 'BANK_TRANSFER';
  static const String cheque = 'CHEQUE';
}

/// Inventory item classifications.
class ItemType {
  ItemType._();

  static const String merchandise = 'MERCHANDISE'; // بضاعة تجارية جاهزة
  static const String rawMaterial = 'RAW_MATERIAL'; // مواد خام
  static const String finishedProduct = 'FINISHED_PRODUCT'; // منتجات تامة الصنع
  static const String semiFinished = 'SEMI_FINISHED'; // منتجات نصف مصنعة
  static const String consumable = 'CONSUMABLE'; // مواد ومهمات استهلاكية
  static const String service = 'SERVICE'; // خدمات (لا تتبع للمخزون)
}

/// Stock document types.
class StockDocumentType {
  StockDocumentType._();

  static const String opening = 'OPENING'; // رصيد افتتاحي للمخزون
  static const String receipt = 'RECEIPT'; // سند إدخال / استلام بضاعة
  static const String issue = 'ISSUE'; // سند إخراج / صرف بضاعة ومواد
  static const String transfer = 'TRANSFER'; // مناقلة بين المستودعات
  static const String adjustment = 'ADJUSTMENT'; // تسوية جردية (عجز / فائض)
}

/// Stock document lifecycle statuses.
class StockDocumentStatus {
  StockDocumentStatus._();

  static const String draft = 'DRAFT';
  static const String posted = 'POSTED';
  static const String cancelled = 'CANCELLED';
}

/// Physical movement ledger types.
class StockMovementType {
  StockMovementType._();

  static const String opening = 'OPENING';
  static const String receipt = 'RECEIPT';
  static const String issue = 'ISSUE';
  static const String transferOut = 'TRANSFER_OUT';
  static const String transferIn = 'TRANSFER_IN';
  static const String adjustmentIn = 'ADJUSTMENT_IN';
  static const String adjustmentOut = 'ADJUSTMENT_OUT';
}

/// Inventory valuation methods.
class ValuationMethod {
  ValuationMethod._();

  static const String weightedAverage = 'WEIGHTED_AVERAGE'; // المتوسط المرجح
  static const String fifo = 'FIFO'; // الوارد أولاً يصرف أولاً
}

/// Stocktaking session statuses.
class StocktakingStatus {
  StocktakingStatus._();

  static const String inProgress = 'IN_PROGRESS';
  static const String completed = 'COMPLETED';
  static const String posted = 'POSTED';
  static const String cancelled = 'CANCELLED';
}

