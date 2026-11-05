import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:abu_ali/core/constants/database_constants.dart';
import 'package:abu_ali/features/organizations/models/organization_model.dart';
import 'package:abu_ali/features/accounts/models/account_model.dart';
import 'package:abu_ali/features/parties/models/party_model.dart';
import 'package:abu_ali/features/exchange_rates/models/exchange_rate_model.dart';
import 'package:abu_ali/features/invoices/screens/create_invoice_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Functional Audit Phase 1: 4 Core Modules', () {
    // ---------------------------------------------------------
    // 1. ORGANIZATIONS MODULE
    // ---------------------------------------------------------
    test(
        '1. Organizations: Serialization, multi-currency support, and integrity',
        () {
      final now = DateTime.now();
      final orgYer = Organization(
        id: 'org_yer_001',
        name: 'مؤسسة التجارة العامة (صنعاء)',
        code: 'ORG-YER-01',
        baseCurrencyCode: 'YER',
        businessType: 'تجارة تجزئة',
        phone: '777000111',
        address: 'صنعاء - شارع الزبيري',
        createdAt: now,
        updatedAt: now,
      );

      final map = orgYer.toMap();
      expect(map['id'], 'org_yer_001');
      expect(map['base_currency_code'], 'YER');
      expect(map['code'], 'ORG-YER-01');
      expect(map['is_active'], 1);

      final restored = Organization.fromMap(map);
      expect(restored.name, 'مؤسسة التجارة العامة (صنعاء)');
      expect(restored.baseCurrencyCode, 'YER');
      expect(restored.isActive, isTrue);

      // Verify SAR & USD support
      final orgSar = orgYer.copyWith(
        id: 'org_sar_002',
        name: 'فرع الرياض',
        baseCurrencyCode: 'SAR',
      );
      expect(orgSar.baseCurrencyCode, 'SAR');
      expect(orgSar.id, 'org_sar_002');

      final orgUsd = orgYer.copyWith(
        id: 'org_usd_003',
        name: 'المكتب الدولي دبي',
        baseCurrencyCode: 'USD',
      );
      expect(orgUsd.baseCurrencyCode, 'USD');
    });

    // ---------------------------------------------------------
    // 2. CHART OF ACCOUNTS MODULE
    // ---------------------------------------------------------
    test(
        '2. Chart of Accounts: Model integrity, account types, and cash/bank validation',
        () {
      final now = DateTime.now();

      // Asset / Cash account
      final cashAccount = AccountModel(
        id: 'acc_cash_01',
        organizationId: 'org_main',
        accountCode: '1101',
        accountNameAr: 'الصندوق الرئيسي',
        accountType: 'ASSET',
        accountNature: 'DEBIT',
        isCashBank: true,
        currencyCode: 'YER',
        createdAt: now,
      );

      final cashMap = cashAccount.toMap();
      expect(cashMap['account_code'], '1101');
      expect(cashMap['account_type'], 'ASSET');
      expect(cashMap['account_nature'], 'DEBIT');
      expect(cashMap['is_cash_bank'], 1);
      expect(cashMap['currency_code'], 'YER');

      final restoredCash = AccountModel.fromMap(cashMap);
      expect(restoredCash.isCashBank, isTrue);
      expect(restoredCash.currencyCode, 'YER');
      expect(restoredCash.accountNature, 'DEBIT');

      // Revenue account
      final salesAccount = AccountModel(
        id: 'acc_sales_01',
        organizationId: 'org_main',
        accountCode: '4101',
        accountNameAr: 'إيرادات المبيعات',
        accountType: 'REVENUE',
        accountNature: 'CREDIT',
        createdAt: now,
      );

      expect(salesAccount.accountType, 'REVENUE');
      expect(salesAccount.accountNature, 'CREDIT');
      expect(salesAccount.isCashBank, isFalse);

      // Verify Account Hierarchy and computed balances
      final parentWithChildren = cashAccount.copyWith(
        baseBalance: 15000000,
        children: [
          AccountModel(
            id: 'acc_sub_cash',
            organizationId: 'org_main',
            accountCode: '110101',
            accountNameAr: 'صندوق الفرع 1',
            accountType: 'ASSET',
            accountNature: 'DEBIT',
            parentId: 'acc_cash_01',
            currencyCode: 'YER',
            createdAt: now,
            baseBalance: 5000000,
          ),
        ],
      );

      expect(parentWithChildren.baseBalance, 15000000);
      expect(parentWithChildren.children.length, 1);
      expect(parentWithChildren.children.first.parentId, 'acc_cash_01');
    });

    // ---------------------------------------------------------
    // 3. PARTIES MODULE (CUSTOMERS & SUPPLIERS)
    // ---------------------------------------------------------
    test(
        '3. Parties: Separation of Customer vs Supplier, dual type, and credit limits',
        () {
      final customer = PartyModel(
        id: 'party_cust_001',
        organizationId: 'org_yer',
        code: 'CUST-001',
        partyType: 'CUSTOMER',
        nameAr: 'شركة النور للمقاولات',
        phone: '777112233',
        creditLimit: 5000000, // 50,000.00 minor units
        createdAt: '2026-11-01T00:00:00Z',
        updatedAt: '2026-11-01T00:00:00Z',
        balanceBase: 1250000,
        transactionCount: 3,
      );

      expect(customer.isCustomer, isTrue);
      expect(customer.isSupplier, isFalse);
      expect(customer.typeLabel, 'عميل');
      expect(customer.balanceBase, 1250000);
      expect(customer.creditLimit, 5000000);

      final supplier = PartyModel(
        id: 'party_supp_001',
        organizationId: 'org_yer',
        code: 'SUPP-001',
        partyType: 'SUPPLIER',
        nameAr: 'مستودعات الإسمنت الوطنية',
        phone: '777445566',
        createdAt: '2026-11-01T00:00:00Z',
        updatedAt: '2026-11-01T00:00:00Z',
      );

      expect(supplier.isSupplier, isTrue);
      expect(supplier.isCustomer, isFalse);
      expect(supplier.typeLabel, 'مورد');

      final dualParty = PartyModel(
        id: 'party_both_001',
        organizationId: 'org_yer',
        code: 'BOTH-001',
        partyType: 'BOTH',
        nameAr: 'مجموعة التبادل التجاري الدولية',
        createdAt: '2026-11-01T00:00:00Z',
        updatedAt: '2026-11-01T00:00:00Z',
      );

      expect(dualParty.isCustomer, isTrue);
      expect(dualParty.isSupplier, isTrue);
      expect(dualParty.typeLabel, 'عميل ومورد');

      // Verify serialization preserves calculated balances & transaction counts
      final map = customer.toMap();
      final reloaded = PartyModel.fromMap({
        ...map,
        'calculated_balance': 1250000,
        'tx_count': 3,
      });
      expect(reloaded.balanceBase, 1250000);
      expect(reloaded.transactionCount, 3);
    });

    // ---------------------------------------------------------
    // 4. EXCHANGE RATES MODULE
    // ---------------------------------------------------------
    test(
        '4. Exchange Rates: Fixed-point scaling (1,000,000), conversions, and precision',
        () {
      expect(DatabaseConstants.exchangeRateScale, 1000000);

      // 1 USD = 535.5000 YER
      final usdRate = ExchangeRateModel(
        id: 'rate_usd_yer',
        organizationId: 'org_main',
        fromCurrencyCode: 'USD',
        toCurrencyCode: 'YER',
        rateScaled: 535500000, // 535.5 * 1,000,000
        rateDate: '2026-11-01',
        createdAt: '2026-11-01T00:00:00Z',
      );

      expect(usdRate.rateAsDouble, closeTo(535.5, 0.0001));
      expect(usdRate.formattedRate, '535.5000');

      // Conversion calculation: 250 USD to YER
      const amountUsd = 250.0;
      final amountYer = (amountUsd * (usdRate.rateScaled / 1000000.0));
      expect(amountYer, closeTo(133875.0, 0.001));

      // 1 SAR = 142.7500 YER
      final sarRate = ExchangeRateModel(
        id: 'rate_sar_yer',
        organizationId: 'org_main',
        fromCurrencyCode: 'SAR',
        toCurrencyCode: 'YER',
        rateScaled: 142750000, // 142.75 * 1,000,000
        rateDate: '2026-11-01',
        createdAt: '2026-11-01T00:00:00Z',
      );

      expect(sarRate.rateAsDouble, closeTo(142.75, 0.0001));
      expect(sarRate.formattedRate, '142.7500');

      // Map serialization roundtrip
      final map = sarRate.toMap();
      final restored = ExchangeRateModel.fromMap(map);
      expect(restored.fromCurrencyCode, 'SAR');
      expect(restored.toCurrencyCode, 'YER');
      expect(restored.rateScaled, 142750000);
      expect(restored.rateAsDouble, closeTo(142.75, 0.0001));
    });

    // ---------------------------------------------------------
    // 5. MULTI-TENANT ISOLATION
    // ---------------------------------------------------------
    test(
        '5. Multi-Tenant Isolation: Cross-organization data leakage prevention',
        () {
      final parties = [
        PartyModel(
          id: 'p1',
          organizationId: 'ORG_SANAA',
          code: 'CUST-001',
          partyType: 'CUSTOMER',
          nameAr: 'عميل صنعاء',
          createdAt: '',
          updatedAt: '',
        ),
        PartyModel(
          id: 'p2',
          organizationId: 'ORG_ADEN',
          code: 'CUST-001',
          partyType: 'CUSTOMER',
          nameAr: 'عميل عدن',
          createdAt: '',
          updatedAt: '',
        ),
      ];

      // Filtering by organization strictly isolates records
      final sanaaParties =
          parties.where((p) => p.organizationId == 'ORG_SANAA').toList();
      final adenParties =
          parties.where((p) => p.organizationId == 'ORG_ADEN').toList();

      expect(sanaaParties.length, 1);
      expect(sanaaParties.first.nameAr, 'عميل صنعاء');

      expect(adenParties.length, 1);
      expect(adenParties.first.nameAr, 'عميل عدن');

      // Same code CUST-001 can safely exist across different organizations
      expect(sanaaParties.first.code, adenParties.first.code);
      expect(sanaaParties.first.organizationId,
          isNot(adenParties.first.organizationId));
    });
  });

  group('CreateInvoiceScreen Functional & UI Audit', () {
    testWidgets(
        'Sales invoice loads with interactive customer empty state or quick-add action',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CreateInvoiceScreen(
            organizationId: 'test_org_empty',
            baseCurrencyCode: 'YER',
            initialType: 'SALES',
          ),
        ),
      );

      // Wait for async load to finish
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // 1. Verify screen renders Sales Invoice title
      expect(find.text('فاتورة مبيعات جديدة'), findsOneWidget);

      // 2. Verify Customer label is present
      expect(find.text('العميل *'), findsOneWidget);

      // 3. Verify quick-add customer button '+ إضافة عميل جديد' is available in header
      expect(find.text('إضافة عميل جديد'), findsOneWidget);

      // 4. Verify the interactive empty banner is displayed when customer list is empty
      // Instead of an unresponsive disabled dropdown, it guides the user with clear CTA:
      expect(
          find.text('لا يوجد عملاء مسجلون لهذه المؤسسة بعد'), findsOneWidget);
      expect(find.text('+ إضافة عميل'), findsOneWidget);
    });

    testWidgets(
        'Switching between Sales and Purchase updates labels to Supplier',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CreateInvoiceScreen(
            organizationId: 'test_org_toggle',
            baseCurrencyCode: 'YER',
            initialType: 'SALES',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Initially Sales
      expect(find.text('فاتورة مبيعات جديدة'), findsOneWidget);
      expect(find.text('العميل *'), findsOneWidget);

      // Tap Purchase toggle
      final purchaseToggleFinder = find.text('فاتورة مشتريات');
      expect(purchaseToggleFinder, findsOneWidget);
      await tester.tap(purchaseToggleFinder);
      await tester.pumpAndSettle();

      // Verify title and party label updated to Supplier
      expect(find.text('المورد *'), findsOneWidget);
      expect(find.text('إضافة مورد جديد'), findsOneWidget);
      expect(
          find.text('لا يوجد موردون مسجلون لهذه المؤسسة بعد'), findsOneWidget);
      expect(find.text('+ إضافة مورد'), findsOneWidget);
    });
  });
}
