import 'package:flutter_test/flutter_test.dart';
import 'package:abu_ali/features/parties/models/party_model.dart';
import 'package:abu_ali/features/exchange_rates/models/exchange_rate_model.dart';
import 'package:abu_ali/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Group 1: Parties Model Tests', () {
    test('PartyModel serializes and deserializes properly with balance', () {
      final model = PartyModel(
        id: 'party_001',
        organizationId: 'org_main',
        code: 'CUST-001',
        partyType: 'CUSTOMER',
        nameAr: 'مؤسسة الأمل التجارية',
        nameEn: 'Al-Amal Trading',
        phone: '777123456',
        email: 'info@alamal.com',
        creditLimit: 5000000, // 50,000.00
        defaultCurrencyCode: 'YER',
        isActive: true,
        createdAt: '2026-11-01T00:00:00Z',
        updatedAt: '2026-11-01T00:00:00Z',
        balanceBase: 2500000,
        transactionCount: 4,
      );

      final map = model.toMap();
      expect(map['id'], 'party_001');
      expect(map['party_type'], 'CUSTOMER');
      expect(map['credit_limit'], 5000000);
      expect(map['is_active'], 1);

      final restored = PartyModel.fromMap({
        ...map,
        'calculated_balance': 2500000,
        'tx_count': 4,
      });

      expect(restored.nameAr, 'مؤسسة الأمل التجارية');
      expect(restored.isCustomer, isTrue);
      expect(restored.isSupplier, isFalse);
      expect(restored.typeLabel, 'عميل');
      expect(restored.balanceBase, 2500000);
      expect(restored.transactionCount, 4);
    });

    test('PartyModel distinguishes supplier and dual types', () {
      final supplier = PartyModel(
        id: 's1',
        organizationId: 'org_main',
        code: 'SUPP-001',
        partyType: 'SUPPLIER',
        nameAr: 'شركة التوريد المتحدة',
        createdAt: '',
        updatedAt: '',
      );
      expect(supplier.isSupplier, isTrue);
      expect(supplier.isCustomer, isFalse);
      expect(supplier.typeLabel, 'مورد');

      final dual = PartyModel(
        id: 'd1',
        organizationId: 'org_main',
        code: 'BOTH-001',
        partyType: 'BOTH',
        nameAr: 'مجموعة التجارة المتبادلة',
        createdAt: '',
        updatedAt: '',
      );
      expect(dual.isSupplier, isTrue);
      expect(dual.isCustomer, isTrue);
      expect(dual.typeLabel, 'عميل ومورد');
    });
  });

  group('Group 1: Exchange Rates Model Tests', () {
    test('ExchangeRateModel calculates decimal rates and formatted text', () {
      final rate = ExchangeRateModel(
        id: 'rate_usd_yer',
        organizationId: 'org_main',
        fromCurrencyCode: 'USD',
        toCurrencyCode: 'YER',
        rateScaled: 535500000, // 535.500000
        rateDate: '2026-11-01',
        createdAt: '2026-11-01T00:00:00Z',
      );

      expect(rate.rateAsDouble, closeTo(535.5, 0.0001));
      expect(rate.formattedRate, '535.5000');

      final map = rate.toMap();
      expect(map['rate_scaled'], 535500000);

      final restored = ExchangeRateModel.fromMap(map);
      expect(restored.fromCurrencyCode, 'USD');
      expect(restored.toCurrencyCode, 'YER');
      expect(restored.rateAsDouble, closeTo(535.5, 0.0001));
    });
  });

  group('Group 1: Accounts Tab Navigation', () {
    testWidgets('Tapping Accounts tab switches to Accounts Screen',
        (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Find Accounts bottom navigation tab
      final accountsTabFinder = find.text('الحسابات');
      expect(accountsTabFinder, findsOneWidget);

      await tester.tap(accountsTabFinder);
      await tester.pumpAndSettle();

      // Accounts screen appbar or title should be visible
      expect(find.text('دليل الحسابات (شجرة الحسابات)'), findsOneWidget);
    });
  });
}
