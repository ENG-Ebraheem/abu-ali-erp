import 'package:sqflite/sqflite.dart';
import '../../../core/constants/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/models/account_model.dart';
import '../../journal/data/journal_repository.dart';
import '../../journal/models/journal_entry_line_model.dart';
import '../../journal/models/journal_entry_model.dart';
import '../models/invoice_line_model.dart';
import '../models/invoice_model.dart';

/// Repository managing Invoices (Sales, Purchases, Returns, Openings) and their automatic General Ledger integration.
class InvoiceRepository {
  final DatabaseHelper _dbHelper;
  final JournalRepository _journalRepo;
  final AccountRepository _accountRepo;

  InvoiceRepository({
    DatabaseHelper? dbHelper,
    JournalRepository? journalRepo,
    AccountRepository? accountRepo,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _journalRepo = journalRepo ?? JournalRepository(),
        _accountRepo = accountRepo ?? AccountRepository();

  Future<Database> get _db async => await _dbHelper.database;

  /// Generates the next sequential invoice number.
  Future<String> getNextInvoiceNumber(
      String organizationId, String invoiceType) async {
    final db = await _db;
    final year = DateTime.now().year;

    String prefix = 'INV';
    if (invoiceType == 'PURCHASE') prefix = 'BILL';
    if (invoiceType == 'SALES_RETURN') prefix = 'SR';
    if (invoiceType == 'PURCHASE_RETURN') prefix = 'PR';
    if (invoiceType == 'OPENING_RECEIVABLE') prefix = 'OP-REC';
    if (invoiceType == 'OPENING_PAYABLE') prefix = 'OP-PAY';

    final results = await db.rawQuery('''
      SELECT invoice_number FROM ${DatabaseConstants.tableInvoices}
      WHERE organization_id = ? AND invoice_number LIKE '$prefix-$year-%'
      ORDER BY invoice_number DESC
      LIMIT 1
    ''', [organizationId]);

    if (results.isEmpty) {
      return '$prefix-$year-0001';
    }

    final last = results.first['invoice_number'] as String;
    final parts = last.split('-');
    if (parts.length >= 3) {
      final numVal = int.tryParse(parts.last);
      if (numVal != null) {
        return '$prefix-$year-${(numVal + 1).toString().padLeft(4, '0')}';
      }
    }

    return '$prefix-$year-${DateTime.now().millisecondsSinceEpoch % 10000}';
  }

  /// Fetches invoices with party details.
  Future<List<InvoiceModel>> getInvoices({
    required String organizationId,
    String? invoiceType, // 'SALES', 'PURCHASE', 'ALL'
    String? status, // 'DRAFT', 'POSTED', 'CANCELLED'
    String? paymentStatus, // 'UNPAID', 'PARTIALLY_PAID', 'PAID'
    String? query,
    int limit = 50,
  }) async {
    final db = await _db;
    final args = <dynamic>[organizationId];
    String whereClause = 'inv.organization_id = ?';

    if (invoiceType != null && invoiceType != 'ALL') {
      if (invoiceType == 'SALES') {
        whereClause +=
            " AND inv.invoice_type IN ('SALES', 'OPENING_RECEIVABLE', 'SALES_RETURN')";
      } else if (invoiceType == 'PURCHASE') {
        whereClause +=
            " AND inv.invoice_type IN ('PURCHASE', 'OPENING_PAYABLE', 'PURCHASE_RETURN')";
      } else {
        whereClause += ' AND inv.invoice_type = ?';
        args.add(invoiceType);
      }
    }

    if (status != null && status != 'ALL') {
      whereClause += ' AND inv.status = ?';
      args.add(status);
    }

    if (paymentStatus != null && paymentStatus != 'ALL') {
      whereClause += ' AND inv.payment_status = ?';
      args.add(paymentStatus);
    }

    if (query != null && query.trim().isNotEmpty) {
      whereClause +=
          ' AND (inv.invoice_number LIKE ? OR p.name_ar LIKE ? OR inv.notes LIKE ?)';
      final q = '%${query.trim()}%';
      args.addAll([q, q, q]);
    }

    final sql = '''
      SELECT 
        inv.*,
        p.name_ar AS party_name_ar,
        p.code AS party_code
      FROM ${DatabaseConstants.tableInvoices} inv
      INNER JOIN ${DatabaseConstants.tableParties} p 
        ON p.id = inv.party_id AND p.organization_id = inv.organization_id
      WHERE $whereClause
      ORDER BY inv.issue_date DESC, inv.invoice_number DESC
      LIMIT $limit
    ''';

    final results = await db.rawQuery(sql, args);
    return results.map((map) => InvoiceModel.fromMap(map)).toList();
  }

  /// Fetches full invoice by ID with line items.
  Future<InvoiceModel?> getInvoiceById(String id, String organizationId) async {
    final db = await _db;

    final headerResults = await db.rawQuery('''
      SELECT 
        inv.*,
        p.name_ar AS party_name_ar,
        p.code AS party_code
      FROM ${DatabaseConstants.tableInvoices} inv
      INNER JOIN ${DatabaseConstants.tableParties} p 
        ON p.id = inv.party_id AND p.organization_id = inv.organization_id
      WHERE inv.id = ? AND inv.organization_id = ?
      LIMIT 1
    ''', [id, organizationId]);

    if (headerResults.isEmpty) return null;

    final linesResults = await db.rawQuery('''
      SELECT 
        il.*,
        coa.account_name_ar
      FROM ${DatabaseConstants.tableInvoiceLines} il
      INNER JOIN ${DatabaseConstants.tableChartOfAccounts} coa 
        ON coa.id = il.account_id AND coa.organization_id = il.organization_id
      WHERE il.invoice_id = ? AND il.organization_id = ?
      ORDER BY il.line_number ASC
    ''', [id, organizationId]);

    final lines = linesResults.map((m) => InvoiceLineModel.fromMap(m)).toList();
    return InvoiceModel.fromMap(headerResults.first, lines: lines);
  }

  /// Fetches payment voucher allocations for a given invoice.
  Future<List<Map<String, dynamic>>> getInvoiceAllocations(
      String invoiceId, String organizationId) async {
    final db = await _db;
    return await db.rawQuery('''
      SELECT 
        pa.id AS allocation_id,
        pa.payment_id,
        pa.allocated_amount,
        pa.realized_forex_gain_loss,
        pa.allocation_date,
        p.payment_number,
        p.payment_type,
        p.payment_date,
        p.currency_code,
        p.exchange_rate_scaled
      FROM ${DatabaseConstants.tablePaymentAllocations} pa
      INNER JOIN ${DatabaseConstants.tablePayments} p 
        ON p.id = pa.payment_id AND p.organization_id = pa.organization_id
      WHERE pa.invoice_id = ? AND pa.organization_id = ?
      ORDER BY pa.allocation_date ASC
    ''', [invoiceId, organizationId]);
  }

  /// Fetches unpaid/partially paid invoices for a given party.
  Future<List<InvoiceModel>> getOutstandingInvoicesForParty({
    required String organizationId,
    required String partyId,
    String? invoiceType,
  }) async {
    final db = await _db;
    final args = <dynamic>[organizationId, partyId];
    String typeClause = '';
    if (invoiceType != null && invoiceType.isNotEmpty) {
      typeClause = ' AND inv.invoice_type = ?';
      args.add(invoiceType);
    }

    final sql = '''
      SELECT 
        inv.*,
        p.name_ar AS party_name_ar,
        p.code AS party_code
      FROM ${DatabaseConstants.tableInvoices} inv
      INNER JOIN ${DatabaseConstants.tableParties} p 
        ON p.id = inv.party_id AND p.organization_id = inv.organization_id
      WHERE inv.organization_id = ? 
        AND inv.party_id = ?
        AND inv.status = 'POSTED'
        AND inv.payment_status != 'PAID'
        $typeClause
      ORDER BY inv.due_date ASC, inv.issue_date ASC
    ''';

    final results = await db.rawQuery(sql, args);
    return results.map((m) => InvoiceModel.fromMap(m)).toList();
  }

  /// Saves an invoice and its lines in SQLite.
  Future<void> saveInvoice({
    required InvoiceModel invoice,
    required List<InvoiceLineModel> lines,
    bool autoPost = false,
    String? cashBankAccountId,
  }) async {
    final db = await _db;

    // Check if modifying an already posted invoice
    final existingHeader = await db.query(
      DatabaseConstants.tableInvoices,
      columns: ['status'],
      where: 'id = ? AND organization_id = ?',
      whereArgs: [invoice.id, invoice.organizationId],
      limit: 1,
    );
    if (existingHeader.isNotEmpty &&
        existingHeader.first['status'] == 'POSTED') {
      throw Exception(
        'لا يمكن تعديل فاتورة مرحّلة! الفواتير المرحلة محمية لمنع اختلال القيود المحاسبية.',
      );
    }

    // Calculate totals
    int subtotal = 0;
    int taxAmount = 0;
    int discountAmount = 0;
    int totalAmount = 0;

    for (final l in lines) {
      // Line gross = (qty * unitPrice) / 1000
      final gross = (l.quantityScaled * l.unitPrice) ~/ 1000;
      subtotal += gross;
      taxAmount += l.taxAmount;
      discountAmount += l.discountAmount;
      totalAmount += l.lineTotal;
    }

    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // 1. Insert or update header
      final map = invoice
          .copyWith(
            subtotal: subtotal,
            taxAmount: taxAmount,
            discountAmount: discountAmount,
            totalAmount: totalAmount,
            updatedAt: now,
          )
          .toMap();

      if (map['created_at'] == null || (map['created_at'] as String).isEmpty) {
        map['created_at'] = now;
      }

      await txn.insert(
        DatabaseConstants.tableInvoices,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Delete existing lines
      await txn.delete(
        DatabaseConstants.tableInvoiceLines,
        where: 'invoice_id = ? AND organization_id = ?',
        whereArgs: [invoice.id, invoice.organizationId],
      );

      // 3. Insert lines
      for (int i = 0; i < lines.length; i++) {
        final l = lines[i];
        final lineMap = InvoiceLineModel(
          id: l.id,
          organizationId: invoice.organizationId,
          invoiceId: invoice.id,
          lineNumber: i + 1,
          accountId: l.accountId,
          itemDescription: l.itemDescription,
          quantityScaled: l.quantityScaled,
          unitPrice: l.unitPrice,
          discountAmount: l.discountAmount,
          taxAmount: l.taxAmount,
          lineTotal: l.lineTotal,
          createdAt: now,
        ).toMap();

        await txn.insert(
          DatabaseConstants.tableInvoiceLines,
          lineMap,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });

    if (autoPost) {
      await postInvoice(
        invoice.id,
        invoice.organizationId,
        cashBankAccountId: cashBankAccountId,
      );
    }
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
        'لم يتم العثور على حساب قابل للترحيل لـ "$errorName" في دليل الحسابات.');
  }

  /// Posts an invoice and automatically creates a balanced General Ledger Journal Entry.
  Future<void> postInvoice(
    String id,
    String organizationId, {
    String? cashBankAccountId,
  }) async {
    final inv = await getInvoiceById(id, organizationId);
    if (inv == null) throw Exception('الفاتورة غير موجودة.');
    if (inv.isPosted) throw Exception('الفاتورة مرحّلة مسبقاً.');
    if (inv.lines.isEmpty) throw Exception('الفاتورة لا تحتوي على أي بنود.');
    if (inv.totalAmount <= 0) {
      throw Exception(
          'إجمالي مبلغ الفاتورة يجب أن يكون أكبر من الصفر للترحيل.');
    }

    // Ensure Accounts
    final accounts = await _accountRepo.getAccountsFlat(organizationId);

    // Resolve postable leaf accounts
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

    final openingSuspenseId = _resolveLeafAccount(
      accounts: accounts,
      preferredCodes: ['3999'],
      requiredType: 'EQUITY',
      requiredNature: 'CREDIT',
      keyword: 'افتتاحي',
      errorName: 'الأرصدة الافتتاحية',
    );

    // Resolve tax account if invoice has tax
    final isSalesSide = inv.invoiceType == 'SALES' ||
        inv.invoiceType == 'SALES_RETURN' ||
        inv.invoiceType == 'OPENING_RECEIVABLE';
    String? taxAccountId;
    if (inv.taxAmount > 0) {
      taxAccountId = _resolveLeafAccount(
        accounts: accounts,
        preferredCodes: ['2102', '2112', '212', '1104'],
        requiredType: isSalesSide ? 'LIABILITY' : 'ASSET',
        requiredNature: isSalesSide ? 'CREDIT' : 'DEBIT',
        keyword: 'ضريب',
        errorName: 'أمانات الضرائب',
      );
    }

    // Ensure Fiscal Period
    final periodId =
        await _journalRepo.ensureFiscalPeriod(organizationId, inv.issueDate);
    final entryType =
        inv.isOpening ? 'OPENING' : (isSalesSide ? 'SALES' : 'PURCHASE');
    final entryNumber =
        await _journalRepo.getNextEntryNumber(organizationId, entryType);
    final entryId = 'je_inv_${inv.id}';

    // Calculate base amounts
    final int fxScaled = inv.exchangeRateScaled;
    int baseTotal = inv.totalAmount;
    if (fxScaled != DatabaseConstants.exchangeRateScale) {
      baseTotal =
          ((inv.totalAmount * fxScaled) / DatabaseConstants.exchangeRateScale)
              .round();
    }

    final glLines = <JournalEntryLineModel>[];
    final bool isCash = cashBankAccountId != null;

    if (inv.invoiceType == 'SALES') {
      // 1. Debit Cash/Bank (if cash sale) OR Accounts Receivable (if credit sale)
      final debitAccountId = isCash ? cashBankAccountId : arAccountId;
      glLines.add(
        JournalEntryLineModel(
          id: 'line_${entryId}_1',
          organizationId: organizationId,
          journalEntryId: entryId,
          lineNumber: 1,
          accountId: debitAccountId,
          partyId: isCash ? null : inv.partyId,
          description: isCash
              ? 'مبيعات نقدية - فاتورة رقم ${inv.invoiceNumber}'
              : 'فاتورة مبيعات آجل رقم ${inv.invoiceNumber}',
          currencyCode: inv.currencyCode,
          exchangeRateScaled: fxScaled,
          foreignDebit: inv.totalAmount,
          foreignCredit: 0,
          baseDebit: baseTotal,
          baseCredit: 0,
        ),
      );

      // 2. Base tax calculation
      int baseTax = 0;
      if (inv.taxAmount > 0) {
        if (fxScaled == DatabaseConstants.exchangeRateScale) {
          baseTax = inv.taxAmount;
        } else {
          baseTax =
              ((inv.taxAmount * fxScaled) / DatabaseConstants.exchangeRateScale)
                  .round();
        }
      }

      // 3. Credit Revenue lines (net of tax)
      final int totalNetBase = baseTotal - baseTax;
      int runningBaseCredit = 0;

      for (int i = 0; i < inv.lines.length; i++) {
        final l = inv.lines[i];
        final int netLineForeign = l.lineTotal - l.taxAmount;

        int baseLine = 0;
        if (i == inv.lines.length - 1 && inv.taxAmount == 0) {
          // Adjust last line to eliminate rounding discrepancies
          baseLine = baseTotal - runningBaseCredit;
        } else if (i == inv.lines.length - 1 && inv.taxAmount > 0) {
          baseLine = totalNetBase - runningBaseCredit;
        } else {
          baseLine = fxScaled == DatabaseConstants.exchangeRateScale
              ? netLineForeign
              : ((netLineForeign * fxScaled) /
                      DatabaseConstants.exchangeRateScale)
                  .round();
          runningBaseCredit += baseLine;
        }

        glLines.add(
          JournalEntryLineModel(
            id: 'line_${entryId}_${i + 2}',
            organizationId: organizationId,
            journalEntryId: entryId,
            lineNumber: i + 2,
            accountId: l.accountId,
            partyId: inv.partyId,
            description: l.itemDescription,
            currencyCode: inv.currencyCode,
            exchangeRateScaled: fxScaled,
            foreignDebit: 0,
            foreignCredit: netLineForeign,
            baseDebit: 0,
            baseCredit: baseLine,
          ),
        );
      }

      // 4. Credit Tax Liability if tax applied
      if (inv.taxAmount > 0 && taxAccountId != null) {
        glLines.add(
          JournalEntryLineModel(
            id: 'line_${entryId}_${inv.lines.length + 2}',
            organizationId: organizationId,
            journalEntryId: entryId,
            lineNumber: inv.lines.length + 2,
            accountId: taxAccountId,
            partyId: null,
            description: 'ضريبة القيمة المضافة - فاتورة ${inv.invoiceNumber}',
            currencyCode: inv.currencyCode,
            exchangeRateScaled: fxScaled,
            foreignDebit: 0,
            foreignCredit: inv.taxAmount,
            baseDebit: 0,
            baseCredit: baseTax,
          ),
        );
      }
    } else if (inv.invoiceType == 'PURCHASE') {
      // 1. Debit Purchases/Expense/Asset per line (net of tax)
      int baseTax = 0;
      if (inv.taxAmount > 0) {
        if (fxScaled == DatabaseConstants.exchangeRateScale) {
          baseTax = inv.taxAmount;
        } else {
          baseTax =
              ((inv.taxAmount * fxScaled) / DatabaseConstants.exchangeRateScale)
                  .round();
        }
      }

      final int totalNetBase = baseTotal - baseTax;
      int runningBaseDebit = 0;

      for (int i = 0; i < inv.lines.length; i++) {
        final l = inv.lines[i];
        final int netLineForeign = l.lineTotal - l.taxAmount;

        int baseLine = 0;
        if (i == inv.lines.length - 1 && inv.taxAmount == 0) {
          baseLine = baseTotal - runningBaseDebit;
        } else if (i == inv.lines.length - 1 && inv.taxAmount > 0) {
          baseLine = totalNetBase - runningBaseDebit;
        } else {
          baseLine = fxScaled == DatabaseConstants.exchangeRateScale
              ? netLineForeign
              : ((netLineForeign * fxScaled) /
                      DatabaseConstants.exchangeRateScale)
                  .round();
          runningBaseDebit += baseLine;
        }

        glLines.add(
          JournalEntryLineModel(
            id: 'line_${entryId}_${i + 1}',
            organizationId: organizationId,
            journalEntryId: entryId,
            lineNumber: i + 1,
            accountId: l.accountId,
            partyId: inv.partyId,
            description: l.itemDescription,
            currencyCode: inv.currencyCode,
            exchangeRateScaled: fxScaled,
            foreignDebit: netLineForeign,
            foreignCredit: 0,
            baseDebit: baseLine,
            baseCredit: 0,
          ),
        );
      }

      // 2. Debit Tax input if tax applied
      int nextLine = inv.lines.length + 1;
      if (inv.taxAmount > 0 && taxAccountId != null) {
        glLines.add(
          JournalEntryLineModel(
            id: 'line_${entryId}_$nextLine',
            organizationId: organizationId,
            journalEntryId: entryId,
            lineNumber: nextLine,
            accountId: taxAccountId,
            partyId: null,
            description:
                'ضريبة القيمة المضافة مدخلات - فاتورة ${inv.invoiceNumber}',
            currencyCode: inv.currencyCode,
            exchangeRateScaled: fxScaled,
            foreignDebit: inv.taxAmount,
            foreignCredit: 0,
            baseDebit: baseTax,
            baseCredit: 0,
          ),
        );
        nextLine++;
      }

      // 3. Credit Cash/Bank (if cash purchase) OR Accounts Payable (if credit purchase)
      final creditAccountId = isCash ? cashBankAccountId : apAccountId;
      glLines.add(
        JournalEntryLineModel(
          id: 'line_${entryId}_$nextLine',
          organizationId: organizationId,
          journalEntryId: entryId,
          lineNumber: nextLine,
          accountId: creditAccountId,
          partyId: isCash ? null : inv.partyId,
          description: isCash
              ? 'مشتريات نقدية - فاتورة رقم ${inv.invoiceNumber}'
              : 'فاتورة مشتريات آجل رقم ${inv.invoiceNumber}',
          currencyCode: inv.currencyCode,
          exchangeRateScaled: fxScaled,
          foreignDebit: 0,
          foreignCredit: inv.totalAmount,
          baseDebit: 0,
          baseCredit: baseTotal,
        ),
      );
    } else if (inv.invoiceType == 'SALES_RETURN') {
      // 1. Debit Revenue / Sales Return per line (net of tax)
      int baseTax = 0;
      if (inv.taxAmount > 0) {
        if (fxScaled == DatabaseConstants.exchangeRateScale) {
          baseTax = inv.taxAmount;
        } else {
          baseTax =
              ((inv.taxAmount * fxScaled) / DatabaseConstants.exchangeRateScale)
                  .round();
        }
      }

      final int totalNetBase = baseTotal - baseTax;
      int runningBaseDebit = 0;

      for (int i = 0; i < inv.lines.length; i++) {
        final l = inv.lines[i];
        final int netLineForeign = l.lineTotal - l.taxAmount;

        int baseLine = 0;
        if (i == inv.lines.length - 1 && inv.taxAmount == 0) {
          baseLine = baseTotal - runningBaseDebit;
        } else if (i == inv.lines.length - 1 && inv.taxAmount > 0) {
          baseLine = totalNetBase - runningBaseDebit;
        } else {
          baseLine = fxScaled == DatabaseConstants.exchangeRateScale
              ? netLineForeign
              : ((netLineForeign * fxScaled) /
                      DatabaseConstants.exchangeRateScale)
                  .round();
          runningBaseDebit += baseLine;
        }

        glLines.add(
          JournalEntryLineModel(
            id: 'line_${entryId}_${i + 1}',
            organizationId: organizationId,
            journalEntryId: entryId,
            lineNumber: i + 1,
            accountId: l.accountId,
            partyId: inv.partyId,
            description: 'مردود مبيعات: ${l.itemDescription}',
            currencyCode: inv.currencyCode,
            exchangeRateScaled: fxScaled,
            foreignDebit: netLineForeign,
            foreignCredit: 0,
            baseDebit: baseLine,
            baseCredit: 0,
          ),
        );
      }

      // 2. Debit Tax liability (reducing output tax payable)
      int nextLine = inv.lines.length + 1;
      if (inv.taxAmount > 0 && taxAccountId != null) {
        glLines.add(
          JournalEntryLineModel(
            id: 'line_${entryId}_$nextLine',
            organizationId: organizationId,
            journalEntryId: entryId,
            lineNumber: nextLine,
            accountId: taxAccountId,
            partyId: null,
            description:
                'تخفيض ضريبة القيمة المضافة - مردود مبيعات ${inv.invoiceNumber}',
            currencyCode: inv.currencyCode,
            exchangeRateScaled: fxScaled,
            foreignDebit: inv.taxAmount,
            foreignCredit: 0,
            baseDebit: baseTax,
            baseCredit: 0,
          ),
        );
        nextLine++;
      }

      // 3. Credit Cash/Bank (if cash refund) OR Accounts Receivable (if credit note)
      final creditAccountId = isCash ? cashBankAccountId : arAccountId;
      glLines.add(
        JournalEntryLineModel(
          id: 'line_${entryId}_$nextLine',
          organizationId: organizationId,
          journalEntryId: entryId,
          lineNumber: nextLine,
          accountId: creditAccountId,
          partyId: isCash ? null : inv.partyId,
          description: isCash
              ? 'مردود مبيعات نقدي - إشعار رقم ${inv.invoiceNumber}'
              : 'مردود مبيعات آجل - إشعار دائن رقم ${inv.invoiceNumber}',
          currencyCode: inv.currencyCode,
          exchangeRateScaled: fxScaled,
          foreignDebit: 0,
          foreignCredit: inv.totalAmount,
          baseDebit: 0,
          baseCredit: baseTotal,
        ),
      );
    } else if (inv.invoiceType == 'PURCHASE_RETURN') {
      // 1. Debit Cash/Bank (if cash refund) OR Accounts Payable (if debit note reducing debt)
      final debitAccountId = isCash ? cashBankAccountId : apAccountId;
      glLines.add(
        JournalEntryLineModel(
          id: 'line_${entryId}_1',
          organizationId: organizationId,
          journalEntryId: entryId,
          lineNumber: 1,
          accountId: debitAccountId,
          partyId: isCash ? null : inv.partyId,
          description: isCash
              ? 'مردود مشتريات نقدي - إشعار رقم ${inv.invoiceNumber}'
              : 'مردود مشتريات آجل - إشعار مدين رقم ${inv.invoiceNumber}',
          currencyCode: inv.currencyCode,
          exchangeRateScaled: fxScaled,
          foreignDebit: inv.totalAmount,
          foreignCredit: 0,
          baseDebit: baseTotal,
          baseCredit: 0,
        ),
      );

      // 2. Base tax calculation
      int baseTax = 0;
      if (inv.taxAmount > 0) {
        if (fxScaled == DatabaseConstants.exchangeRateScale) {
          baseTax = inv.taxAmount;
        } else {
          baseTax =
              ((inv.taxAmount * fxScaled) / DatabaseConstants.exchangeRateScale)
                  .round();
        }
      }

      // 3. Credit Purchases / Expense / Inventory per line (net of tax)
      final int totalNetBase = baseTotal - baseTax;
      int runningBaseCredit = 0;

      for (int i = 0; i < inv.lines.length; i++) {
        final l = inv.lines[i];
        final int netLineForeign = l.lineTotal - l.taxAmount;

        int baseLine = 0;
        if (i == inv.lines.length - 1 && inv.taxAmount == 0) {
          baseLine = baseTotal - runningBaseCredit;
        } else if (i == inv.lines.length - 1 && inv.taxAmount > 0) {
          baseLine = totalNetBase - runningBaseCredit;
        } else {
          baseLine = fxScaled == DatabaseConstants.exchangeRateScale
              ? netLineForeign
              : ((netLineForeign * fxScaled) /
                      DatabaseConstants.exchangeRateScale)
                  .round();
          runningBaseCredit += baseLine;
        }

        glLines.add(
          JournalEntryLineModel(
            id: 'line_${entryId}_${i + 2}',
            organizationId: organizationId,
            journalEntryId: entryId,
            lineNumber: i + 2,
            accountId: l.accountId,
            partyId: inv.partyId,
            description: 'مردود مشتريات: ${l.itemDescription}',
            currencyCode: inv.currencyCode,
            exchangeRateScaled: fxScaled,
            foreignDebit: 0,
            foreignCredit: netLineForeign,
            baseDebit: 0,
            baseCredit: baseLine,
          ),
        );
      }

      // 4. Credit Tax input (reducing input tax asset) if tax applied
      if (inv.taxAmount > 0 && taxAccountId != null) {
        glLines.add(
          JournalEntryLineModel(
            id: 'line_${entryId}_${inv.lines.length + 2}',
            organizationId: organizationId,
            journalEntryId: entryId,
            lineNumber: inv.lines.length + 2,
            accountId: taxAccountId,
            partyId: null,
            description:
                'تخفيض ضريبة القيمة المضافة مدخلات - مردود مشتريات ${inv.invoiceNumber}',
            currencyCode: inv.currencyCode,
            exchangeRateScaled: fxScaled,
            foreignDebit: 0,
            foreignCredit: inv.taxAmount,
            baseDebit: 0,
            baseCredit: baseTax,
          ),
        );
      }
    } else if (inv.invoiceType == 'OPENING_RECEIVABLE') {
      // Debit Accounts Receivable, Credit Opening Suspense
      glLines.add(
        JournalEntryLineModel(
          id: 'line_${entryId}_1',
          organizationId: organizationId,
          journalEntryId: entryId,
          lineNumber: 1,
          accountId: arAccountId,
          partyId: inv.partyId,
          description: 'رصيد افتتاحي للعميل - فاتورة ${inv.invoiceNumber}',
          currencyCode: inv.currencyCode,
          exchangeRateScaled: fxScaled,
          foreignDebit: inv.totalAmount,
          foreignCredit: 0,
          baseDebit: baseTotal,
          baseCredit: 0,
        ),
      );
      glLines.add(
        JournalEntryLineModel(
          id: 'line_${entryId}_2',
          organizationId: organizationId,
          journalEntryId: entryId,
          lineNumber: 2,
          accountId: openingSuspenseId,
          partyId: null,
          description: 'تسوية رصيد افتتاحي - فاتورة ${inv.invoiceNumber}',
          currencyCode: inv.currencyCode,
          exchangeRateScaled: fxScaled,
          foreignDebit: 0,
          foreignCredit: inv.totalAmount,
          baseDebit: 0,
          baseCredit: baseTotal,
        ),
      );
    } else if (inv.invoiceType == 'OPENING_PAYABLE') {
      // Debit Opening Suspense, Credit Accounts Payable
      glLines.add(
        JournalEntryLineModel(
          id: 'line_${entryId}_1',
          organizationId: organizationId,
          journalEntryId: entryId,
          lineNumber: 1,
          accountId: openingSuspenseId,
          partyId: null,
          description: 'تسوية رصيد افتتاحي - فاتورة مورد ${inv.invoiceNumber}',
          currencyCode: inv.currencyCode,
          exchangeRateScaled: fxScaled,
          foreignDebit: inv.totalAmount,
          foreignCredit: 0,
          baseDebit: baseTotal,
          baseCredit: 0,
        ),
      );
      glLines.add(
        JournalEntryLineModel(
          id: 'line_${entryId}_2',
          organizationId: organizationId,
          journalEntryId: entryId,
          lineNumber: 2,
          accountId: apAccountId,
          partyId: inv.partyId,
          description: 'رصيد افتتاحي للمورد - فاتورة ${inv.invoiceNumber}',
          currencyCode: inv.currencyCode,
          exchangeRateScaled: fxScaled,
          foreignDebit: 0,
          foreignCredit: inv.totalAmount,
          baseDebit: 0,
          baseCredit: baseTotal,
        ),
      );
    }

    // Save and post GL entry atomically
    final glHeader = JournalEntryModel(
      id: entryId,
      organizationId: organizationId,
      entryNumber: entryNumber,
      fiscalPeriodId: periodId,
      entryDate: inv.issueDate,
      entryType: entryType,
      status: 'POSTED',
      reference: inv.invoiceNumber,
      narration:
          '${inv.typeLabel} رقم ${inv.invoiceNumber} للطرف ${inv.partyNameAr ?? ""}',
      totalBaseDebit: baseTotal,
      totalBaseCredit: baseTotal,
      postedAt: DateTime.now().toIso8601String(),
    );

    await _journalRepo.saveEntry(
      entry: glHeader,
      lines: glLines,
      autoPost: true,
    );

    // Update invoice status to POSTED
    final db = await _db;
    final now = DateTime.now().toIso8601String();

    await db.update(
      DatabaseConstants.tableInvoices,
      {
        'status': 'POSTED',
        'paid_amount': isCash ? inv.totalAmount : 0,
        'payment_status': isCash ? 'PAID' : 'UNPAID',
        'journal_entry_id': entryId,
        'updated_at': now,
      },
      where: 'id = ? AND organization_id = ?',
      whereArgs: [id, organizationId],
    );
  }

  /// Cancels an invoice and reverses its General Ledger entry.
  Future<void> cancelInvoice(
      String id, String organizationId, String reason) async {
    final inv = await getInvoiceById(id, organizationId);
    if (inv == null) return;
    if (inv.paidAmount > 0) {
      throw Exception(
        'لا يمكن إلغاء فاتورة مسددة جزئياً أو كلياً! يرجى إلغاء سندات الدفع المرتبطة بها أولاً.',
      );
    }

    final db = await _db;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      if (inv.isPosted && inv.journalEntryId != null) {
        // Reverse GL Entry with immutable reversal audit
        await _journalRepo.reverseJournalEntry(
          id: inv.journalEntryId!,
          organizationId: organizationId,
          reason: 'إلغاء الفاتورة ${inv.invoiceNumber}: $reason',
        );
      }

      await txn.update(
        DatabaseConstants.tableInvoices,
        {
          'status': 'CANCELLED',
          'updated_at': now,
        },
        where: 'id = ? AND organization_id = ?',
        whereArgs: [id, organizationId],
      );
    });
  }

  /// Deletes a draft invoice.
  Future<void> deleteDraftInvoice(String id, String organizationId) async {
    final inv = await getInvoiceById(id, organizationId);
    if (inv == null) return;
    if (inv.isPosted) {
      throw Exception('لا يمكن حذف فاتورة مرحّلة! يجب إلغاؤها بدلاً من الحذف.');
    }

    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        DatabaseConstants.tableInvoiceLines,
        where: 'invoice_id = ? AND organization_id = ?',
        whereArgs: [id, organizationId],
      );
      await txn.delete(
        DatabaseConstants.tableInvoices,
        where: 'id = ? AND organization_id = ?',
        whereArgs: [id, organizationId],
      );
    });
  }
}
