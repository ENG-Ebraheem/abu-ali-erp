import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../exchange_rates/screens/exchange_rates_screen.dart';
import '../../organizations/data/organization_repository.dart';
import '../../organizations/models/organization_model.dart';
import '../services/notification_service.dart';
import 'about_screen.dart';
import 'accountant_profile_screen.dart';
import 'audit_trail_screen.dart';
import 'backup_restore_screen.dart';
import 'fiscal_periods_screen.dart';
import 'notifications_screen.dart';
import 'security_settings_screen.dart';

/// Screen managing system configuration and settings (Tab 4 in bottom navigation).
class SettingsScreen extends StatefulWidget {
  final VoidCallback? onBackToDashboard;

  const SettingsScreen({
    super.key,
    this.onBackToDashboard,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final OrganizationRepository _orgRepo = OrganizationRepository();
  final NotificationService _notificationService = NotificationService.instance;

  Organization? _activeOrg;
  int _activeAlertsCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final activeId = await _orgRepo.getActiveOrganizationId();
      Organization? org;
      if (activeId != null) {
        org = await _orgRepo.getOrganizationById(activeId);
      } else {
        final list = await _orgRepo.getAllOrganizations(includeArchived: false);
        if (list.isNotEmpty) org = list.first;
      }

      int alertsCount = 0;
      try {
        final alerts = await _notificationService.getActiveAlerts(org?.id);
        alertsCount = alerts.length;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _activeOrg = org ??
              Organization(
                id: 'default',
                name: 'المؤسسة النشطة',
                code: 'MAIN',
                baseCurrencyCode: 'YER',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
          _activeAlertsCount = alertsCount;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _activeOrg = Organization(
            id: 'default',
            name: 'المؤسسة النشطة',
            code: 'MAIN',
            baseCurrencyCode: 'YER',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          _isLoading = false;
        });
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
          leading: widget.onBackToDashboard != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: widget.onBackToDashboard,
                )
              : null,
          title: const Text(
            'الإعدادات والنظام',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkNavy,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadData,
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.primary,
                child: ListView(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 96,
                  ),
                  children: [
                    // 1. Active Organization Overview Card
                    Container(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: 96,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.domain_rounded,
                                color: AppColors.primary, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _activeOrg?.name ?? 'المؤسسة النشطة',
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.darkNavy,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'العملة الأساسية: ${_activeOrg?.currencyLabel ?? "ريال يمني (YER)"}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'نشط',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section: Accounting Operations
                    _buildSectionHeader(
                        'إعدادات المحاسبة والتشغيل', AppColors.primary),
                    const SizedBox(height: 10),

                    _buildSettingCard(
                      title: 'السنوات والفترات المالية',
                      subtitle:
                          'إدارة الفترات المحاسبية، قفل الشهور، وإقفال السنة وترحيل الأرباح',
                      icon: Icons.calendar_month_rounded,
                      color: const Color(0xFF2563EB),
                      bgColor: const Color(0xFFEFF6FF),
                      onTap: () {
                        if (_activeOrg != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FiscalPeriodsScreen(
                                organizationId: _activeOrg!.id,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 10),

                    _buildSettingCard(
                      title: 'أسعار صرف العملات الأجنبية',
                      subtitle:
                          'تحديث أسعار صرف الريال السعودي والدولار وحاسبة التحويل',
                      icon: Icons.currency_exchange_rounded,
                      color: const Color(0xFFD97706),
                      bgColor: const Color(0xFFFFFBEB),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ExchangeRatesScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    _buildSettingCard(
                      title: 'الملف المهني للمحاسب',
                      subtitle:
                          'اسم المحاسب، رقم الترخيص، بيانات التواصل، وإقرار الاعتماد',
                      icon: Icons.badge_rounded,
                      color: const Color(0xFF0284C7),
                      bgColor: const Color(0xFFF0F9FF),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AccountantProfileScreen(
                              organizationId: _activeOrg?.id,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    _buildSettingCard(
                      title: 'مركز التنبيهات والإشعارات',
                      subtitle:
                          'الفواتير المستحقة، اقتراب نهاية الفترات، وتذكيرات النسخ',
                      icon: Icons.notifications_active_rounded,
                      color: const Color(0xFFEA580C),
                      bgColor: const Color(0xFFFFF7ED),
                      badgeText:
                          _activeAlertsCount > 0 ? '$_activeAlertsCount' : null,
                      badgeColor: AppColors.danger,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NotificationsScreen(
                              organizationId: _activeOrg?.id,
                            ),
                          ),
                        ).then((_) => _loadData());
                      },
                    ),
                    const SizedBox(height: 20),

                    // Section: Security & System Health
                    _buildSectionHeader('الأمان وصحة البيانات والرقابة',
                        const Color(0xFF059669)),
                    const SizedBox(height: 10),

                    _buildSettingCard(
                      title: 'فحص سلامة قاعدة البيانات والنسخ الاحتياطي',
                      subtitle:
                          'فحص النزاهة، إنشاء نسخة ببصمة SHA-256، والاستعادة الآمنة',
                      icon: Icons.storage_rounded,
                      color: const Color(0xFF059669),
                      bgColor: const Color(0xFFECFDF5),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BackupRestoreScreen(
                              organizationId: _activeOrg?.id,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    _buildSettingCard(
                      title: 'تصفير كافة المنشآت والبيانات المحاسبية',
                      subtitle:
                          'إنشاء نسخة احتياطية آمنة أولاً وتصفير المنشآت والقيود للبدء من الصفر',
                      icon: Icons.delete_sweep_rounded,
                      color: AppColors.danger,
                      bgColor: const Color(0xFFFEF2F2),
                      onTap: _confirmResetAllData,
                    ),
                    const SizedBox(height: 10),

                    _buildSettingCard(
                      title: 'حول تطبيق أبو علي للمحاسبة',
                      subtitle:
                          'معايير النظام المحاسبي، الترخيص، والتوافق مع Android',
                      icon: Icons.info_outline_rounded,
                      color: const Color(0xFF7C3AED),
                      bgColor: const Color(0xFFF5F3FF),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AboutScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    _buildSettingCard(
                      title: 'الأمان وقفل التطبيق (PIN)',
                      subtitle:
                          'رمز مرور PIN مشفر SHA-256، البصمة الحيوية، ومهلة القفل',
                      icon: Icons.security_rounded,
                      color: const Color(0xFF0D9488),
                      bgColor: const Color(0xFFF0FDFA),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SecuritySettingsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    _buildSettingCard(
                      title: 'سجل التدقيق والرقابة (Audit Trail)',
                      subtitle:
                          'تتبع كافة عمليات النظام وتعديلات القيود والسنوات المالية',
                      icon: Icons.history_edu_rounded,
                      color: const Color(0xFF4F46E5),
                      bgColor: const Color(0xFFEEF2FF),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AuditTrailScreen(
                              organizationId: _activeOrg?.id,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    _buildSettingCard(
                      title: 'تسجيل الخروج',
                      subtitle:
                          'إنهاء الجلسة الحالية والعودة لشاشة تسجيل الدخول',
                      icon: Icons.logout_rounded,
                      color: AppColors.danger,
                      bgColor: AppColors.dangerLight,
                      onTap: _handleLogout,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _confirmResetAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.danger),
              SizedBox(width: 8),
              Text('تصفير كافة البيانات والمنشآت'),
            ],
          ),
          content: const Text(
            'تحذير: سيتم إنشاء نسخة احتياطية أولاً تلقائياً، ثم حذف كافة المنشآت والقيود والفواتير والحسابات القديمة نهائياً للبدء من الصفر.\n\nهل ترغب بالاستمرار؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد التصفير والبدء من جديد'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final res = await _orgRepo.resetAllInstitutionsAndAccountingData(
          createBackupFirst: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'تم تصفير البيانات بنجاح. تم حفظ نسخة احتياطية: ${res['backup_file'] ?? ''}'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ أثناء التصفير: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: AppColors.danger),
              SizedBox(width: 8),
              Text('تأكيد تسجيل الخروج'),
            ],
          ),
          content: const Text(
              'هل أنت متأكد من رغبتك في تسجيل الخروج من جلسة العمل الحالية؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تسجيل الخروج',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true && mounted) {
      await AuthService.instance.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Widget _buildSectionHeader(String title, Color barColor) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.bold,
            color: AppColors.darkNavy,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    String? badgeText,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkNavy,
                ),
              ),
            ),
            if (badgeText != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor ?? AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary, height: 1.3),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded,
            size: 16, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}
