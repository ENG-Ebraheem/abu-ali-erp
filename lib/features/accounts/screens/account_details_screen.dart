import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../journal/screens/journal_entry_details_screen.dart';
import '../data/account_repository.dart';
import '../models/account_model.dart';
import '../widgets/account_form_sheet.dart';

/// Detailed view of a single account in the Chart of Accounts.
class AccountDetailsScreen extends StatefulWidget {
  final AccountModel account;
  final VoidCallback? onAccountChanged;

  const AccountDetailsScreen({
    super.key,
    required this.account,
    this.onAccountChanged,
  });

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  final AccountRepository _repository = AccountRepository();
  late AccountModel _account;
  bool _isLoading = true;
  bool _hasPostedTransactions = false;
  List<AccountLedgerEntryModel> _ledgerEntries = [];

  @override
  void initState() {
    super.initState();
    _account = widget.account;
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    try {
      final updated = await _repository.getAccountById(
        _account.id,
        _account.organizationId,
      );
      final hasTx = await _repository.hasPostedTransactions(
        _account.id,
        _account.organizationId,
      );
      final ledger = await _repository.getAccountLedgerEntries(
        _account.id,
        _account.organizationId,
      );

      if (mounted) {
        setState(() {
          if (updated != null) _account = updated;
          _hasPostedTransactions = hasTx;
          _ledgerEntries = ledger;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openEdit() async {
    final all = await _repository.getAccountsFlat(_account.organizationId);
    if (!mounted) return;

    AccountFormSheet.show(
      context: context,
      organizationId: _account.organizationId,
      defaultCurrency: _account.currencyCode ?? 'YER',
      account: _account,
      availableParents: all,
      onSave: (updated) async {
        await _repository.updateAccount(updated);
        await _refresh();
        widget.onAccountChanged?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث بيانات الحساب بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
    );
  }

  Future<void> _toggleActive() async {
    final newStatus = !_account.isActive;
    await _repository.toggleAccountActive(
      _account.id,
      _account.organizationId,
      newStatus,
    );
    await _refresh();
    widget.onAccountChanged?.call();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus ? 'تم تفعيل الحساب' : 'تم تعطيل الحساب'),
          backgroundColor: newStatus ? AppColors.success : AppColors.warning,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBalance = _account.baseBalance != 0;
    final isNegative = _account.baseBalance < 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${_account.accountCode} - ${_account.accountNameAr}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _openEdit,
            tooltip: 'تعديل الحساب',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance & Nature Highlight Card
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'الرصيد المحاسبي الصافي',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${hasBalance ? (_account.baseBalance / 100).toStringAsFixed(2) : "0.00"} ر.ي',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: isNegative
                                          ? AppColors.danger
                                          : AppColors.darkNavy,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _account.isActive
                                      ? AppColors.successLight
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _account.isActive ? 'حساب نشط' : 'حساب معطل',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _account.isActive
                                        ? AppColors.success
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _metricBox(
                                'إجمالي المدين',
                                '${(_account.totalDebit / 100).toStringAsFixed(2)} ر.ي',
                                AppColors.primary,
                              ),
                              _metricBox(
                                'إجمالي الدائن',
                                '${(_account.totalCredit / 100).toStringAsFixed(2)} ر.ي',
                                AppColors.success,
                              ),
                              _metricBox(
                                'طبيعة الرصيد',
                                _account.natureNameAr,
                                AppColors.darkNavy,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Specification Card
                    const Text(
                      'خصائص وتصنيف الحساب',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkNavy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _specRow('نوع الحساب', _account.typeNameAr),
                          const Divider(height: 18),
                          _specRow(
                            'عملة الحساب',
                            _account.currencyCode ?? 'متعدد العملات / الأساسية',
                          ),
                          const Divider(height: 18),
                          _specRow(
                            'حساب نقدية / بنك',
                            _account.isCashBank ? 'نعم (صندوق / بنك)' : 'لا',
                          ),
                          const Divider(height: 18),
                          _specRow(
                            'حساب نظامي أساسي',
                            _account.isSystem ? 'نعم (حساب نظام محمي)' : 'لا',
                          ),
                          const Divider(height: 18),
                          _specRow(
                            'حركات محاسبية مقيدة',
                            _hasPostedTransactions
                                ? 'يوجد قيود مرحلة'
                                : 'لا يوجد حركات مسجلة',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Actions Card
                    const Text(
                      'الإجراءات',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkNavy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _account.isActive
                                    ? AppColors.warningLight
                                    : AppColors.successLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _account.isActive
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: _account.isActive
                                    ? AppColors.warning
                                    : AppColors.success,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              _account.isActive
                                  ? 'تعطيل الحساب'
                                  : 'إعادة تفعيل الحساب',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              _account.isActive
                                  ? 'منع استخدامه في سندات وقيود جديدة'
                                  : 'إتاحة الحساب في القيود والفواتير',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                            ),
                            onTap: _toggleActive,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Ledger Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
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
                            const Text(
                              'كشف حركات الحساب (سجل الأستاذ)',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkNavy,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_ledgerEntries.length} حركة مرحّلة',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_ledgerEntries.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Center(
                          child: Text(
                            'لا توجد حركات أو قيود مرحّلة على هذا الحساب بعد',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      ..._ledgerEntries.map((entry) => _buildLedgerCard(entry)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLedgerCard(AccountLedgerEntryModel entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => JournalEntryDetailsScreen(
                entryId: entry.journalEntryId,
                organizationId: _account.organizationId,
                baseCurrencyCode: _account.currencyCode ?? 'YER',
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        entry.entryTypeLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.entryNumber,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkNavy,
                      ),
                    ),
                  ],
                ),
                Text(
                  entry.entryDate,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (entry.narration.isNotEmpty || entry.partyNameAr != null) ...[
              const SizedBox(height: 6),
              Text(
                entry.partyNameAr != null
                    ? '${entry.partyNameAr!} • ${entry.narration}'
                    : entry.narration,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (entry.baseDebit > 0)
                      Text(
                        'مدين: +${entry.baseDebitDouble.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    if (entry.baseDebit > 0 && entry.baseCredit > 0)
                      const SizedBox(width: 12),
                    if (entry.baseCredit > 0)
                      Text(
                        'دائن: -${entry.baseCreditDouble.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                  ],
                ),
                Text(
                  'الرصيد: ${entry.runningBalanceDouble.toStringAsFixed(2)} ر.ي',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNavy,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricBox(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _specRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: AppColors.darkNavy,
          ),
        ),
      ],
    );
  }
}
