import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:abu_ali/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Test navigation across all 5 bottom nav tabs without freeze',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // 1. Check Tab 0
    expect(find.text('أبو علي'), findsOneWidget);

    // 2. Tap Tab 1: Organizations
    final orgTab = find.text('المؤسسات');
    expect(orgTab, findsOneWidget);
    await tester.tap(orgTab);
    await tester.pumpAndSettle();
    expect(find.text('المؤسسات والشركات'), findsOneWidget);

    // 3. Tap Tab 2: Accounts
    final accTab = find.text('الحسابات');
    expect(accTab, findsOneWidget);
    await tester.tap(accTab);
    await tester.pumpAndSettle();
    expect(find.text('دليل الحسابات (شجرة الحسابات)'), findsOneWidget);

    // 4. Tap Tab 3: Reports
    final repTab = find.text('التقارير');
    expect(repTab, findsOneWidget);
    await tester.tap(repTab);
    await tester.pumpAndSettle();
    expect(find.text('التقارير والقوائم المالية'), findsOneWidget);

    // 5. Tap Tab 4: Settings
    final setTab = find.text('الإعدادات');
    expect(setTab, findsOneWidget);
    await tester.tap(setTab);
    await tester.pumpAndSettle();
    expect(find.text('الإعدادات والنظام'), findsOneWidget);

    // 6. Tap Back to Tab 0: Dashboard
    final homeTab = find.text('الرئيسية');
    expect(homeTab, findsOneWidget);
    await tester.tap(homeTab);
    await tester.pumpAndSettle();
    expect(find.text('أبو علي'), findsOneWidget);
  });

  testWidgets(
      'Test Navigator route push and pop does not throw Hero assertion errors',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify Tab 1 (Organizations) and Tab 2 (Accounts) with FABs do not collide when pushing route
    final orgTab = find.text('المؤسسات');
    await tester.tap(orgTab);
    await tester.pumpAndSettle();

    // Tap Tab 4 (Settings)
    final setTab = find.text('الإعدادات');
    await tester.tap(setTab);
    await tester.pumpAndSettle();

    // Dismiss any error SnackBars from uninitialized sqflite in headless test
    final scaffoldMessengers = find.byType(ScaffoldMessenger);
    if (scaffoldMessengers.evaluate().isNotEmpty) {
      tester
          .state<ScaffoldMessengerState>(scaffoldMessengers.first)
          .clearSnackBars();
      await tester.pumpAndSettle();
    }

    // Tap 'حول تطبيق أبو علي للمحاسبة' to push AboutScreen
    final aboutTile = find.text('حول تطبيق أبو علي للمحاسبة');
    expect(aboutTile, findsOneWidget);
    await tester.tap(aboutTile);
    await tester.pumpAndSettle();

    // Verify About screen is pushed without hero collision crash
    expect(find.text('حول التطبيق والنظام'), findsOneWidget);

    // Pop back to settings
    final backBtn = find.byType(BackButton);
    expect(backBtn, findsOneWidget);
    await tester.tap(backBtn);
    await tester.pumpAndSettle();

    // Verify back on settings
    expect(find.text('الإعدادات والنظام'), findsOneWidget);
  });
}
