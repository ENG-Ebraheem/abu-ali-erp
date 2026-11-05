import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/journal_repository.dart';
import '../models/journal_entry_model.dart';
import 'create_journal_entry_screen.dart';

/// Screen presenting the full general ledger journal voucher, lines, debit/credit balance, and actions.
class JournalEntryDetailsScreen extends StatefulWidget {
  final String entryId;
  final String organizationId;
  final String baseCurrencyCode;

  const JournalEntryDetailsScreen({
    super.key,
    required this.entryId,
    required this.organizationId,
    required this.baseCurrencyCode,
  });

  @override
  State<JournalEntryDetailsScreen> createState() =>
      _JournalEntryDetailsScreenState();
}

class _JournalEntryDetailsScreenState extends State<JournalEntryDetailsScreen> {
  final JournalRepository _journalRepo = JournalRepository();
  JournalEntryModel? _entry;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntry();
  }

  Future<void> _loadEntry() async {
    setState(() => _isLoading = true);
    try {
      final item = await _journalRepo.getJournalEntryById(
        widget.entryId,
        widget.organizationId,
      );
      if (mounted) {
        setState(() {
          _entry = item;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatMoney(int amountMinor) {
    final double val = amountMinor / 100.0;
    return val.toStringAsFixed(2);
  }

  Future<void> _postEntry() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _journalRepo.postJournalEntry(
          widget.entryId, widget.organizationId);
      await _loadEntry();
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content:
                Text('تم ترحيل القيد المحاسبي بنجاح وتحديث أرصدة الحسابات'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _confirmReverse() async {
    final reasonController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد عكس وإلغاء القيد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'القيود المرحلة لا يمكن حذفها للحفاظ على التسلسل المحاسبي والرقابي. سيتم إنشاء قيد عكسي تلقائياً وإلغاء أثر هذا القيد.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'سبب الإلغاء أو العكس *',
                hintText: 'مثال: خطأ في الحساب / إلغاء المعاملة',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(dialogContext);

              try {
                final revNumber = await _journalRepo.reverseJournalEntry(
                  id: widget.entryId,
                  organizationId: widget.organizationId,
                  reason: reason,
                );
                await _loadEntry();
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                          'تم إلغاء القيد وإنشاء القيد العكسي: $revNumber'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('تأكيد العكس'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDraft() async {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد حذف المسودة'),
        content: const Text('هل أنت متأكد من رغبتك في حذف مسودة هذا القيد؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await _journalRepo.deleteDraftEntry(
                  widget.entryId,
                  widget.organizationId,
                );
                if (mounted) {
                  Navigator.pop(context, true);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف المسودة بنجاح'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_entry == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل القيد')),
        body: const Center(child: Text('لم يتم العثور على القيد المحاسبي')),
      );
    }

    final entry = _entry!;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            entry.entryNumber,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadEntry,
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Header Information Card
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.typeLabel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkNavy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'تاريخ القيد: ${entry.entryDate}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: entry.isPosted
                              ? const Color(0xFFECFDF5)
                              : (entry.isDraft
                                  ? const Color(0xFFFFFBEB)
                                  : const Color(0xFFFEF2F2)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          entry.statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: entry.isPosted
                                ? const Color(0xFF059669)
                                : (entry.isDraft
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFFDC2626)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.description_outlined,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.narration,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (entry.reference != null &&
                      entry.reference!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.link_rounded,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          'المرجع: ${entry.reference!}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 2. Lines Header
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'أسطر القيد المحاسبي (${entry.lines.length})',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNavy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 3. Lines List
            ...entry.lines.map((line) {
              final isDebit = line.baseDebit > 0;
              final amount = isDebit ? line.baseDebit : line.baseCredit;
              final isForeign = line.currencyCode != widget.baseCurrencyCode;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge: Debit / Credit
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDebit
                            ? const Color(0xFFEFF6FF)
                            : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isDebit ? 'مدين' : 'دائن',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color:
                              isDebit ? AppColors.primary : AppColors.success,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Account info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.accountNameAr ?? 'حساب',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkNavy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'رمز الحساب: ${line.accountCode ?? "-"}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontFamily: 'monospace',
                            ),
                          ),
                          if (line.partyNameAr != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'الطرف: ${line.partyNameAr}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7C3AED),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (line.description != null &&
                              line.description!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              line.description!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Amount
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatMoney(amount),
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color:
                                isDebit ? AppColors.primary : AppColors.success,
                          ),
                        ),
                        Text(
                          widget.baseCurrencyCode,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (isForeign) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${_formatMoney(isDebit ? line.foreignDebit : line.foreignCredit)} ${line.currencyCode}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),

            // 4. Totals and Balance Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      entry.isBalanced ? AppColors.success : AppColors.danger,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('إجمالي المدين:',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                      Text(
                        '${_formatMoney(entry.totalBaseDebit)} ${widget.baseCurrencyCode}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('إجمالي الدائن:',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                      Text(
                        '${_formatMoney(entry.totalBaseCredit)} ${widget.baseCurrencyCode}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            entry.isBalanced
                                ? Icons.check_circle_rounded
                                : Icons.error_outline_rounded,
                            color: entry.isBalanced
                                ? AppColors.success
                                : AppColors.danger,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            entry.isBalanced
                                ? 'القيد متزن محاسبياً'
                                : 'القيد غير متزن!',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: entry.isBalanced
                                  ? AppColors.success
                                  : AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'الفرق: ${_formatMoney((entry.totalBaseDebit - entry.totalBaseCredit).abs())}',
                        style: TextStyle(
                          fontSize: 12,
                          color: entry.isBalanced
                              ? AppColors.textSecondary
                              : AppColors.danger,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 5. Action Buttons
            if (entry.isDraft) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: entry.isBalanced ? _postEntry : null,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('ترحيل القيد إلى دفتر الأستاذ العام'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateJournalEntryScreen(
                          organizationId: widget.organizationId,
                          baseCurrencyCode: widget.baseCurrencyCode,
                          entryToEdit: entry,
                        ),
                      ),
                    );
                    if (updated == true) _loadEntry();
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('تعديل المسودة'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _deleteDraft,
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.danger),
                  label: const Text('حذف المسودة',
                      style: TextStyle(color: AppColors.danger)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.danger)),
                ),
              ),
            ] else if (entry.isPosted) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _confirmReverse,
                  icon: const Icon(Icons.undo_rounded, color: AppColors.danger),
                  label: const Text(
                    'عكس وإلغاء القيد (قيد عكسي)',
                    style: TextStyle(
                        color: AppColors.danger, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
