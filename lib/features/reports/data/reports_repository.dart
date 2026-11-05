import 'package:sqflite/sqflite.dart';
import '../../../core/constants/database_constants.dart';
import '../../../core/database/database_helper.dart';

/// Repository computing financial reports from posted General Ledger entries in SQLite.
class ReportsRepository {
  final DatabaseHelper _dbHelper;

  ReportsRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db async => await _dbHelper.database;

  // ===========================================================================
  // 1. TRIAL BALANCE (ميزان المراجعة)
  // ===========================================================================
  /// Fetches Trial Balance (ميزان المراجعة) by totals and net balances.
  /// Supports asOfDate and optional date range (fromDate, toDate).
  Future<Map<String, dynamic>> getTrialBalance(
    String organizationId, {
    String? asOfDate,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _db;
    final date =
        toDate ?? asOfDate ?? DateTime.now().toIso8601String().split('T').first;

    final String dateCondition;
    final List<dynamic> queryArgs;

    if (fromDate != null && fromDate.isNotEmpty) {
      dateCondition = 'je.entry_date >= ? AND je.entry_date <= ?';
      queryArgs = [fromDate, date, organizationId];
    } else {
      dateCondition = 'je.entry_date <= ?';
      queryArgs = [date, organizationId];
    }

    final sql = '''
      SELECT 
        coa.id,
        coa.account_code,
        coa.account_name_ar,
        coa.account_type,
        coa.account_nature,
        coa.currency_code,
        COALESCE(SUM(jel.base_debit), 0) AS total_debit,
        COALESCE(SUM(jel.base_credit), 0) AS total_credit
      FROM ${DatabaseConstants.tableChartOfAccounts} coa
      LEFT JOIN ${DatabaseConstants.tableJournalEntryLines} jel 
        ON jel.account_id = coa.id AND jel.organization_id = coa.organization_id
      LEFT JOIN ${DatabaseConstants.tableJournalEntries} je 
        ON je.id = jel.journal_entry_id 
        AND je.organization_id = jel.organization_id 
        AND je.status = 'POSTED'
        AND $dateCondition
      WHERE coa.organization_id = ?
      GROUP BY coa.id
      ORDER BY coa.account_code ASC
    ''';

    final rows = await db.rawQuery(sql, queryArgs);

    int sumTotalDebit = 0;
    int sumTotalCredit = 0;
    int sumNetDebit = 0;
    int sumNetCredit = 0;

    final accountsList = <Map<String, dynamic>>[];

    for (final r in rows) {
      final totalDebit = (r['total_debit'] as num).toInt();
      final totalCredit = (r['total_credit'] as num).toInt();

      if (totalDebit == 0 && totalCredit == 0) {
        // Skip accounts with zero activity in trial balance
        continue;
      }

      sumTotalDebit += totalDebit;
      sumTotalCredit += totalCredit;

      int netDebit = 0;
      int netCredit = 0;

      if (totalDebit > totalCredit) {
        netDebit = totalDebit - totalCredit;
        sumNetDebit += netDebit;
      } else if (totalCredit > totalDebit) {
        netCredit = totalCredit - totalDebit;
        sumNetCredit += netCredit;
      }

      accountsList.add({
        'id': r['id'],
        'account_code': r['account_code'],
        'account_name_ar': r['account_name_ar'],
        'account_type': r['account_type'],
        'account_nature': r['account_nature'],
        'currency_code': r['currency_code'],
        'total_debit': totalDebit,
        'total_credit': totalCredit,
        'net_debit': netDebit,
        'net_credit': netCredit,
      });
    }

    return {
      'accounts': accountsList,
      'sum_total_debit': sumTotalDebit,
      'sum_total_credit': sumTotalCredit,
      'sum_net_debit': sumNetDebit,
      'sum_net_credit': sumNetCredit,
      'is_balanced':
          sumTotalDebit == sumTotalCredit && sumNetDebit == sumNetCredit,
    };
  }

  // ===========================================================================
  // 2. BALANCE SHEET (الميزانية العمومية)
  // ===========================================================================
  /// Computes Balance Sheet (الميزانية العمومية / قائمة المركز المالي).
  /// Formula: Assets = Liabilities + Equity (including current period profit/loss).
  Future<Map<String, dynamic>> getBalanceSheet(
    String organizationId, {
    required String asOfDate,
  }) async {
    final db = await _db;

    final sql = '''
      SELECT 
        coa.id,
        coa.account_code,
        coa.account_name_ar,
        coa.account_type,
        COALESCE(SUM(jel.base_debit), 0) AS total_debit,
        COALESCE(SUM(jel.base_credit), 0) AS total_credit
      FROM ${DatabaseConstants.tableChartOfAccounts} coa
      LEFT JOIN ${DatabaseConstants.tableJournalEntryLines} jel 
        ON jel.account_id = coa.id AND jel.organization_id = coa.organization_id
      LEFT JOIN ${DatabaseConstants.tableJournalEntries} je 
        ON je.id = jel.journal_entry_id 
        AND je.organization_id = jel.organization_id 
        AND je.status = 'POSTED'
        AND je.entry_date <= ?
      WHERE coa.organization_id = ?
      GROUP BY coa.id
      ORDER BY coa.account_code ASC
    ''';

    final rows = await db.rawQuery(sql, [asOfDate, organizationId]);

    final assets = <Map<String, dynamic>>[];
    final liabilities = <Map<String, dynamic>>[];
    final equity = <Map<String, dynamic>>[];

    int totalAssets = 0;
    int totalLiabilities = 0;
    int totalEquity = 0;
    int currentPeriodNetProfit = 0;

    for (final r in rows) {
      final debit = (r['total_debit'] as num).toInt();
      final credit = (r['total_credit'] as num).toInt();
      final type = r['account_type'] as String;

      if (type == 'ASSET') {
        final net = debit - credit;
        if (net != 0) {
          totalAssets += net;
          assets.add({
            'code': r['account_code'],
            'name': r['account_name_ar'],
            'amount': net,
          });
        }
      } else if (type == 'LIABILITY') {
        final net = credit - debit;
        if (net != 0) {
          totalLiabilities += net;
          liabilities.add({
            'code': r['account_code'],
            'name': r['account_name_ar'],
            'amount': net,
          });
        }
      } else if (type == 'EQUITY') {
        final net = credit - debit;
        if (net != 0) {
          totalEquity += net;
          equity.add({
            'code': r['account_code'],
            'name': r['account_name_ar'],
            'amount': net,
          });
        }
      } else if (type == 'REVENUE') {
        currentPeriodNetProfit += (credit - debit);
      } else if (type == 'EXPENSE') {
        currentPeriodNetProfit -= (debit - credit);
      }
    }

    // Add current period net profit to equity
    totalEquity += currentPeriodNetProfit;

    return {
      'assets': assets,
      'liabilities': liabilities,
      'equity': equity,
      'total_assets': totalAssets,
      'total_liabilities': totalLiabilities,
      'total_equity': totalEquity,
      'current_period_profit': currentPeriodNetProfit,
      'is_balanced': totalAssets == (totalLiabilities + totalEquity),
    };
  }

  // ===========================================================================
  // 3. INCOME STATEMENT / PROFIT & LOSS (قائمة الأرباح والخسائر)
  // ===========================================================================
  /// Computes Profit & Loss / Income Statement (قائمة الدخل).
  Future<Map<String, dynamic>> getIncomeStatement(
    String organizationId, {
    required String fromDate,
    required String toDate,
  }) async {
    final db = await _db;

    final sql = '''
      SELECT 
        coa.id,
        coa.account_code,
        coa.account_name_ar,
        coa.account_type,
        COALESCE(SUM(jel.base_debit), 0) AS total_debit,
        COALESCE(SUM(jel.base_credit), 0) AS total_credit
      FROM ${DatabaseConstants.tableChartOfAccounts} coa
      LEFT JOIN ${DatabaseConstants.tableJournalEntryLines} jel 
        ON jel.account_id = coa.id AND jel.organization_id = coa.organization_id
      LEFT JOIN ${DatabaseConstants.tableJournalEntries} je 
        ON je.id = jel.journal_entry_id 
        AND je.organization_id = jel.organization_id 
        AND je.status = 'POSTED'
        AND je.entry_date >= ? AND je.entry_date <= ?
      WHERE coa.organization_id = ? AND coa.account_type IN ('REVENUE', 'EXPENSE')
      GROUP BY coa.id
      ORDER BY coa.account_code ASC
    ''';

    final rows = await db.rawQuery(sql, [fromDate, toDate, organizationId]);

    final revenues = <Map<String, dynamic>>[];
    final expenses = <Map<String, dynamic>>[];

    int totalRevenue = 0;
    int totalExpense = 0;

    for (final r in rows) {
      final debit = (r['total_debit'] as num).toInt();
      final credit = (r['total_credit'] as num).toInt();
      final type = r['account_type'] as String;

      if (type == 'REVENUE') {
        final net = credit - debit;
        if (net != 0) {
          totalRevenue += net;
          revenues.add({
            'code': r['account_code'],
            'name': r['account_name_ar'],
            'amount': net,
          });
        }
      } else if (type == 'EXPENSE') {
        final net = debit - credit;
        if (net != 0) {
          totalExpense += net;
          expenses.add({
            'code': r['account_code'],
            'name': r['account_name_ar'],
            'amount': net,
          });
        }
      }
    }

    final netProfitLoss = totalRevenue - totalExpense;

    return {
      'revenues': revenues,
      'expenses': expenses,
      'total_revenue': totalRevenue,
      'total_expense': totalExpense,
      'net_profit_loss': netProfitLoss,
    };
  }

  // ===========================================================================
  // 4. GENERAL LEDGER (دفتر الأستاذ العام)
  // ===========================================================================
  /// Computes General Ledger for a specific account.
  Future<Map<String, dynamic>> getAccountLedger(
    String organizationId,
    String accountId, {
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _db;
    final fDate = fromDate ?? '2000-01-01';
    final tDate = toDate ?? DateTime.now().toIso8601String().split('T').first;

    // 1. Calculate opening balance before fromDate
    final openingRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(jel.base_debit), 0) AS opening_debit,
        COALESCE(SUM(jel.base_credit), 0) AS opening_credit
      FROM ${DatabaseConstants.tableJournalEntryLines} jel
      INNER JOIN ${DatabaseConstants.tableJournalEntries} je 
        ON je.id = jel.journal_entry_id 
        AND je.organization_id = jel.organization_id
        AND je.status = 'POSTED'
        AND je.entry_date < ?
      WHERE jel.account_id = ? AND jel.organization_id = ?
    ''', [fDate, accountId, organizationId]);

    int openingDebit = 0;
    int openingCredit = 0;
    if (openingRes.isNotEmpty) {
      openingDebit = (openingRes.first['opening_debit'] as num).toInt();
      openingCredit = (openingRes.first['opening_credit'] as num).toInt();
    }
    final int openingBalance = openingDebit - openingCredit;

    // 2. Fetch posted lines between dates
    final linesRes = await db.rawQuery('''
      SELECT 
        jel.id,
        je.entry_number,
        je.entry_date,
        je.entry_type,
        jel.description,
        jel.currency_code,
        jel.foreign_debit,
        jel.foreign_credit,
        jel.base_debit,
        jel.base_credit,
        p.name_ar AS party_name_ar
      FROM ${DatabaseConstants.tableJournalEntryLines} jel
      INNER JOIN ${DatabaseConstants.tableJournalEntries} je 
        ON je.id = jel.journal_entry_id 
        AND je.organization_id = jel.organization_id
        AND je.status = 'POSTED'
        AND je.entry_date >= ? AND je.entry_date <= ?
      LEFT JOIN ${DatabaseConstants.tableParties} p 
        ON p.id = jel.party_id AND p.organization_id = jel.organization_id
      WHERE jel.account_id = ? AND jel.organization_id = ?
      ORDER BY je.entry_date ASC, je.entry_number ASC
    ''', [fDate, tDate, accountId, organizationId]);

    int runningBalance = openingBalance;
    int periodDebit = 0;
    int periodCredit = 0;

    final linesWithBalance = <Map<String, dynamic>>[];
    for (final l in linesRes) {
      final debit = (l['base_debit'] as num).toInt();
      final credit = (l['base_credit'] as num).toInt();
      periodDebit += debit;
      periodCredit += credit;
      runningBalance += (debit - credit);

      linesWithBalance.add({
        ...l,
        'running_balance': runningBalance,
      });
    }

    return {
      'opening_balance': openingBalance,
      'period_debit': periodDebit,
      'period_credit': periodCredit,
      'closing_balance': runningBalance,
      'lines': linesWithBalance,
    };
  }

  // ===========================================================================
  // 5. CASH AND BANK REPORT (تقرير الصناديق والبنوك)
  // ===========================================================================
  /// Fetches Cash and Bank movements with period inflows and outflows.
  Future<List<Map<String, dynamic>>> getCashBankMovements(
    String organizationId, {
    String? asOfDate,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _db;
    final date =
        toDate ?? asOfDate ?? DateTime.now().toIso8601String().split('T').first;

    final sql = '''
      SELECT 
        coa.id,
        coa.account_code,
        coa.account_name_ar,
        coa.currency_code,
        COALESCE(SUM(CASE WHEN je.entry_date <= ? THEN jel.base_debit ELSE 0 END), 0) AS total_inflow,
        COALESCE(SUM(CASE WHEN je.entry_date <= ? THEN jel.base_credit ELSE 0 END), 0) AS total_outflow,
        (COALESCE(SUM(CASE WHEN je.entry_date <= ? THEN jel.base_debit ELSE 0 END), 0) - 
         COALESCE(SUM(CASE WHEN je.entry_date <= ? THEN jel.base_credit ELSE 0 END), 0)) AS net_balance
      FROM ${DatabaseConstants.tableChartOfAccounts} coa
      LEFT JOIN ${DatabaseConstants.tableJournalEntryLines} jel 
        ON jel.account_id = coa.id AND jel.organization_id = coa.organization_id
      LEFT JOIN ${DatabaseConstants.tableJournalEntries} je 
        ON je.id = jel.journal_entry_id 
        AND je.organization_id = jel.organization_id 
        AND je.status = 'POSTED'
      WHERE coa.organization_id = ? AND coa.is_cash_bank = 1
      GROUP BY coa.id
      ORDER BY coa.account_code ASC
    ''';

    return await db.rawQuery(sql, [date, date, date, date, organizationId]);
  }

  // ===========================================================================
  // 6. CUSTOMER STATEMENTS (كشوف حسابات العملاء)
  // ===========================================================================
  /// Computes detailed Customer Statement with opening balance and running balance.
  /// Reconciles with Customer Control Account (1121 / 1103).
  Future<Map<String, dynamic>> getCustomerStatement(
    String organizationId,
    String partyId, {
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _db;
    final fDate = fromDate ?? '2000-01-01';
    final tDate = toDate ?? DateTime.now().toIso8601String().split('T').first;

    // Fetch customer details
    final partyRows = await db.query(
      DatabaseConstants.tableParties,
      where: 'id = ? AND organization_id = ?',
      whereArgs: [partyId, organizationId],
    );
    final partyInfo =
        partyRows.isNotEmpty ? partyRows.first : <String, dynamic>{};

    // 1. Calculate opening balance before fromDate
    final openingRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(jel.base_debit), 0) AS opening_debit,
        COALESCE(SUM(jel.base_credit), 0) AS opening_credit
      FROM ${DatabaseConstants.tableJournalEntryLines} jel
      INNER JOIN ${DatabaseConstants.tableJournalEntries} je 
        ON je.id = jel.journal_entry_id 
        AND je.organization_id = jel.organization_id
        AND je.status = 'POSTED'
        AND je.entry_date < ?
      WHERE jel.party_id = ? AND jel.organization_id = ?
    ''', [fDate, partyId, organizationId]);

    int openingDebit = 0;
    int openingCredit = 0;
    if (openingRes.isNotEmpty) {
      openingDebit = (openingRes.first['opening_debit'] as num).toInt();
      openingCredit = (openingRes.first['opening_credit'] as num).toInt();
    }
    // For customers, debit increases receivable, credit decreases
    final int openingBalance = openingDebit - openingCredit;

    // 2. Fetch posted lines in date range
    final linesRes = await db.rawQuery('''
      SELECT 
        jel.id,
        je.entry_number,
        je.entry_date,
        je.entry_type,
        jel.description,
        jel.currency_code,
        jel.exchange_rate_scaled,
        jel.foreign_debit,
        jel.foreign_credit,
        jel.base_debit,
        jel.base_credit,
        coa.account_code,
        coa.account_name_ar
      FROM ${DatabaseConstants.tableJournalEntryLines} jel
      INNER JOIN ${DatabaseConstants.tableJournalEntries} je 
        ON je.id = jel.journal_entry_id 
        AND je.organization_id = jel.organization_id
        AND je.status = 'POSTED'
        AND je.entry_date >= ? AND je.entry_date <= ?
      LEFT JOIN ${DatabaseConstants.tableChartOfAccounts} coa
        ON coa.id = jel.account_id AND coa.organization_id = jel.organization_id
      WHERE jel.party_id = ? AND jel.organization_id = ?
      ORDER BY je.entry_date ASC, je.entry_number ASC
    ''', [fDate, tDate, partyId, organizationId]);

    int runningBalance = openingBalance;
    int periodDebit = 0;
    int periodCredit = 0;

    final linesWithBalance = <Map<String, dynamic>>[];
    for (final l in linesRes) {
      final debit = (l['base_debit'] as num).toInt();
      final credit = (l['base_credit'] as num).toInt();
      periodDebit += debit;
      periodCredit += credit;
      runningBalance += (debit - credit);

      linesWithBalance.add({
        ...l,
        'running_balance': runningBalance,
      });
    }

    return {
      'party': partyInfo,
      'opening_balance': openingBalance,
      'period_debit': periodDebit,
      'period_credit': periodCredit,
      'closing_balance': runningBalance,
      'lines': linesWithBalance,
    };
  }

  // ===========================================================================
  // 7. SUPPLIER STATEMENTS (كشوف حسابات الموردين)
  // ===========================================================================
  /// Computes detailed Supplier Statement with opening balance and running balance.
  /// Reconciles with Supplier Control Account (2111 / 2101).
  Future<Map<String, dynamic>> getSupplierStatement(
    String organizationId,
    String partyId, {
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _db;
    final fDate = fromDate ?? '2000-01-01';
    final tDate = toDate ?? DateTime.now().toIso8601String().split('T').first;

    // Fetch supplier details
    final partyRows = await db.query(
      DatabaseConstants.tableParties,
      where: 'id = ? AND organization_id = ?',
      whereArgs: [partyId, organizationId],
    );
    final partyInfo =
        partyRows.isNotEmpty ? partyRows.first : <String, dynamic>{};

    // 1. Calculate opening balance before fromDate
    final openingRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(jel.base_debit), 0) AS opening_debit,
        COALESCE(SUM(jel.base_credit), 0) AS opening_credit
      FROM ${DatabaseConstants.tableJournalEntryLines} jel
      INNER JOIN ${DatabaseConstants.tableJournalEntries} je 
        ON je.id = jel.journal_entry_id 
        AND je.organization_id = jel.organization_id
        AND je.status = 'POSTED'
        AND je.entry_date < ?
      WHERE jel.party_id = ? AND jel.organization_id = ?
    ''', [fDate, partyId, organizationId]);

    int openingDebit = 0;
    int openingCredit = 0;
    if (openingRes.isNotEmpty) {
      openingDebit = (openingRes.first['opening_debit'] as num).toInt();
      openingCredit = (openingRes.first['opening_credit'] as num).toInt();
    }
    // For suppliers, credit increases payable (liability), debit decreases
    final int openingBalance = openingCredit - openingDebit;

    // 2. Fetch posted lines in date range
    final linesRes = await db.rawQuery('''
      SELECT 
        jel.id,
        je.entry_number,
        je.entry_date,
        je.entry_type,
        jel.description,
        jel.currency_code,
        jel.exchange_rate_scaled,
        jel.foreign_debit,
        jel.foreign_credit,
        jel.base_debit,
        jel.base_credit,
        coa.account_code,
        coa.account_name_ar
      FROM ${DatabaseConstants.tableJournalEntryLines} jel
      INNER JOIN ${DatabaseConstants.tableJournalEntries} je 
        ON je.id = jel.journal_entry_id 
        AND je.organization_id = jel.organization_id
        AND je.status = 'POSTED'
        AND je.entry_date >= ? AND je.entry_date <= ?
      LEFT JOIN ${DatabaseConstants.tableChartOfAccounts} coa
        ON coa.id = jel.account_id AND coa.organization_id = jel.organization_id
      WHERE jel.party_id = ? AND jel.organization_id = ?
      ORDER BY je.entry_date ASC, je.entry_number ASC
    ''', [fDate, tDate, partyId, organizationId]);

    int runningBalance = openingBalance;
    int periodDebit = 0;
    int periodCredit = 0;

    final linesWithBalance = <Map<String, dynamic>>[];
    for (final l in linesRes) {
      final debit = (l['base_debit'] as num).toInt();
      final credit = (l['base_credit'] as num).toInt();
      periodDebit += debit;
      periodCredit += credit;
      // For suppliers: credit increases balance, debit decreases
      runningBalance += (credit - debit);

      linesWithBalance.add({
        ...l,
        'running_balance': runningBalance,
      });
    }

    return {
      'party': partyInfo,
      'opening_balance': openingBalance,
      'period_debit': periodDebit,
      'period_credit': periodCredit,
      'closing_balance': runningBalance,
      'lines': linesWithBalance,
    };
  }

  // ===========================================================================
  // 8. ACCOUNT ACTIVITY REPORT (حركة الحساب / كشف العمليات)
  // ===========================================================================
  /// Flexible activity report filtering journal lines across accounts, parties, and dates.
  Future<Map<String, dynamic>> getAccountActivity(
    String organizationId, {
    String? accountId,
    String? partyId,
    String? currencyCode,
    String? entryType,
    String? fromDate,
    String? toDate,
    int limit = 200,
  }) async {
    final db = await _db;
    final conditions = <String>[
      'je.organization_id = ?',
      "je.status = 'POSTED'"
    ];
    final args = <dynamic>[organizationId];

    if (accountId != null && accountId.isNotEmpty) {
      conditions.add('jel.account_id = ?');
      args.add(accountId);
    }
    if (partyId != null && partyId.isNotEmpty) {
      conditions.add('jel.party_id = ?');
      args.add(partyId);
    }
    if (currencyCode != null && currencyCode.isNotEmpty) {
      conditions.add('jel.currency_code = ?');
      args.add(currencyCode);
    }
    if (entryType != null && entryType.isNotEmpty) {
      conditions.add('je.entry_type = ?');
      args.add(entryType);
    }
    if (fromDate != null && fromDate.isNotEmpty) {
      conditions.add('je.entry_date >= ?');
      args.add(fromDate);
    }
    if (toDate != null && toDate.isNotEmpty) {
      conditions.add('je.entry_date <= ?');
      args.add(toDate);
    }

    final whereClause = conditions.join(' AND ');

    final sql = '''
      SELECT 
        jel.id,
        je.entry_number,
        je.entry_date,
        je.entry_type,
        je.narration,
        jel.description,
        jel.currency_code,
        jel.exchange_rate_scaled,
        jel.foreign_debit,
        jel.foreign_credit,
        jel.base_debit,
        jel.base_credit,
        coa.account_code,
        coa.account_name_ar,
        p.name_ar AS party_name_ar
      FROM ${DatabaseConstants.tableJournalEntryLines} jel
      INNER JOIN ${DatabaseConstants.tableJournalEntries} je 
        ON je.id = jel.journal_entry_id AND je.organization_id = jel.organization_id
      INNER JOIN ${DatabaseConstants.tableChartOfAccounts} coa 
        ON coa.id = jel.account_id AND coa.organization_id = jel.organization_id
      LEFT JOIN ${DatabaseConstants.tableParties} p 
        ON p.id = jel.party_id AND p.organization_id = jel.organization_id
      WHERE $whereClause
      ORDER BY je.entry_date DESC, je.entry_number DESC
      LIMIT $limit
    ''';

    final rows = await db.rawQuery(sql, args);

    int totalDebit = 0;
    int totalCredit = 0;

    for (final r in rows) {
      totalDebit += (r['base_debit'] as num).toInt();
      totalCredit += (r['base_credit'] as num).toInt();
    }

    return {
      'rows': rows,
      'total_debit': totalDebit,
      'total_credit': totalCredit,
      'net_balance': totalDebit - totalCredit,
      'count': rows.length,
    };
  }

  // ===========================================================================
  // 9. OUTSTANDING RECEIVABLES (الذمم المدينة المستحقة / أعمار الديون)
  // ===========================================================================
  /// Calculates aging and outstanding balances for unpaid/partially paid sales invoices.
  Future<Map<String, dynamic>> getOutstandingReceivables(
    String organizationId, {
    String? asOfDate,
  }) async {
    final db = await _db;
    final date = asOfDate ?? DateTime.now().toIso8601String().split('T').first;
    final asOfDateTime = DateTime.parse(date);

    final sql = '''
      SELECT 
        inv.id,
        inv.invoice_number,
        inv.issue_date,
        inv.due_date,
        inv.currency_code,
        inv.exchange_rate_scaled,
        inv.total_amount,
        inv.paid_amount,
        (inv.total_amount - inv.paid_amount) AS remaining_amount,
        inv.payment_status,
        p.id AS party_id,
        p.name_ar AS party_name,
        p.code AS party_code,
        p.phone AS party_phone
      FROM ${DatabaseConstants.tableInvoices} inv
      INNER JOIN ${DatabaseConstants.tableParties} p 
        ON p.id = inv.party_id AND p.organization_id = inv.organization_id
      WHERE inv.organization_id = ?
        AND inv.invoice_type = 'SALES'
        AND inv.status = 'POSTED'
        AND inv.payment_status != 'PAID'
        AND inv.issue_date <= ?
      ORDER BY inv.issue_date ASC
    ''';

    final rows = await db.rawQuery(sql, [organizationId, date]);

    int bucket0To30 = 0;
    int bucket31To60 = 0;
    int bucket61To90 = 0;
    int bucket90Plus = 0;
    int totalReceivables = 0;

    final invoiceList = <Map<String, dynamic>>[];

    for (final r in rows) {
      final remaining = (r['remaining_amount'] as num).toInt();
      if (remaining <= 0) continue;

      totalReceivables += remaining;

      final issueDate =
          DateTime.tryParse(r['issue_date'] as String) ?? asOfDateTime;
      final int ageDays = asOfDateTime.difference(issueDate).inDays;
      final int days = ageDays < 0 ? 0 : ageDays;

      String bucket = '0-30';
      if (days <= 30) {
        bucket0To30 += remaining;
        bucket = '0-30';
      } else if (days <= 60) {
        bucket31To60 += remaining;
        bucket = '31-60';
      } else if (days <= 90) {
        bucket61To90 += remaining;
        bucket = '61-90';
      } else {
        bucket90Plus += remaining;
        bucket = '90+';
      }

      invoiceList.add({
        ...r,
        'age_days': days,
        'aging_bucket': bucket,
      });
    }

    return {
      'invoices': invoiceList,
      'total_receivables': totalReceivables,
      'bucket_0_30': bucket0To30,
      'bucket_31_60': bucket31To60,
      'bucket_61_90': bucket61To90,
      'bucket_90_plus': bucket90Plus,
      'count': invoiceList.length,
    };
  }

  // ===========================================================================
  // 10. OUTSTANDING PAYABLES (الذمم الدائنة المستحقة / أعمار الديون للموردين)
  // ===========================================================================
  /// Calculates aging and outstanding balances for unpaid/partially paid purchase invoices.
  Future<Map<String, dynamic>> getOutstandingPayables(
    String organizationId, {
    String? asOfDate,
  }) async {
    final db = await _db;
    final date = asOfDate ?? DateTime.now().toIso8601String().split('T').first;
    final asOfDateTime = DateTime.parse(date);

    final sql = '''
      SELECT 
        inv.id,
        inv.invoice_number,
        inv.issue_date,
        inv.due_date,
        inv.currency_code,
        inv.exchange_rate_scaled,
        inv.total_amount,
        inv.paid_amount,
        (inv.total_amount - inv.paid_amount) AS remaining_amount,
        inv.payment_status,
        p.id AS party_id,
        p.name_ar AS party_name,
        p.code AS party_code,
        p.phone AS party_phone
      FROM ${DatabaseConstants.tableInvoices} inv
      INNER JOIN ${DatabaseConstants.tableParties} p 
        ON p.id = inv.party_id AND p.organization_id = inv.organization_id
      WHERE inv.organization_id = ?
        AND inv.invoice_type = 'PURCHASE'
        AND inv.status = 'POSTED'
        AND inv.payment_status != 'PAID'
        AND inv.issue_date <= ?
      ORDER BY inv.issue_date ASC
    ''';

    final rows = await db.rawQuery(sql, [organizationId, date]);

    int bucket0To30 = 0;
    int bucket31To60 = 0;
    int bucket61To90 = 0;
    int bucket90Plus = 0;
    int totalPayables = 0;

    final invoiceList = <Map<String, dynamic>>[];

    for (final r in rows) {
      final remaining = (r['remaining_amount'] as num).toInt();
      if (remaining <= 0) continue;

      totalPayables += remaining;

      final issueDate =
          DateTime.tryParse(r['issue_date'] as String) ?? asOfDateTime;
      final int ageDays = asOfDateTime.difference(issueDate).inDays;
      final int days = ageDays < 0 ? 0 : ageDays;

      String bucket = '0-30';
      if (days <= 30) {
        bucket0To30 += remaining;
        bucket = '0-30';
      } else if (days <= 60) {
        bucket31To60 += remaining;
        bucket = '31-60';
      } else if (days <= 90) {
        bucket61To90 += remaining;
        bucket = '61-90';
      } else {
        bucket90Plus += remaining;
        bucket = '90+';
      }

      invoiceList.add({
        ...r,
        'age_days': days,
        'aging_bucket': bucket,
      });
    }

    return {
      'invoices': invoiceList,
      'total_payables': totalPayables,
      'bucket_0_30': bucket0To30,
      'bucket_31_60': bucket31To60,
      'bucket_61_90': bucket61To90,
      'bucket_90_plus': bucket90Plus,
      'count': invoiceList.length,
    };
  }

  // ===========================================================================
  // 11. REALIZED FOREX GAINS AND LOSSES (أرباح وخسائر فروق العملة المحققة)
  // ===========================================================================
  /// Computes realized foreign exchange gain/loss per settlement allocation and general ledger.
  Future<Map<String, dynamic>> getRealizedForexReport(
    String organizationId, {
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _db;
    final fDate = fromDate ?? '2000-01-01';
    final tDate = toDate ?? DateTime.now().toIso8601String().split('T').first;

    final sql = '''
      SELECT 
        pa.id,
        pa.allocation_date,
        pa.allocated_amount,
        pa.realized_forex_gain_loss,
        p.payment_number,
        p.payment_type,
        p.currency_code AS payment_currency,
        p.exchange_rate_scaled AS payment_rate,
        inv.invoice_number,
        inv.invoice_type,
        inv.currency_code AS invoice_currency,
        inv.exchange_rate_scaled AS invoice_rate,
        party.name_ar AS party_name
      FROM ${DatabaseConstants.tablePaymentAllocations} pa
      INNER JOIN ${DatabaseConstants.tablePayments} p 
        ON p.id = pa.payment_id AND p.organization_id = pa.organization_id
      INNER JOIN ${DatabaseConstants.tableInvoices} inv 
        ON inv.id = pa.invoice_id AND inv.organization_id = pa.organization_id
      INNER JOIN ${DatabaseConstants.tableParties} party 
        ON party.id = p.party_id AND party.organization_id = p.organization_id
      WHERE pa.organization_id = ?
        AND pa.allocation_date >= ? AND pa.allocation_date <= ?
        AND pa.realized_forex_gain_loss != 0
      ORDER BY pa.allocation_date DESC
    ''';

    final rows = await db.rawQuery(sql, [organizationId, fDate, tDate]);

    int totalRealizedGains = 0;
    int totalRealizedLosses = 0;

    for (final r in rows) {
      final diff = (r['realized_forex_gain_loss'] as num).toInt();
      if (diff > 0) {
        totalRealizedGains += diff;
      } else {
        totalRealizedLosses += diff.abs();
      }
    }

    final int netForexGainLoss = totalRealizedGains - totalRealizedLosses;

    return {
      'allocations': rows,
      'total_realized_gains': totalRealizedGains,
      'total_realized_losses': totalRealizedLosses,
      'net_forex_gain_loss': netForexGainLoss,
      'count': rows.length,
    };
  }

  // ===========================================================================
  // 12. OPENING BALANCES REPORT (تقرير الأرصدة الافتتاحية)
  // ===========================================================================
  /// Fetches opening ledger entries established for the organization.
  Future<Map<String, dynamic>> getOpeningBalancesReport(
    String organizationId,
  ) async {
    final db = await _db;

    final sql = '''
      SELECT 
        coa.id,
        coa.account_code,
        coa.account_name_ar,
        coa.account_type,
        coa.account_nature,
        jel.currency_code,
        jel.exchange_rate_scaled,
        jel.foreign_debit,
        jel.foreign_credit,
        jel.base_debit,
        jel.base_credit,
        je.entry_number,
        je.entry_date,
        je.status
      FROM ${DatabaseConstants.tableJournalEntryLines} jel
      INNER JOIN ${DatabaseConstants.tableJournalEntries} je 
        ON je.id = jel.journal_entry_id AND je.organization_id = jel.organization_id
      INNER JOIN ${DatabaseConstants.tableChartOfAccounts} coa 
        ON coa.id = jel.account_id AND coa.organization_id = jel.organization_id
      WHERE jel.organization_id = ?
        AND je.entry_type = 'OPENING'
        AND je.status = 'POSTED'
      ORDER BY coa.account_code ASC
    ''';

    final rows = await db.rawQuery(sql, [organizationId]);

    int totalDebit = 0;
    int totalCredit = 0;

    for (final r in rows) {
      totalDebit += (r['base_debit'] as num).toInt();
      totalCredit += (r['base_credit'] as num).toInt();
    }

    return {
      'lines': rows,
      'total_debit': totalDebit,
      'total_credit': totalCredit,
      'is_balanced': totalDebit == totalCredit,
      'imbalance': (totalDebit - totalCredit).abs(),
    };
  }

  // ===========================================================================
  // 13. AUDIT LOGS
  // ===========================================================================
  /// Fetches system audit logs.
  Future<List<Map<String, dynamic>>> getAuditLogs(
    String organizationId, {
    int limit = 100,
  }) async {
    final db = await _db;
    return await db.query(
      DatabaseConstants.tableAuditLogs,
      where: 'organization_id = ? OR organization_id IS NULL',
      whereArgs: [organizationId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  // ===========================================================================
  // 14. LIVE DASHBOARD METRICS (مؤشرات لوحة التحكم المباشرة)
  // ===========================================================================
  /// Computes live financial metrics from posted General Ledger entries for an organization.
  /// All figures are integers in base currency minor units (scale 100).
  Future<Map<String, dynamic>> getDashboardMetrics(
      String organizationId) async {
    final db = await _db;

    final sql = '''
      SELECT 
        coa.account_type,
        COALESCE(SUM(jel.base_debit), 0) AS total_debit,
        COALESCE(SUM(jel.base_credit), 0) AS total_credit
      FROM ${DatabaseConstants.tableChartOfAccounts} coa
      LEFT JOIN ${DatabaseConstants.tableJournalEntryLines} jel 
        ON jel.account_id = coa.id AND jel.organization_id = coa.organization_id
      LEFT JOIN ${DatabaseConstants.tableJournalEntries} je 
        ON je.id = jel.journal_entry_id 
        AND je.organization_id = jel.organization_id 
        AND je.status = 'POSTED'
      WHERE coa.organization_id = ?
      GROUP BY coa.account_type
    ''';

    final rows = await db.rawQuery(sql, [organizationId]);

    int totalAssets = 0;
    int totalLiabilities = 0;
    int totalRevenue = 0;
    int totalExpense = 0;

    for (final r in rows) {
      final type = r['account_type'] as String;
      final debit = (r['total_debit'] as num).toInt();
      final credit = (r['total_credit'] as num).toInt();

      if (type == 'ASSET') {
        totalAssets += (debit - credit);
      } else if (type == 'LIABILITY') {
        totalLiabilities += (credit - debit);
      } else if (type == 'REVENUE') {
        totalRevenue += (credit - debit);
      } else if (type == 'EXPENSE') {
        totalExpense += (debit - credit);
      }
    }

    final netProfit = totalRevenue - totalExpense;

    return {
      'total_assets': totalAssets,
      'total_liabilities': totalLiabilities,
      'total_revenue': totalRevenue,
      'total_expense': totalExpense,
      'net_profit': netProfit,
    };
  }
}
