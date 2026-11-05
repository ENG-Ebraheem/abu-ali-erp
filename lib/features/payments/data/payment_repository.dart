import 'package:sqflite/sqflite.dart';
import '../../../core/constants/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/models/account_model.dart';
import '../../journal/data/journal_repository.dart';
import '../../journal/models/journal_entry_line_model.dart';
import '../../journal/models/journal_entry_model.dart';
import '../models/payment_allocation_model.dart';
import '../models/payment_model.dart';

/// Repository managing Payment vouchers (Receipts & Disbursements), Invoice Allocations,
/// Realized Foreign Exchange differences, and General Ledger integration.
class PaymentRepository {
  final DatabaseHelper _dbHelper;
  final JournalRepository _journalRepo;
  final AccountRepository _accountRepo;

  PaymentRepository({
    DatabaseHelper? dbHelper,
    JournalRepository? journalRepo,
    AccountRepository? accountRepo,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _journalRepo = journalRepo ?? JournalRepository(),
        _accountRepo = accountRepo ?? AccountRepository();

  Future<Database> get _db async => await _dbHelper.database;

  /// Generates the next sequential payment voucher number.
  Future<String> getNextPaymentNumber(
      String organizationId, String paymentType) async {
    final db = await _db;
    final year = DateTime.now().year;
    final prefix = paymentType == 'RECEIPT' ? 'RC' : 'PY';

    final results = await db.rawQuery('''
      SELECT payment_number FROM ${DatabaseConstants.tablePayments}
      WHERE organization_id = ? AND payment_number LIKE '$prefix-$year-%'
      ORDER BY payment_number DESC
      LIMIT 1
    ''', [organizationId]);

    if (results.isEmpty) {
      return '$prefix-$year-0001';
    }

    final last = results.first['payment_number'] as String;
    final parts = last.split('-');
    if (parts.length >= 3) {
      final numVal = int.tryParse(parts.last);
      if (numVal != null) {
        return '$prefix-$year-${(numVal + 1).toString().padLeft(4, '0')}';
      }
    }

    return '$prefix-$year-${DateTime.now().millisecondsSinceEpoch % 10000}';
  }

  /// Fetches unpaid or partially paid invoices for a given party to allocate against.
  Future<List<Map<String, dynamic>>> getUnpaidInvoicesForParty({
    required String organizationId,
    required String partyId,
    required String paymentType, // 'RECEIPT' or 'PAYMENT'
  }) async {
    final db = await _db;
    final typeFilter = paymentType == 'RECEIPT'
        ? "('SALES', 'OPENING_RECEIVABLE')"
        : "('PURCHASE', 'OPENING_PAYABLE')";

    final sql = '''
      SELECT 
        id,
        invoice_number,
        invoice_type,
        issue_date,
        due_date,
        currency_code,
        exchange_rate_scaled,
        total_amount,
        paid_amount,
        (total_amount - paid_amount) AS remaining_amount
      FROM ${DatabaseConstants.tableInvoices}
      WHERE organization_id = ? 
        AND party_id = ?
        AND invoice_type IN $typeFilter
        AND status = 'POSTED'
        AND payment_status != 'PAID'
      ORDER BY issue_date ASC
    ''';

    return await db.rawQuery(sql, [organizationId, partyId]);
  }

  /// Fetches payments list with party and cash account names.
  Future<List<PaymentModel>> getPayments({
    required String organizationId,
    String? paymentType, // 'RECEIPT', 'PAYMENT', or 'ALL'
    String? status,
    String? query,
    int limit = 50,
  }) async {
    final db = await _db;
    final args = <dynamic>[organizationId];
    String whereClause = 'pay.organization_id = ?';

    if (paymentType != null && paymentType != 'ALL') {
      whereClause += ' AND pay.payment_type = ?';
      args.add(paymentType);
    }

    if (status != null && status != 'ALL') {
      whereClause += ' AND pay.status = ?';
      args.add(status);
    }

    if (query != null && query.trim().isNotEmpty) {
      whereClause +=
          ' AND (pay.payment_number LIKE ? OR p.name_ar LIKE ? OR pay.notes LIKE ?)';
      final q = '%${query.trim()}%';
      args.addAll([q, q, q]);
    }

    final sql = '''
      SELECT 
        pay.*,
        p.name_ar AS party_name_ar,
        p.code AS party_code,
        coa.account_name_ar AS cash_bank_account_name_ar
      FROM ${DatabaseConstants.tablePayments} pay
      INNER JOIN ${DatabaseConstants.tableParties} p 
        ON p.id = pay.party_id AND p.organization_id = pay.organization_id
      INNER JOIN ${DatabaseConstants.tableChartOfAccounts} coa 
        ON coa.id = pay.cash_bank_account_id AND coa.organization_id = pay.organization_id
      WHERE $whereClause
      ORDER BY pay.payment_date DESC, pay.payment_number DESC
      LIMIT $limit
    ''';

    final results = await db.rawQuery(sql, args);
    return results.map((map) => PaymentModel.fromMap(map)).toList();
  }

  /// Fetches a single payment by ID with allocations.
  Future<PaymentModel?> getPaymentById(String id, String organizationId) async {
    final db = await _db;

    final headerResults = await db.rawQuery('''
      SELECT 
        pay.*,
        p.name_ar AS party_name_ar,
        p.code AS party_code,
        coa.account_name_ar AS cash_bank_account_name_ar
      FROM ${DatabaseConstants.tablePayments} pay
      INNER JOIN ${DatabaseConstants.tableParties} p 
        ON p.id = pay.party_id AND p.organization_id = pay.organization_id
      INNER JOIN ${DatabaseConstants.tableChartOfAccounts} coa 
        ON coa.id = pay.cash_bank_account_id AND coa.organization_id = pay.organization_id
      WHERE pay.id = ? AND pay.organization_id = ?
      LIMIT 1
    ''', [id, organizationId]);

    if (headerResults.isEmpty) return null;

    final allocResults = await db.rawQuery('''
      SELECT 
        pa.*,
        inv.invoice_number,
        inv.invoice_type
      FROM ${DatabaseConstants.tablePaymentAllocations} pa
      INNER JOIN ${DatabaseConstants.tableInvoices} inv 
        ON inv.id = pa.invoice_id AND inv.organization_id = pa.organization_id
      WHERE pa.payment_id = ? AND pa.organization_id = ?
      ORDER BY pa.allocation_date ASC
    ''', [id, organizationId]);

    final allocations =
        allocResults.map((m) => PaymentAllocationModel.fromMap(m)).toList();
    return PaymentModel.fromMap(headerResults.first, allocations: allocations);
  }

  /// Helper to safely resolve a postable leaf account.
  String _resolveLeafAccount({
    required List<AccountModel> accounts,
    required List<String> preferredCodes,
    required String requiredType,
    required String requiredNature,
    String? keyword,
    required String errorName,
  }) {
    final parentIds =
        accounts.map((a) => a.parentId).whereType<String>().toSet();
    final postableLeaves =
        accounts.where((a) => a.isActive && !parentIds.contains(a.id)).toList();

    // 1. By exact preferred code among leaves
    for (final code in preferredCodes) {
      final match =
          postableLeaves.where((a) => a.accountCode == code).firstOrNull;
      if (match != null) return match.id;
    }

    // 2. By keyword in Arabic name among leaves of matching type
    if (keyword != null && keyword.isNotEmpty) {
      final match = postableLeaves
          .where((a) =>
              a.accountType == requiredType &&
              a.accountNameAr.contains(keyword))
          .firstOrNull;
      if (match != null) return match.id;
    }

    // 3. Any leaf of matching type and nature
    final match = postableLeaves
        .where((a) =>
            a.accountType == requiredType && a.accountNature == requiredNature)
        .firstOrNull;
    if (match != null) return match.id;

    // 4. Any leaf of matching type
    final matchTypeOnly =
        postableLeaves.where((a) => a.accountType == requiredType).firstOrNull;
    if (matchTypeOnly != null) return matchTypeOnly.id;

    throw Exception(
        'لم يتم العثور على حساب مناسب لـ "$errorName" في شجرة الحسابات.');
  }

  /// Saves a payment and its invoice allocations with multi-tenant and cross-party validation.
  Future<void> savePayment({
    required PaymentModel payment,
    required List<PaymentAllocationModel> allocations,
    bool autoPost = false,
  }) async {
    final db = await _db;

    // 1. Check if modifying an already posted payment
    final existingHeader = await db.query(
      DatabaseConstants.tablePayments,
      columns: ['status'],
      where: 'id = ? AND organization_id = ?',
      whereArgs: [payment.id, payment.organizationId],
      limit: 1,
    );
    if (existingHeader.isNotEmpty &&
        existingHeader.first['status'] == 'POSTED') {
      throw Exception(
        'لا يمكن تعديل سند دفع مرحّل! السندات المرحلة محمية للحفاظ على دقة القيود المحاسبية.',
      );
    }

    // 2. Multi-tenant and Party Isolation Validation
    int totalAllocated = 0;
    for (final a in allocations) {
      if (a.allocatedAmount <= 0) {
        throw Exception('مبلغ التخصيص لكل فاتورة يجب أن يكون أكبر من الصفر.');
      }
      totalAllocated += a.allocatedAmount;

      // Validate the invoice exists, belongs to the SAME organization and party
      final invRow = await db.query(
        DatabaseConstants.tableInvoices,
        columns: [
          'id',
          'organization_id',
          'party_id',
          'status',
          'total_amount',
          'paid_amount'
        ],
        where: 'id = ? AND organization_id = ?',
        whereArgs: [a.invoiceId, payment.organizationId],
        limit: 1,
      );

      if (invRow.isEmpty) {
        throw Exception(
          'الفاتورة المراد تخصيص السند لها (${a.invoiceId}) غير موجودة ضمن هذه المؤسسة.',
        );
      }

      final inv = invRow.first;
      if (inv['party_id'] != payment.partyId) {
        throw Exception(
          'لا يمكن تخصيص سند دفع لفاتورة تخص طرفاً آخر! التخصيص مسموح فقط لنفس العميل أو المورد.',
        );
      }

      if (inv['status'] != 'POSTED') {
        throw Exception('لا يمكن تخصيص سند دفع لفاتورة مسودة أو ملغية.');
      }

      final total = (inv['total_amount'] as num).toInt();
      final paid = (inv['paid_amount'] as num).toInt();
      final remaining = total - paid;

      if (a.allocatedAmount > remaining) {
        throw Exception(
          'المبلغ المخصص (${(a.allocatedAmount / 100.0).toStringAsFixed(2)}) يتجاوز المتبقي للسداد في الفاتورة (${(remaining / 100.0).toStringAsFixed(2)}).',
        );
      }
    }

    // 3. Validate total allocated does not exceed payment amount
    if (totalAllocated > payment.amount) {
      throw Exception(
        'إجمالي المبالغ المخصصة (${(totalAllocated / 100.0).toStringAsFixed(2)}) يتجاوز إجمالي مبلغ السند (${(payment.amount / 100.0).toStringAsFixed(2)}).',
      );
    }

    final unallocated = payment.amount - totalAllocated;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // 1. Insert or update payment header
      final headerMap = payment
          .copyWith(
            allocatedAmount: totalAllocated,
            unallocatedAmount: unallocated,
            updatedAt: now,
          )
          .toMap();

      if (headerMap['created_at'] == null ||
          (headerMap['created_at'] as String).isEmpty) {
        headerMap['created_at'] = now;
      }

      await txn.insert(
        DatabaseConstants.tablePayments,
        headerMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Delete existing allocations
      await txn.delete(
        DatabaseConstants.tablePaymentAllocations,
        where: 'payment_id = ? AND organization_id = ?',
        whereArgs: [payment.id, payment.organizationId],
      );

      // 3. Insert allocations
      for (final a in allocations) {
        final allocMap = a.toMap();
        allocMap['created_at'] = now;
        await txn.insert(
          DatabaseConstants.tablePaymentAllocations,
          allocMap,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });

    if (autoPost) {
      await postPayment(payment.id, payment.organizationId);
    }
  }

  /// Posts a payment, computes Realized Foreign Exchange differences, generates balanced GL entry,
  /// and updates invoice paid amounts and settlement statuses atomically.
  Future<void> postPayment(String id, String organizationId) async {
    final pay = await getPaymentById(id, organizationId);
    if (pay == null) throw Exception('سند الدفع غير موجود.');
    if (pay.isPosted) throw Exception('السند مرحّل مسبقاً.');
    if (pay.amount <= 0) {
      throw Exception('مبلغ السند يجب أن يكون أكبر من الصفر للترحيل.');
    }

    // Ensure Accounts
    final accounts = await _accountRepo.getAccountsFlat(organizationId);

    // Resolve Control Accounts
    final arAccountId = _resolveLeafAccount(
      accounts: accounts,
      preferredCodes: ['1121', '1103'],
      requiredType: 'ASSET',
      requiredNature: 'DEBIT',
      keyword: 'عملاء',
      errorName: 'مراقبة العملاء (الذمم المدينة)',
    );

    final apAccountId = _resolveLeafAccount(
      accounts: accounts,
      preferredCodes: ['2111', '2101'],
      requiredType: 'LIABILITY',
      requiredNature: 'CREDIT',
      keyword: 'مورد',
      errorName: 'مراقبة الموردين (الذمم الدائنة)',
    );

    final fxGainAccountId = _resolveLeafAccount(
      accounts: accounts,
      preferredCodes: ['4201', '42'],
      requiredType: 'REVENUE',
      requiredNature: 'CREDIT',
      keyword: 'صرف',
      errorName: 'أرباح فروق أسعار صرف العملات',
    );

    final fxLossAccountId = _resolveLeafAccount(
      accounts: accounts,
      preferredCodes: ['5301', '53'],
      requiredType: 'EXPENSE',
      requiredNature: 'DEBIT',
      keyword: 'صرف',
      errorName: 'خسائر فروق أسعار صرف العملات',
    );

    // Ensure Fiscal Period
    final periodId =
        await _journalRepo.ensureFiscalPeriod(organizationId, pay.paymentDate);
    final entryType = pay.isReceipt ? 'RECEIPT' : 'PAYMENT';
    final entryNumber =
        await _journalRepo.getNextEntryNumber(organizationId, entryType);
    final entryId = 'je_pay_${pay.id}';

    final int payFx = pay.exchangeRateScaled;
    final int baseCashAmount = payFx == DatabaseConstants.exchangeRateScale
        ? pay.amount
        : ((pay.amount * payFx) / DatabaseConstants.exchangeRateScale).round();

    final db = await _db;

    // Calculate Realized Forex Differences for each allocation
    int totalGain = 0;
    int totalLoss = 0;
    final List<Map<String, dynamic>> allocationCalculations = [];

    for (final alloc in pay.allocations) {
      final invRow = await db.query(
        DatabaseConstants.tableInvoices,
        columns: ['exchange_rate_scaled', 'currency_code', 'invoice_number'],
        where: 'id = ? AND organization_id = ?',
        whereArgs: [alloc.invoiceId, organizationId],
        limit: 1,
      );

      final int invFx = invRow.isNotEmpty
          ? (invRow.first['exchange_rate_scaled'] as num).toInt()
          : payFx;
      final String invNumber = invRow.isNotEmpty
          ? invRow.first['invoice_number'] as String
          : alloc.invoiceId;

      final int allocForeign = alloc.allocatedAmount;
      final int baseInvoice = invFx == DatabaseConstants.exchangeRateScale
          ? allocForeign
          : ((allocForeign * invFx) / DatabaseConstants.exchangeRateScale)
              .round();
      final int basePayment = payFx == DatabaseConstants.exchangeRateScale
          ? allocForeign
          : ((allocForeign * payFx) / DatabaseConstants.exchangeRateScale)
              .round();

      // Realized Exchange Difference:
      // Receipt (Customer):
      // diff = basePayment - baseInvoice
      // If diff > 0 -> Gain (we collected more base currency)
      // If diff < 0 -> Loss (we collected less base currency)
      // Payment (Supplier):
      // diff = baseInvoice - basePayment
      // If diff > 0 -> Gain (we settled the liability with less base currency)
      // If diff < 0 -> Loss (we settled the liability with more base currency)
      int gainForAlloc = 0;
      int lossForAlloc = 0;

      if (pay.isReceipt) {
        final diff = basePayment - baseInvoice;
        if (diff > 0) gainForAlloc = diff;
        if (diff < 0) lossForAlloc = -diff;
      } else {
        final diff = baseInvoice - basePayment;
        if (diff > 0) gainForAlloc = diff;
        if (diff < 0) lossForAlloc = -diff;
      }

      totalGain += gainForAlloc;
      totalLoss += lossForAlloc;

      allocationCalculations.add({
        'allocation': alloc,
        'invoiceNumber': invNumber,
        'allocForeign': allocForeign,
        'baseInvoice': baseInvoice,
        'basePayment': basePayment,
        'realizedForex': gainForAlloc > 0 ? gainForAlloc : -lossForAlloc,
      });
    }

    // Unallocated portion (Advance payment)
    final int unallocatedForeign = pay.unallocatedAmount;
    final int unallocatedBase = payFx == DatabaseConstants.exchangeRateScale
        ? unallocatedForeign
        : ((unallocatedForeign * payFx) / DatabaseConstants.exchangeRateScale)
            .round();

    final glLines = <JournalEntryLineModel>[];
    int lineIdx = 1;

    if (pay.isReceipt) {
      // 1. Debit Cash/Bank for total received
      glLines.add(
        JournalEntryLineModel(
          id: 'line_${entryId}_$lineIdx',
          organizationId: organizationId,
          journalEntryId: entryId,
          lineNumber: lineIdx++,
          accountId: pay.cashBankAccountId,
          partyId: null,
          description:
              'سند قبض رقم ${pay.paymentNumber} من ${pay.partyNameAr ?? ""}',
          currencyCode: pay.currencyCode,
          exchangeRateScaled: payFx,
          foreignDebit: pay.amount,
          foreignCredit: 0,
          baseDebit: baseCashAmount,
          baseCredit: 0,
        ),
      );

      // 2. Debit Realized FX Loss (if any)
      if (totalLoss > 0) {
        glLines.add(
          JournalEntryLineModel(
            id: 'line_${entryId}_$lineIdx',
            organizationId: organizationId,
            journalEntryId: entryId,
            lineNumber: lineIdx++,
            accountId: fxLossAccountId,
            partyId: null,
            description: 'خسائر فروق صرف محققة - سند قبض ${pay.paymentNumber}',
            currencyCode: pay.currencyCode,
            exchangeRateScaled: payFx,
            foreignDebit: 0,
            foreignCredit: 0,
            baseDebit: totalLoss,
            baseCredit: 0,
          ),
        );
      }

      // 3. Credit AR for allocated invoices (cleared at invoice historical rate)
      for (final item in allocationCalculations) {
        final invNum = item['invoiceNumber'] as String;
        final int allocForeign = item['allocForeign'] as int;
        final int baseInvoice = item['baseInvoice'] as int;

        glLines.add(
          JournalEntryLineModel(
            id: 'line_${entryId}_$lineIdx',
            organizationId: organizationId,
            journalEntryId: entryId,
            lineNumber: lineIdx++,
            accountId: arAccountId,
            partyId: pay.partyId,
            description:
                'سداد فاتورة $invNum - سند قبض رقم ${pay.paymentNumber}',
            currencyCode: pay.currencyCode,
            exchangeRateScaled: payFx,
            foreignDebit: 0,
            foreignCredit: allocForeign,
            baseDebit: 0,
            baseCredit: baseInvoice,
          ),
        );
      }

      // 4. Credit AR for unallocated advance
      if (unallocatedForeign > 0) {
        glLines.add(
          JournalEntryLineModel(
            id: 'line_${entryId}_$lineIdx',
            organizationId: organizationId,
            journalEntryId: entryId,
            lineNumber: lineIdx++,
            accountId: arAccountId,
            partyId: pay.partyId,
            description: 'دفعة مقدمة على الحساب - سند قبض ${pay.paymentNumber}',
            currencyCode: pay.currencyCode,
            exchangeRateScaled: payFx,
            foreignDebit: 0,
            foreignCredit: unallocatedForeign,
            baseDebit: 0,
            baseCredit: unallocatedBase,
          ),
        );
      }

      // 5. Credit Realized FX Gain (if any)
      if (totalGain > 0) {
        glLines.add(
          JournalEntryLineModel(
            id: 'line_${entryId}_$lineIdx',
            organizationId: organizationId,
            journalEntryId: entryId,
            lineNumber: lineIdx++,
            accountId: fxGainAccountId,
            partyId: null,
            description: 'أرباح فروق صرف محققة - سند قبض ${pay.paymentNumber}',
            currencyCode: pay.currencyCode,
            exchangeRateScaled: payFx,
            foreignDebit: 0,
            foreignCredit: 0,
            baseDebit: 0,
            baseCredit: totalGain,
          ),
        );
      }
    } else {
      // PAYMENT (Disbursement to supplier):
      // 1. Debit AP for allocated invoices (cleared at invoice historical rate)
      for (final item in allocationCalculations) {
        final invNum = item['invoiceNumber'] as String;
        final int allocForeign = item['allocForeign'] as int;
        final int baseInvoice = item['baseInvoice'] as int;

        glLines.add(
          JournalEntryLineModel(
            id: 'line_${entryId}_$lineIdx',
            organizationId: organizationId,
            journalEntryId: entryId,
            lineNumber: lineIdx++,
            accountId: apAccountId,
            partyId: pay.partyId,
            description:
                'سداد فاتورة مشتريات $invNum - سند صرف رقم ${pay.paymentNumber}',
            currencyCode: pay.currencyCode,
            exchangeRateScaled: payFx,
            foreignDebit: allocForeign,
            foreignCredit: 0,
            baseDebit: baseInvoice,
            baseCredit: 0,
          ),
        );
      }

      // 2. Debit AP for unallocated advance
      if (unallocatedForeign > 0) {
        glLines.add(
          JournalEntryLineModel(
            id: 'line_${entryId}_$lineIdx',
            organizationId: organizationId,
            journalEntryId: entryId,
            lineNumber: lineIdx++,
            accountId: apAccountId,
            partyId: pay.partyId,
            description: 'دفعة مقدمة للمورد - سند صرف ${pay.paymentNumber}',
            currencyCode: pay.currencyCode,
            exchangeRateScaled: payFx,
            foreignDebit: unallocatedForeign,
            foreignCredit: 0,
            baseDebit: unallocatedBase,
            baseCredit: 0,
          ),
        );
      }

      // 3. Debit Realized FX Loss (if any)
      if (totalLoss > 0) {
        glLines.add(
          JournalEntryLineModel(
            id: 'line_${entryId}_$lineIdx',
            organizationId: organizationId,
            journalEntryId: entryId,
            lineNumber: lineIdx++,
            accountId: fxLossAccountId,
            partyId: null,
            description: 'خسائر فروق صرف محققة - سند صرف ${pay.paymentNumber}',
            currencyCode: pay.currencyCode,
            exchangeRateScaled: payFx,
            foreignDebit: 0,
            foreignCredit: 0,
            baseDebit: totalLoss,
            baseCredit: 0,
          ),
        );
      }

      // 4. Credit Cash/Bank for total paid
      glLines.add(
        JournalEntryLineModel(
          id: 'line_${entryId}_$lineIdx',
          organizationId: organizationId,
          journalEntryId: entryId,
          lineNumber: lineIdx++,
          accountId: pay.cashBankAccountId,
          partyId: null,
          description:
              'سند صرف رقم ${pay.paymentNumber} إلى ${pay.partyNameAr ?? ""}',
          currencyCode: pay.currencyCode,
          exchangeRateScaled: payFx,
          foreignDebit: 0,
          foreignCredit: pay.amount,
          baseDebit: 0,
          baseCredit: baseCashAmount,
        ),
      );

      // 5. Credit Realized FX Gain (if any)
      if (totalGain > 0) {
        glLines.add(
          JournalEntryLineModel(
            id: 'line_${entryId}_$lineIdx',
            organizationId: organizationId,
            journalEntryId: entryId,
            lineNumber: lineIdx++,
            accountId: fxGainAccountId,
            partyId: null,
            description: 'أرباح فروق صرف محققة - سند صرف ${pay.paymentNumber}',
            currencyCode: pay.currencyCode,
            exchangeRateScaled: payFx,
            foreignDebit: 0,
            foreignCredit: 0,
            baseDebit: 0,
            baseCredit: totalGain,
          ),
        );
      }
    }

    // Verify balance and determine total base debit
    final totalBaseDebit = glLines.fold<int>(0, (sum, l) => sum + l.baseDebit);
    final totalBaseCredit =
        glLines.fold<int>(0, (sum, l) => sum + l.baseCredit);

    // Save and post GL entry atomically
    final glHeader = JournalEntryModel(
      id: entryId,
      organizationId: organizationId,
      entryNumber: entryNumber,
      fiscalPeriodId: periodId,
      entryDate: pay.paymentDate,
      entryType: entryType,
      status: 'POSTED',
      reference: pay.paymentNumber,
      narration:
          '${pay.typeLabel} رقم ${pay.paymentNumber} للطرف ${pay.partyNameAr ?? ""}',
      totalBaseDebit: totalBaseDebit,
      totalBaseCredit: totalBaseCredit,
      postedAt: DateTime.now().toIso8601String(),
    );

    await _journalRepo.saveEntry(
      entry: glHeader,
      lines: glLines,
      autoPost: true,
    );

    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // 1. Mark payment POSTED
      await txn.update(
        DatabaseConstants.tablePayments,
        {
          'status': 'POSTED',
          'journal_entry_id': entryId,
          'updated_at': now,
        },
        where: 'id = ? AND organization_id = ?',
        whereArgs: [id, organizationId],
      );

      // 2. Update realized forex on allocations and update allocated invoices
      for (final item in allocationCalculations) {
        final alloc = item['allocation'] as PaymentAllocationModel;
        final int fxDiff = item['realizedForex'] as int;

        await txn.update(
          DatabaseConstants.tablePaymentAllocations,
          {'realized_forex_gain_loss': fxDiff},
          where: 'id = ? AND organization_id = ?',
          whereArgs: [alloc.id, organizationId],
        );

        final invRes = await txn.query(
          DatabaseConstants.tableInvoices,
          where: 'id = ? AND organization_id = ?',
          whereArgs: [alloc.invoiceId, organizationId],
          limit: 1,
        );

        if (invRes.isNotEmpty) {
          final inv = invRes.first;
          final currentPaid = (inv['paid_amount'] as num).toInt();
          final total = (inv['total_amount'] as num).toInt();
          final newPaid = currentPaid + alloc.allocatedAmount;
          final newStatus = newPaid >= total ? 'PAID' : 'PARTIALLY_PAID';

          await txn.update(
            DatabaseConstants.tableInvoices,
            {
              'paid_amount': newPaid,
              'payment_status': newStatus,
              'updated_at': now,
            },
            where: 'id = ? AND organization_id = ?',
            whereArgs: [alloc.invoiceId, organizationId],
          );
        }
      }
    });
  }

  /// Voids a posted payment, restores invoice balances, and reverses the General Ledger entry.
  Future<void> voidPayment(
      String id, String organizationId, String reason) async {
    final pay = await getPaymentById(id, organizationId);
    if (pay == null) return;
    if (!pay.isPosted) throw Exception('يمكن فقط إلغاء السندات المرحلة.');

    final db = await _db;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // 1. Reverse GL Entry with immutable reversal audit
      if (pay.journalEntryId != null) {
        await _journalRepo.reverseJournalEntry(
          id: pay.journalEntryId!,
          organizationId: organizationId,
          reason: 'إلغاء السند ${pay.paymentNumber}: $reason',
        );
      }

      // 2. Rollback invoice allocations
      for (final alloc in pay.allocations) {
        final invRes = await txn.query(
          DatabaseConstants.tableInvoices,
          where: 'id = ? AND organization_id = ?',
          whereArgs: [alloc.invoiceId, organizationId],
          limit: 1,
        );

        if (invRes.isNotEmpty) {
          final inv = invRes.first;
          final currentPaid = (inv['paid_amount'] as num).toInt();
          final total = (inv['total_amount'] as num).toInt();
          final newPaid = (currentPaid - alloc.allocatedAmount) > 0
              ? currentPaid - alloc.allocatedAmount
              : 0;
          final newStatus = newPaid == 0
              ? 'UNPAID'
              : (newPaid >= total ? 'PAID' : 'PARTIALLY_PAID');

          await txn.update(
            DatabaseConstants.tableInvoices,
            {
              'paid_amount': newPaid,
              'payment_status': newStatus,
              'updated_at': now,
            },
            where: 'id = ? AND organization_id = ?',
            whereArgs: [alloc.invoiceId, organizationId],
          );
        }
      }

      // 3. Mark payment VOIDED
      await txn.update(
        DatabaseConstants.tablePayments,
        {
          'status': 'VOIDED',
          'updated_at': now,
        },
        where: 'id = ? AND organization_id = ?',
        whereArgs: [id, organizationId],
      );
    });
  }

  /// Deletes a draft payment.
  Future<void> deleteDraftPayment(String id, String organizationId) async {
    final pay = await getPaymentById(id, organizationId);
    if (pay == null) return;
    if (pay.isPosted) throw Exception('لا يمكن حذف سند مرحّل!');

    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        DatabaseConstants.tablePaymentAllocations,
        where: 'payment_id = ? AND organization_id = ?',
        whereArgs: [id, organizationId],
      );
      await txn.delete(
        DatabaseConstants.tablePayments,
        where: 'id = ? AND organization_id = ?',
        whereArgs: [id, organizationId],
      );
    });
  }
}
