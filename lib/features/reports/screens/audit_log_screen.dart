import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../data/reports_repository.dart';

/// Screen displaying the financial audit trail and system activity logs.
class AuditLogScreen extends StatefulWidget {
  final String organizationId;

  const AuditLogScreen({
    super.key,
    required this.organizationId,
  });

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final ReportsRepository _repo = ReportsRepository();
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
      final list = await _repo.getAuditLogs(widget.organizationId);
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
          title: const Text('سجل التدقيق والرقابة',
              style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadLogs,
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : _logs.isEmpty
                ? const Center(child: Text('لا توجد سجلات تدقيق حتى الآن'))
                : RefreshIndicator(
                    onRefresh: _loadLogs,
                    color: AppColors.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        final action = log['action'] as String;
                        final tableName = log['table_name'] as String;
                        final newValues = log['new_values'] as String?;
                        final createdAt = log['created_at'] as String;

                        Color actionColor;
                        if (action == 'POST') {
                          actionColor = AppColors.success;
                        } else if (action == 'VOID') {
                          actionColor = AppColors.danger;
                        } else if (action == 'UPDATE') {
                          actionColor = const Color(0xFFD97706);
                        } else {
                          actionColor = AppColors.primary;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: actionColor.withValues(
                                              alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          action,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: actionColor,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        tableName,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    createdAt
                                        .split('.')
                                        .first
                                        .replaceAll('T', ' '),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              if (newValues != null &&
                                  newValues.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  newValues,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textPrimary),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
