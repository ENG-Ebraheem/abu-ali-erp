import 'package:sqflite/sqflite.dart';
import '../../../core/constants/database_constants.dart';
import '../../../core/database/database_helper.dart';

/// Repository managing system settings, fiscal periods, and database health metrics.
class SettingsRepository {
  final DatabaseHelper _dbHelper;

  SettingsRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db async => await _dbHelper.database;

  // ===========================================================================
  // 1. DATABASE STATS & INTEGRITY
  // ===========================================================================

  /// Retrieves comprehensive SQLite database statistics and integrity status.
  Future<Map<String, dynamic>> getDatabaseStats(String? organizationId) async {
    final db = await _db;

    // 1. SQLite Engine and DB version
    final sqliteVerRes = await db.rawQuery('SELECT sqlite_version() AS ver');
    final String sqliteVersion = sqliteVerRes.isNotEmpty
        ? (sqliteVerRes.first['ver'] as String)
        : '3.32.2';

    final userVerRes = await db.rawQuery('PRAGMA user_version');
    final int dbVersion = userVerRes.isNotEmpty
        ? (userVerRes.first['user_version'] as int)
        : DatabaseConstants.databaseVersion;

    // 2. PRAGMA integrity check
    final integrityRes = await db.rawQuery('PRAGMA integrity_check');
    final String integrityStatus = integrityRes.isNotEmpty
        ? (integrityRes.first['integrity_check'] as String)
        : 'ok';

    // 3. Foreign key status
    final fkRes = await db.rawQuery('PRAGMA foreign_keys');
    final bool foreignKeysEnabled =
        fkRes.isNotEmpty && (fkRes.first.values.first as int) == 1;

    // 4. Record counts
    final orgCount = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM ${DatabaseConstants.tableOrganizations}',
        )) ??
        0;

    int accountsCount = 0;
    int journalEntriesCount = 0;
    int journalLinesCount = 0;
    int invoicesCount = 0;
    int paymentsCount = 0;

    if (organizationId != null && organizationId.isNotEmpty) {
      accountsCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM ${DatabaseConstants.tableChartOfAccounts} WHERE organization_id = ?',
            [organizationId],
          )) ??
          0;

      journalEntriesCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM ${DatabaseConstants.tableJournalEntries} WHERE organization_id = ?',
            [organizationId],
          )) ??
          0;

      journalLinesCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM ${DatabaseConstants.tableJournalEntryLines} WHERE organization_id = ?',
            [organizationId],
          )) ??
          0;

      invoicesCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM ${DatabaseConstants.tableInvoices} WHERE organization_id = ?',
            [organizationId],
          )) ??
          0;

      paymentsCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM ${DatabaseConstants.tablePayments} WHERE organization_id = ?',
            [organizationId],
          )) ??
          0;
    }

    return {
      'sqlite_version': sqliteVersion,
      'db_version': dbVersion,
      'integrity_status': integrityStatus,
      'foreign_keys_enabled': foreignKeysEnabled,
      'organizations_count': orgCount,
      'accounts_count': accountsCount,
      'journal_entries_count': journalEntriesCount,
      'journal_lines_count': journalLinesCount,
      'invoices_count': invoicesCount,
      'payments_count': paymentsCount,
      'db_path': db.path,
    };
  }

  // ===========================================================================
  // 2. FISCAL YEARS & PERIODS MANAGEMENT
  // ===========================================================================

  /// Fetches fiscal years and their 12 periods.
  Future<List<Map<String, dynamic>>> getFiscalYears(
      String organizationId) async {
    final db = await _db;

    final years = await db.query(
      DatabaseConstants.tableFiscalYears,
      where: 'organization_id = ?',
      whereArgs: [organizationId],
      orderBy: 'start_date DESC',
    );

    final results = <Map<String, dynamic>>[];

    for (final y in years) {
      final yId = y['id'] as String;
      final periods = await db.query(
        DatabaseConstants.tableFiscalPeriods,
        where: 'fiscal_year_id = ? AND organization_id = ?',
        whereArgs: [yId, organizationId],
        orderBy: 'period_number ASC',
      );

      results.add({
        ...y,
        'periods': periods,
      });
    }

    return results;
  }

  /// Creates a new fiscal year and automatically generates 12 monthly periods.
  Future<String> createFiscalYear({
    required String organizationId,
    required String name,
    required String startDate,
    required String endDate,
  }) async {
    final db = await _db;

    // Check for overlapping fiscal years within the same organization
    final overlap = await db.rawQuery('''
      SELECT id, name FROM ${DatabaseConstants.tableFiscalYears}
      WHERE organization_id = ?
        AND ((start_date <= ? AND end_date >= ?) OR (start_date <= ? AND end_date >= ?))
    ''', [organizationId, startDate, startDate, endDate, endDate]);

    if (overlap.isNotEmpty) {
      throw Exception(
          'تاريخ السنة المالية يتداخل مع سنة مالية مسجلة مسبقاً (${overlap.first['name']})');
    }

    final yearId =
        'fy_${organizationId}_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      await txn.insert(
        DatabaseConstants.tableFiscalYears,
        {
          'id': yearId,
          'organization_id': organizationId,
          'name': name,
          'start_date': startDate,
          'end_date': endDate,
          'is_closed': 0,
          'created_at': now,
        },
      );

      // Generate 12 monthly periods
      final start = DateTime.parse(startDate);
      for (int i = 1; i <= 12; i++) {
        final periodStart = DateTime(start.year, i, 1);
        final nextMonth = i == 12
            ? DateTime(start.year + 1, 1, 1)
            : DateTime(start.year, i + 1, 1);
        final periodEnd = nextMonth.subtract(const Duration(days: 1));

        final pStartStr = periodStart.toIso8601String().split('T').first;
        final pEndStr = periodEnd.toIso8601String().split('T').first;

        await txn.insert(
          DatabaseConstants.tableFiscalPeriods,
          {
            'id': 'fp_${yearId}_$i',
            'organization_id': organizationId,
            'fiscal_year_id': yearId,
            'period_number': i,
            'name': 'فترة شهر $i - ${start.year}',
            'start_date': pStartStr,
            'end_date': pEndStr,
            'is_locked': 0,
            'is_closed': 0,
            'created_at': now,
          },
        );
      }

      // Audit log
      await txn.insert(
        DatabaseConstants.tableAuditLogs,
        {
          'organization_id': organizationId,
          'table_name': DatabaseConstants.tableFiscalYears,
          'record_id': yearId,
          'action': 'INSERT',
          'new_values':
              '{"name": "$name", "start_date": "$startDate", "end_date": "$endDate"}',
          'created_at': now,
        },
      );
    });

    return yearId;
  }

  /// Toggles period lock status.
  Future<void> togglePeriodLock(
    String periodId,
    String organizationId,
    bool isLocked,
  ) async {
    final db = await _db;
    await db.update(
      DatabaseConstants.tableFiscalPeriods,
      {'is_locked': isLocked ? 1 : 0},
      where: 'id = ? AND organization_id = ?',
      whereArgs: [periodId, organizationId],
    );

    // Audit log
    await db.insert(
      DatabaseConstants.tableAuditLogs,
      {
        'organization_id': organizationId,
        'table_name': DatabaseConstants.tableFiscalPeriods,
        'record_id': periodId,
        'action': 'UPDATE',
        'new_values': '{"is_locked": ${isLocked ? 1 : 0}}',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  /// Finds the fiscal period corresponding to a specific date.
  Future<Map<String, dynamic>?> getFiscalPeriodForDate(
    String organizationId,
    String entryDate,
  ) async {
    final db = await _db;
    final res = await db.query(
      DatabaseConstants.tableFiscalPeriods,
      where: 'organization_id = ? AND start_date <= ? AND end_date >= ?',
      whereArgs: [organizationId, entryDate, entryDate],
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  /// Performs an accounting Year-End Closing (إقفال السنة المالية).
  /// Generates a closing journal entry zeroing out Revenues and Expenses
  /// and transferring net income to Retained Earnings / Equity.
  Future<Map<String, dynamic>> performYearEndClosing({
    required String fiscalYearId,
    required String organizationId,
    required String retainedEarningsAccountId,
    String? narration,
  }) async {
    final db = await _db;

    // 1. Fetch fiscal year
    final fyRes = await db.query(
      DatabaseConstants.tableFiscalYears,
      where: 'id = ? AND organization_id = ?',
      whereArgs: [fiscalYearId, organizationId],
    );
    if (fyRes.isEmpty) {
      throw Exception('السنة المالية غير موجودة');
    }
    final fy = fyRes.first;
    if ((fy['is_closed'] as int) == 1) {
      throw Exception('هذه السنة المالية مقفلة مسبقاً');
    }

    final startDate = fy['start_date'] as String;
    final endDate = fy['end_date'] as String;

    // 2. Fetch revenue and expense balances for this period
    final pnlSql = '''
      SELECT 
        coa.id,
        coa.account_code,
        coa.account_name_ar,
        coa.account_type,
        coa.currency_code,
        COALESCE(SUM(jel.base_debit), 0) AS total_debit,
        COALESCE(SUM(jel.base_credit), 0) AS total_credit
      FROM ${DatabaseConstants.tableChartOfAccounts} coa
      INNER JOIN ${DatabaseConstants.tableJournalEntryLines} jel 
        ON jel.account_id = coa.id AND jel.organization_id = coa.organization_id
      INNER JOIN ${DatabaseConstants.tableJournalEntries} je 
        ON je.id = jel.journal_entry_id 
        AND je.organization_id = jel.organization_id 
        AND je.status = 'POSTED'
        AND je.entry_date >= ? AND je.entry_date <= ?
      WHERE coa.organization_id = ? AND coa.account_type IN ('REVENUE', 'EXPENSE')
      GROUP BY coa.id
    ''';

    final rows =
        await db.rawQuery(pnlSql, [startDate, endDate, organizationId]);

    int totalRevenue = 0;
    int totalExpense = 0;
    final closingLines = <Map<String, dynamic>>[];

    for (final r in rows) {
      final debit = (r['total_debit'] as num).toInt();
      final credit = (r['total_credit'] as num).toInt();
      final type = r['account_type'] as String;
      final accId = r['id'] as String;
      final currency = r['currency_code'] as String? ?? 'YER';

      if (type == 'REVENUE') {
        final net = credit - debit;
        if (net != 0) {
          totalRevenue += net;
          // To close revenue (normally credit), DEBIT the revenue account
          closingLines.add({
            'account_id': accId,
            'base_debit': net > 0 ? net : 0,
            'base_credit': net < 0 ? net.abs() : 0,
            'currency_code': currency,
            'description': 'إقفال حساب الإيراد: ${r['account_name_ar']}',
          });
        }
      } else if (type == 'EXPENSE') {
        final net = debit - credit;
        if (net != 0) {
          totalExpense += net;
          // To close expense (normally debit), CREDIT the expense account
          closingLines.add({
            'account_id': accId,
            'base_debit': net < 0 ? net.abs() : 0,
            'base_credit': net > 0 ? net : 0,
            'currency_code': currency,
            'description': 'إقفال حساب المصروف: ${r['account_name_ar']}',
          });
        }
      }
    }

    final netProfitLoss = totalRevenue - totalExpense;

    // Transfer net profit/loss to retained earnings
    // If Profit (Revenue > Expense): Credit Retained Earnings
    // If Loss (Expense > Revenue): Debit Retained Earnings
    if (netProfitLoss != 0) {
      closingLines.add({
        'account_id': retainedEarningsAccountId,
        'base_debit': netProfitLoss < 0 ? netProfitLoss.abs() : 0,
        'base_credit': netProfitLoss > 0 ? netProfitLoss : 0,
        'currency_code': 'YER',
        'description': netProfitLoss > 0
            ? 'ترحيل صافي أرباح السنة المالية إلى الأرباح المبقاة'
            : 'ترحيل صافي خسائر السنة المالية إلى الأرباح المبقاة',
      });
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final closingEntryId =
        'je_closing_${organizationId}_${DateTime.now().millisecondsSinceEpoch}';
    final entryNumber = 'CLS-${fy['name']}';

    await db.transaction((txn) async {
      // 1. Get or pick period for the closing date (endDate)
      final pRes = await txn.query(
        DatabaseConstants.tableFiscalPeriods,
        where: 'fiscal_year_id = ? AND organization_id = ?',
        whereArgs: [fiscalYearId, organizationId],
        orderBy: 'period_number DESC',
        limit: 1,
      );
      final periodId =
          pRes.isNotEmpty ? pRes.first['id'] as String : 'fp_default';

      // 2. Insert Closing Journal Entry Header
      int totalDebits = 0;
      int totalCredits = 0;
      for (final l in closingLines) {
        totalDebits += (l['base_debit'] as int);
        totalCredits += (l['base_credit'] as int);
      }

      if (totalDebits != totalCredits) {
        throw Exception(
            'قيد الإقفال غير متوازن محاسبياً! (مدين: $totalDebits, دائن: $totalCredits)');
      }

      await txn.insert(
        DatabaseConstants.tableJournalEntries,
        {
          'id': closingEntryId,
          'organization_id': organizationId,
          'entry_number': entryNumber,
          'fiscal_period_id': periodId,
          'entry_date': endDate,
          'entry_type': 'CLOSING',
          'status': 'POSTED',
          'narration': narration ??
              'قيد إقفال الحسابات الاسمية والأرباح والخسائر للسنة المالية ${fy['name']}',
          'total_base_debit': totalDebits,
          'total_base_credit': totalCredits,
          'posted_at': now,
          'created_at': now,
          'updated_at': now,
        },
      );

      // 3. Insert Closing Lines
      for (int i = 0; i < closingLines.length; i++) {
        final line = closingLines[i];
        final bDeb = line['base_debit'] as int;
        final bCred = line['base_credit'] as int;

        await txn.insert(
          DatabaseConstants.tableJournalEntryLines,
          {
            'id': 'jel_${closingEntryId}_$i',
            'organization_id': organizationId,
            'journal_entry_id': closingEntryId,
            'line_number': i + 1,
            'account_id': line['account_id'],
            'description': line['description'],
            'currency_code': line['currency_code'],
            'exchange_rate_scaled': DatabaseConstants.exchangeRateScale,
            'foreign_debit': bDeb,
            'foreign_credit': bCred,
            'base_debit': bDeb,
            'base_credit': bCred,
            'created_at': now,
          },
        );
      }

      // 4. Mark Fiscal Year and Periods as Closed and Locked
      await txn.update(
        DatabaseConstants.tableFiscalYears,
        {'is_closed': 1},
        where: 'id = ? AND organization_id = ?',
        whereArgs: [fiscalYearId, organizationId],
      );
      await txn.update(
        DatabaseConstants.tableFiscalPeriods,
        {'is_closed': 1, 'is_locked': 1},
        where: 'fiscal_year_id = ? AND organization_id = ?',
        whereArgs: [fiscalYearId, organizationId],
      );

      // 5. Audit Log
      await txn.insert(
        DatabaseConstants.tableAuditLogs,
        {
          'organization_id': organizationId,
          'table_name': DatabaseConstants.tableFiscalYears,
          'record_id': fiscalYearId,
          'action': 'POST',
          'new_values':
              '{"closed": 1, "closing_entry_id": "$closingEntryId", "net_profit": $netProfitLoss}',
          'created_at': now,
        },
      );
    });

    return {
      'closing_entry_id': closingEntryId,
      'net_profit_loss': netProfitLoss,
      'total_revenue': totalRevenue,
      'total_expense': totalExpense,
      'is_closed': true,
    };
  }

  /// Reopens a closed fiscal year with a documented reason.
  Future<void> reopenFiscalYear({
    required String fiscalYearId,
    required String organizationId,
    required String reason,
  }) async {
    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      // 1. Find closing journal entry and void it
      final fyRes = await txn.query(
        DatabaseConstants.tableFiscalYears,
        where: 'id = ? AND organization_id = ?',
        whereArgs: [fiscalYearId, organizationId],
      );
      if (fyRes.isEmpty) throw Exception('السنة المالية غير موجودة');
      final fy = fyRes.first;

      await txn.update(
        DatabaseConstants.tableJournalEntries,
        {'status': 'VOIDED', 'updated_at': now},
        where: 'organization_id = ? AND entry_number = ? AND entry_type = ?',
        whereArgs: [organizationId, 'CLS-${fy['name']}', 'CLOSING'],
      );

      // 2. Mark year and periods open
      await txn.update(
        DatabaseConstants.tableFiscalYears,
        {'is_closed': 0},
        where: 'id = ? AND organization_id = ?',
        whereArgs: [fiscalYearId, organizationId],
      );
      await txn.update(
        DatabaseConstants.tableFiscalPeriods,
        {'is_closed': 0, 'is_locked': 0},
        where: 'fiscal_year_id = ? AND organization_id = ?',
        whereArgs: [fiscalYearId, organizationId],
      );

      // 3. Document in Audit Log
      await txn.insert(
        DatabaseConstants.tableAuditLogs,
        {
          'organization_id': organizationId,
          'table_name': DatabaseConstants.tableFiscalYears,
          'record_id': fiscalYearId,
          'action': 'VOID',
          'new_values': '{"reopened": 1, "reason": "$reason"}',
          'created_at': now,
        },
      );
    });
  }

  // ===========================================================================
  // 3. APP SETTINGS & CONFIGURATION
  // ===========================================================================

  /// Gets a setting value.
  Future<String?> getAppSetting(String key, {String? organizationId}) async {
    final db = await _db;
    final res = await db.query(
      DatabaseConstants.tableAppSettings,
      where:
          'setting_key = ? AND (organization_id = ? OR organization_id IS NULL)',
      whereArgs: [key, organizationId],
      limit: 1,
    );
    if (res.isNotEmpty) {
      return res.first['setting_value'] as String?;
    }
    return null;
  }

  /// Saves or updates a setting.
  Future<void> saveAppSetting(
    String key,
    String value, {
    String? organizationId,
    String dataType = 'STRING',
  }) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final id = 'set_${organizationId ?? "global"}_$key';

    await db.insert(
      DatabaseConstants.tableAppSettings,
      {
        'id': id,
        'organization_id': organizationId,
        'setting_key': key,
        'setting_value': value,
        'data_type': dataType,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ===========================================================================
  // 4. AUDIT LOGS TRAIL
  // ===========================================================================

  /// Fetches audit trail records.
  Future<List<Map<String, dynamic>>> getAuditLogs({
    String? organizationId,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await _db;
    final where = organizationId != null && organizationId.isNotEmpty
        ? 'organization_id = ? OR organization_id IS NULL'
        : null;
    final whereArgs = organizationId != null && organizationId.isNotEmpty
        ? [organizationId]
        : null;

    return await db.query(
      DatabaseConstants.tableAuditLogs,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
      offset: offset,
    );
  }
}
