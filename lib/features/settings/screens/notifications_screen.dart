import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../services/notification_service.dart';
import 'backup_restore_screen.dart';
import 'fiscal_periods_screen.dart';

/// Screen displaying business alerts and in-app notifications.
class NotificationsScreen extends StatefulWidget {
  final String? organizationId;

  const NotificationsScreen({super.key, this.organizationId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService.instance;
  List<AppAlert> _alerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    final list =
        await _notificationService.getActiveAlerts(widget.organizationId);
    if (mounted) {
      setState(() {
        _alerts = list;
        _isLoading = false;
      });
    }
  }

  void _onAlertTap(AppAlert alert) {
    if (alert.targetRoute == 'backup') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              BackupRestoreScreen(organizationId: widget.organizationId),
        ),
      );
    } else if (alert.targetRoute == 'fiscal_periods') {
      if (widget.organizationId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                FiscalPeriodsScreen(organizationId: widget.organizationId!),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'مركز التنبيهات والإشعارات',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkNavy,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadAlerts,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : _alerts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                                Icons.check_circle_outline_rounded,
                                color: AppColors.success,
                                size: 44),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'لا توجد تنبيهات نشطة',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkNavy,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'جميع الحسابات، الفواتير، والفترات المحاسبية منتظمة ومحدثة.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _alerts.length,
                    itemBuilder: (ctx, i) {
                      final a = _alerts[i];
                      Color badgeBg;
                      Color badgeText;
                      String typeLabel;
                      IconData icon;

                      if (a.severity == 'danger') {
                        badgeBg = const Color(0xFFFEE2E2);
                        badgeText = AppColors.danger;
                        typeLabel = 'إجراء مطلوب';
                        icon = Icons.warning_rounded;
                      } else if (a.severity == 'warning') {
                        badgeBg = const Color(0xFFFEF3C7);
                        badgeText = const Color(0xFFD97706);
                        typeLabel = 'تحذير';
                        icon = Icons.error_outline_rounded;
                      } else {
                        badgeBg = const Color(0xFFEFF6FF);
                        badgeText = const Color(0xFF2563EB);
                        typeLabel = 'تنبيه';
                        icon = Icons.info_outline_rounded;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: InkWell(
                          onTap: a.targetRoute != null
                              ? () => _onAlertTap(a)
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(icon, color: badgeText, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        a.title,
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.darkNavy,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: badgeBg,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        typeLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: badgeText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  a.message,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                                if (a.targetRoute != null) ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        'عرض التفاصيل والمتابعة',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.arrow_forward_rounded,
                                          size: 14, color: AppColors.primary),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
