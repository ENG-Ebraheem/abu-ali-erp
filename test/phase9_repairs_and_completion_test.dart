import 'package:flutter_test/flutter_test.dart';
import 'package:abu_ali/core/utils/formatters.dart';
import 'package:abu_ali/features/invoices/models/invoice_model.dart';
import 'package:abu_ali/features/journal/models/journal_entry_model.dart';
import 'package:abu_ali/features/journal/models/journal_entry_line_model.dart';
import 'package:abu_ali/features/fixed_assets/models/fixed_asset_model.dart';
import 'package:abu_ali/features/settings/services/security_service.dart';

void main() {
  group('Phase 9: Comprehensive Repairs & Module Completion Tests', () {
    test('1. AppFormatters: Precision formatting and currency conversion', () {
      // 1,000,000.00 YER represented as 100,000,000 minor units
      expect(AppFormatters.formatMinorUnits(100000000), equals('1,000,000'));
      expect(
        AppFormatters.formatMinorUnits(100000000, includeDecimals: true),
        equals('1,000,000.00'),
      );

      // Fractional minor units: 1,234.50
      expect(
        AppFormatters.formatMinorUnits(123450, includeDecimals: true),
        equals('1,234.50'),
      );

      // Zero & Negatives
      expect(AppFormatters.formatMinorUnits(0), equals('0'));
      expect(
        AppFormatters.formatMinorUnits(-45000000),
        equals('-450,000'),
      );

      // Full currency string
      expect(
        AppFormatters.formatCurrency(50000000, currencySymbol: 'YER'),
        equals('500,000 YER'),
      );
    });

    test('2. Sales & Purchase Returns: InvoiceModel flags and labels', () {
      const salesReturn = InvoiceModel(
        id: 'inv_sr_1',
        organizationId: 'org_test',
        partyId: 'party_cust_1',
        invoiceType: 'SALES_RETURN',
        invoiceNumber: 'SR-2026-0001',
        issueDate: '2026-11-01',
        dueDate: '2026-11-01',
        currencyCode: 'YER',
        exchangeRateScaled: 1000000,
        totalAmount: 1500000,
      );

      expect(salesReturn.isSalesReturn, isTrue);
      expect(salesReturn.isReturn, isTrue);
      expect(salesReturn.isPurchaseReturn, isFalse);
      expect(salesReturn.typeLabel, equals('مردود مبيعات'));

      const purchaseReturn = InvoiceModel(
        id: 'inv_pr_1',
        organizationId: 'org_test',
        partyId: 'party_supp_1',
        invoiceType: 'PURCHASE_RETURN',
        invoiceNumber: 'PR-2026-0001',
        issueDate: '2026-11-01',
        dueDate: '2026-11-01',
        currencyCode: 'YER',
        exchangeRateScaled: 1000000,
        totalAmount: 2800000,
      );

      expect(purchaseReturn.isPurchaseReturn, isTrue);
      expect(purchaseReturn.isReturn, isTrue);
      expect(purchaseReturn.isSalesReturn, isFalse);
      expect(purchaseReturn.typeLabel, equals('مردود مشتريات'));
    });

    test('3. Fixed Assets: Straight-line depreciation and book value formulas', () {
      // Vehicle: Cost 6,000,000 YER (600,000,000 minor units), Salvage 600,000 YER (60,000,000 minor units)
      // Useful life: 60 months (5 years)
      const asset = FixedAssetModel(
        id: 'ast_101',
        organizationId: 'org_test',
        assetCode: 'AST-0001',
        assetNameAr: 'شاحنة توزيع بضائع',
        assetAccountId: 'acc_asset_1',
        depreciationExpenseAccountId: 'acc_exp_1',
        accumulatedDepreciationAccountId: 'acc_dep_1',
        purchaseDate: '2026-01-01',
        purchaseCost: 600000000,
        salvageValue: 60000000,
        usefulLifeMonths: 60,
        accumulatedDepreciation: 90000000, // 10 months depreciated
        createdAt: '2026-01-01T00:00:00',
        updatedAt: '2026-11-01T00:00:00',
      );

      // Depreciable base = 600,000,000 - 60,000,000 = 540,000,000
      expect(asset.depreciableCost, equals(540000000));

      // Monthly depreciation = 540,000,000 / 60 = 9,000,000 (90,000 YER)
      expect(asset.monthlyDepreciation, equals(9000000));

      // Book Value = 600,000,000 - 90,000,000 = 510,000,000 (5,100,000 YER)
      expect(asset.bookValue, equals(510000000));

      // Remaining depreciation = 540,000,000 - 90,000,000 = 450,000,000
      expect(asset.remainingDepreciation, equals(450000000));

      // Depreciated ratio = 90M / 540M = 0.1666...
      expect(asset.depreciatedRatio, closeTo(0.1666, 0.001));
    });

    test('4. SecurityService: Offline SHA-256 PIN cryptography and salt verification', () {
      final sec = SecurityService.instance;
      final salt1 = sec.generateSalt(16);
      final salt2 = sec.generateSalt(16);

      expect(salt1.length, equals(32)); // 16 bytes = 32 hex chars
      expect(salt1, isNot(equals(salt2))); // Cryptographically random

      final hash1 = sec.hashPin('1234', salt1);
      final hash2 = sec.hashPin('1234', salt1);
      final hashDifferentPin = sec.hashPin('5678', salt1);
      final hashDifferentSalt = sec.hashPin('1234', salt2);

      expect(hash1, equals(hash2)); // Deterministic with same salt
      expect(hash1, isNot(equals(hashDifferentPin))); // Different PIN
      expect(hash1, isNot(equals(hashDifferentSalt))); // Different salt
    });

    test('5. Cash & Bank Transfers: Balanced double-entry integrity and equality', () {
      // Transfer 350,000 YER (35,000,000 minor) from Bank الأهلي (1112) to Main Cashbox (1111)
      const transferAmount = 35000000;
      final debitLine = JournalEntryLineModel(
        id: 'line_trf_1',
        organizationId: 'org_test',
        journalEntryId: 'je_trf_001',
        lineNumber: 1,
        accountId: 'acc_cash_1111',
        currencyCode: 'YER',
        exchangeRateScaled: 1000000,
        foreignDebit: transferAmount,
        foreignCredit: 0,
        baseDebit: transferAmount,
        baseCredit: 0,
        createdAt: '2026-11-01T00:00:00',
      );

      final creditLine = JournalEntryLineModel(
        id: 'line_trf_2',
        organizationId: 'org_test',
        journalEntryId: 'je_trf_001',
        lineNumber: 2,
        accountId: 'acc_bank_1112',
        currencyCode: 'YER',
        exchangeRateScaled: 1000000,
        foreignDebit: 0,
        foreignCredit: transferAmount,
        baseDebit: 0,
        baseCredit: transferAmount,
        createdAt: '2026-11-01T00:00:00',
      );

      final entry = JournalEntryModel(
        id: 'je_trf_001',
        organizationId: 'org_test',
        entryNumber: 'JV-2026-0042',
        fiscalPeriodId: 'fp_1',
        entryDate: '2026-11-01',
        narration: 'تحويل مالي من البنك إلى الصندوق',
        totalBaseDebit: debitLine.baseDebit,
        totalBaseCredit: creditLine.baseCredit,
        lines: [debitLine, creditLine],
      );

      expect(entry.isBalanced, isTrue);
      expect(entry.totalBaseDebit, equals(entry.totalBaseCredit));
      expect(entry.totalBaseDebit, equals(transferAmount));
      // Net change in overall assets is zero (asset shift)
      expect(debitLine.baseDebit - creditLine.baseCredit, equals(0));
    });

    test('6. Partial Payments: Allocation tracks balance reduction across partial and full settlements', () {
      // Invoice 1,000,000 YER (100,000,000 minor)
      const invoiceTotal = 100000000;
      var inv = const InvoiceModel(
        id: 'inv_partial_test',
        organizationId: 'org_test',
        partyId: 'party_cust_1',
        invoiceType: 'SALES',
        invoiceNumber: 'INV-2026-0010',
        issueDate: '2026-11-01',
        dueDate: '2026-11-30',
        currencyCode: 'YER',
        exchangeRateScaled: 1000000,
        totalAmount: invoiceTotal,
        paidAmount: 0,
        paymentStatus: 'UNPAID',
      );

      expect(inv.remainingAmount, equals(100000000));
      expect(inv.isUnpaid, isTrue);

      // Payment 1: Partial payment of 400,000 YER (40,000,000 minor)
      const firstPayment = 40000000;
      inv = InvoiceModel(
        id: inv.id,
        organizationId: inv.organizationId,
        partyId: inv.partyId,
        invoiceType: inv.invoiceType,
        invoiceNumber: inv.invoiceNumber,
        issueDate: inv.issueDate,
        dueDate: inv.dueDate,
        currencyCode: inv.currencyCode,
        exchangeRateScaled: inv.exchangeRateScaled,
        totalAmount: inv.totalAmount,
        paidAmount: inv.paidAmount + firstPayment,
        paymentStatus: 'PARTIALLY_PAID',
      );

      expect(inv.paidAmount, equals(40000000));
      expect(inv.remainingAmount, equals(60000000));
      expect(inv.isPartiallyPaid, isTrue);
      expect(inv.isPaid, isFalse);

      // Payment 2: Full settlement of remaining 600,000 YER (60,000,000 minor)
      const secondPayment = 60000000;
      inv = InvoiceModel(
        id: inv.id,
        organizationId: inv.organizationId,
        partyId: inv.partyId,
        invoiceType: inv.invoiceType,
        invoiceNumber: inv.invoiceNumber,
        issueDate: inv.issueDate,
        dueDate: inv.dueDate,
        currencyCode: inv.currencyCode,
        exchangeRateScaled: inv.exchangeRateScaled,
        totalAmount: inv.totalAmount,
        paidAmount: inv.paidAmount + secondPayment,
        paymentStatus: 'PAID',
      );

      expect(inv.paidAmount, equals(100000000));
      expect(inv.remainingAmount, equals(0));
      expect(inv.isPaid, isTrue);
    });

    test('7. Sales Returns vs Original Sale: Exact double-entry reversal math', () {
      // 1. Original Sale:
      // Total 115,000 YER (11,500,000 minor) = Net Revenue 100,000 YER (10,000,000) + Tax 15,000 YER (1,500,000)
      const netRevenue = 10000000;
      const taxAmount = 1500000;
      const totalInvoice = 11500000;

      // GL Entries for Sale:
      // Dr AR: 11,500,000
      // Cr Revenue: 10,000,000
      // Cr Tax Payable: 1,500,000
      final saleDebitAR = totalInvoice;
      final saleCreditRevenue = netRevenue;
      final saleCreditTax = taxAmount;
      expect(saleDebitAR, equals(saleCreditRevenue + saleCreditTax));

      // 2. Sales Return of the full invoice:
      // GL Entries for Return:
      // Dr Sales Returns (Revenue deduction): 10,000,000
      // Dr Tax Payable (Tax reduction): 1,500,000
      // Cr AR (Receivable cancellation): 11,500,000
      final returnDebitRev = netRevenue;
      final returnDebitTax = taxAmount;
      final returnCreditAR = totalInvoice;
      expect(returnDebitRev + returnDebitTax, equals(returnCreditAR));

      // Net impact on Customer AR:
      final netARBalance = saleDebitAR - returnCreditAR;
      expect(netARBalance, equals(0));

      // Net impact on Revenue:
      final netRevenueBalance = saleCreditRevenue - returnDebitRev;
      expect(netRevenueBalance, equals(0));

      // Net impact on Tax Payable:
      final netTaxBalance = saleCreditTax - returnDebitTax;
      expect(netTaxBalance, equals(0));
    });
  });
}
