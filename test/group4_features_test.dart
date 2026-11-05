import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:abu_ali/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Group 4: Settings & System Health Tests', () {
    testWidgets('Tapping Settings tab in bottom nav opens Settings Screen',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Find Settings bottom navigation item
      final settingsTab = find.text('الإعدادات');
      expect(settingsTab, findsOneWidget);

      await tester.tap(settingsTab);
      await tester.pumpAndSettle();

      // Assert header
      expect(find.text('الإعدادات والنظام'), findsOneWidget);

      // Assert core settings tiles
      expect(find.text('السنوات والفترات المالية'), findsOneWidget);
      expect(find.text('فحص سلامة قاعدة البيانات والنسخ الاحتياطي'),
          findsOneWidget);
      expect(find.text('أسعار صرف العملات الأجنبية'), findsOneWidget);
      expect(find.text('حول تطبيق أبو علي للمحاسبة'), findsOneWidget);
    });
  });
}
