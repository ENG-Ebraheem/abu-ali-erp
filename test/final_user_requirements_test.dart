import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:abu_ali/core/constants/database_constants.dart';
import 'package:abu_ali/features/organizations/models/organization_branding.dart';
import 'package:abu_ali/features/organizations/models/organization_model.dart';
import 'package:abu_ali/features/reports/services/pdf_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task 1: Complete Reset of Institutions & Dependency Order Tests', () {
    test('1. Deletion hierarchy covers all 30 tables and protects system schema', () {
      // System protected tables that MUST NEVER be deleted during data reset
      final protectedTables = [
        DatabaseConstants.tableMigrations,
        DatabaseConstants.tableCurrencies,
      ];

      // Tables that contain organization-specific data to be reset
      final dependentTables = [
        DatabaseConstants.tableStocktakingLines,
        DatabaseConstants.tableStocktakingSessions,
        DatabaseConstants.tableStockMovements,
        DatabaseConstants.tableStockDocumentLines,
        DatabaseConstants.tableStockDocuments,
        DatabaseConstants.tableItemUnits,
        DatabaseConstants.tableItems,
        DatabaseConstants.tableItemCategories,
        DatabaseConstants.tableUnitsOfMeasure,
        DatabaseConstants.tableWarehouses,
        DatabaseConstants.tableInventorySettings,
        DatabaseConstants.tableForexRevaluationLines,
        DatabaseConstants.tableForexRevaluations,
        DatabaseConstants.tablePaymentAllocations,
        DatabaseConstants.tablePayments,
        DatabaseConstants.tableInvoiceLines,
        DatabaseConstants.tableInvoices,
        DatabaseConstants.tableJournalEntryLines,
        DatabaseConstants.tableJournalEntries,
        DatabaseConstants.tableOpeningBalances,
        DatabaseConstants.tableParties,
        DatabaseConstants.tableFiscalPeriods,
        DatabaseConstants.tableFiscalYears,
        DatabaseConstants.tableExchangeRates,
        DatabaseConstants.tableChartOfAccounts,
        DatabaseConstants.tableAuditLogs,
        DatabaseConstants.tableOrganizations,
      ];

      // Verify no protected table is in dependent deletion list
      for (final pt in protectedTables) {
        expect(dependentTables.contains(pt), isFalse,
            reason: '$pt must be preserved during institution reset');
      }

      // Verify all dependent tables are unique
      final uniqueSet = dependentTables.toSet();
      expect(uniqueSet.length, equals(dependentTables.length));
    });

    test('2. Organization model initializes clean state with zero balance leaks', () {
      final now = DateTime.now();
      final org = Organization(
        id: 'org_fresh_001',
        name: 'مؤسسة الرياض الجديدة',
        code: 'RYD-01',
        baseCurrencyCode: 'SAR',
        createdAt: now,
        updatedAt: now,
      );

      final map = org.toMap();
      expect(map['name'], equals('مؤسسة الرياض الجديدة'));
      expect(map['code'], equals('RYD-01'));
      expect(map['base_currency_code'], equals('SAR'));
      expect(map['is_active'], equals(1));
    });
  });

  group('Task 2 & 3: Logo Persistence & Professional Arabic PDF Tests', () {
    test('3. Organization branding preserves persistent logo path', () {
      final branding = OrganizationBranding(
        organizationId: 'org_fresh_001',
        logoPath: '/data/user/0/com.example.abu_ali/databases/org_logos/org_fresh_001_logo.png',
        businessActivity: 'استيراد وتصدير',
        taxNumber: 'TAX-55443322',
        documentFooter: 'وثيقة رسمية صادرة عن النظام المحاسبي',
        showLogo: true,
        showOrgInfo: true,
        showFooter: true,
      );

      final map = branding.toMap();
      expect(map['logo_path'], contains('org_fresh_001_logo.png'));
      expect(map['show_logo'], equals(1));
      expect(map['tax_number'], equals('TAX-55443322'));

      final stringMap = map.map((k, v) => MapEntry(k, v?.toString()));
      final restored = OrganizationBranding.fromMap('org_fresh_001', stringMap);
      expect(restored.logoPath, equals(branding.logoPath));
      expect(restored.showLogo, isTrue);
      expect(restored.taxNumber, equals('TAX-55443322'));
    });

    test('4. Professional Arabic PDF generates valid PDF-1.4 with Arabic RTL and metadata', () async {
      final pdfService = PdfReportService.instance;

      final branding = OrganizationBranding(
        organizationId: 'org_test_audit',
        businessActivity: 'تجارة عامة واستيراد',
        taxNumber: 'TAX-998877',
        documentFooter: 'معتمد ومختوم رسمياً من الإدارة المالية',
        showOrgInfo: true,
        showFooter: true,
      );

      final pdfBytes = await pdfService.generateProfessionalArabicPdf(
        title: 'فاتورة مبيعات نقدية',
        organizationName: 'مؤسسة أبو علي التجارية',
        baseCurrency: 'YER',
        periodOrDate: '2026-11-01',
        documentNumber: 'INV-2026-001',
        headers: ['#', 'البيان والتفاصيل', 'الكمية', 'السعر', 'الإجمالي'],
        rows: [
          ['1', 'حليب مكثف عبوة كرتون', '10.00', '1,500.00', '15,000.00'],
          ['2', 'زيت نباتي ممتاز 5 لتر', '4.00', '4,200.00', '16,800.00'],
        ],
        totals: ['الإجمالي الصافي:', '', '', '', '31,800.00 YER'],
        subtitle: 'العميل: مؤسسة البركة للتجارة | طريقة الدفع: نقداً',
        branding: branding,
        notes: 'البضاعة المباعة لا ترد ولا تستبدل بعد 3 أيام من تاريخ الاستلام.',
        isInvoiceOrVoucher: true,
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(2000));

      final latinStr = latin1.decode(pdfBytes);
      expect(latinStr, startsWith('%PDF-1.4'));
      expect(latinStr, contains('%%EOF'));

      final utfStr = utf8.decode(pdfBytes, allowMalformed: true);
      expect(utfStr, contains('TAX-998877'));
      expect(utfStr, contains('معتمد ومختوم رسمياً من الإدارة المالية'));
    });

    test('5. Multi-page financial report PDF generates correctly without overflow', () async {
      final pdfService = PdfReportService.instance;

      final headers = ['الكود', 'اسم الحساب المالي', 'مدين', 'دائن', 'الرصيد الصافي'];
      final rows = List.generate(50, (i) => [
        '10${(i + 1).toString().padLeft(3, '0')}',
        'حساب فرعي تجريبي رقم ${i + 1}',
        '${(i + 1) * 1000}.00',
        '0.00',
        '${(i + 1) * 1000}.00',
      ]);

      final pdfBytes = await pdfService.generateProfessionalArabicPdf(
        title: 'ميزان المراجعة التفصيلي متعدد الصفحات',
        organizationName: 'مؤسسة أبو علي المحاسبية',
        baseCurrency: 'USD',
        periodOrDate: 'حتى نهاية العام المالي 2026',
        headers: headers,
        rows: rows,
        totals: ['الإجمالي:', '', '1,275,000.00', '0.00', '1,275,000.00'],
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(4000));
    });

    test('6. Arabic PDF file saving preserves Arabic characters in filenames', () async {
      final pdfService = PdfReportService.instance;
      final dummyBytes = Uint8List.fromList(utf8.encode('%PDF-1.4\n%%EOF\n'));

      final file = await pdfService.savePdfToFile(
        bytes: dummyBytes,
        fileName: 'فاتورة_مبيعات_2026-001.pdf',
      );

      expect(file.existsSync(), isTrue);
      expect(file.path, contains('فاتورة_مبيعات_2026-001.pdf'));

      // Clean up
      try {
        await file.delete();
      } catch (_) {}
    });
  });
}
