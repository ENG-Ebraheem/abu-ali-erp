import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/settings_repository.dart';

/// Screen displaying immutable audit trail records and system logs.
class AuditTrailScreen extends StatefulWidget {
  final String? organizationId;

  const AuditTrailScreen({super.key, this.organizationId});

  @override
  State<AuditTrailScreen> createState() => _AuditTrailScreenState();
}

class _AuditTrailScreenState extends State<AuditTrailScreen> {
  final SettingsRepository _settingsRepo = SettingsRepository();
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final list = await _settingsRepo.getAuditLogs(
        organizationId: widget.organizationId,
        limit: 150,
      );
      if (mounted) {
        setState(() {
          _logs = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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
            'سجل التدقيق والرقابة (Audit Trail)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkNavy,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadLogs,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : _logs.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد سجلات تدقيق مسجلة حتى الآن.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _logs.length,
                    itemBuilder: (ctx, i) {
                      final item = _logs[i];
                      final action = item['action'] as String? ?? 'LOG';
                      final table = item['table_name'] as String? ?? '';
                      final recordId = item['record_id'] as String? ?? '';
                      final createdAt = item['created_at'] as String? ?? '';
                      final newVals = item['new_values'] as String? ?? '';

                      Color actionColor;
                      Color actionBg;
                      String actionLabel;

                      if (action == 'POST' || action == 'INSERT') {
                        actionColor = AppColors.success;
                        actionBg = const Color(0xFFECFDF5);
                        actionLabel =
                            action == 'POST' ? 'ترحيل / إقفال' : 'إضافة جديدة';
                      } else if (action == 'VOID' || action == 'DELETE') {
                        actionColor = AppColors.danger;
                        actionBg = const Color(0xFFFEE2E2);
                        actionLabel =
                            action == 'VOID' ? 'إلغاء / إعادة فتح' : 'حذف';
                      } else if (action == 'BACKUP_CREATED') {
                        actionColor = const Color(0xFF2563EB);
                        actionBg = const Color(0xFFEFF6FF);
                        actionLabel = 'نسخة احتياطية';
                      } else if (action == 'RESTORE_COMPLETED') {
                        actionColor = const Color(0xFF7C3AED);
                        actionBg = const Color(0xFFF5F3FF);
                        actionLabel = 'استعادة قاعدة بيانات';
                      } else {
                        actionColor = const Color(0xFFD97706);
                        actionBg = const Color(0xFFFFFBEB);
                        actionLabel = 'تعديل';
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: actionBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    actionLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: actionColor,
                                    ),
                                  ),
                                ),
                                Text(
                                  createdAt
                                      .replaceFirst('T', ' ')
                                      .split('.')
                                      .first,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'الجدول: $table • المعرف: $recordId',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkNavy,
                              ),
                            ),
                            if (newVals.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                newVals,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                  fontFamily: 'monospace',
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
