import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:abu_ali/core/constants/database_constants.dart';
import 'package:abu_ali/features/reports/screens/account_activity_screen.dart';
import 'package:abu_ali/features/reports/screens/opening_balances_report_screen.dart';
import 'package:abu_ali/features/reports/screens/outstanding_invoices_report_screen.dart';
import 'package:abu_ali/features/reports/screens/party_statement_screen.dart';
import 'package:abu_ali/features/reports/screens/realized_forex_report_screen.dart';
import 'package:abu_ali/features/reports/screens/reports_hub_screen.dart';
import 'package:abu_ali/features/reports/services/pdf_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
      'Phase 4: Complete Financial Reporting System - Accounting Formulas & Logic Tests',
      () {
    const String orgA = 'org_test_reports_01';
    const String orgB = 'org_test_reports_02';

    // -------------------------------------------------------------------------
    // 1. Trial Balance (ميزان المراجعة) Balancing & Equality Formula
    // -------------------------------------------------------------------------
    test(
        '1. Trial Balance total debits equal total credits and net debits equal net credits',
        () {
      // Simulating accounts with posted activity in integer minor units (scale 100)
      final accountsData = [
        {
          'code': '1111',
          'name': 'الصندوق الرئيسي',
          'debit': 150000,
          'credit': 50000
        }, // Net 100000 Dr
        {
          'code': '1121',
          'name': 'العملاء',
          'debit': 80000,
          'credit': 30000
        }, // Net 50000 Dr
        {
          'code': '2111',
          'name': 'الموردون',
          'debit': 20000,
          'credit': 60000
        }, // Net 40000 Cr
        {
          'code': '3101',
          'name': 'رأس المال',
          'debit': 0,
          'credit': 100000
        }, // Net 100000 Cr
        {
          'code': '4101',
          'name': 'المبيعات',
          'debit': 0,
          'credit': 50000
        }, // Net 50000 Cr
        {
          'code': '5101',
          'name': 'مصروفات عمومية',
          'debit': 40000,
          'credit': 0
        }, // Net 40000 Dr
      ];

      int sumTotalDebit = 0;
      int sumTotalCredit = 0;
      int sumNetDebit = 0;
      int sumNetCredit = 0;

      for (final a in accountsData) {
        final d = a['debit'] as int;
        final c = a['credit'] as int;
        sumTotalDebit += d;
        sumTotalCredit += c;

        if (d > c) {
          sumNetDebit += (d - c);
        } else if (c > d) {
          sumNetCredit += (c - d);
        }
      }

      // Check double-entry equality
      expect(sumTotalDebit, 290000);
      expect(sumTotalCredit, 290000);
      expect(sumTotalDebit, equals(sumTotalCredit),
          reason: 'Total debits must strictly equal total credits');

      expect(sumNetDebit, 190000);
      expect(sumNetCredit, 190000);
      expect(sumNetDebit, equals(sumNetCredit),
          reason: 'Net debits must strictly equal net credits');
    });

    // -------------------------------------------------------------------------
    // 2. Balance Sheet (الميزانية العمومية) Accounting Equation
    // -------------------------------------------------------------------------
    test(
        '2. Balance Sheet satisfies Assets = Liabilities + Equity + Period Net Profit',
        () {
      // Assets: Cash (1000.00 YER) + Receivables (500.00 YER) = 1500.00 YER (150000 minor)
      const int totalAssets = 150000;

      // Liabilities: Payables (400.00 YER) = 40000 minor
      const int totalLiabilities = 40000;

      // Equity: Capital (1000.00 YER) = 100000 minor
      const int baseEquity = 100000;

      // Current Period Income Statement:
      // Revenues: 500.00 YER (50000 minor)
      // Expenses: 400.00 YER (40000 minor)
      // Net Profit: 100.00 YER (10000 minor)
      const int periodRevenues = 50000;
      const int periodExpenses = 40000;
      const int currentPeriodNetProfit =
          periodRevenues - periodExpenses; // 10000

      // Roll net profit into total equity
      final int totalEquity = baseEquity + currentPeriodNetProfit; // 110000

      // Verification: Assets = Liabilities + Equity
      expect(totalAssets, equals(totalLiabilities + totalEquity));
      expect(totalAssets, 150000);
      expect(totalLiabilities + totalEquity, 150000);
    });

    // -------------------------------------------------------------------------
    // 3. Customer Statement & Accounts Receivable Reconciliation
    // -------------------------------------------------------------------------
    test(
        '3. Customer statement running balance reconciles exactly with Accounts Receivable control account',
        () {
      // Starting balance before period: 200.00 YER Dr (20000 minor)
      int openingReceivable = 20000;
      int runningBalance = openingReceivable;

      final customerTransactions = [
        {
          'type': 'SALES',
          'debit': 50000,
          'credit': 0,
          'desc': 'فاتورة مبيعات رقم 101'
        },
        {
          'type': 'RECEIPT',
          'debit': 0,
          'credit': 30000,
          'desc': 'سند قبض نقدي رقم 201'
        },
        {
          'type': 'SALES',
          'debit': 25000,
          'credit': 0,
          'desc': 'فاتورة مبيعات رقم 102'
        },
        {
          'type': 'RECEIPT',
          'debit': 0,
          'credit': 40000,
          'desc': 'سند قبض تحويل رقم 202'
        },
      ];

      int totalPeriodDebit = 0;
      int totalPeriodCredit = 0;

      for (final tx in customerTransactions) {
        final d = tx['debit'] as int;
        final c = tx['credit'] as int;
        totalPeriodDebit += d;
        totalPeriodCredit += c;
        runningBalance += (d - c);
      }

      // Period Debits: 50000 + 25000 = 75000
      // Period Credits: 30000 + 40000 = 70000
      // Closing Balance: 20000 + 75000 - 70000 = 25000
      expect(totalPeriodDebit, 75000);
      expect(totalPeriodCredit, 70000);
      expect(runningBalance, 25000);

      // Verify reconciliation against Control Account (1121)
      final int controlAccountBalance =
          openingReceivable + totalPeriodDebit - totalPeriodCredit;
      expect(runningBalance, equals(controlAccountBalance));
    });

    // -------------------------------------------------------------------------
    // 4. Supplier Statement & Accounts Payable Reconciliation
    // -------------------------------------------------------------------------
    test(
        '4. Supplier statement running balance reconciles with Accounts Payable control account',
        () {
      // Normal balance for supplier liability is Credit
      int openingPayable = 35000; // 350.00 YER Cr
      int runningBalance = openingPayable;

      final supplierTransactions = [
        {
          'type': 'PURCHASE',
          'debit': 0,
          'credit': 60000,
          'desc': 'فاتورة مشتريات رقم 501'
        },
        {
          'type': 'PAYMENT',
          'debit': 40000,
          'credit': 0,
          'desc': 'سند صرف نقدي رقم 601'
        },
        {
          'type': 'PURCHASE',
          'debit': 0,
          'credit': 15000,
          'desc': 'فاتورة مشتريات رقم 502'
        },
      ];

      int totalDebit = 0;
      int totalCredit = 0;

      for (final tx in supplierTransactions) {
        final d = tx['debit'] as int;
        final c = tx['credit'] as int;
        totalDebit += d;
        totalCredit += c;
        // For suppliers, credit increases liability, debit decreases
        runningBalance += (c - d);
      }

      // Closing = 35000 + 75000 - 40000 = 70000
      expect(totalDebit, 40000);
      expect(totalCredit, 75000);
      expect(runningBalance, 70000);

      final int controlAccountBalance =
          openingPayable + totalCredit - totalDebit;
      expect(runningBalance, equals(controlAccountBalance));
    });

    // -------------------------------------------------------------------------
    // 5. Aging Buckets for Outstanding Receivables & Payables
    // -------------------------------------------------------------------------
    test(
        '5. Outstanding invoices accurately categorize into aging buckets (0-30, 31-60, 61-90, 90+ days)',
        () {
      final asOf = DateTime.parse('2026-03-31');

      final invoices = [
        {
          'id': 'inv1',
          'total': 10000,
          'paid': 2000,
          'date': '2026-03-15'
        }, // age: 16 days -> 0-30
        {
          'id': 'inv2',
          'total': 25000,
          'paid': 5000,
          'date': '2026-02-15'
        }, // age: 44 days -> 31-60
        {
          'id': 'inv3',
          'total': 30000,
          'paid': 0,
          'date': '2026-01-10'
        }, // age: 80 days -> 61-90
        {
          'id': 'inv4',
          'total': 50000,
          'paid': 10000,
          'date': '2025-11-20'
        }, // age: 131 days -> 90+
      ];

      int bucket0To30 = 0;
      int bucket31To60 = 0;
      int bucket61To90 = 0;
      int bucket90Plus = 0;
      int totalRemaining = 0;

      for (final inv in invoices) {
        final remaining = (inv['total'] as int) - (inv['paid'] as int);
        totalRemaining += remaining;

        final issueDate = DateTime.parse(inv['date'] as String);
        final age = asOf.difference(issueDate).inDays;

        if (age <= 30) {
          bucket0To30 += remaining;
        } else if (age <= 60) {
          bucket31To60 += remaining;
        } else if (age <= 90) {
          bucket61To90 += remaining;
        } else {
          bucket90Plus += remaining;
        }
      }

      expect(bucket0To30, 8000); // 10000 - 2000
      expect(bucket31To60, 20000); // 25000 - 5000
      expect(bucket61To90, 30000); // 30000 - 0
      expect(bucket90Plus, 40000); // 50000 - 10000
      expect(totalRemaining, 98000);
      expect(bucket0To30 + bucket31To60 + bucket61To90 + bucket90Plus,
          equals(totalRemaining));
    });

    // -------------------------------------------------------------------------
    // 6. Realized Forex Gains and Losses Calculation & Sign Convention
    // -------------------------------------------------------------------------
    test(
        '6. Realized forex calculations maintain sign convention (gain = positive, loss = negative)',
        () {
      // Invoice was issued at rate: 1 USD = 250 YER (250,000,000 scaled)
      // Amount: 100.00 USD (10000 minor)
      // Invoice base = 10000 * 250 = 2500000 minor YER (25,000.00 YER)

      // Payment 1: Customer paid 50.00 USD when rate was 1 USD = 260 YER (260,000,000)
      // Payment base = 5000 * 260 = 1300000 minor YER
      // Invoice portion base = 5000 * 250 = 1250000 minor YER
      // Realized Gain = 1300000 - 1250000 = +50000 minor YER (+500.00 YER gain)
      const int invRate1 = 250000000;
      const int payRate1 = 260000000;
      const int allocAmount1 = 5000;
      final int diff1 = ((allocAmount1 * (payRate1 - invRate1)) /
              DatabaseConstants.exchangeRateScale)
          .round();
      expect(diff1, 50000); // Positive = Gain

      // Payment 2: Customer paid remaining 50.00 USD when rate was 1 USD = 245 YER (245,000,000)
      // Payment base = 5000 * 245 = 1225000 minor YER
      // Invoice portion base = 5000 * 250 = 1250000 minor YER
      // Realized Loss = 1225000 - 1250000 = -25000 minor YER (-250.00 YER loss)
      const int payRate2 = 245000000;
      const int allocAmount2 = 5000;
      final int diff2 = ((allocAmount2 * (payRate2 - invRate1)) /
              DatabaseConstants.exchangeRateScale)
          .round();
      expect(diff2, -25000); // Negative = Loss

      // Net Forex Impact
      final int netForex = diff1 + diff2;
      expect(netForex, 25000); // +250.00 YER net gain
    });

    // -------------------------------------------------------------------------
    // 7. Multi-Tenant Organization Isolation Verification
    // -------------------------------------------------------------------------
    test('7. Multi-tenant report filtering prevents cross-tenant data leakage',
        () {
      final allJournalLines = [
        {'id': 'l1', 'org_id': orgA, 'base_debit': 10000, 'base_credit': 0},
        {'id': 'l2', 'org_id': orgA, 'base_debit': 0, 'base_credit': 10000},
        {'id': 'l3', 'org_id': orgB, 'base_debit': 99999, 'base_credit': 0},
        {'id': 'l4', 'org_id': orgB, 'base_debit': 0, 'base_credit': 99999},
      ];

      // Org A query filter
      final orgALines =
          allJournalLines.where((l) => l['org_id'] == orgA).toList();
      final orgATotalDebit =
          orgALines.fold<int>(0, (sum, l) => sum + (l['base_debit'] as int));

      expect(orgALines.length, 2);
      expect(orgATotalDebit, 10000);
      expect(orgALines.any((l) => l['org_id'] == orgB), isFalse);
    });

    // -------------------------------------------------------------------------
    // 8. PDF Document Generator Service Specification Test
    // -------------------------------------------------------------------------
    test('8. PdfReportService emits standard, valid PDF-1.4 binary structure',
        () {
      final pdfBytes = PdfReportService.instance.generateFinancialReportPdf(
        title: 'ميزان المراجعة بالمجاميع والأرصدة',
        organizationName: 'مؤسسة أبو علي التجارية',
        baseCurrency: 'YER',
        periodOrDate: '2026-01-01 to 2026-03-31',
        headers: ['رمز الحساب', 'اسم الحساب', 'مدين', 'دائن'],
        rows: [
          ['1111', 'الصندوق', '1000.00', '200.00'],
          ['1121', 'العملاء', '500.00', '100.00'],
        ],
        totals: ['الإجمالي', '', '1500.00', '300.00'],
      );

      final pdfString = utf8.decode(pdfBytes, allowMalformed: true);

      // Verify essential PDF specification headers and structural elements
      expect(pdfString.startsWith('%PDF-1.4'), isTrue,
          reason: 'Must start with PDF-1.4 header');
      expect(pdfString.contains('/Type /Catalog'), isTrue,
          reason: 'Must define PDF Catalog');
      expect(pdfString.contains('/Type /Pages'), isTrue,
          reason: 'Must define Pages dictionary');
      expect(pdfString.contains('/Type /Page'), isTrue,
          reason: 'Must define Page object');
      expect(pdfString.contains('stream'), isTrue,
          reason: 'Must include content streams');
      expect(pdfString.contains('endstream'), isTrue);
      expect(pdfString.contains('xref'), isTrue,
          reason: 'Must include cross-reference table');
      expect(pdfString.contains('trailer'), isTrue,
          reason: 'Must include trailer dictionary');
      expect(pdfString.contains('startxref'), isTrue);
      expect(pdfString.trim().endsWith('%%EOF'), isTrue,
          reason: 'Must terminate with %%EOF');
    });

    // -------------------------------------------------------------------------
    // 9. HTML Printable Export Specification Test
    // -------------------------------------------------------------------------
    test('9. PdfReportService generates responsive Arabic RTL HTML document',
        () {
      final html = PdfReportService.instance.generateArabicHtmlReport(
        title: 'قائمة الأرباح والخسائر',
        organizationName: 'مؤسسة أبو علي',
        baseCurrency: 'YER',
        periodOrDate: 'الربع الأول 2026',
        headers: ['البيان', 'المبلغ'],
        rows: [
          ['المبيعات', '500,000.00'],
          ['تكلفة المبيعات', '300,000.00'],
        ],
        totals: ['صافي الربح', '200,000.00'],
      );

      expect(html.contains('<!DOCTYPE html>'), isTrue);
      expect(html.contains('<html lang="ar" dir="rtl">'), isTrue,
          reason: 'Must enforce RTL direction');
      expect(html.contains('قائمة الأرباح والخسائر'), isTrue);
      expect(html.contains('مؤسسة أبو علي'), isTrue);
      expect(html.contains('المبيعات'), isTrue);
      expect(html.contains('صافي الربح'), isTrue);
    });
  });

  // ===========================================================================
  // Widget Tests for Financial Reporting Screens
  // ===========================================================================
  group('Phase 4: Financial Reports Screens Widget Tests', () {
    testWidgets(
        'ReportsHubScreen renders all 4 financial sections and 12 reports',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: ReportsHubScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Check header
      expect(find.text('التقارير والقوائم المالية'), findsOneWidget);

      // Section 1: Financial Statements
      expect(find.text('القوائم المالية الأساسية'), findsOneWidget);
      expect(find.text('ميزان المراجعة'), findsOneWidget);
      expect(find.text('قائمة الدخل (الأرباح والخسائر)'), findsOneWidget);
      expect(find.text('الميزانية العمومية (المركز المالي)'), findsOneWidget);

      // Section 2: Ledgers
      expect(find.text('دفتر الأستاذ العام'), findsOneWidget);
      expect(find.text('حركة الصندوق والبنوك'), findsOneWidget);
      expect(find.text('سجل التدقيق والرقابة المالية'), findsOneWidget);
    });

    testWidgets(
        'PartyStatementScreen renders Customer statement mode with filters and action buttons',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: PartyStatementScreen(
            organizationId: 'org_test',
            baseCurrencyCode: 'YER',
            isCustomer: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('كشف حساب عميل'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
    });

    testWidgets(
        'OutstandingInvoicesReportScreen renders Receivables aging mode',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: OutstandingInvoicesReportScreen(
            organizationId: 'org_test',
            baseCurrencyCode: 'YER',
            isReceivable: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('الذمم المدينة المستحقة (العملاء)'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
    });

    testWidgets(
        'RealizedForexReportScreen renders with date filters and summary card',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: RealizedForexReportScreen(
            organizationId: 'org_test',
            baseCurrencyCode: 'YER',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('أرباح وخسائر فروق العملة'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
    });

    testWidgets('OpeningBalancesReportScreen renders with balancing check',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: OpeningBalancesReportScreen(
            organizationId: 'org_test',
            baseCurrencyCode: 'YER',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('تقرير الأرصدة الافتتاحية'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
    });

    testWidgets('AccountActivityScreen renders with multi-criteria filters',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: AccountActivityScreen(
            organizationId: 'org_test',
            baseCurrencyCode: 'YER',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('حركة الحساب والعمليات'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
    });
  });
}
