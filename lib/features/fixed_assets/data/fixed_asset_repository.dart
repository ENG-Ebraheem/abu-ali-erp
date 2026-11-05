import 'package:sqflite/sqflite.dart';
import '../../../core/constants/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../journal/data/journal_repository.dart';
import '../../journal/models/journal_entry_line_model.dart';
import '../../journal/models/journal_entry_model.dart';
import '../models/fixed_asset_model.dart';

/// Repository managing Fixed Assets register and straight-line depreciation GL journal postings.
class FixedAssetRepository {
  final DatabaseHelper _dbHelper;
  final JournalRepository _journalRepo;

  FixedAssetRepository({
    DatabaseHelper? dbHelper,
    JournalRepository? journalRepo,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _journalRepo = journalRepo ?? JournalRepository();

  Future<Database> get _db async => await _dbHelper.database;

  /// Ensures the fixed_assets table and index exist non-destructively.
  Future<void> _ensureTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fixed_assets (
        id TEXT PRIMARY KEY,
        organization_id TEXT NOT NULL,
        asset_code TEXT NOT NULL,
        asset_name_ar TEXT NOT NULL,
        asset_account_id TEXT NOT NULL,
        depreciation_expense_account_id TEXT NOT NULL,
        accumulated_depreciation_account_id TEXT NOT NULL,
        purchase_date TEXT NOT NULL,
        purchase_cost INTEGER NOT NULL,
        salvage_value INTEGER NOT NULL DEFAULT 0,
        useful_life_months INTEGER NOT NULL,
        depreciation_method TEXT NOT NULL DEFAULT 'STRAIGHT_LINE',
        accumulated_depreciation INTEGER NOT NULL DEFAULT 0,
        last_depreciation_date TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_fixed_assets_org 
      ON fixed_assets(organization_id);
    ''');
  }

  /// Generates the next sequential asset code.
  Future<String> getNextAssetCode(String organizationId) async {
    final db = await _db;
    await _ensureTable(db);

    final results = await db.rawQuery('''
      SELECT asset_code FROM fixed_assets
      WHERE organization_id = ?
      ORDER BY asset_code DESC
      LIMIT 1
    ''', [organizationId]);

    if (results.isEmpty) return 'AST-0001';

    final last = results.first['asset_code'] as String;
    final parts = last.split('-');
    if (parts.length >= 2) {
      final numVal = int.tryParse(parts.last);
      if (numVal != null) {
        return 'AST-${(numVal + 1).toString().padLeft(4, '0')}';
      }
    }
    return 'AST-${DateTime.now().millisecondsSinceEpoch % 10000}';
  }

  /// Fetches all fixed assets for an organization including resolved account names.
  Future<List<FixedAssetModel>> getAssets(String organizationId) async {
    final db = await _db;
    await _ensureTable(db);

    final sql = '''
      SELECT 
        fa.*,
        coa_asset.account_name_ar AS asset_account_name,
        coa_exp.account_name_ar AS expense_account_name,
        coa_acc.account_name_ar AS accumulated_account_name
      FROM fixed_assets fa
      LEFT JOIN ${DatabaseConstants.tableChartOfAccounts} coa_asset 
        ON coa_asset.id = fa.asset_account_id AND coa_asset.organization_id = fa.organization_id
      LEFT JOIN ${DatabaseConstants.tableChartOfAccounts} coa_exp 
        ON coa_exp.id = fa.depreciation_expense_account_id AND coa_exp.organization_id = fa.organization_id
      LEFT JOIN ${DatabaseConstants.tableChartOfAccounts} coa_acc 
        ON coa_acc.id = fa.accumulated_depreciation_account_id AND coa_acc.organization_id = fa.organization_id
      WHERE fa.organization_id = ?
      ORDER BY fa.created_at DESC
    ''';

    final rows = await db.rawQuery(sql, [organizationId]);
    return rows.map((r) => FixedAssetModel.fromMap(r)).toList();
  }

  /// Inserts a new fixed asset record.
  Future<void> createAsset(FixedAssetModel asset) async {
    final db = await _db;
    await _ensureTable(db);

    await db.insert(
      'fixed_assets',
      asset.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Calculates and posts a straight-line depreciation journal entry for an asset.
  Future<String> postDepreciation({
    required String assetId,
    required String organizationId,
    required int amount,
    required String asOfDate,
    required String baseCurrencyCode,
  }) async {
    if (amount <= 0) {
      throw Exception('مبلغ الإهلاك يجب أن يكون أكبر من صفر.');
    }

    final db = await _db;
    await _ensureTable(db);

    final assetRows = await db.query(
      'fixed_assets',
      where: 'id = ? AND organization_id = ?',
      whereArgs: [assetId, organizationId],
      limit: 1,
    );

    if (assetRows.isEmpty) throw Exception('الأصل الثابت غير موجود.');
    final asset = FixedAssetModel.fromMap(assetRows.first);

    if (amount > asset.remainingDepreciation) {
      throw Exception(
        'مبلغ الإهلاك المطلوب (${amount / 100}) يتجاوز القيمة المتبقية للإهلاك (${asset.remainingDepreciation / 100}).',
      );
    }

    final periodId =
        await _journalRepo.ensureFiscalPeriod(organizationId, asOfDate);
    final entryNumber =
        await _journalRepo.getNextEntryNumber(organizationId, 'GENERAL');
    final entryId = 'je_dep_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().toIso8601String();

    final narration =
        'قيد إهلاك أصل ثابت: [${asset.assetNameAr}] (${asset.assetCode}) - حتى $asOfDate';

    final glEntry = JournalEntryModel(
      id: entryId,
      organizationId: organizationId,
      entryNumber: entryNumber,
      fiscalPeriodId: periodId,
      entryDate: asOfDate,
      entryType: 'GENERAL',
      status: 'POSTED',
      reference: asset.assetCode,
      narration: narration,
      totalBaseDebit: amount,
      totalBaseCredit: amount,
      postedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    // Line 1: Debit Depreciation Expense (زيادة مصروف الإهلاك)
    final debitLine = JournalEntryLineModel(
      id: 'line_${entryId}_1',
      organizationId: organizationId,
      journalEntryId: entryId,
      lineNumber: 1,
      accountId: asset.depreciationExpenseAccountId,
      partyId: null,
      description: 'مصروف إهلاك: ${asset.assetNameAr}',
      currencyCode: baseCurrencyCode,
      exchangeRateScaled: 1000000,
      foreignDebit: amount,
      foreignCredit: 0,
      baseDebit: amount,
      baseCredit: 0,
      createdAt: now,
    );

    // Line 2: Credit Accumulated Depreciation (زيادة مجمع الإهلاك - حساب عكسي للأصول)
    final creditLine = JournalEntryLineModel(
      id: 'line_${entryId}_2',
      organizationId: organizationId,
      journalEntryId: entryId,
      lineNumber: 2,
      accountId: asset.accumulatedDepreciationAccountId,
      partyId: null,
      description: 'مجمع إهلاك متراكم: ${asset.assetNameAr}',
      currencyCode: baseCurrencyCode,
      exchangeRateScaled: 1000000,
      foreignDebit: 0,
      foreignCredit: amount,
      baseDebit: 0,
      baseCredit: amount,
      createdAt: now,
    );

    await db.transaction((txn) async {
      // 1. Save and auto-post entry
      await _journalRepo.saveEntry(
        entry: glEntry,
        lines: [debitLine, creditLine],
        autoPost: true,
      );

      // 2. Update asset accumulated depreciation and last date
      await txn.update(
        'fixed_assets',
        {
          'accumulated_depreciation': asset.accumulatedDepreciation + amount,
          'last_depreciation_date': asOfDate,
          'updated_at': now,
        },
        where: 'id = ? AND organization_id = ?',
        whereArgs: [assetId, organizationId],
      );
    });

    return entryNumber;
  }
}
