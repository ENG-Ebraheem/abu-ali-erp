import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:abu_ali/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Group 3: Reports Navigation & Hub Tests', () {
    testWidgets('Tapping Reports tab in bottom nav opens Reports Hub',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Find Reports bottom navigation item
      final reportsTab = find.text('التقارير');
      expect(reportsTab, findsOneWidget);

      await tester.tap(reportsTab);
      await tester.pumpAndSettle();

      // Assert header
      expect(find.text('التقارير والقوائم المالية'), findsOneWidget);

      // Assert core financial report entries
      expect(find.text('ميزان المراجعة'), findsOneWidget);
      expect(find.text('قائمة الدخل (الأرباح والخسائر)'), findsOneWidget);
      expect(find.text('الميزانية العمومية (المركز المالي)'), findsOneWidget);
      expect(find.text('دفتر الأستاذ العام'), findsOneWidget);
      expect(find.text('حركة الصندوق والبنوك'), findsOneWidget);
      expect(find.text('سجل التدقيق والرقابة المالية'), findsOneWidget);
    });
  });
}
