import 'package:sqflite/sqflite.dart';
import '../../../core/constants/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../accounts/data/account_repository.dart';
import '../../settings/services/backup_service.dart';
import '../data/organization_branding_service.dart';
import '../models/organization_model.dart';

/// Repository managing SQLite persistence and accounting safeguards for organizations.
class OrganizationRepository {
  final DatabaseHelper _databaseHelper;

  OrganizationRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<Database> get _db async => await _databaseHelper.database;

  /// Fetches all organizations ordered by active status and creation time.
  Future<List<Organization>> getAllOrganizations({
    bool includeArchived = true,
  }) async {
    final db = await _db;
    final whereClause = includeArchived ? null : 'is_active = 1';

    final rows = await db.query(
      DatabaseConstants.tableOrganizations,
      where: whereClause,
      orderBy: 'is_active DESC, created_at DESC',
    );

    return rows.map((row) => Organization.fromMap(row)).toList();
  }

  /// Retrieves an organization by its unique ID.
  Future<Organization?> getOrganizationById(String id) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseConstants.tableOrganizations,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return Organization.fromMap(rows.first);
  }

  /// Inserts a new organization into the SQLite database.
  Future<void> createOrganization(Organization organization) async {
    final db = await _db;

    // Check code uniqueness
    final existingCode = await db.query(
      DatabaseConstants.tableOrganizations,
      where: 'code = ?',
      whereArgs: [organization.code],
      limit: 1,
    );

    if (existingCode.isNotEmpty) {
      throw Exception('رمز المؤسسة (${organization.code}) مستخدم مسبقاً.');
    }

    await db.insert(
      DatabaseConstants.tableOrganizations,
      organization.toMap(),
    );

    // Seed standard Chart of Accounts for new organization
    final accountRepo = AccountRepository(databaseHelper: _databaseHelper);
    await accountRepo.seedStandardChartOfAccounts(
      organization.id,
      organization.baseCurrencyCode,
    );

    // Seed default inventory warehouse, units of measure, category, and settings
    await _seedDefaultInventoryForOrganization(db, organization);
  }

  Future<void> _seedDefaultInventoryForOrganization(
      DatabaseExecutor db, Organization organization) async {
    final orgId = organization.id;
    final now = DateTime.now().toUtc().toIso8601String();

    final standardUnits = [
      {'code': 'PCS', 'name': 'قطعة / حبة', 'symbol': 'حبة'},
      {'code': 'BOX', 'name': 'صندوق', 'symbol': 'صندوق'},
      {'code': 'CTN', 'name': 'كرتون', 'symbol': 'كرتون'},
      {'code': 'KG', 'name': 'كيلوجرام', 'symbol': 'كجم'},
      {'code': 'G', 'name': 'جرام', 'symbol': 'جم'},
      {'code': 'L', 'name': 'لتر', 'symbol': 'لتر'},
      {'code': 'M', 'name': 'متر', 'symbol': 'م'},
      {'code': 'PKG', 'name': 'طرد / باكت', 'symbol': 'طرد'},
    ];

    for (final u in standardUnits) {
      await db.insert(
        DatabaseConstants.tableUnitsOfMeasure,
        {
          'id': 'uom_${orgId}_${u['code']}',
          'organization_id': orgId,
          'code': u['code'],
          'name_ar': u['name'],
          'symbol': u['symbol'],
          'is_active': 1,
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    await db.insert(
      DatabaseConstants.tableWarehouses,
      {
        'id': 'wh_${orgId}_main',
        'organization_id': orgId,
        'code': 'WH-01',
        'name': 'المستودع الرئيسي',
        'description': 'المستودع المركزي للبضائع والمواد',
        'location': 'المركز الرئيسي',
        'responsible_person': 'أمين المستودع',
        'is_active': 1,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.insert(
      DatabaseConstants.tableItemCategories,
      {
        'id': 'cat_${orgId}_general',
        'organization_id': orgId,
        'code': 'CAT-01',
        'name_ar': 'بضائع عامة',
        'name_en': 'General Merchandise',
        'parent_id': null,
        'description': 'التصنيف الافتراضي للأصناف التجارية',
        'is_active': 1,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.insert(
      DatabaseConstants.tableInventorySettings,
      {
        'id': 'inv_set_$orgId',
        'organization_id': orgId,
        'is_inventory_enabled': 1,
        'inventory_asset_account_id': '${orgId}_1131',
        'inventory_adjustment_account_id': '${orgId}_5202',
        'cogs_account_id': '${orgId}_51',
        'opening_equity_account_id': '${orgId}_3999',
        'default_valuation_method': 'WEIGHTED_AVERAGE',
        'allow_negative_stock': 0,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Updates details of an existing organization.
  Future<void> updateOrganization(Organization organization) async {
    final db = await _db;

    // Verify code uniqueness if changed
    final existingWithCode = await db.query(
      DatabaseConstants.tableOrganizations,
      where: 'code = ? AND id != ?',
      whereArgs: [organization.code, organization.id],
      limit: 1,
    );

    if (existingWithCode.isNotEmpty) {
      throw Exception(
          'رمز المؤسسة (${organization.code}) مستخدم لدى مؤسسة أخرى.');
    }

    final data = organization.toMap();
    data['updated_at'] = DateTime.now().toUtc().toIso8601String();

    await db.update(
      DatabaseConstants.tableOrganizations,
      data,
      where: 'id = ?',
      whereArgs: [organization.id],
    );
  }

  /// Sets the active or archived status of an organization.
  Future<void> setOrganizationActiveStatus(String id, bool isActive) async {
    final db = await _db;
    await db.update(
      DatabaseConstants.tableOrganizations,
      {
        'is_active': isActive ? 1 : 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Checks whether an organization has posted or draft accounting transactions.
  Future<bool> hasTransactions(String organizationId) async {
    final db = await _db;

    final jeResult = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${DatabaseConstants.tableJournalEntries} WHERE organization_id = ?',
      [organizationId],
    );
    final jeCount = Sqflite.firstIntValue(jeResult) ?? 0;

    final invResult = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${DatabaseConstants.tableInvoices} WHERE organization_id = ?',
      [organizationId],
    );
    final invCount = Sqflite.firstIntValue(invResult) ?? 0;

    final payResult = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${DatabaseConstants.tablePayments} WHERE organization_id = ?',
      [organizationId],
    );
    final payCount = Sqflite.firstIntValue(payResult) ?? 0;

    final stockResult = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${DatabaseConstants.tableStockDocuments} WHERE organization_id = ?',
      [organizationId],
    );
    final stockCount = Sqflite.firstIntValue(stockResult) ?? 0;

    return (jeCount + invCount + payCount + stockCount) > 0;
  }

  /// Deletes an organization only if it has no accounting records.
  /// Throws an informative [Exception] if records exist to preserve ledger integrity.
  Future<void> deleteOrganization(String organizationId) async {
    final db = await _db;

    final hasData = await hasTransactions(organizationId);
    if (hasData) {
      throw Exception(
        'لا يمكن حذف هذه المؤسسة نهائياً لوجود قيود محاسبية أو فواتير مسجلة بها. يمكنك أرشفتها بدلاً من ذلك لحفظ السجلات المالية.',
      );
    }

    // Safe deletion of organization
    await db.delete(
      DatabaseConstants.tableOrganizations,
      where: 'id = ?',
      whereArgs: [organizationId],
    );
  }

  /// Retrieves the persisted active organization ID from app_settings.
  Future<String?> getActiveOrganizationId() async {
    final db = await _db;
    final rows = await db.query(
      DatabaseConstants.tableAppSettings,
      columns: ['setting_value'],
      where:
          "setting_key = 'active_organization_id' AND organization_id IS NULL",
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return rows.first['setting_value'] as String?;
  }

  /// Persists the selected active organization ID in app_settings.
  Future<void> setActiveOrganizationId(String organizationId) async {
    final db = await _db;

    final existing = await db.query(
      DatabaseConstants.tableAppSettings,
      columns: ['id'],
      where:
          "setting_key = 'active_organization_id' AND organization_id IS NULL",
      limit: 1,
    );

    final now = DateTime.now().toUtc().toIso8601String();

    if (existing.isEmpty) {
      await db.insert(
        DatabaseConstants.tableAppSettings,
        {
          'id': 'setting_global_active_org',
          'organization_id': null,
          'setting_key': 'active_organization_id',
          'setting_value': organizationId,
          'data_type': 'STRING',
          'description': 'Active selected organization identifier',
          'updated_at': now,
        },
      );
    } else {
      await db.update(
        DatabaseConstants.tableAppSettings,
        {
          'setting_value': organizationId,
          'updated_at': now,
        },
        where:
            "setting_key = 'active_organization_id' AND organization_id IS NULL",
      );
    }
  }

  /// Safely and completely resets all organizations, chart of accounts, accounting transactions,
  /// invoices, payments, inventory, and institution-specific data.
  /// 
  /// Respects foreign key constraints by deleting in strict dependency order inside a transaction.
  /// Backs up the database before deletion if [createBackupFirst] is true.
  Future<Map<String, dynamic>> resetAllInstitutionsAndAccountingData({
    bool createBackupFirst = true,
  }) async {
    Map<String, dynamic>? backupInfo;
    if (createBackupFirst) {
      try {
        backupInfo = await BackupService.instance.createBackup();
      } catch (e) {
        // Log backup warning but proceed if user specifically requested reset
      }
    }

    final db = await _db;

    // Temporarily disable foreign key constraints during bulk truncation
    // to prevent self-referencing foreign key deadlocks in chart_of_accounts and item_categories
    await db.execute('PRAGMA foreign_keys = OFF;');

    try {
      await db.transaction((txn) async {
        // 1. Stock / Inventory Lines & Movements
        await txn.delete(DatabaseConstants.tableStocktakingLines);
        await txn.delete(DatabaseConstants.tableStocktakingSessions);
        await txn.delete(DatabaseConstants.tableStockMovements);
        await txn.delete(DatabaseConstants.tableStockDocumentLines);
        await txn.delete(DatabaseConstants.tableStockDocuments);
        await txn.delete(DatabaseConstants.tableItemUnits);
        await txn.delete(DatabaseConstants.tableItems);
        await txn.delete(DatabaseConstants.tableItemCategories);
        await txn.delete(DatabaseConstants.tableUnitsOfMeasure);
        await txn.delete(DatabaseConstants.tableWarehouses);
        await txn.delete(DatabaseConstants.tableInventorySettings);

        // 2. Fixed Assets if table exists
        try {
          await txn.delete('fixed_assets');
        } catch (_) {}

        // 3. Forex Revaluation
        await txn.delete(DatabaseConstants.tableForexRevaluationLines);
        await txn.delete(DatabaseConstants.tableForexRevaluations);

        // 4. Payments and Allocations
        await txn.delete(DatabaseConstants.tablePaymentAllocations);
        await txn.delete(DatabaseConstants.tablePayments);

        // 5. Invoices and Lines
        await txn.delete(DatabaseConstants.tableInvoiceLines);
        await txn.delete(DatabaseConstants.tableInvoices);

        // 6. Journal Entries and Lines
        await txn.delete(DatabaseConstants.tableJournalEntryLines);
        await txn.delete(DatabaseConstants.tableJournalEntries);

        // 7. Opening Balances
        await txn.delete(DatabaseConstants.tableOpeningBalances);

        // 8. Parties (Customers & Suppliers)
        await txn.delete(DatabaseConstants.tableParties);

        // 9. Fiscal Periods & Years
        await txn.delete(DatabaseConstants.tableFiscalPeriods);
        await txn.delete(DatabaseConstants.tableFiscalYears);

        // 10. Exchange Rates
        await txn.delete(DatabaseConstants.tableExchangeRates);

        // 11. Chart of Accounts
        await txn.delete(DatabaseConstants.tableChartOfAccounts);

        // 12. Audit Logs
        await txn.delete(DatabaseConstants.tableAuditLogs);

        // 13. Org-specific App Settings & active organization reference
        await txn.delete(
          DatabaseConstants.tableAppSettings,
          where:
              "organization_id IS NOT NULL OR setting_key = 'active_organization_id'",
        );

        // 14. Organizations table
        await txn.delete(DatabaseConstants.tableOrganizations);
      });
    } finally {
      // Re-enable foreign key constraints
      await db.execute('PRAGMA foreign_keys = ON;');
    }

    // 15. Verify foreign key integrity
    final fkCheck = await db.rawQuery('PRAGMA foreign_key_check');
    if (fkCheck.isNotEmpty) {
      throw Exception('Foreign key integrity violation after reset: $fkCheck');
    }

    // 16. Clean up any stored logos on disk
    try {
      final logosDir =
          await OrganizationBrandingService.instance.getLogosDirectory();
      if (logosDir.existsSync()) {
        final files = logosDir.listSync();
        for (final file in files) {
          try {
            file.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}

    return {
      'status': 'SUCCESS',
      'backup_file': backupInfo?['backup_file'],
      'backup_sha256': backupInfo?['sha256'],
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
