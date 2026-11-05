import 'package:sqflite/sqflite.dart';
import '../../../core/constants/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../journal/data/journal_repository.dart';
import '../models/opening_balance_model.dart';

/// Repository managing Opening Balances and subledger reconciliation for organizations.
class OpeningBalanceRepository {
  final DatabaseHelper _dbHelper;
  final JournalRepository _journalRepo;

  OpeningBalanceRepository({
    DatabaseHelper? dbHelper,
    JournalRepository? journalRepo,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _journalRepo = journalRepo ?? JournalRepository(dbHelper: dbHelper);

  Future<Database> get _db async => await _dbHelper.database;

  /// Retrieves the opening balance record for the specified organization and fiscal year.
  Future<OpeningBalanceModel?> getOpeningBalanceHeader(
    String organizationId, {
    String? fiscalYearId,
  }) async {
    final db = await _db;
    final whereArgs = <dynamic>[organizationId];
    String whereSql = 'organization_id = ?';

    if (fiscalYearId != null) {
      whereSql += ' AND fiscal_year_id = ?';
      whereArgs.add(fiscalYearId);
    }

    final results = await db.query(
      DatabaseConstants.tableOpeningBalances,
      where: whereSql,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;
    return OpeningBalanceModel.fromMap(results.first);
  }

  /// Loads the line items associated with an opening balance's journal entry.
  Future<List<OpeningBalanceLineItem>> getOpeningBalanceLines(
    String journalEntryId,
    String organizationId,
  ) async {
    final db = await _db;

    final rows = await db.rawQuery('''
      SELECT 
        jel.*,
        coa.account_code,
        coa.account_name_ar,
        coa.account_type,
        coa.account_nature,
        p.name_ar AS party_name_ar
      FROM ${DatabaseConstants.tableJournalEntryLines} jel
      INNER JOIN ${DatabaseConstants.tableChartOfAccounts} coa 
        ON coa.id = jel.account_id AND coa.organization_id = jel.organization_id
      LEFT JOIN ${DatabaseConstants.tableParties} p 
        ON p.id = jel.party_id AND p.organization_id = jel.organization_id
      WHERE jel.journal_entry_id = ? AND jel.organization_id = ?
      ORDER BY jel.line_number ASC
    ''', [journalEntryId, organizationId]);

    return rows.map((r) {
      return OpeningBalanceLineItem(
        id: r['id'] as String,
        accountId: r['account_id'] as String,
        accountCode: r['account_code'] as String,
        accountNameAr: r['account_name_ar'] as String,
        accountType: r['account_type'] as String,
        accountNature: r['account_nature'] as String,
        partyId: r['party_id'] as String?,
        partyNameAr: r['party_name_ar'] as String?,
        currencyCode: r['currency_code'] as String? ?? 'YER',
        exchangeRateScaled: (r['exchange_rate_scaled'] as num?)?.toInt() ??
            DatabaseConstants.exchangeRateScale,
        foreignDebit: (r['foreign_debit'] as num?)?.toInt() ?? 0,
        foreignCredit: (r['foreign_credit'] as num?)?.toInt() ?? 0,
        baseDebit: (r['base_debit'] as num?)?.toInt() ?? 0,
        baseCredit: (r['base_credit'] as num?)?.toInt() ?? 0,
        description: r['description'] as String?,
      );
    }).toList();
  }

  /// Saves or updates the opening balance draft lines atomically.
  Future<OpeningBalanceModel> saveOpeningBalanceDraft({
    required String organizationId,
    required String asOfDate,
    required List<OpeningBalanceLineItem> lines,
    String? notes,
  }) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();

    // 1. Ensure fiscal period and year exist
    final periodId =
        await _journalRepo.ensureFiscalPeriod(organizationId, asOfDate);

    // Fetch the fiscal year ID for this period
    final periodRows = await db.query(
      DatabaseConstants.tableFiscalPeriods,
      columns: ['fiscal_year_id'],
      where: 'id = ? AND organization_id = ?',
      whereArgs: [periodId, organizationId],
      limit: 1,
    );
    final fiscalYearId = periodRows.first['fiscal_year_id'] as String;

    // Check if an existing opening balance record exists
    final existingHeader = await getOpeningBalanceHeader(organizationId,
        fiscalYearId: fiscalYearId);
    if (existingHeader != null && existingHeader.isPosted) {
      throw Exception(
          'الأرصدة الافتتاحية لهذه السنة مرحلة مسبقاً ولا يمكن تعديلها.');
    }

    final openingId =
        existingHeader?.id ?? 'ob_${organizationId}_$fiscalYearId';
    String entryId = existingHeader?.journalEntryId ??
        'je_ob_${organizationId}_$fiscalYearId';

    // Calculate totals
    int totalDebit = 0;
    int totalCredit = 0;
    for (final l in lines) {
      totalDebit += l.baseDebit;
      totalCredit += l.baseCredit;
    }

    // Save atomically in SQLite transaction
    await db.transaction((txn) async {
      // 1. Journal Entry Header
      final entryNumber = 'OP-${DateTime.now().year}-0001';
      final entryMap = {
        'id': entryId,
        'organization_id': organizationId,
        'entry_number': entryNumber,
        'fiscal_period_id': periodId,
        'entry_date': asOfDate,
        'entry_type': 'OPENING',
        'status': 'DRAFT',
        'reference': 'OPENING_BALANCES',
        'narration': 'الأرصدة الافتتاحية للمؤسسة للسنة المالية',
        'total_base_debit': totalDebit,
        'total_base_credit': totalCredit,
        'created_at': now,
        'updated_at': now,
      };

      await txn.insert(
        DatabaseConstants.tableJournalEntries,
        entryMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Clear old lines for this entry
      await txn.delete(
        DatabaseConstants.tableJournalEntryLines,
        where: 'journal_entry_id = ? AND organization_id = ?',
        whereArgs: [entryId, organizationId],
      );

      // 3. Insert new lines
      for (int i = 0; i < lines.length; i++) {
        final l = lines[i];
        await txn.insert(
          DatabaseConstants.tableJournalEntryLines,
          {
            'id': 'line_${entryId}_${i + 1}',
            'organization_id': organizationId,
            'journal_entry_id': entryId,
            'line_number': i + 1,
            'account_id': l.accountId,
            'party_id': l.partyId,
            'description': l.description ?? 'رصيد افتتاحي: ${l.accountNameAr}',
            'currency_code': l.currencyCode,
            'exchange_rate_scaled': l.exchangeRateScaled,
            'foreign_debit': l.foreignDebit,
            'foreign_credit': l.foreignCredit,
            'base_debit': l.baseDebit,
            'base_credit': l.baseCredit,
            'created_at': now,
          },
        );
      }

      // 4. Upsert Opening Balance Record
      final obMap = {
        'id': openingId,
        'organization_id': organizationId,
        'fiscal_year_id': fiscalYearId,
        'journal_entry_id': entryId,
        'as_of_date': asOfDate,
        'status': 'DRAFT',
        'notes': notes,
        'created_at': existingHeader?.createdAt ?? now,
        'updated_at': now,
      };

      await txn.insert(
        DatabaseConstants.tableOpeningBalances,
        obMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    return OpeningBalanceModel(
      id: openingId,
      organizationId: organizationId,
      fiscalYearId: fiscalYearId,
      journalEntryId: entryId,
      asOfDate: asOfDate,
      status: 'DRAFT',
      notes: notes,
      createdAt: existingHeader?.createdAt ?? now,
      updatedAt: now,
    );
  }

  /// Posts opening balances with strict accounting rules and subledger reconciliation.
  Future<void> postOpeningBalances({
    required String organizationId,
    required String asOfDate,
    required List<OpeningBalanceLineItem> lines,
    String? notes,
  }) async {
    if (lines.length < 2) {
      throw Exception(
          'الأرصدة الافتتاحية تتطلب سطرين على الأقل لإتمام القيد المزدوج.');
    }

    int totalDebit = 0;
    int totalCredit = 0;
    for (int i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (l.baseDebit == 0 && l.baseCredit == 0) {
        throw Exception(
            'السطر (${l.accountNameAr}) يحتوي على رصيد صفر؛ يرجى حذفه أو إدخال قيمة.');
      }
      if (l.baseDebit > 0 && l.baseCredit > 0) {
        throw Exception(
            'السطر (${l.accountNameAr}) لا يمكن أن يكون مديناً ودائناً في آن واحد.');
      }
      totalDebit += l.baseDebit;
      totalCredit += l.baseCredit;
    }

    // 1. Balance check
    if (totalDebit != totalCredit) {
      final diff = (totalDebit - totalCredit).abs();
      throw Exception(
        'القيد الافتتاحي غير متزن! إجمالي المدين (${(totalDebit / 100.0).toStringAsFixed(2)}) لا يساوي إجمالي الدائن (${(totalCredit / 100.0).toStringAsFixed(2)}). الفارق: ${(diff / 100.0).toStringAsFixed(2)} ر.ي.',
      );
    }

    if (totalDebit <= 0) {
      throw Exception('إجمالي المبالغ الافتتاحية يجب أن يكون أكبر من الصفر.');
    }

    // 2. Subledger reconciliation: customer & supplier accounts
    for (final l in lines) {
      // Check customer accounts (1103)
      if (l.accountCode.startsWith('1103') && l.partyId == null) {
        throw Exception(
          'حساب ذمم العملاء (${l.accountNameAr}) يتطلب تحديد العميل التابع له لضبط مطابقة الأستاذ المساعد.',
        );
      }
      // Check supplier accounts (2101)
      if (l.accountCode.startsWith('2101') && l.partyId == null) {
        throw Exception(
          'حساب ذمم الموردين (${l.accountNameAr}) يتطلب تحديد المورد التابع له لضبط مطابقة الأستاذ المساعد.',
        );
      }
    }

    // 3. Save as draft first to ensure all records and lines are prepared
    final draft = await saveOpeningBalanceDraft(
      organizationId: organizationId,
      asOfDate: asOfDate,
      lines: lines,
      notes: notes,
    );

    // 4. Post atomically
    final db = await _db;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // Update journal entry to POSTED
      await txn.update(
        DatabaseConstants.tableJournalEntries,
        {
          'status': 'POSTED',
          'posted_at': now,
          'updated_at': now,
        },
        where: 'id = ? AND organization_id = ?',
        whereArgs: [draft.journalEntryId, organizationId],
      );

      // Update opening_balances to POSTED
      await txn.update(
        DatabaseConstants.tableOpeningBalances,
        {
          'status': 'POSTED',
          'updated_at': now,
        },
        where: 'id = ? AND organization_id = ?',
        whereArgs: [draft.id, organizationId],
      );

      // Audit log
      await txn.insert(
        DatabaseConstants.tableAuditLogs,
        {
          'organization_id': organizationId,
          'table_name': DatabaseConstants.tableOpeningBalances,
          'record_id': draft.id,
          'action': 'POST',
          'new_values':
              'Posted opening balances: Total $totalDebit minor units',
          'created_at': now,
        },
      );
    });
  }
}
