import 'package:flutter_test/flutter_test.dart';
import 'package:abu_ali/main.dart';

void main() {
  testWidgets('MyApp displays Main Dashboard with Arabic RTL and core sections',
      (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify Header
    expect(find.text('أبو علي'), findsWidgets);
    expect(find.text('مرحباً بك'), findsOneWidget);
    expect(find.text('إدارة حساباتك بكل سهولة'), findsOneWidget);

    // Verify Organization selector
    expect(find.text('إدارة'), findsOneWidget);

    // Verify Financial Summary
    expect(find.text('المؤشرات المالية'), findsOneWidget);
    expect(find.text('إجمالي الأصول'), findsOneWidget);
    expect(find.text('إجمالي الالتزامات'), findsOneWidget);
    expect(find.text('الإيرادات'), findsOneWidget);
    expect(find.text('المصروفات'), findsOneWidget);

    // Verify Quick Actions
    expect(find.text('إجراءات سريعة'), findsOneWidget);
    expect(find.text('قيد يومية'), findsOneWidget);
    expect(find.text('فاتورة جديدة'), findsOneWidget);
    expect(find.text('تسجيل دفعة'), findsOneWidget);
    expect(find.text('إضافة حساب'), findsOneWidget);

    // Verify Recent Transactions
    expect(find.text('آخر العمليات'), findsOneWidget);
    expect(find.text('عرض الكل'), findsOneWidget);

    // Verify Bottom Navigation items
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('المؤسسات'), findsOneWidget);
    expect(find.text('الحسابات'), findsOneWidget);
    expect(find.text('التقارير'), findsOneWidget);
    expect(find.text('الإعدادات'), findsOneWidget);
  });
}
