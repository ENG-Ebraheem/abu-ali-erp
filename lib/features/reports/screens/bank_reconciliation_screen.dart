import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/models/account_model.dart';

/// Screen for reconciling bank statements against general ledger cash/bank transactions.
/// Helps accountants identify in-transit deposits, outstanding checks, and bank fee variances.
class BankReconciliationScreen extends StatefulWidget {
  final String organizationId;
  final String baseCurrencyCode;

  const BankReconciliationScreen({
    super.key,
    required this.organizationId,
    required this.baseCurrencyCode,
  });

  @override
  State<BankReconciliationScreen> createState() =>
      _BankReconciliationScreenState();
}

class _ReconciliationItem {
  final String lineId;
  final String entryDate;
  final String entryNumber;
  final String description;
  final int baseDebit;
  final int baseCredit;
  bool isCleared;

  _ReconciliationItem({
    required this.lineId,
    required this.entryDate,
    required this.entryNumber,
    required this.description,
    required this.baseDebit,
    required this.baseCredit,
    this.isCleared = false,
  });

  int get netAmount => baseDebit - baseCredit;
}

class _BankReconciliationScreenState extends State<BankReconciliationScreen> {
  final AccountRepository _accountRepo = AccountRepository();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<AccountModel> _bankAccounts = [];
  AccountModel? _selectedAccount;
  String _asOfDate = DateTime.now().toIso8601String().split('T').first;

  final TextEditingController _statementBalanceController =
      TextEditingController(text: '0.00');

  List<_ReconciliationItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void dispose() {
    _statementBalanceController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    try {
      final list = await _accountRepo.getCashBankAccounts(widget.organizationId);
      if (!mounted) return;
      setState(() {
        _bankAccounts = list;
        if (list.isNotEmpty) {
          _selectedAccount = list.first;
        }
      });
      if (_selectedAccount != null) {
        await _loadTransactions();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTransactions() async {
    if (_selectedAccount == null) return;
    setState(() => _isLoading = true);

    try {
      final db = await _dbHelper.database;
      final rows = await db.rawQuery('''
        SELECT 
          jel.id AS line_id,
          je.entry_date,
          je.entry_number,
          COALESCE(jel.description, je.narration) AS description,
          jel.base_debit,
          jel.base_credit
        FROM ${DatabaseConstants.tableJournalEntryLines} jel
        INNER JOIN ${DatabaseConstants.tableJournalEntries} je 
          ON je.id = jel.journal_entry_id 
          AND je.organization_id = jel.organization_id 
          AND je.status = 'POSTED'
          AND je.entry_date <= ?
        WHERE jel.account_id = ? AND jel.organization_id = ?
        ORDER BY je.entry_date ASC, je.entry_number ASC
      ''', [_asOfDate, _selectedAccount!.id, widget.organizationId]);

      final loaded = rows.map((r) {
        return _ReconciliationItem(
          lineId: r['line_id'] as String,
          entryDate: r['entry_date'] as String,
          entryNumber: r['entry_number'] as String,
          description: (r['description'] as String?) ?? 'حركة بنكية',
          baseDebit: (r['base_debit'] as num).toInt(),
          baseCredit: (r['base_credit'] as num).toInt(),
          isCleared: true, // By default mark posted lines as cleared
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _items = loaded;
        _isLoading = false;
        // Pre-fill statement balance with the net cleared book balance
        final netMinor = loaded.fold(0, (sum, i) => sum + i.netAmount);
        _statementBalanceController.text = (netMinor / 100.0).toStringAsFixed(2);
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _statementBalanceMinor {
    final val = double.tryParse(_statementBalanceController.text.trim()) ?? 0.0;
    return (val * 100).round();
  }

  int get _clearedBalanceMinor {
    return _items
        .where((i) => i.isCleared)
        .fold(0, (sum, i) => sum + i.netAmount);
  }

  int get _unclearedDepositsMinor {
    return _items
        .where((i) => !i.isCleared && i.baseDebit > 0)
        .fold(0, (sum, i) => sum + i.baseDebit);
  }

  int get _unclearedChecksMinor {
    return _items
        .where((i) => !i.isCleared && i.baseCredit > 0)
        .fold(0, (sum, i) => sum + i.baseCredit);
  }

  int get _varianceMinor => _statementBalanceMinor - _clearedBalanceMinor;

  @override
  Widget build(BuildContext context) {
    final isMatched = _varianceMinor == 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'مذكرة التسوية البنكية (Reconciliation)',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.darkNavy,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Filter header
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: AppColors.surface,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                value: _selectedAccount?.id,
                                decoration: InputDecoration(
                                  labelText: 'الحساب البنكي / الصندوق',
                                  prefixIcon: const Icon(Icons.account_balance_rounded, size: 20),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                items: _bankAccounts.map((a) {
                                  return DropdownMenuItem(
                                    value: a.id,
                                    child: Text(
                                      '${a.accountCode} - ${a.accountNameAr}',
                                      style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedAccount =
                                        _bankAccounts.firstWhere((a) => a.id == val);
                                  });
                                  _loadTransactions();
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: 'حتى تاريخ',
                                  prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                                controller: TextEditingController(text: _asOfDate),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.tryParse(_asOfDate) ?? DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2050),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _asOfDate = picked.toIso8601String().split('T').first;
                                    });
                                    _loadTransactions();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Statement ending balance input
                        TextFormField(
                          controller: _statementBalanceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'رصيد كشف الحساب البنكي الفعلي (Statement Ending Balance)',
                            suffixText: widget.baseCurrencyCode,
                            prefixIcon: const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Reconciliation Summary Card
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isMatched ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isMatched ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                      ),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isMatched ? 'التسوية متطابقة تماماً (متوازنة)' : 'يوجد فارق تسوية بحاجة لمراجعة',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: isMatched ? const Color(0xFF065F46) : const Color(0xFF92400E),
                              ),
                            ),
                            Icon(
                              isMatched ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                              color: isMatched ? AppColors.success : AppColors.warning,
                              size: 22,
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildMetric('رصيد الدفاتر المطابق', _clearedBalanceMinor),
                            _buildMetric('رصيد كشف البنك', _statementBalanceMinor),
                            _buildMetric('الفارق (الانحراف)', _varianceMinor,
                                isHighlight: true, isError: !isMatched),
                          ],
                        ),
                        if (_unclearedDepositsMinor > 0 || _unclearedChecksMinor > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'إيداعات معلقة بالطريق: ${AppFormatters.formatCurrency(_unclearedDepositsMinor, currencySymbol: widget.baseCurrencyCode)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              Text(
                                'شيكات لم تصرف بعد: ${AppFormatters.formatCurrency(_unclearedChecksMinor, currencySymbol: widget.baseCurrencyCode)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Transaction list header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'حركات الحساب (${_items.length} حركة مسجلة)',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkNavy,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final allCleared = _items.every((i) => i.isCleared);
                            setState(() {
                              for (final i in _items) {
                                i.isCleared = !allCleared;
                              }
                            });
                          },
                          child: Text(
                            _items.every((i) => i.isCleared) ? 'إلغاء تحديد الكل' : 'تحديد الكل كمطابق',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Transaction checklist
                  Expanded(
                    child: _items.isEmpty
                        ? Center(
                            child: Text(
                              'لا توجد حركات مسجلة لهذا الحساب حتى تاريخ $_asOfDate',
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              final isDeposit = item.baseDebit > 0;
                              final amount = isDeposit ? item.baseDebit : item.baseCredit;

                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: item.isCleared ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border,
                                    width: item.isCleared ? 1.2 : 1,
                                  ),
                                ),
                                elevation: 0,
                                color: item.isCleared ? AppColors.surface : AppColors.background,
                                child: CheckboxListTile(
                                  value: item.isCleared,
                                  onChanged: (val) {
                                    setState(() => item.isCleared = val ?? false);
                                  },
                                  activeColor: AppColors.primary,
                                  title: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        item.entryNumber,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${isDeposit ? "+" : "-"} ${AppFormatters.formatCurrency(amount, currencySymbol: widget.baseCurrencyCode)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isDeposit ? AppColors.success : AppColors.danger,
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.description,
                                            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          item.entryDate,
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildMetric(String label, int minorAmount,
      {bool isHighlight = false, bool isError = false}) {
    Color color = AppColors.darkNavy;
    if (isHighlight) {
      color = isError ? AppColors.danger : AppColors.success;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          AppFormatters.formatCurrency(minorAmount, currencySymbol: widget.baseCurrencyCode),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
