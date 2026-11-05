import 'package:sqflite/sqflite.dart';
import '../../../core/constants/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../models/journal_entry_line_model.dart';
import '../models/journal_entry_model.dart';

/// Repository managing General Ledger Journal Entries and strict double-entry integrity.
class JournalRepository {
  final DatabaseHelper _dbHelper;

  JournalRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db async => await _dbHelper.database;

  /// Ensures a valid open fiscal period exists for the given organization and date.
  Future<String> ensureFiscalPeriod(String organizationId, String date) async {
    final db = await _db;
    final dateStr = date.split('T').first;

    // Check if period exists for this date
    final existing = await db.rawQuery('''
      SELECT id FROM ${DatabaseConstants.tableFiscalPeriods}
      WHERE organization_id = ? AND start_date <= ? AND end_date >= ? AND is_closed = 0
      LIMIT 1
    ''', [organizationId, dateStr, dateStr]);

    if (existing.isNotEmpty) {
      return existing.first['id'] as String;
    }

    // Auto-create Fiscal Year and 12 monthly periods if missing
    final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();
    final year = parsedDate.year;
    final yearName = 'السنة المالية $year';

    // Find or create fiscal year
    final fyResults = await db.query(
      DatabaseConstants.tableFiscalYears,
      where: 'organization_id = ? AND name = ?',
      whereArgs: [organizationId, yearName],
      limit: 1,
    );

    String fiscalYearId;
    if (fyResults.isNotEmpty) {
      fiscalYearId = fyResults.first['id'] as String;
    } else {
      fiscalYearId = 'fy_${organizationId}_$year';
      await db.insert(
        DatabaseConstants.tableFiscalYears,
        {
          'id': fiscalYearId,
          'organization_id': organizationId,
          'name': yearName,
          'start_date': '$year-01-01',
          'end_date': '$year-12-31',
          'is_closed': 0,
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // Create 12 monthly periods
    String targetPeriodId = '';
    for (int m = 1; m <= 12; m++) {
      final periodId = 'fp_${organizationId}_${year}_$m';
      final mStr = m.toString().padLeft(2, '0');
      final lastDay = DateTime(year, m + 1, 0).day;
      final startDate = '$year-$mStr-01';
      final endDate = '$year-$mStr-$lastDay';

      await db.insert(
        DatabaseConstants.tableFiscalPeriods,
        {
          'id': periodId,
          'organization_id': organizationId,
          'fiscal_year_id': fiscalYearId,
          'period_number': m,
          'name': 'فترة $mStr/$year',
          'start_date': startDate,
          'end_date': endDate,
          'is_locked': 0,
          'is_closed': 0,
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      if (parsedDate.month == m) {
        targetPeriodId = periodId;
      }
    }

    return targetPeriodId;
  }

  /// Generates the next sequential entry number.
  Future<String> getNextEntryNumber(
      String organizationId, String entryType) async {
    final db = await _db;
    final year = DateTime.now().year;
    String prefix = 'JV';
    if (entryType == 'OPENING') prefix = 'OP';
    if (entryType == 'SALES') prefix = 'SL';
    if (entryType == 'PURCHASE') prefix = 'PR';
    if (entryType == 'RECEIPT') prefix = 'RC';
    if (entryType == 'PAYMENT') prefix = 'PY';

    final results = await db.rawQuery('''
      SELECT entry_number FROM ${DatabaseConstants.tableJournalEntries}
      WHERE organization_id = ? AND entry_number LIKE '$prefix-$year-%'
      ORDER BY entry_number DESC
      LIMIT 1
    ''', [organizationId]);

    if (results.isEmpty) {
      return '$prefix-$year-0001';
    }

    final last = results.first['entry_number'] as String;
    final parts = last.split('-');
    if (parts.length >= 3) {
      final numVal = int.tryParse(parts.last);
      if (numVal != null) {
        return '$prefix-$year-${(numVal + 1).toString().padLeft(4, '0')}';
      }
    }

    return '$prefix-$year-${DateTime.now().millisecondsSinceEpoch % 10000}';
  }

  /// Fetches journal entries for an organization with optional filtering.
  Future<List<JournalEntryModel>> getJournalEntries({
    required String organizationId,
    String? status,
    String? entryType,
    String? query,
    int limit = 50,
  }) async {
    final db = await _db;
    final List<dynamic> args = [organizationId];
    String whereClause = 'organization_id = ?';

    if (status != null && status != 'ALL') {
      whereClause += ' AND status = ?';
      args.add(status);
    }

    if (entryType != null && entryType != 'ALL') {
      whereClause += ' AND entry_type = ?';
      args.add(entryType);
    }

    if (query != null && query.trim().isNotEmpty) {
      whereClause +=
          ' AND (entry_number LIKE ? OR narration LIKE ? OR reference LIKE ?)';
      final q = '%${query.trim()}%';
      args.addAll([q, q, q]);
    }

    final results = await db.query(
      DatabaseConstants.tableJournalEntries,
      where: whereClause,
      whereArgs: args,
      orderBy: 'entry_date DESC, entry_number DESC',
      limit: limit,
    );

    return results.map((map) => JournalEntryModel.fromMap(map)).toList();
  }

  /// Fetches a single journal entry by ID including all lines with joined account and party names.
  Future<JournalEntryModel?> getJournalEntryById(
      String id, String organizationId) async {
    final db = await _db;

    final headerResults = await db.query(
      DatabaseConstants.tableJournalEntries,
      where: 'id = ? AND organization_id = ?',
      whereArgs: [id, organizationId],
      limit: 1,
    );

    if (headerResults.isEmpty) return null;

    final linesResults = await db.rawQuery('''
      SELECT 
        jel.*,
        coa.account_code,
        coa.account_name_ar,
        p.name_ar AS party_name_ar
      FROM ${DatabaseConstants.tableJournalEntryLines} jel
      INNER JOIN ${DatabaseConstants.tableChartOfAccounts} coa 
        ON coa.id = jel.account_id AND coa.organization_id = jel.organization_id
      LEFT JOIN ${DatabaseConstants.tableParties} p 
        ON p.id = jel.party_id AND p.organization_id = jel.organization_id
      WHERE jel.journal_entry_id = ? AND jel.organization_id = ?
      ORDER BY jel.line_number ASC
    ''', [id, organizationId]);

    final lines =
        linesResults.map((m) => JournalEntryLineModel.fromMap(m)).toList();
    return JournalEntryModel.fromMap(headerResults.first, lines: lines);
  }

  /// Validates that a fiscal period exists and is open for posting.
  Future<void> validateFiscalPeriodOpen(
      String periodId, String organizationId) async {
    final db = await _db;
    final results = await db.query(
      DatabaseConstants.tableFiscalPeriods,
      columns: ['is_closed', 'is_locked'],
      where: 'id = ? AND organization_id = ?',
      whereArgs: [periodId, organizationId],
      limit: 1,
    );

    if (results.isEmpty) {
      throw Exception('الفترة المالية المحددة غير موجودة في النظام.');
    }

    final isClosed = (results.first['is_closed'] as num?)?.toInt() == 1;
    final isLocked = (results.first['is_locked'] as num?)?.toInt() == 1;

    if (isClosed) {
      throw Exception('لا يمكن الترحيل: الفترة المالية مغلقة محاسبياً.');
    }
    if (isLocked) {
      throw Exception(
          'لا يمكن الترحيل: الفترة المالية مقفلة ومحمية ضد التعديل.');
    }
  }

  /// Validates that accounts are active and postable (not parent summary accounts).
  Future<void> validateAccountsPostable(
      List<String> accountIds, String organizationId) async {
    final db = await _db;
    for (final accId in accountIds) {
      final acc = await db.query(
        DatabaseConstants.tableChartOfAccounts,
        columns: ['account_code', 'account_name_ar', 'is_active'],
        where: 'id = ? AND organization_id = ?',
        whereArgs: [accId, organizationId],
        limit: 1,
      );

      if (acc.isEmpty) {
        throw Exception(
            'الحساب ($accId) غير موجود في دليل حسابات هذه المؤسسة.');
      }

      final isActive = (acc.first['is_active'] as num?)?.toInt() == 1;
      if (!isActive) {
        throw Exception(
          'لا يمكن الترحيل للحساب "${acc.first['account_name_ar']}" (${acc.first['account_code']}) لأنه معطل.',
        );
      }

      final childCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM ${DatabaseConstants.tableChartOfAccounts} WHERE parent_id = ? AND organization_id = ?',
            [accId, organizationId],
          )) ??
          0;

      if (childCount > 0) {
        throw Exception(
          'لا يمكن الترحيل للحساب الرئيسي "${acc.first['account_name_ar']}" (${acc.first['account_code']})؛ يجب اختيار حساب فرعي قابل للترحيل.',
        );
      }
    }
  }

  /// Saves a journal entry and its lines in a single atomic transaction.
  Future<void> saveEntry({
    required JournalEntryModel entry,
    required List<JournalEntryLineModel> lines,
    bool autoPost = false,
  }) async {
    final db = await _db;

    // Check if updating an already POSTED entry
    final existingHeader = await db.query(
      DatabaseConstants.tableJournalEntries,
      columns: ['status'],
      where: 'id = ? AND organization_id = ?',
      whereArgs: [entry.id, entry.organizationId],
      limit: 1,
    );
    if (existingHeader.isNotEmpty &&
        existingHeader.first['status'] == 'POSTED') {
      throw Exception(
        'لا يمكن تعديل قيد مرحل! القيود المرحلة غير قابلة للتعديل للحفاظ على سلامة الدفاتر.',
      );
    }

    // Calculate totals
    int totalBaseDebit = 0;
    int totalBaseCredit = 0;
    for (final l in lines) {
      if (l.baseDebit == 0 && l.baseCredit == 0) {
        throw Exception(
          'السطر رقم ${l.lineNumber} يحتوي على مبالغ صفرية؛ لا يمكن حفظ سطر دون مبلغ.',
        );
      }
      if (l.baseDebit > 0 && l.baseCredit > 0) {
        throw Exception(
          'السطر رقم ${l.lineNumber} يحتوي على مدين ودائن معاً، وهذا غير مسموح به محاسبياً.',
        );
      }
      totalBaseDebit += l.baseDebit;
      totalBaseCredit += l.baseCredit;
    }

    if (autoPost) {
      if (lines.length < 2) {
        throw Exception('الترحيل يتطلب سطرين على الأقل في القيد المحاسبي.');
      }
      if (totalBaseDebit != totalBaseCredit) {
        throw Exception(
          'القيد غير متزن! إجمالي المدين (${(totalBaseDebit / 100.0).toStringAsFixed(2)}) لا يساوي إجمالي الدائن (${(totalBaseCredit / 100.0).toStringAsFixed(2)}).',
        );
      }
      if (totalBaseDebit <= 0) {
        throw Exception('المبلغ الإجمالي للقيد يجب أن يكون أكبر من الصفر.');
      }

      // Validate fiscal period is open
      await validateFiscalPeriodOpen(
        entry.fiscalPeriodId,
        entry.organizationId,
      );

      // Validate accounts are postable and active
      await validateAccountsPostable(
        lines.map((l) => l.accountId).toSet().toList(),
        entry.organizationId,
      );
    }

    final now = DateTime.now().toIso8601String();
    final status = autoPost ? 'POSTED' : entry.status;
    final postedAt = autoPost ? now : entry.postedAt;

    await db.transaction((txn) async {
      // 1. Insert or update header
      final headerMap = entry
          .copyWith(
            status: status,
            totalBaseDebit: totalBaseDebit,
            totalBaseCredit: totalBaseCredit,
            postedAt: postedAt,
            updatedAt: now,
          )
          .toMap();

      if (headerMap['created_at'] == null ||
          (headerMap['created_at'] as String).isEmpty) {
        headerMap['created_at'] = now;
      }

      await txn.insert(
        DatabaseConstants.tableJournalEntries,
        headerMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Delete existing lines if updating
      await txn.delete(
        DatabaseConstants.tableJournalEntryLines,
        where: 'journal_entry_id = ? AND organization_id = ?',
        whereArgs: [entry.id, entry.organizationId],
      );

      // 3. Insert new lines
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final lineMap = line
            .copyWith(
              lineNumber: i + 1,
              createdAt: now,
            )
            .toMap();

        await txn.insert(
          DatabaseConstants.tableJournalEntryLines,
          lineMap,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }

      // 4. Audit log
      await txn.insert(
        DatabaseConstants.tableAuditLogs,
        {
          'organization_id': entry.organizationId,
          'table_name': DatabaseConstants.tableJournalEntries,
          'record_id': entry.id,
          'action': autoPost ? 'POST' : 'INSERT',
          'new_values':
              'Entry ${entry.entryNumber}: $totalBaseDebit minor units',
          'created_at': now,
        },
      );
    });
  }

  /// Posts an existing DRAFT journal entry atomically.
  Future<void> postJournalEntry(String id, String organizationId) async {
    final entry = await getJournalEntryById(id, organizationId);
    if (entry == null) {
      throw Exception('القيد المحاسبي غير موجود.');
    }
    if (entry.isPosted) {
      throw Exception('القيد مرحّل مسبقاً ولا يمكن ترحيله مرة أخرى.');
    }
    if (entry.lines.length < 2) {
      throw Exception('الترحيل يتطلب سطرين على الأقل في القيد المحاسبي.');
    }
    if (!entry.isBalanced) {
      throw Exception(
        'لا يمكن ترحيل القيد لعدم التوازن: المدين (${entry.totalBaseDebitDouble.toStringAsFixed(2)}) والدائن (${entry.totalBaseCreditDouble.toStringAsFixed(2)}).',
      );
    }

    // Validate period is open
    await validateFiscalPeriodOpen(entry.fiscalPeriodId, organizationId);

    // Validate all accounts are active and postable
    await validateAccountsPostable(
      entry.lines.map((l) => l.accountId).toSet().toList(),
      organizationId,
    );

    final db = await _db;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.update(
        DatabaseConstants.tableJournalEntries,
        {
          'status': 'POSTED',
          'posted_at': now,
          'updated_at': now,
        },
        where: 'id = ? AND organization_id = ?',
        whereArgs: [id, organizationId],
      );

      await txn.insert(
        DatabaseConstants.tableAuditLogs,
        {
          'organization_id': organizationId,
          'table_name': DatabaseConstants.tableJournalEntries,
          'record_id': id,
          'action': 'POST',
          'new_values': 'Posted entry ${entry.entryNumber}',
          'created_at': now,
        },
      );
    });
  }

  /// Reverses and voids a posted journal entry to maintain immutable audit trail.
  Future<String> reverseJournalEntry({
    required String id,
    required String organizationId,
    required String reason,
  }) async {
    final entry = await getJournalEntryById(id, organizationId);
    if (entry == null) throw Exception('القيد المحاسبي غير موجود.');
    if (!entry.isPosted) throw Exception('يمكن فقط عكس القيود المرحلة.');

    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final revId = 'rev_${DateTime.now().millisecondsSinceEpoch}';
    final revNumber = 'REV-${entry.entryNumber}';

    await db.transaction((txn) async {
      // 1. Mark original entry as VOIDED
      await txn.update(
        DatabaseConstants.tableJournalEntries,
        {
          'status': 'VOIDED',
          'updated_at': now,
        },
        where: 'id = ? AND organization_id = ?',
        whereArgs: [id, organizationId],
      );

      // 2. Create reversal header
      await txn.insert(
        DatabaseConstants.tableJournalEntries,
        {
          'id': revId,
          'organization_id': organizationId,
          'entry_number': revNumber,
          'fiscal_period_id': entry.fiscalPeriodId,
          'entry_date': DateTime.now().toIso8601String().split('T').first,
          'entry_type': entry.entryType,
          'status': 'POSTED',
          'reference': entry.entryNumber,
          'narration': 'قيد عكسي للقيد رقم ${entry.entryNumber}: $reason',
          'total_base_debit': entry.totalBaseCredit,
          'total_base_credit': entry.totalBaseDebit,
          'posted_at': now,
          'created_at': now,
          'updated_at': now,
        },
      );

      // 3. Create swapped lines (swap debit and credit)
      for (int i = 0; i < entry.lines.length; i++) {
        final line = entry.lines[i];
        await txn.insert(
          DatabaseConstants.tableJournalEntryLines,
          {
            'id': 'line_${revId}_${i + 1}',
            'organization_id': organizationId,
            'journal_entry_id': revId,
            'line_number': i + 1,
            'account_id': line.accountId,
            'party_id': line.partyId,
            'description': 'عكس: ${line.description ?? ''}',
            'currency_code': line.currencyCode,
            'exchange_rate_scaled': line.exchangeRateScaled,
            'foreign_debit': line.foreignCredit,
            'foreign_credit': line.foreignDebit,
            'base_debit': line.baseCredit,
            'base_credit': line.baseDebit,
            'created_at': now,
          },
        );
      }

      // 4. Audit log
      await txn.insert(
        DatabaseConstants.tableAuditLogs,
        {
          'organization_id': organizationId,
          'table_name': DatabaseConstants.tableJournalEntries,
          'record_id': id,
          'action': 'VOID',
          'new_values': 'Voided by reversal entry $revNumber. Reason: $reason',
          'created_at': now,
        },
      );
    });

    return revNumber;
  }

  /// Deletes a DRAFT journal entry. Throws if posted or voided.
  Future<void> deleteDraftEntry(String id, String organizationId) async {
    final entry = await getJournalEntryById(id, organizationId);
    if (entry == null) return;
    if (entry.isPosted) {
      throw Exception(
          'لا يمكن حذف قيد مرحّل! يجب إجراء قيد عكسي للحفاظ على التسلسل المحاسبي.');
    }

    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        DatabaseConstants.tableJournalEntryLines,
        where: 'journal_entry_id = ? AND organization_id = ?',
        whereArgs: [id, organizationId],
      );
      await txn.delete(
        DatabaseConstants.tableJournalEntries,
        where: 'id = ? AND organization_id = ?',
        whereArgs: [id, organizationId],
      );
    });
  }
}
