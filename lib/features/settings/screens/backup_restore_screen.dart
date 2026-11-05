import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/settings_repository.dart';
import '../services/backup_service.dart';

/// Screen managing SQLite database health, SHA-256 backup creation, and atomic restore.
class BackupRestoreScreen extends StatefulWidget {
  final String? organizationId;

  const BackupRestoreScreen({
    super.key,
    this.organizationId,
  });

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final SettingsRepository _repo = SettingsRepository();
  final BackupService _backupService = BackupService.instance;

  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _backups = [];
  bool _isLoading = true;
  bool _isBackingUp = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final res = await _repo.getDatabaseStats(widget.organizationId);
      final backups = await _backupService.getAvailableBackups();
      if (mounted) {
        setState(() {
          _stats = res;
          _backups = backups;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCreateBackup() async {
    setState(() => _isBackingUp = true);
    try {
      final backup = await _backupService.createBackup(
          organizationId: widget.organizationId);
      await _loadData();
      if (mounted) {
        final sha = (backup['sha256'] as String).substring(0, 16);
        final sizeKb =
            ((backup['size_bytes'] as int) / 1024).toStringAsFixed(1);

        showDialog(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.success),
                  SizedBox(width: 8),
                  Text('تم إنشاء النسخة الاحتياطية بنجاح'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الملف: ${backup['file_name']}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('الحجم: $sizeKb كيلوبايت'),
                  const SizedBox(height: 6),
                  Text('بصمة الأمان (SHA-256): $sha...'),
                  const SizedBox(height: 8),
                  Text('المسار: ${backup['file_path']}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('حسناً',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إنشاء النسخة الاحتياطية: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _handleRestoreBackup(Map<String, dynamic> backup) async {
    final fileName = backup['file_name'] as String;
    final filePath = backup['file_path'] as String;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.danger),
              SizedBox(width: 8),
              Text('تأكيد استعادة قاعدة البيانات'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('أنت على وشك استعادة قاعدة البيانات من الملف:\n$fileName'),
              const SizedBox(height: 12),
              const Text(
                'ملاحظة أمان فائقة:\n'
                'يقوم النظام تلقائياً بأخذ نسخة تراجع أمان (Safety Snapshot) '
                'من بياناتك الحالية قبل أي استبدال. في حال كان ملف النسخة تالفاً '
                'سيتم التراجع تلقائياً دون أي فقدان للبيانات.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('استعادة الآن',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final res = await _backupService.restoreBackup(
        filePath,
        organizationId: widget.organizationId,
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] as String? ?? 'تمت الاستعادة بنجاح.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isHealthy = _stats?['integrity_status'] == 'ok';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('صحة قاعدة البيانات والنسخ الاحتياطي',
              style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadData,
              tooltip: 'إعادة فحص',
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
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 1. Health Status Banner
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isHealthy
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: isHealthy
                                ? AppColors.success
                                : AppColors.danger),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isHealthy
                                ? Icons.verified_user_rounded
                                : Icons.warning_rounded,
                            color: isHealthy
                                ? AppColors.success
                                : AppColors.danger,
                            size: 32,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isHealthy
                                      ? 'قاعدة البيانات سليمة ومتوافقة 100%'
                                      : 'تحذير في فحص السلامة!',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isHealthy
                                        ? const Color(0xFF065F46)
                                        : const Color(0xFF991B1B),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'SQLite 3.32.2 • الإصدار: V${_stats?['db_version'] ?? 3} • قيود المفاتيح الأجنبية: مفعلة',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 2. Immediate Backup Action Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.backup_rounded,
                                  color: AppColors.primary, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'النسخ الاحتياطي الفوري (Snapshot)',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkNavy,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'إنشاء نسخة متكاملة ومتحقق منها ببصمة SHA-256 مع تسوية ملف WAL لضمان اكتمال كل القيود والفواتير.',
                            style: TextStyle(
                                fontSize: 12.5, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed:
                                  _isBackingUp ? null : _handleCreateBackup,
                              icon: _isBackingUp
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.cloud_upload_outlined,
                                      color: Colors.white),
                              label: Text(
                                _isBackingUp
                                    ? 'جارِ إنشاء النسخة...'
                                    : 'إنشاء نسخة احتياطية الآن',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. Available Backups List
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 18,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'النسخ المتوفرة محلياً (${_backups.length})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkNavy,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_backups.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Center(
                          child: Text(
                            'لا توجد نسخ احتياطية مسجلة بعد. اضغط الزر أعلاه لإنشاء أول نسخة.',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else
                      ...List.generate(_backups.length, (idx) {
                        final b = _backups[idx];
                        final name = b['file_name'] as String;
                        final size = b['size_mb'] as String;
                        final date = (b['modified_at'] as String)
                            .replaceFirst('T', ' ')
                            .split('.')
                            .first;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.storage_rounded,
                                    color: Color(0xFF2563EB), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.darkNavy,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$size ميجابايت • $date',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                ),
                                icon:
                                    const Icon(Icons.restore_rounded, size: 18),
                                label: const Text('استعادة',
                                    style: TextStyle(fontSize: 12)),
                                onPressed: () => _handleRestoreBackup(b),
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 20),

                    // 4. Database Records Summary Card
                    Row(
                      children: [
                        Container(
                            width: 4,
                            height: 18,
                            decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 8),
                        const Text(
                          'إحصائيات السجلات المحفوظة',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkNavy),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Column(
                        children: [
                          _countRow(
                              'المؤسسات المسجلة',
                              '${_stats?['organizations_count'] ?? 0} مؤسسة',
                              Icons.domain_rounded),
                          const Divider(height: 16),
                          _countRow(
                              'حسابات الدليل المحاسبي',
                              '${_stats?['accounts_count'] ?? 0} حساب',
                              Icons.account_tree_rounded),
                          const Divider(height: 16),
                          _countRow(
                              'قيود اليومية العامة',
                              '${_stats?['journal_entries_count'] ?? 0} قيد',
                              Icons.receipt_long_rounded),
                          const Divider(height: 16),
                          _countRow(
                              'أسطر حركات الأستاذ العام',
                              '${_stats?['journal_lines_count'] ?? 0} حركة',
                              Icons.list_alt_rounded),
                          const Divider(height: 16),
                          _countRow(
                              'الفواتير (مبيعات ومشتريات)',
                              '${_stats?['invoices_count'] ?? 0} فاتورة',
                              Icons.shopping_bag_rounded),
                          const Divider(height: 16),
                          _countRow(
                              'سندات القبض والصرف',
                              '${_stats?['payments_count'] ?? 0} سند',
                              Icons.payments_rounded),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 5. File Path & Local Backup Info
                    Row(
                      children: [
                        Container(
                            width: 4,
                            height: 18,
                            decoration: BoxDecoration(
                                color: const Color(0xFFD97706),
                                borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 8),
                        const Text(
                          'مسار ملف قاعدة البيانات المحلي',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkNavy),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ملف SQLite مشفر ومحفوظ محلياً في ذاكرة التخزين الآمنة للجهاز (أوفلاين بالكامل):',
                            style: TextStyle(
                                fontSize: 12.5, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _stats?['db_path'] as String? ??
                                        'abu_ali.db',
                                    style: const TextStyle(
                                        fontSize: 12, fontFamily: 'monospace'),
                                    textDirection: TextDirection.ltr,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded,
                                      size: 18, color: AppColors.primary),
                                  tooltip: 'نسخ المسار',
                                  onPressed: () {
                                    final path =
                                        _stats?['db_path'] as String? ??
                                            'abu_ali.db';
                                    Clipboard.setData(
                                        ClipboardData(text: path));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'تم نسخ مسار ملف قاعدة البيانات')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _countRow(String label, String count, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(fontSize: 13.5, color: AppColors.darkNavy)),
        const Spacer(),
        Text(count,
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: AppColors.darkNavy)),
      ],
    );
  }
}
