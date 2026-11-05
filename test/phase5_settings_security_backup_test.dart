import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:abu_ali/features/settings/services/security_service.dart';
import 'package:abu_ali/features/settings/services/notification_service.dart';
import 'package:abu_ali/features/settings/screens/accountant_profile_screen.dart';
import 'package:abu_ali/features/settings/screens/security_settings_screen.dart';
import 'package:abu_ali/features/settings/screens/app_lock_screen.dart';
import 'package:abu_ali/features/settings/screens/notifications_screen.dart';
import 'package:abu_ali/features/settings/screens/audit_trail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 5 & 6: Cryptographic Security Engine Tests', () {
    test(
        'Pure-Dart SHA-256 complies with NIST FIPS 180-4 standard test vectors',
        () {
      // Vector 1: Empty string
      final hashEmpty = SecurityService.computeSha256(utf8.encode(''));
      expect(
        hashEmpty.toLowerCase(),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );

      // Vector 2: 'abc'
      final hashAbc = SecurityService.computeSha256(utf8.encode('abc'));
      expect(
        hashAbc.toLowerCase(),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );

      // Vector 3: Longer standard string
      const testStr =
          'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq';
      final hashLong = SecurityService.computeSha256(utf8.encode(testStr));
      expect(
        hashLong.toLowerCase(),
        '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
      );
    });

    test('Cryptographic salt generation produces unique random hex salts', () {
      final s1 = SecurityService.instance.generateSalt();
      final s2 = SecurityService.instance.generateSalt();

      expect(s1.length, 32);
      expect(s2.length, 32);
      expect(s1, isNot(equals(s2)));
    });

    test('Salted PIN hashing produces reproducible hashes with salt protection',
        () {
      const pin = '1234';
      final salt = SecurityService.instance.generateSalt();

      final hash1 = SecurityService.instance.hashPin(pin, salt);
      final hash2 = SecurityService.instance.hashPin(pin, salt);
      expect(hash1, equals(hash2));
      expect(hash1.length, 64);

      // Different salt with same PIN produces completely different hash
      final differentSalt = SecurityService.instance.generateSalt();
      final hashDifferent =
          SecurityService.instance.hashPin(pin, differentSalt);
      expect(hash1, isNot(equals(hashDifferent)));

      // Different PIN with same salt produces different hash
      final hashOtherPin = SecurityService.instance.hashPin('9999', salt);
      expect(hash1, isNot(equals(hashOtherPin)));
    });
  });

  group('Phase 5 & 6: Business Notifications & Alerts Engine Models', () {
    test('AppAlert model correctly holds severity and routes', () {
      final now = DateTime.now();
      final alert = AppAlert(
        id: 'alert_inv_101',
        title: 'فاتورة متأخرة السداد (#INV-2026-001)',
        message: 'مستحقة منذ 15 يوماً بمبلغ 4,500.00 YER',
        type: 'ACTION_REQUIRED',
        severity: 'danger',
        targetRoute: 'invoices',
        createdAt: now,
      );

      expect(alert.id, 'alert_inv_101');
      expect(alert.title, contains('INV-2026-001'));
      expect(alert.type, 'ACTION_REQUIRED');
      expect(alert.severity, 'danger');
      expect(alert.targetRoute, 'invoices');
      expect(alert.createdAt, now);
    });
  });

  group('Phase 5 & 6: UI Screens & Keypad Verification', () {
    testWidgets(
        'AppLockScreen renders logo, 4 PIN dots, numeric keypad and biometric trigger',
        (tester) async {
      bool unlocked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AppLockScreen(onUnlocked: () => unlocked = true),
        ),
      );
      await tester.pumpAndSettle();

      // Brand & title
      expect(find.text('أبو علي للمحاسبة'), findsOneWidget);
      expect(find.text('أدخل رمز PIN لإلغاء قفل النظام'), findsOneWidget);

      // All digits 0-9 present on keypad
      for (int i = 0; i <= 9; i++) {
        expect(find.text('$i'), findsOneWidget);
      }

      // Biometric and backspace buttons
      expect(find.byIcon(Icons.fingerprint_rounded), findsOneWidget);
      expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);

      // Tapping digits enters PIN
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('3'));
      await tester.pump();

      // Tap backspace deletes last digit
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();

      expect(unlocked, isFalse);
    });

    testWidgets('AccountantProfileScreen renders with RTL and core fields',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AccountantProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الملف المهني للمحاسب'), findsOneWidget);
      expect(find.text('اسم المحاسب الكامل *'), findsOneWidget);
      expect(find.text('المسمى المهني / الوظيفي *'), findsOneWidget);
      expect(find.text('حفظ بيانات المحاسب'), findsOneWidget);
    });

    testWidgets(
        'SecuritySettingsScreen renders PIN status, biometrics switch and privacy disclosure',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SecuritySettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الأمان وقفل التطبيق'), findsOneWidget);
      expect(find.text('رمز قفل التطبيق (PIN)'), findsOneWidget);
      expect(find.text('بصمة الإصبع / المصادقة الحيوية'), findsOneWidget);
      expect(find.text('إقرار الخصوصية والأمان المحلي 100%'), findsOneWidget);
    });

    testWidgets('NotificationsScreen renders empty state or alerts list',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NotificationsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('مركز التنبيهات والإشعارات'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });

    testWidgets('AuditTrailScreen renders with RTL and refresh button',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AuditTrailScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('سجل التدقيق والرقابة (Audit Trail)'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });
  });
}
