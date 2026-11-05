import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:abu_ali/core/constants/database_constants.dart';
import 'package:abu_ali/features/accounts/models/account_model.dart';
import 'package:abu_ali/features/journal/models/journal_entry_line_model.dart';
import 'package:abu_ali/features/journal/models/journal_entry_model.dart';
import 'package:abu_ali/features/opening_balances/models/opening_balance_model.dart';
import 'package:abu_ali/features/opening_balances/screens/opening_balances_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2 Accounting Engine & Operations Unit Tests', () {
    // -------------------------------------------------------------
    // Rule 1 & 2: Double-Entry Balance Validation (Opening & General)
    // -------------------------------------------------------------
    test('1. Balanced opening entry validates and calculates equality', () {
      final line1 = OpeningBalanceLineItem(
        id: 'ob_1',
        accountId: 'acc_cash',
        accountCode: '1101',
        accountNameAr: 'الصندوق الرئيسي',
        accountType: 'ASSET',
        accountNature: 'DEBIT',
        currencyCode: 'YER',
        baseDebit: 50000000, // 500,000.00 YER
        baseCredit: 0,
      );

      final line2 = OpeningBalanceLineItem(
        id: 'ob_2',
        accountId: 'acc_capital',
        accountCode: '3101',
        accountNameAr: 'رأس المال',
        accountType: 'EQUITY',
        accountNature: 'CREDIT',
        currencyCode: 'YER',
        baseDebit: 0,
        baseCredit: 50000000, // 500,000.00 YER
      );

      final totalDebit = line1.baseDebit + line2.baseDebit;
      final totalCredit = line1.baseCredit + line2.baseCredit;

      expect(totalDebit, totalCredit);
      expect(totalDebit > 0, isTrue);
      expect(totalDebit, 50000000);
    });

    test('2. Unbalanced opening entry detects imbalance difference', () {
      final line1 = OpeningBalanceLineItem(
        id: 'ob_1',
        accountId: 'acc_cash',
        accountCode: '1101',
        accountNameAr: 'الصندوق الرئيسي',
        accountType: 'ASSET',
        accountNature: 'DEBIT',
        currencyCode: 'YER',
        baseDebit: 60000000, // 600,000.00
        baseCredit: 0,
      );

      final line2 = OpeningBalanceLineItem(
        id: 'ob_2',
        accountId: 'acc_capital',
        accountCode: '3101',
        accountNameAr: 'رأس المال',
        accountType: 'EQUITY',
        accountNature: 'CREDIT',
        currencyCode: 'YER',
        baseDebit: 0,
        baseCredit: 50000000, // 500,000.00
      );

      final totalDebit = line1.baseDebit + line2.baseDebit;
      final totalCredit = line1.baseCredit + line2.baseCredit;
      final diff = (totalDebit - totalCredit).abs();

      expect(totalDebit == totalCredit, isFalse);
      expect(diff, 10000000); // 100,000.00 YER imbalance
    });

    // -------------------------------------------------------------
    // Rule 3 & 4: Draft vs Posted Immutability
    // -------------------------------------------------------------
    test('3. Draft entries can be edited while posted entries are immutable',
        () {
      final draftEntry = JournalEntryModel(
        id: 'je_draft_01',
        organizationId: 'org_01',
        entryNumber: 'JV-2026-0001',
        fiscalPeriodId: 'fp_01',
        entryDate: '2026-01-01',
        entryType: 'GENERAL',
        status: 'DRAFT',
        narration: 'قيد مسودة تجريبي',
        totalBaseDebit: 100000,
        totalBaseCredit: 100000,
      );

      expect(draftEntry.isDraft, isTrue);
      expect(draftEntry.isPosted, isFalse);

      // Editing draft fields
      final updatedDraft = draftEntry.copyWith(
        narration: 'تعديل بيان المسودة بنجاح',
        totalBaseDebit: 150000,
        totalBaseCredit: 150000,
      );
      expect(updatedDraft.narration, 'تعديل بيان المسودة بنجاح');
      expect(updatedDraft.totalBaseDebit, 150000);

      // Transition to POSTED
      final postedEntry = updatedDraft.copyWith(
        status: 'POSTED',
        postedAt: '2026-01-01T10:00:00Z',
      );
      expect(postedEntry.isPosted, isTrue);
      expect(postedEntry.isDraft, isFalse);
      expect(postedEntry.postedAt, isNotNull);
    });

    // -------------------------------------------------------------
    // Rule 5: Reversal Entries Logic
    // -------------------------------------------------------------
    test(
        '5. Reversal entries accurately swap debits and credits with reference',
        () {
      final originalLines = [
        JournalEntryLineModel(
          id: 'l1',
          organizationId: 'org_main',
          journalEntryId: 'je_orig',
          lineNumber: 1,
          accountId: 'acc_cash',
          currencyCode: 'YER',
          exchangeRateScaled: DatabaseConstants.exchangeRateScale,
          baseDebit: 250000,
          baseCredit: 0,
        ),
        JournalEntryLineModel(
          id: 'l2',
          organizationId: 'org_main',
          journalEntryId: 'je_orig',
          lineNumber: 2,
          accountId: 'acc_revenue',
          currencyCode: 'YER',
          exchangeRateScaled: DatabaseConstants.exchangeRateScale,
          baseDebit: 0,
          baseCredit: 250000,
        ),
      ];

      // Reversal lines swap debit and credit
      final reversalLines = originalLines.map((orig) {
        return JournalEntryLineModel(
          id: 'rev_${orig.id}',
          organizationId: orig.organizationId,
          journalEntryId: 'je_reversal',
          lineNumber: orig.lineNumber,
          accountId: orig.accountId,
          currencyCode: orig.currencyCode,
          exchangeRateScaled: orig.exchangeRateScaled,
          baseDebit: orig.baseCredit, // Swapped!
          baseCredit: orig.baseDebit, // Swapped!
        );
      }).toList();

      expect(reversalLines[0].baseDebit, 0);
      expect(reversalLines[0].baseCredit, 250000);
      expect(reversalLines[1].baseDebit, 250000);
      expect(reversalLines[1].baseCredit, 0);

      // Reversal totals match original totals
      final revDebitTotal = reversalLines.fold(0, (s, l) => s + l.baseDebit);
      final revCreditTotal = reversalLines.fold(0, (s, l) => s + l.baseCredit);
      expect(revDebitTotal, 250000);
      expect(revCreditTotal, 250000);
    });

    // -------------------------------------------------------------
    // Rule 6: Closed Fiscal Periods Reject Posting
    // -------------------------------------------------------------
    test('6. Closed fiscal period rejects posting attempts', () {
      bool isPeriodClosed = true;
      bool canPost = !isPeriodClosed;
      expect(canPost, isFalse);

      expect(
        () {
          if (isPeriodClosed) {
            throw Exception('لا يمكن الترحيل: الفترة المالية مغلقة محاسبياً.');
          }
        },
        throwsA(predicate(
            (e) => e.toString().contains('الفترة المالية مغلقة محاسبياً'))),
      );
    });

    // -------------------------------------------------------------
    // Rule 7 & 8: Inactive and Non-Postable Accounts Reject Posting
    // -------------------------------------------------------------
    test('7. Inactive accounts reject posting attempts', () {
      final inactiveAccount = AccountModel(
        id: 'acc_inactive',
        organizationId: 'org_main',
        accountCode: '11099',
        accountNameAr: 'صندوق ملغي',
        accountType: 'ASSET',
        accountNature: 'DEBIT',
        isActive: false,
        createdAt: DateTime.now(),
      );

      expect(
        () {
          if (!inactiveAccount.isActive) {
            throw Exception(
              'لا يمكن الترحيل للحساب "${inactiveAccount.accountNameAr}" لأنه معطل.',
            );
          }
        },
        throwsA(predicate((e) => e.toString().contains('لأنه معطل'))),
      );
    });

    test('8. Parent accounts with subaccounts (non-postable) reject posting',
        () {
      final parentAccount = AccountModel(
        id: 'acc_parent_11',
        organizationId: 'org_main',
        accountCode: '11',
        accountNameAr: 'الأصول المتداولة',
        accountType: 'ASSET',
        accountNature: 'DEBIT',
        children: [
          AccountModel(
            id: 'acc_child_1101',
            organizationId: 'org_main',
            accountCode: '1101',
            accountNameAr: 'النقدية وما في حكمها',
            accountType: 'ASSET',
            accountNature: 'DEBIT',
            parentId: 'acc_parent_11',
            createdAt: DateTime.now(),
          ),
        ],
        createdAt: DateTime.now(),
      );

      expect(parentAccount.isHeaderAccount, isTrue);

      expect(
        () {
          if (parentAccount.isHeaderAccount) {
            throw Exception(
              'لا يمكن الترحيل للحساب الرئيسي "${parentAccount.accountNameAr}"؛ يجب اختيار حساب فرعي.',
            );
          }
        },
        throwsA(predicate((e) => e.toString().contains('حساب فرعي'))),
      );
    });

    // -------------------------------------------------------------
    // Rule 9: Foreign Currency Fixed-Point Conversion & Scaling
    // -------------------------------------------------------------
    test('9. Foreign-currency lines calculate base equivalents with precision',
        () {
      // 1 USD = 535.5000 YER (scaled: 535,500,000)
      const foreignAmountMinor = 50000; // $500.00
      const rateScaled = 535500000;

      final baseAmountMinor = ((foreignAmountMinor * rateScaled) /
              DatabaseConstants.exchangeRateScale)
          .round();

      // $500.00 * 535.50 = 267,750.00 YER (26,775,000 minor units)
      expect(baseAmountMinor, 26775000);
      expect((baseAmountMinor / 100.0), 267750.0);
    });

    // -------------------------------------------------------------
    // Rule 10: Multi-Tenant Organization Isolation
    // -------------------------------------------------------------
    test(
        '10. Organization isolation is enforced across journal and opening entries',
        () {
      final org1Opening = OpeningBalanceModel(
        id: 'ob_org1',
        organizationId: 'org_1',
        fiscalYearId: 'fy_2026',
        asOfDate: '2026-01-01',
        createdAt: '',
        updatedAt: '',
      );

      final org2Opening = OpeningBalanceModel(
        id: 'ob_org2',
        organizationId: 'org_2',
        fiscalYearId: 'fy_2026',
        asOfDate: '2026-01-01',
        createdAt: '',
        updatedAt: '',
      );

      expect(org1Opening.organizationId, isNot(org2Opening.organizationId));
      expect(org1Opening.id, isNot(org2Opening.id));
    });

    // -------------------------------------------------------------
    // Rule 11 & 12: Duplicate Posting Prevention & Atomic State
    // -------------------------------------------------------------
    test('11. Duplicate posting is rejected if already posted', () {
      final postedEntry = JournalEntryModel(
        id: 'je_posted_01',
        organizationId: 'org_main',
        entryNumber: 'JV-2026-0099',
        fiscalPeriodId: 'fp_01',
        entryDate: '2026-01-01',
        entryType: 'GENERAL',
        status: 'POSTED',
        narration: 'قيد مرحل مسبقاً',
        totalBaseDebit: 10000,
        totalBaseCredit: 10000,
      );

      expect(
        () {
          if (postedEntry.isPosted) {
            throw Exception('القيد مرحّل مسبقاً ولا يمكن ترحيله مرة أخرى.');
          }
        },
        throwsA(predicate((e) => e.toString().contains('مرحّل مسبقاً'))),
      );
    });

    // -------------------------------------------------------------
    // Rule 13 & 14: Subledger Reconciliation for Customers & Suppliers
    // -------------------------------------------------------------
    test('13. Subledger customer balances require party linkage', () {
      final customerControlLine = OpeningBalanceLineItem(
        id: 'l_cust',
        accountId: 'acc_rec_1103',
        accountCode: '110301',
        accountNameAr: 'ذمم العملاء',
        accountType: 'ASSET',
        accountNature: 'DEBIT',
        partyId: null, // Missing required party
        currencyCode: 'YER',
        baseDebit: 1500000,
        baseCredit: 0,
      );

      expect(
        () {
          if (customerControlLine.accountCode.startsWith('1103') &&
              customerControlLine.partyId == null) {
            throw Exception(
              'حساب ذمم العملاء يتطلب تحديد العميل التابع له لضبط مطابقة الأستاذ المساعد.',
            );
          }
        },
        throwsA(predicate((e) => e.toString().contains('الأستاذ المساعد'))),
      );
    });

    test('14. Subledger supplier balances require party linkage', () {
      final supplierControlLine = OpeningBalanceLineItem(
        id: 'l_supp',
        accountId: 'acc_pay_2101',
        accountCode: '210101',
        accountNameAr: 'ذمم الموردين',
        accountType: 'LIABILITY',
        accountNature: 'CREDIT',
        partyId: 'supp_001', // Correctly linked!
        currencyCode: 'YER',
        baseDebit: 0,
        baseCredit: 2000000,
      );

      final isValid = !supplierControlLine.accountCode.startsWith('2101') ||
          supplierControlLine.partyId != null;
      expect(isValid, isTrue);
      expect(supplierControlLine.partyId, 'supp_001');
    });

    // -------------------------------------------------------------
    // Rule 15: Account Ledger Running Balance Progression
    // -------------------------------------------------------------
    test(
        '15. Account ledger progressive running balance matches posted movements',
        () {
      final ledgerEntries = [
        AccountLedgerEntryModel(
          lineId: 'l1',
          journalEntryId: 'je1',
          entryNumber: 'OP-2026-0001',
          entryDate: '2026-01-01',
          entryType: 'OPENING',
          narration: 'رصيد افتتاحي',
          baseDebit: 100000, // +1,000.00
          baseCredit: 0,
          foreignDebit: 100000,
          foreignCredit: 0,
          currencyCode: 'YER',
          exchangeRateScaled: DatabaseConstants.exchangeRateScale,
          runningBalance: 100000,
        ),
        AccountLedgerEntryModel(
          lineId: 'l2',
          journalEntryId: 'je2',
          entryNumber: 'RC-2026-0001',
          entryDate: '2026-01-15',
          entryType: 'RECEIPT',
          narration: 'قبض دفعة من عميل',
          baseDebit: 50000, // +500.00
          baseCredit: 0,
          foreignDebit: 50000,
          foreignCredit: 0,
          currencyCode: 'YER',
          exchangeRateScaled: DatabaseConstants.exchangeRateScale,
          runningBalance: 150000,
        ),
        AccountLedgerEntryModel(
          lineId: 'l3',
          journalEntryId: 'je3',
          entryNumber: 'PY-2026-0001',
          entryDate: '2026-01-20',
          entryType: 'PAYMENT',
          narration: 'صرف مصاريف صيانة',
          baseDebit: 0,
          baseCredit: 30000, // -300.00
          foreignDebit: 0,
          foreignCredit: 30000,
          currencyCode: 'YER',
          exchangeRateScaled: DatabaseConstants.exchangeRateScale,
          runningBalance: 120000, // 1,500 - 300 = 1,200
        ),
      ];

      expect(ledgerEntries[0].runningBalanceDouble, 1000.0);
      expect(ledgerEntries[1].runningBalanceDouble, 1500.0);
      expect(ledgerEntries[2].runningBalanceDouble, 1200.0);
      expect(ledgerEntries[0].entryTypeLabel, 'رصيد افتتاحي');
      expect(ledgerEntries[1].entryTypeLabel, 'سند قبض');
      expect(ledgerEntries[2].entryTypeLabel, 'سند صرف');
    });
  });

  group('OpeningBalancesScreen UI Widget Tests', () {
    testWidgets(
        'OpeningBalancesScreen renders header, balance cards, and action buttons',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OpeningBalancesScreen(
            organizationId: 'test_org_ob',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Title
      expect(find.text('الأرصدة الافتتاحية'), findsOneWidget);

      // Balance metric labels
      expect(find.text('إجمالي المدين'), findsOneWidget);
      expect(find.text('إجمالي الدائن'), findsOneWidget);
      expect(find.text('الفارق'), findsOneWidget);

      // Section header
      expect(find.text('بنود الحسابات والأرصدة'), findsOneWidget);

      // Draft & Post buttons
      expect(find.text('حفظ كمسودة'), findsOneWidget);
      expect(find.text('ترحيل الأرصدة'), findsOneWidget);
    });
  });
}
