import 'package:sqflite/sqflite.dart';
import '../../../core/constants/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../models/account_model.dart';

/// Repository for the Chart of Accounts (COA) and general ledger balances.
class AccountRepository {
  final DatabaseHelper _databaseHelper;

  AccountRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<Database> get _db async => await _databaseHelper.database;

  /// Fetches flat list of accounts for an organization with dynamically computed balances from posted entries.
  Future<List<AccountModel>> getAccountsFlat(
    String organizationId, {
    String? type,
    bool includeInactive = true,
  }) async {
    final db = await _db;

    String whereSql = 'coa.organization_id = ?';
    final whereArgs = <dynamic>[organizationId];

    if (type != null && type.isNotEmpty && type != 'ALL') {
      whereSql += ' AND coa.account_type = ?';
      whereArgs.add(type);
    }

    if (!includeInactive) {
      whereSql += ' AND coa.is_active = 1';
    }

    final query = '''
      SELECT 
        coa.*,
        COALESCE(SUM(CASE WHEN je.status = 'POSTED' THEN jel.base_debit ELSE 0 END), 0) AS total_debit,
        COALESCE(SUM(CASE WHEN je.status = 'POSTED' THEN jel.base_credit ELSE 0 END), 0) AS total_credit,
        COALESCE(SUM(CASE WHEN je.status = 'POSTED' THEN jel.foreign_debit ELSE 0 END), 0) AS total_foreign_debit,
        COALESCE(SUM(CASE WHEN je.status = 'POSTED' THEN jel.foreign_credit ELSE 0 END), 0) AS total_foreign_credit
      FROM ${DatabaseConstants.tableChartOfAccounts} coa
      LEFT JOIN ${DatabaseConstants.tableJournalEntryLines} jel 
        ON coa.id = jel.account_id AND coa.organization_id = jel.organization_id
      LEFT JOIN ${DatabaseConstants.tableJournalEntries} je 
        ON jel.journal_entry_id = je.id
      WHERE $whereSql
      GROUP BY coa.id
      ORDER BY coa.account_code ASC
    ''';

    final rows = await db.rawQuery(query, whereArgs);

    return rows.map((row) {
      final tDebit = (row['total_debit'] as num?)?.toInt() ?? 0;
      final tCredit = (row['total_credit'] as num?)?.toInt() ?? 0;
      final fDebit = (row['total_foreign_debit'] as num?)?.toInt() ?? 0;
      final fCredit = (row['total_foreign_credit'] as num?)?.toInt() ?? 0;
      final nature = row['account_nature'] as String;

      // Base balance: if DEBIT normal -> (debit - credit); if CREDIT normal -> (credit - debit)
      final baseBalance =
          nature == 'DEBIT' ? (tDebit - tCredit) : (tCredit - tDebit);
      final foreignBalance =
          nature == 'DEBIT' ? (fDebit - fCredit) : (fCredit - fDebit);

      return AccountModel.fromMap(
        row,
        baseBalance: baseBalance,
        totalDebit: tDebit,
        totalCredit: tCredit,
        foreignBalance: foreignBalance,
      );
    }).toList();
  }

  /// Builds a hierarchical tree of accounts from the flat database rows.
  Future<List<AccountModel>> getAccountsTree(
    String organizationId, {
    String? type,
  }) async {
    final flatList = await getAccountsFlat(organizationId, type: type);
    final lookup = <String, AccountModel>{};

    for (final acc in flatList) {
      lookup[acc.id] = acc;
    }

    final roots = <AccountModel>[];
    final childrenMap = <String, List<AccountModel>>{};

    for (final acc in flatList) {
      if (acc.parentId == null || !lookup.containsKey(acc.parentId)) {
        roots.add(acc);
      } else {
        childrenMap.putIfAbsent(acc.parentId!, () => []).add(acc);
      }
    }

    AccountModel buildNode(AccountModel node) {
      final directChildren = childrenMap[node.id] ?? [];
      final resolvedChildren = directChildren.map(buildNode).toList();
      return node.copyWith(children: resolvedChildren);
    }

    return roots.map(buildNode).toList();
  }

  /// Retrieves a specific account by its ID within an organization.
  Future<AccountModel?> getAccountById(
    String id,
    String organizationId,
  ) async {
    final list = await getAccountsFlat(organizationId);
    try {
      return list.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Inserts a new account into the organization's Chart of Accounts.
  Future<void> createAccount(AccountModel account) async {
    final db = await _db;

    // Validate account code uniqueness per organization
    final existing = await db.query(
      DatabaseConstants.tableChartOfAccounts,
      where: 'organization_id = ? AND account_code = ?',
      whereArgs: [account.organizationId, account.accountCode],
    );

    if (existing.isNotEmpty) {
      throw Exception(
        'رقم الحساب (${account.accountCode}) مستخدم مسبقاً في هذه المؤسسة.',
      );
    }

    await db.insert(
      DatabaseConstants.tableChartOfAccounts,
      account.toMap(),
    );
  }

  /// Updates an existing account's details.
  Future<void> updateAccount(AccountModel account) async {
    final db = await _db;

    final existing = await db.query(
      DatabaseConstants.tableChartOfAccounts,
      where: 'organization_id = ? AND account_code = ? AND id != ?',
      whereArgs: [account.organizationId, account.accountCode, account.id],
    );

    if (existing.isNotEmpty) {
      throw Exception(
        'رقم الحساب (${account.accountCode}) مستخدم مسبقاً لحساب آخر.',
      );
    }

    await db.update(
      DatabaseConstants.tableChartOfAccounts,
      account.toMap(),
      where: 'id = ? AND organization_id = ?',
      whereArgs: [account.id, account.organizationId],
    );
  }

  /// Toggles an account's active or inactive state.
  Future<void> toggleAccountActive(
    String id,
    String organizationId,
    bool isActive,
  ) async {
    final db = await _db;
    await db.update(
      DatabaseConstants.tableChartOfAccounts,
      {'is_active': isActive ? 1 : 0},
      where: 'id = ? AND organization_id = ?',
      whereArgs: [id, organizationId],
    );
  }

  /// Checks whether an account has any transactions in posted journal entries.
  Future<bool> hasPostedTransactions(
    String accountId,
    String organizationId,
  ) async {
    final db = await _db;
    final res = await db.rawQuery(
      '''
      SELECT COUNT(*) AS cnt 
      FROM ${DatabaseConstants.tableJournalEntryLines} jel
      JOIN ${DatabaseConstants.tableJournalEntries} je ON jel.journal_entry_id = je.id
      WHERE jel.account_id = ? AND jel.organization_id = ? AND je.status = 'POSTED'
    ''',
      [accountId, organizationId],
    );
    return (Sqflite.firstIntValue(res) ?? 0) > 0;
  }

  /// Fetches chronological ledger activity entries for a specific account.
  /// Balances are computed progressively based on the account's normal nature (DEBIT or CREDIT).
  Future<List<AccountLedgerEntryModel>> getAccountLedgerEntries(
    String accountId,
    String organizationId,
  ) async {
    final db = await _db;

    // Get account nature
    final accRows = await db.query(
      DatabaseConstants.tableChartOfAccounts,
      columns: ['account_nature'],
      where: 'id = ? AND organization_id = ?',
      whereArgs: [accountId, organizationId],
      limit: 1,
    );
    if (accRows.isEmpty) return [];
    final nature = accRows.first['account_nature'] as String;

    final query = '''
      SELECT 
        jel.id AS line_id,
        jel.journal_entry_id,
        je.entry_number,
        je.entry_date,
        je.entry_type,
        je.reference,
        je.narration,
        jel.description AS line_description,
        jel.party_id,
        p.name_ar AS party_name_ar,
        jel.base_debit,
        jel.base_credit,
        jel.foreign_debit,
        jel.foreign_credit,
        jel.currency_code,
        jel.exchange_rate_scaled
      FROM ${DatabaseConstants.tableJournalEntryLines} jel
      JOIN ${DatabaseConstants.tableJournalEntries} je 
        ON jel.journal_entry_id = je.id AND jel.organization_id = je.organization_id
      LEFT JOIN ${DatabaseConstants.tableParties} p 
        ON jel.party_id = p.id AND jel.organization_id = p.organization_id
      WHERE jel.account_id = ? 
        AND jel.organization_id = ? 
        AND je.status = 'POSTED'
      ORDER BY je.entry_date ASC, je.entry_number ASC, jel.line_number ASC
    ''';

    final rows = await db.rawQuery(query, [accountId, organizationId]);

    int runningBalance = 0;
    final List<AccountLedgerEntryModel> result = [];

    for (final r in rows) {
      final bDebit = (r['base_debit'] as num?)?.toInt() ?? 0;
      final bCredit = (r['base_credit'] as num?)?.toInt() ?? 0;

      if (nature == 'DEBIT') {
        runningBalance += (bDebit - bCredit);
      } else {
        runningBalance += (bCredit - bDebit);
      }

      result.add(
        AccountLedgerEntryModel(
          lineId: r['line_id'] as String,
          journalEntryId: r['journal_entry_id'] as String,
          entryNumber: r['entry_number'] as String,
          entryDate: r['entry_date'] as String,
          entryType: r['entry_type'] as String,
          reference: r['reference'] as String?,
          narration: r['narration'] as String? ?? '',
          lineDescription: r['line_description'] as String?,
          partyId: r['party_id'] as String?,
          partyNameAr: r['party_name_ar'] as String?,
          baseDebit: bDebit,
          baseCredit: bCredit,
          foreignDebit: (r['foreign_debit'] as num?)?.toInt() ?? 0,
          foreignCredit: (r['foreign_credit'] as num?)?.toInt() ?? 0,
          currencyCode: r['currency_code'] as String? ?? 'YER',
          exchangeRateScaled:
              (r['exchange_rate_scaled'] as num?)?.toInt() ?? 1000000,
          runningBalance: runningBalance,
        ),
      );
    }

    return result;
  }

  /// Deletes an account only if it has zero transactions and zero child subaccounts.
  Future<void> deleteAccount(String accountId, String organizationId) async {
    final db = await _db;

    final hasChildren = (Sqflite.firstIntValue(await db.rawQuery(
              'SELECT COUNT(*) FROM ${DatabaseConstants.tableChartOfAccounts} WHERE parent_id = ? AND organization_id = ?',
              [accountId, organizationId],
            )) ??
            0) >
        0;

    if (hasChildren) {
      throw Exception('لا يمكن حذف حساب رئيسي يحتوي على حسابات فرعية تحته.');
    }

    final hasTx = await hasPostedTransactions(accountId, organizationId);
    if (hasTx) {
      throw Exception(
        'لا يمكن حذف الحساب لوجود حركات وقيود محاسبية مسجلة عليه. يمكنك إلغاء تنشيطه بدلاً من ذلك.',
      );
    }

    await db.delete(
      DatabaseConstants.tableChartOfAccounts,
      where: 'id = ? AND organization_id = ?',
      whereArgs: [accountId, organizationId],
    );
  }

  /// Seeds a standard Arabic Chart of Accounts (COA) for a newly initialized organization.
  Future<void> seedStandardChartOfAccounts(
    String organizationId,
    String baseCurrencyCode,
  ) async {
    final db = await _db;

    final existing = await db.query(
      DatabaseConstants.tableChartOfAccounts,
      where: 'organization_id = ?',
      whereArgs: [organizationId],
      limit: 1,
    );

    if (existing.isNotEmpty) return; // Already seeded

    final now = DateTime.now().toUtc().toIso8601String();

    // Standard Arabic Chart of Accounts definition
    final templates = [
      // 1: الأصول
      {
        'id': '${organizationId}_1',
        'code': '1',
        'name': 'الأصول',
        'type': 'ASSET',
        'nature': 'DEBIT',
        'parent': null,
        'cash': 0,
        'sys': 1
      },
      {
        'id': '${organizationId}_11',
        'code': '11',
        'name': 'الأصول المتداولة',
        'type': 'ASSET',
        'nature': 'DEBIT',
        'parent': '${organizationId}_1',
        'cash': 0,
        'sys': 1
      },
      {
        'id': '${organizationId}_111',
        'code': '111',
        'name': 'النقدية وما في حكمها',
        'type': 'ASSET',
        'nature': 'DEBIT',
        'parent': '${organizationId}_11',
        'cash': 0,
        'sys': 1
      },
      {
        'id': '${organizationId}_1111',
        'code': '1111',
        'name': 'الصندوق الرئيسي',
        'type': 'ASSET',
        'nature': 'DEBIT',
        'parent': '${organizationId}_111',
        'cash': 1,
        'curr': baseCurrencyCode,
        'sys': 1
      },
      {
        'id': '${organizationId}_1112',
        'code': '1112',
        'name': 'الحساب البنكي الجاري',
        'type': 'ASSET',
        'nature': 'DEBIT',
        'parent': '${organizationId}_111',
        'cash': 1,
        'curr': baseCurrencyCode,
        'sys': 0
      },
      {
        'id': '${organizationId}_112',
        'code': '112',
        'name': 'المدينون وحسابات القبض',
        'type': 'ASSET',
        'nature': 'DEBIT',
        'parent': '${organizationId}_11',
        'cash': 0,
        'sys': 1
      },
      {
        'id': '${organizationId}_1121',
        'code': '1121',
        'name': 'حساب مراقبة العملاء (ذمم مدينة)',
        'type': 'ASSET',
        'nature': 'DEBIT',
        'parent': '${organizationId}_112',
        'cash': 0,
        'sys': 1
      },
      {
        'id': '${organizationId}_113',
        'code': '113',
        'name': 'المخزون السلعي',
        'type': 'ASSET',
        'nature': 'DEBIT',
        'parent': '${organizationId}_11',
        'cash': 0,
        'sys': 1
      },
      {
        'id': '${organizationId}_1131',
        'code': '1131',
        'name': 'بضاعة بالمستودعات',
        'type': 'ASSET',
        'nature': 'DEBIT',
        'parent': '${organizationId}_113',
        'cash': 0,
        'sys': 0
      },
      {
        'id': '${organizationId}_12',
        'code': '12',
        'name': 'الأصول الثابتة',
        'type': 'ASSET',
        'nature': 'DEBIT',
        'parent': '${organizationId}_1',
        'cash': 0,
        'sys': 1
      },
      {
        'id': '${organizationId}_121',
        'code': '121',
        'name': 'أجهزة ومعدات وأثاث',
        'type': 'ASSET',
        'nature': 'DEBIT',
        'parent': '${organizationId}_12',
        'cash': 0,
        'sys': 0
      },

      // 2: الخصوم
      {
        'id': '${organizationId}_2',
        'code': '2',
        'name': 'الخصوم (الالتزامات)',
        'type': 'LIABILITY',
        'nature': 'CREDIT',
        'parent': null,
        'cash': 0,
        'sys': 1
      },
      {
        'id': '${organizationId}_21',
        'code': '21',
        'name': 'الخصوم المتداولة',
        'type': 'LIABILITY',
        'nature': 'CREDIT',
        'parent': '${organizationId}_2',
        'cash': 0,
        'sys': 1
      },
      {
        'id': '${organizationId}_211',
        'code': '211',
        'name': 'الدائنون وحسابات الدفع',
        'type': 'LIABILITY',
        'nature': 'CREDIT',
        'parent': '${organizationId}_21',
        'cash': 0,
        'sys': 1
      },
      {
        'id': '${organizationId}_2111',
        'code': '2111',
        'name': 'حساب مراقبة الموردين (ذمم دائنة)',
        'type': 'LIABILITY',
        'nature': 'CREDIT',
        'parent': '${organizationId}_211',
        'cash': 0,
        'sys': 1
      },
      {
        'id': '${organizationId}_212',
        'code': '212',
        'name': 'مصروفات مستحقة الدفع',
        'type': 'LIABILITY',
        'nature': 'CREDIT',
        'parent': '${organizationId}_21',
        'cash': 0,
        'sys': 0
      },

      // 3: حقوق الملكية
      {
        'id': '${organizationId}_3',
        'code': '3',
        'name': 'حقوق الملكية',
        'type': 'EQUITY',
        'nature': 'CREDIT',
        'parent': null,
        'cash': 0,
        'sys': 1
      },
      {
        'id': '${organizationId}_31',
        'code': '31',
        'name': 'رأس المال المدفوع',
        'type': 'EQUITY',
        'nature': 'CREDIT',
        'parent': '${organizationId}_3',
        'cash': 0,
        'sys': 1
      },
      {
        'id': '${organizationId}_32',
        'code': '32',
        'name': 'الأرباح والخسائر المبقاة',
        'type': 'EQUITY',
        'nature': 'CREDIT',
        'parent': '${organizationId}_3',
        'cash': 0,
        'sys': 1
      },
      {
        'id': '${organizationId}_3999',
        'code': '3999',
        'name': 'حساب الأرصدة الافتتاحية',
        'type': 'EQUITY',
        'nature': 'CREDIT',
        'parent': '${organizationId}_3',
        'cash': 0,
        'sys': 1
      },

      // 4: الإيرادات
      {
        'id': '${organizationId}_4',
        'code': '4',
        'name': 'الإيرادات',
        'type': 'REVENUE',
        'nature': 'CREDIT',
        'parent': null,
        'cash': 0,
        'sys': 1
      },
      {
        'id': '${organizationId}_41',
        'code': '41',
        'name': 'إيرادات المبيعات والخدمات',
        'type': 'REVENUE',
        'nature': 'CREDIT',
        'parent': '${organizationId}_4',
        'cash': 0,
        'sys': 1
      },
      {
        'id': '${organizationId}_42',
        'code': '42',
        'name': 'أرباح فروق أسعار صرف العملات',
        'type': 'REVENUE',
        'nature': 'CREDIT',
        'parent': '${organizationId}_4',
        'cash': 0,
        'sys': 1
      },

      // 5: المصروفات
      {
        'id': '${organizationId}_5',
        'code': '5',
        'name': 'المصروفات',
        'type': 'EXPENSE',
        'nature': 'DEBIT',
        'parent': null,
        'cash': 0,
        'sys': 1
      },
      {
        'id': '${organizationId}_51',
        'code': '51',
        'name': 'تكلفة البضاعة المباعة',
        'type': 'EXPENSE',
        'nature': 'DEBIT',
        'parent': '${organizationId}_5',
        'cash': 0,
        'sys': 1
      },
      {
        'id': '${organizationId}_52',
        'code': '52',
        'name': 'المصروفات التشغيلية والإدارية',
        'type': 'EXPENSE',
        'nature': 'DEBIT',
        'parent': '${organizationId}_5',
        'cash': 0,
        'sys': 1
      },
      {
        'id': '${organizationId}_521',
        'code': '521',
        'name': 'إيجار المقرات والمستودعات',
        'type': 'EXPENSE',
        'nature': 'DEBIT',
        'parent': '${organizationId}_52',
        'cash': 0,
        'sys': 0
      },
      {
        'id': '${organizationId}_522',
        'code': '522',
        'name': 'رواتب وأجور ومكافآت',
        'type': 'EXPENSE',
        'nature': 'DEBIT',
        'parent': '${organizationId}_52',
        'cash': 0,
        'sys': 0
      },
      {
        'id': '${organizationId}_5202',
        'code': '5202',
        'name': 'فروقات وتلفيات الجرد المخزني',
        'type': 'EXPENSE',
        'nature': 'DEBIT',
        'parent': '${organizationId}_52',
        'cash': 0,
        'sys': 0
      },
      {
        'id': '${organizationId}_53',
        'code': '53',
        'name': 'خسائر فروق أسعار صرف العملات',
        'type': 'EXPENSE',
        'nature': 'DEBIT',
        'parent': '${organizationId}_5',
        'cash': 0,
        'sys': 1
      },
    ];

    final batch = db.batch();
    for (final t in templates) {
      batch.insert(DatabaseConstants.tableChartOfAccounts, {
        'id': t['id'],
        'organization_id': organizationId,
        'account_code': t['code'],
        'account_name_ar': t['name'],
        'account_name_en': null,
        'account_type': t['type'],
        'account_nature': t['nature'],
        'parent_id': t['parent'],
        'currency_code': t['curr'],
        'is_cash_bank': t['cash'],
        'is_reconcilable': 0,
        'is_active': 1,
        'is_system': t['sys'],
        'created_at': now,
      });
    }
    await batch.commit(noResult: true);
  }

  /// Fetches all active, postable leaf cash and bank accounts for money transfers and settlements.
  Future<List<AccountModel>> getCashBankAccounts(String organizationId) async {
    final all = await getAccountsFlat(organizationId);
    final parentIds = all.map((a) => a.parentId).whereType<String>().toSet();
    return all.where((a) {
      if (!a.isActive || parentIds.contains(a.id)) return false;
      return a.isCashBank ||
          a.accountCode.startsWith('111') ||
          a.accountCode.startsWith('1101') ||
          a.accountCode.startsWith('1102') ||
          a.accountNameAr.contains('صندوق') ||
          a.accountNameAr.contains('بنك') ||
          a.accountNameAr.contains('نقد');
    }).toList();
  }
}
