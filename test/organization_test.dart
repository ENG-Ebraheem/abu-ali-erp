import 'package:flutter_test/flutter_test.dart';
import 'package:abu_ali/features/organizations/models/organization_model.dart';
import 'package:abu_ali/main.dart';

void main() {
  group('Organization Model & Screen Navigation Tests', () {
    test('Organization model correctly maps to and from SQLite maps', () {
      final now = DateTime.now();
      final org = Organization(
        id: 'org_test_1',
        name: 'مؤسسة التجارة العالمية',
        code: 'GLO-01',
        baseCurrencyCode: 'YER',
        businessType: 'استيراد وتصدير',
        phone: '771234567',
        address: 'صنعاء، شارع الزبيري',
        notes: 'ملاحظات تسجيل',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final map = org.toMap();
      expect(map['id'], equals('org_test_1'));
      expect(map['name'], equals('مؤسسة التجارة العالمية'));
      expect(map['code'], equals('GLO-01'));
      expect(map['base_currency_code'], equals('YER'));
      expect(map['tax_number'], equals('استيراد وتصدير'));
      expect(map['phone'], equals('771234567'));
      expect(map['address'], equals('صنعاء، شارع الزبيري'));
      expect(map['email'], equals('ملاحظات تسجيل'));
      expect(map['is_active'], equals(1));

      final restored = Organization.fromMap(map);
      expect(restored.id, equals(org.id));
      expect(restored.name, equals(org.name));
      expect(restored.code, equals(org.code));
      expect(restored.baseCurrencyCode, equals(org.baseCurrencyCode));
      expect(restored.businessType, equals(org.businessType));
      expect(restored.phone, equals(org.phone));
      expect(restored.address, equals(org.address));
      expect(restored.notes, equals(org.notes));
      expect(restored.isActive, isTrue);
      expect(restored.currencyLabel, equals('ريال يمني (YER)'));
      expect(restored.currencySymbol, equals('ر.ي'));
    });

    test('Organization currencyLabel returns correct localized text', () {
      final now = DateTime.now();
      final orgYer = Organization(
        id: '1',
        name: 'O1',
        code: 'C1',
        baseCurrencyCode: 'YER',
        createdAt: now,
        updatedAt: now,
      );
      final orgUsd = Organization(
        id: '2',
        name: 'O2',
        code: 'C2',
        baseCurrencyCode: 'USD',
        createdAt: now,
        updatedAt: now,
      );
      final orgSar = Organization(
        id: '3',
        name: 'O3',
        code: 'C3',
        baseCurrencyCode: 'SAR',
        createdAt: now,
        updatedAt: now,
      );

      expect(orgYer.currencyLabel, equals('ريال يمني (YER)'));
      expect(orgYer.currencySymbol, equals('ر.ي'));
      expect(orgUsd.currencyLabel, equals('دولار أمريكي (USD)'));
      expect(orgUsd.currencySymbol, equals('\$'));
      expect(orgSar.currencyLabel, equals('ريال سعودي (SAR)'));
      expect(orgSar.currencySymbol, equals('ر.س'));
    });

    testWidgets('Tapping Organizations tab switches to Organizations Screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Ensure initially on Dashboard
      expect(find.text('أبو علي'), findsWidgets);
      expect(find.text('إجراءات سريعة'), findsOneWidget);

      // Tap on 'المؤسسات' navigation item
      await tester.tap(find.text('المؤسسات'));
      await tester.pumpAndSettle();

      // Verify Organizations Screen is displayed
      expect(find.text('المؤسسات والشركات'), findsOneWidget);
      expect(find.text('إضافة مؤسسة'), findsWidgets);
      expect(find.textContaining('الكل'), findsOneWidget);
      expect(find.textContaining('النشطة'), findsOneWidget);
      expect(find.textContaining('المؤرشفة'), findsOneWidget);

      // Tap back to 'الرئيسية'
      await tester.tap(find.text('الرئيسية'));
      await tester.pumpAndSettle();

      // Verify back on Dashboard
      expect(find.text('إجراءات سريعة'), findsOneWidget);
    });
  });
}
