import 'package:sqflite/sqflite.dart';
import '../../../core/constants/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../data/settings_repository.dart';
import 'backup_service.dart';

/// Notification Alert Model
class AppAlert {
  final String id;
  final String title;
  final String message;
  final String type; // ACTION_REQUIRED, WARNING, INFO
  final String severity; // danger, warning, info
  final String? targetRoute;
  final DateTime createdAt;

  const AppAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.severity,
    this.targetRoute,
    required this.createdAt,
  });
}

/// Offline Business Notifications & Alerts Engine.
/// Detects overdue invoices, expiring fiscal periods, and missing backups.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final SettingsRepository _settingsRepo = SettingsRepository();

  Future<Database> get _db async => await _dbHelper.database;

  /// Fetches all active business alerts across the organization.
  Future<List<AppAlert>> getActiveAlerts(String? organizationId) async {
    final alerts = <AppAlert>[];
    try {
      final db = await _db;
      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T').first;

      // 1. OVERDUE CUSTOMER INVOICES
      try {
        final whereClause = organizationId != null && organizationId.isNotEmpty
            ? "invoice_type = 'SALES' AND payment_status != 'PAID' AND due_date < ? AND organization_id = ?"
            : "invoice_type = 'SALES' AND payment_status != 'PAID' AND due_date < ?";
        final whereArgs = organizationId != null && organizationId.isNotEmpty
            ? [todayStr, organizationId]
            : [todayStr];

        final overdueInvoices = await db.query(
          DatabaseConstants.tableInvoices,
          where: whereClause,
          whereArgs: whereArgs,
          orderBy: 'due_date ASC',
          limit: 10,
        );

        for (final inv in overdueInvoices) {
          final invNum = inv['invoice_number'] as String? ?? '';
          final dueDateStr = inv['due_date'] as String? ?? todayStr;
          final dueDate = DateTime.tryParse(dueDateStr) ?? now;
          final daysOverdue = now.difference(dueDate).inDays;
          final total = (inv['total_amount'] as num?)?.toInt() ?? 0;
          final paid = (inv['paid_amount'] as num?)?.toInt() ?? 0;
          final remaining = (total - paid) / 100.0;
          final currency = inv['currency_code'] as String? ?? 'YER';

          alerts.add(AppAlert(
            id: 'alert_inv_${inv['id']}',
            title: 'فاتورة مبيعات متأخرة السداد (#$invNum)',
            message:
                'مستحقة منذ $daysOverdue يوماً. المبلغ المتبقي: ${remaining.toStringAsFixed(2)} $currency.',
            type: 'ACTION_REQUIRED',
            severity: 'danger',
            targetRoute: 'invoices',
            createdAt: now,
          ));
        }
      } catch (_) {}

      // 2. FISCAL PERIOD EXPIRING SOON (within 7 days)
      try {
        if (organizationId != null && organizationId.isNotEmpty) {
          final in7Days = now
              .add(const Duration(days: 7))
              .toIso8601String()
              .split('T')
              .first;
          final expiringPeriods = await db.rawQuery('''
          SELECT name, end_date FROM ${DatabaseConstants.tableFiscalPeriods}
          WHERE organization_id = ? 
            AND is_closed = 0 
            AND end_date >= ? 
            AND end_date <= ?
        ''', [organizationId, todayStr, in7Days]);

          for (final p in expiringPeriods) {
            final pName = p['name'] as String? ?? 'الفترة المالية';
            final pEnd = p['end_date'] as String? ?? '';
            alerts.add(AppAlert(
              id: 'alert_period_$pEnd',
              title: 'اقتراب نهاية الفترة المالية',
              message:
                  '$pName تنتهي بتاريخ $pEnd. يرجى مراجعة الحسابات والتأكد من ترحيل القيود.',
              type: 'WARNING',
              severity: 'warning',
              targetRoute: 'fiscal_periods',
              createdAt: now,
            ));
          }
        }
      } catch (_) {}

      // 3. BACKUP REMINDER (> 7 days or never)
      try {
        final lastBackupStr = await _settingsRepo.getAppSetting(
          BackupService.keyLastBackupTimestamp,
          organizationId: organizationId,
        );

        if (lastBackupStr == null || lastBackupStr.isEmpty) {
          alerts.add(AppAlert(
            id: 'alert_backup_never',
            title: 'تنبيه أمان البيانات',
            message:
                'لم يتم إنشاء أي نسخة احتياطية حتى الآن. بادر بأخذ نسخة لحماية سجلاتك المالية.',
            type: 'INFO',
            severity: 'info',
            targetRoute: 'backup',
            createdAt: now,
          ));
        } else {
          final lastBackupDate = DateTime.tryParse(lastBackupStr);
          if (lastBackupDate != null &&
              now.difference(lastBackupDate).inDays >= 7) {
            final days = now.difference(lastBackupDate).inDays;
            alerts.add(AppAlert(
              id: 'alert_backup_stale',
              title: 'تذكير النسخ الاحتياطي',
              message:
                  'مرّت $days يوماً منذ آخر نسخة احتياطية. يوصى بعمل نسخة دورية جديدة.',
              type: 'INFO',
              severity: 'info',
              targetRoute: 'backup',
              createdAt: now,
            ));
          }
        }
      } catch (_) {}
    } catch (_) {}

    return alerts;
  }
}
