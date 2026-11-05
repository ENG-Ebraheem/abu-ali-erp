import 'package:flutter_test/flutter_test.dart';
import 'package:abu_ali/core/constants/database_constants.dart';
import 'package:abu_ali/core/database/migrations/migration_v1_to_v2.dart';
import 'package:abu_ali/core/database/migrations/migration_v2_to_v3.dart';
import 'package:abu_ali/core/database/migrations/migration_v3_to_v4.dart';

void main() {
  group('Database Constants & Migration Tests', () {
    test('Scale factors and version match specifications', () {
      expect(DatabaseConstants.exchangeRateScale, equals(1000000));
      expect(DatabaseConstants.quantityScale, equals(1000));
      expect(DatabaseConstants.defaultMoneyScale, equals(100));
      expect(DatabaseConstants.databaseVersion, equals(4));
      expect(DatabaseConstants.databaseName, equals('abu_ali.db'));
    });

    test('All 30 table names are defined and unique', () {
      final tables = [
        DatabaseConstants.tableMigrations,
        DatabaseConstants.tableCurrencies,
        DatabaseConstants.tableOrganizations,
        DatabaseConstants.tableExchangeRates,
        DatabaseConstants.tableAppSettings,
        DatabaseConstants.tableAuditLogs,
        DatabaseConstants.tableChartOfAccounts,
        DatabaseConstants.tableFiscalYears,
        DatabaseConstants.tableFiscalPeriods,
        DatabaseConstants.tableParties,
        DatabaseConstants.tableJournalEntries,
        DatabaseConstants.tableJournalEntryLines,
        DatabaseConstants.tableInvoices,
        DatabaseConstants.tableInvoiceLines,
        DatabaseConstants.tablePayments,
        DatabaseConstants.tablePaymentAllocations,
        DatabaseConstants.tableOpeningBalances,
        DatabaseConstants.tableForexRevaluations,
        DatabaseConstants.tableForexRevaluationLines,
        // Phase 8 Tables
        DatabaseConstants.tableWarehouses,
        DatabaseConstants.tableItemCategories,
        DatabaseConstants.tableUnitsOfMeasure,
        DatabaseConstants.tableItems,
        DatabaseConstants.tableItemUnits,
        DatabaseConstants.tableStockDocuments,
        DatabaseConstants.tableStockDocumentLines,
        DatabaseConstants.tableStockMovements,
        DatabaseConstants.tableStocktakingSessions,
        DatabaseConstants.tableStocktakingLines,
        DatabaseConstants.tableInventorySettings,
      ];

      expect(tables.toSet().length, equals(30));
    });

    test('Migration V1 to V2 metadata', () {
      final migration = MigrationV1ToV2();
      expect(migration.version, equals(2));
      expect(migration.description, isNotEmpty);
    });

    test('Migration V2 to V3 metadata', () {
      final migration = MigrationV2ToV3();
      expect(migration.version, equals(3));
      expect(migration.description, isNotEmpty);
    });

    test('Migration V3 to V4 metadata', () {
      final migration = MigrationV3ToV4();
      expect(migration.version, equals(4));
      expect(migration.description, isNotEmpty);
    });

    test('Supported currency codes', () {
      expect(CurrencyCodes.yer, equals('YER'));
      expect(CurrencyCodes.usd, equals('USD'));
      expect(CurrencyCodes.sar, equals('SAR'));
    });

    test('Extended invoice types include opening balances', () {
      expect(InvoiceType.sales, equals('SALES'));
      expect(InvoiceType.purchase, equals('PURCHASE'));
      expect(InvoiceType.salesReturn, equals('SALES_RETURN'));
      expect(InvoiceType.purchaseReturn, equals('PURCHASE_RETURN'));
      expect(InvoiceType.openingReceivable, equals('OPENING_RECEIVABLE'));
      expect(InvoiceType.openingPayable, equals('OPENING_PAYABLE'));
    });
  });
}
