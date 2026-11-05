import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/models/account_model.dart';
import '../data/settings_repository.dart';

/// Screen managing Fiscal Years, Accounting Periods, and Year-End Closing.
class FiscalPeriodsScreen extends StatefulWidget {
  final String organizationId;

  const FiscalPeriodsScreen({
    super.key,
    required this.organizationId,
  });

  @override
  State<FiscalPeriodsScreen> createState() => _FiscalPeriodsScreenState();
}

class _FiscalPeriodsScreenState extends State<FiscalPeriodsScreen> {
  final SettingsRepository _repo = SettingsRepository();
  final AccountRepository _accountRepo = AccountRepository();

  List<Map<String, dynamic>> _fiscalYears = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadYears();
  }

  Future<void> _loadYears() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repo.getFiscalYears(widget.organizationId);
      if (mounted) {
        setState(() {
          _fiscalYears = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLock(String periodId, bool currentLocked) async {
    try {
      await _repo.togglePeriodLock(
        periodId,
        widget.organizationId,
        !currentLocked,
      );
      await _loadYears();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentLocked
                  ? 'تم فتح الفترة المحاسبية لإدخال القيود'
                  : 'تم قفل الفترة المحاسبية لمنع التعديل',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _showAddYearDialog() async {
    final now = DateTime.now();
    final nameController =
        TextEditingController(text: 'السنة المالية ${now.year}');
    final startController = TextEditingController(text: '${now.year}-01-01');
    final endController = TextEditingController(text: '${now.year}-12-31');
    String? errorText;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إضافة سنة مالية جديدة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم السنة المالية *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: startController,
                    decoration: const InputDecoration(
                      labelText: 'تاريخ البداية (YYYY-MM-DD) *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: endController,
                    decoration: const InputDecoration(
                      labelText: 'تاريخ النهاية (YYYY-MM-DD) *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorText!,
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary),
                onPressed: () async {
                  final name = nameController.text.trim();
                  final start = startController.text.trim();
                  final end = endController.text.trim();

                  if (name.isEmpty || start.isEmpty || end.isEmpty) {
                    setDlgState(
                        () => errorText = 'يرجى تعبئة كافة الحقول المطلوبة');
                    return;
                  }

                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(ctx);

                  try {
                    await _repo.createFiscalYear(
                      organizationId: widget.organizationId,
                      name: name,
                      startDate: start,
                      endDate: end,
                    );
                    navigator.pop();
                    await _loadYears();
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                              'تم إنشاء السنة المالية و12 فترة شهرية بنجاح'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  } catch (e) {
                    setDlgState(() =>
                        errorText = e.toString().replaceAll('Exception: ', ''));
                  }
                },
                child: const Text('إنشاء السنة المالية',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCloseYearDialog(Map<String, dynamic> fy) async {
    final accounts = await _accountRepo.getAccountsFlat(widget.organizationId);
    final equityAccounts =
        accounts.where((a) => a.accountType == 'EQUITY').toList();
    if (equityAccounts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'لا يوجد حساب حقوق ملكية/أرباح محتجزة مسجل لإقفال السنة فيه.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    AccountModel selectedAccount = equityAccounts.first;
    String? errorText;

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('إقفال السنة المالية: ${fy['name']}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'سيقوم النظام بتصفير كافة حسابات الإيرادات والمصروفات، '
                    'وترحيل صافي الربح أو الخسارة إلى حساب الأرباح المحتجزة، وقفل جميع الفترات.',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'اختر حساب الأرباح المحتجزة / حقوق الملكية:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<AccountModel>(
                    value: selectedAccount,
                    decoration:
                        const InputDecoration(border: OutlineInputBorder()),
                    isExpanded: true,
                    items: equityAccounts.map((a) {
                      return DropdownMenuItem(
                        value: a,
                        child: Text('${a.accountCode} - ${a.accountNameAr}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDlgState(() => selectedAccount = val);
                      }
                    },
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorText!,
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(ctx);

                  try {
                    final res = await _repo.performYearEndClosing(
                      fiscalYearId: fy['id'] as String,
                      organizationId: widget.organizationId,
                      retainedEarningsAccountId: selectedAccount.id,
                      narration:
                          'إقفال السنة المالية ${fy['name']} وترحيل الأرباح',
                    );
                    navigator.pop();
                    await _loadYears();
                    if (mounted) {
                      final net = (res['net_profit_loss'] as num) / 100.0;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'تم إقفال السنة بنجاح! صافي النتيجة: ${net.toStringAsFixed(2)}',
                          ),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  } catch (e) {
                    setDlgState(() =>
                        errorText = e.toString().replaceAll('Exception: ', ''));
                  }
                },
                child: const Text('تأكيد الإقفال السنوي',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showReopenYearDialog(Map<String, dynamic> fy) async {
    final reasonController =
        TextEditingController(text: 'مراجعة وتعديل تسويات جردية');
    String? errorText;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('إعادة فتح السنة المالية: ${fy['name']}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'سيتم إلغاء قيد الإقفال السنوي وإعادة فتح الفترات المالية لتسجيل القيود.',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'سبب إعادة الفتح *',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorText!,
                    style:
                        const TextStyle(color: AppColors.danger, fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706)),
                onPressed: () async {
                  final reason = reasonController.text.trim();
                  if (reason.isEmpty) {
                    setDlgState(
                        () => errorText = 'يرجى كتابة سبب إعادة فتح السنة');
                    return;
                  }

                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(ctx);

                  try {
                    await _repo.reopenFiscalYear(
                      fiscalYearId: fy['id'] as String,
                      organizationId: widget.organizationId,
                      reason: reason,
                    );
                    navigator.pop();
                    await _loadYears();
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('تمت إعادة فتح السنة المالية بنجاح'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  } catch (e) {
                    setDlgState(() =>
                        errorText = e.toString().replaceAll('Exception: ', ''));
                  }
                },
                child: const Text('إعادة الفتح',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('السنوات والفترات المالية',
              style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'إضافة سنة مالية',
              onPressed: _showAddYearDialog,
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadYears,
              tooltip: 'تحديث',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('إضافة سنة مالية',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          onPressed: _showAddYearDialog,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : _fiscalYears.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_month_rounded,
                              size: 48, color: AppColors.textSecondary),
                          const SizedBox(height: 12),
                          const Text(
                            'لا توجد سنوات مالية مسجلة بعد.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary),
                            onPressed: _showAddYearDialog,
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text('إضافة سنة مالية الآن',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadYears,
                    color: AppColors.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(
                          left: 16, right: 16, top: 16, bottom: 80),
                      itemCount: _fiscalYears.length,
                      itemBuilder: (context, index) {
                        final fy = _fiscalYears[index];
                        final periods = (fy['periods'] as List)
                            .cast<Map<String, dynamic>>();
                        final bool isClosed = (fy['is_closed'] as int) == 1;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Theme(
                            data: Theme.of(context)
                                .copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              initiallyExpanded: index == 0,
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isClosed
                                      ? const Color(0xFFFEF2F2)
                                      : AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isClosed
                                      ? Icons.lock_clock_rounded
                                      : Icons.calendar_month_rounded,
                                  color: isClosed
                                      ? AppColors.danger
                                      : AppColors.primary,
                                  size: 22,
                                ),
                              ),
                              title: Text(
                                fy['name'] as String,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'من ${fy['start_date']} إلى ${fy['end_date']} • ${isClosed ? "سنة مقفلة" : "سنة نشطة"}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                              children: [
                                const Divider(
                                    height: 1, color: AppColors.border),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'الفترات الشهرية (${periods.length})',
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.darkNavy),
                                      ),
                                      if (!isClosed)
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.danger,
                                            side: const BorderSide(
                                                color: AppColors.danger),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                          ),
                                          icon: const Icon(Icons.lock_rounded,
                                              size: 16),
                                          label: const Text(
                                              'إقفال السنة المالية',
                                              style: TextStyle(fontSize: 12)),
                                          onPressed: () =>
                                              _showCloseYearDialog(fy),
                                        )
                                      else
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                const Color(0xFFD97706),
                                            side: const BorderSide(
                                                color: Color(0xFFD97706)),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                          ),
                                          icon: const Icon(
                                              Icons.lock_open_rounded,
                                              size: 16),
                                          label: const Text('إعادة فتح السنة',
                                              style: TextStyle(fontSize: 12)),
                                          onPressed: () =>
                                              _showReopenYearDialog(fy),
                                        ),
                                    ],
                                  ),
                                ),
                                ...periods.map((p) {
                                  final bool isLocked =
                                      (p['is_locked'] as int) == 1;

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 2),
                                    leading: Icon(
                                      isLocked
                                          ? Icons.lock_outline_rounded
                                          : Icons.lock_open_rounded,
                                      color: isLocked
                                          ? AppColors.warning
                                          : AppColors.success,
                                      size: 20,
                                    ),
                                    title: Text(
                                      p['name'] as String,
                                      style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      '${p['start_date']} إلى ${p['end_date']}',
                                      style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textSecondary),
                                    ),
                                    trailing: Switch(
                                      value: isLocked,
                                      activeColor: AppColors.warning,
                                      onChanged: isClosed
                                          ? null
                                          : (val) => _toggleLock(
                                              p['id'] as String, isLocked),
                                    ),
                                  );
                                }),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
