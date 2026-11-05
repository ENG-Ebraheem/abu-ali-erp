import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/database_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/models/account_model.dart';
import '../../journal/screens/journal_entry_details_screen.dart';
import '../../organizations/data/organization_repository.dart';
import '../../organizations/models/organization_model.dart';
import '../../parties/data/party_repository.dart';
import '../../parties/models/party_model.dart';
import '../data/opening_balance_repository.dart';
import '../models/opening_balance_model.dart';

/// Screen for entering, balancing, drafting, and posting opening balances for an organization.
class OpeningBalancesScreen extends StatefulWidget {
  final String? organizationId;

  const OpeningBalancesScreen({super.key, this.organizationId});

  @override
  State<OpeningBalancesScreen> createState() => _OpeningBalancesScreenState();
}

class _LineDraftInput {
  String id;
  AccountModel? account;
  PartyModel? party;
  String currencyCode;
  int exchangeRateScaled;
  final TextEditingController debitController = TextEditingController();
  final TextEditingController creditController = TextEditingController();
  final TextEditingController descController = TextEditingController();

  _LineDraftInput({
    required this.id,
    this.account,
    this.party,
    required this.currencyCode,
    this.exchangeRateScaled = DatabaseConstants.exchangeRateScale,
  });

  int get foreignDebit {
    final d = double.tryParse(debitController.text.trim()) ?? 0.0;
    return (d * 100).round();
  }

  int get foreignCredit {
    final c = double.tryParse(creditController.text.trim()) ?? 0.0;
    return (c * 100).round();
  }

  int get baseDebit {
    if (exchangeRateScaled == DatabaseConstants.exchangeRateScale) {
      return foreignDebit;
    }
    return ((foreignDebit * exchangeRateScaled) /
            DatabaseConstants.exchangeRateScale)
        .round();
  }

  int get baseCredit {
    if (exchangeRateScaled == DatabaseConstants.exchangeRateScale) {
      return foreignCredit;
    }
    return ((foreignCredit * exchangeRateScaled) /
            DatabaseConstants.exchangeRateScale)
        .round();
  }

  void dispose() {
    debitController.dispose();
    creditController.dispose();
    descController.dispose();
  }
}

class _OpeningBalancesScreenState extends State<OpeningBalancesScreen> {
  final _orgRepo = OrganizationRepository();
  final _accountRepo = AccountRepository();
  final _partyRepo = PartyRepository();
  final _openingRepo = OpeningBalanceRepository();

  Organization? _currentOrg;
  OpeningBalanceModel? _existingOpeningBalance;
  List<AccountModel> _accounts = [];
  List<PartyModel> _parties = [];
  final List<_LineDraftInput> _lines = [];

  final TextEditingController _asOfDateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final year = DateTime.now().year;
    _asOfDateController.text = '$year-01-01';
    _loadData();
  }

  @override
  void dispose() {
    _asOfDateController.dispose();
    _notesController.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      String? orgId = widget.organizationId;
      orgId ??= await _orgRepo.getActiveOrganizationId();

      Organization? org;
      if (orgId != null) {
        org = await _orgRepo.getOrganizationById(orgId);
      }
      if (org == null) {
        final all = await _orgRepo.getAllOrganizations(includeArchived: false);
        if (all.isNotEmpty) org = all.first;
      }

      if (org == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      _currentOrg = org;

      // Load COA & Parties
      final accs =
          await _accountRepo.getAccountsFlat(org.id, includeInactive: false);
      final prts = await _partyRepo.getParties(
          organizationId: org.id, includeInactive: false);

      // Check existing opening balance
      final existing = await _openingRepo.getOpeningBalanceHeader(org.id);

      _accounts = accs;
      _parties = prts;
      _existingOpeningBalance = existing;

      for (final l in _lines) {
        l.dispose();
      }
      _lines.clear();

      if (existing != null && existing.journalEntryId != null) {
        final savedLines = await _openingRepo.getOpeningBalanceLines(
          existing.journalEntryId!,
          org.id,
        );

        _asOfDateController.text = existing.asOfDate;
        _notesController.text = existing.notes ?? '';

        for (final sl in savedLines) {
          final acc = accs.where((a) => a.id == sl.accountId).firstOrNull;
          final prt = prts.where((p) => p.id == sl.partyId).firstOrNull;

          final lineInput = _LineDraftInput(
            id: sl.id,
            account: acc,
            party: prt,
            currencyCode: sl.currencyCode,
            exchangeRateScaled: sl.exchangeRateScaled,
          );
          if (sl.foreignDebit > 0) {
            lineInput.debitController.text =
                (sl.foreignDebit / 100.0).toStringAsFixed(2);
          }
          if (sl.foreignCredit > 0) {
            lineInput.creditController.text =
                (sl.foreignCredit / 100.0).toStringAsFixed(2);
          }
          lineInput.descController.text = sl.description ?? '';

          lineInput.debitController.addListener(() => setState(() {}));
          lineInput.creditController.addListener(() => setState(() {}));
          _lines.add(lineInput);
        }
      }

      // Default lines if empty and draft
      if (_lines.isEmpty && (existing == null || existing.isDraft)) {
        _addNewLine();
        _addNewLine();
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addNewLine({AccountModel? initialAccount}) {
    final line = _LineDraftInput(
      id: 'draft_${DateTime.now().microsecondsSinceEpoch}',
      account: initialAccount,
      currencyCode: _currentOrg?.baseCurrencyCode ?? 'YER',
      exchangeRateScaled: DatabaseConstants.exchangeRateScale,
    );
    line.debitController.addListener(() => setState(() {}));
    line.creditController.addListener(() => setState(() {}));
    setState(() => _lines.add(line));
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب إبقاء سطر واحد على الأقل'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    final removed = _lines.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  int get _totalBaseDebit => _lines.fold(0, (sum, l) => sum + l.baseDebit);
  int get _totalBaseCredit => _lines.fold(0, (sum, l) => sum + l.baseCredit);
  int get _imbalanceMinor => (_totalBaseDebit - _totalBaseCredit).abs();
  bool get _isBalanced =>
      _totalBaseDebit == _totalBaseCredit && _totalBaseDebit > 0;

  void _autoBalanceWithEquity() {
    if (_isBalanced || _imbalanceMinor == 0) return;

    // Look for Capital account (3101) or Retained Earnings
    final equityAcc = _accounts
        .where((a) => a.accountCode.startsWith('3') && !a.isHeaderAccount)
        .firstOrNull;
    if (equityAcc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم يتم العثور على حساب حقوق ملكية / رأس مال للموازنة'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_totalBaseDebit > _totalBaseCredit) {
      // Need credit
      final diff = _totalBaseDebit - _totalBaseCredit;
      final line = _LineDraftInput(
        id: 'bal_${DateTime.now().microsecondsSinceEpoch}',
        account: equityAcc,
        currencyCode: _currentOrg?.baseCurrencyCode ?? 'YER',
      );
      line.creditController.text = (diff / 100.0).toStringAsFixed(2);
      line.descController.text = 'رأس المال / الفارق الافتتاحي المتوازن';
      line.debitController.addListener(() => setState(() {}));
      line.creditController.addListener(() => setState(() {}));
      setState(() => _lines.add(line));
    } else {
      // Need debit
      final diff = _totalBaseCredit - _totalBaseDebit;
      final line = _LineDraftInput(
        id: 'bal_${DateTime.now().microsecondsSinceEpoch}',
        account: equityAcc,
        currencyCode: _currentOrg?.baseCurrencyCode ?? 'YER',
      );
      line.debitController.text = (diff / 100.0).toStringAsFixed(2);
      line.descController.text = 'رأس المال / الفارق الافتتاحي';
      line.debitController.addListener(() => setState(() {}));
      line.creditController.addListener(() => setState(() {}));
      setState(() => _lines.add(line));
    }
  }

  List<OpeningBalanceLineItem> _buildLineItems() {
    final list = <OpeningBalanceLineItem>[];
    for (int i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      if (l.account == null) continue;
      if (l.baseDebit == 0 && l.baseCredit == 0) continue;

      list.add(
        OpeningBalanceLineItem(
          id: l.id,
          accountId: l.account!.id,
          accountCode: l.account!.accountCode,
          accountNameAr: l.account!.accountNameAr,
          accountType: l.account!.accountType,
          accountNature: l.account!.accountNature,
          partyId: l.party?.id,
          partyNameAr: l.party?.nameAr,
          currencyCode: l.currencyCode,
          exchangeRateScaled: l.exchangeRateScaled,
          foreignDebit: l.foreignDebit,
          foreignCredit: l.foreignCredit,
          baseDebit: l.baseDebit,
          baseCredit: l.baseCredit,
          description: l.descController.text.trim().isEmpty
              ? null
              : l.descController.text.trim(),
        ),
      );
    }
    return list;
  }

  Future<void> _saveDraft() async {
    if (_currentOrg == null) return;
    final items = _buildLineItems();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار حساب واحد على الأقل وإدخال رصيده'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final saved = await _openingRepo.saveOpeningBalanceDraft(
        organizationId: _currentOrg!.id,
        asOfDate: _asOfDateController.text.trim(),
        lines: items,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _existingOpeningBalance = saved;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ مسودة الأرصدة الافتتاحية بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _postBalances() async {
    if (_currentOrg == null) return;
    final items = _buildLineItems();

    if (items.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الترحيل يتطلب سطرين على الأقل لإتمام القيد المزدوج'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (!_isBalanced) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'القيد غير متزن! الفارق: ${(_imbalanceMinor / 100.0).toStringAsFixed(2)} ر.ي. يرجى موازنة القيد قبل الترحيل.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlg) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد ترحيل الأرصدة الافتتاحية'),
        content: const Text(
          'تنبيه: بعد الترحيل تصبح الأرصدة الافتتاحية رسمية وغير قابلة للتعديل أو الحذف، وسيتم إنشاء قيد افتتاحي معتمد في دفتر اليومية. هل ترغب بالاستمرار؟',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlg, false),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(dlg, true),
            child: const Text('نعم، ترحيل الأرصدة'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      await _openingRepo.postOpeningBalances(
        organizationId: _currentOrg!.id,
        asOfDate: _asOfDateController.text.trim(),
        lines: items,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'تم ترحيل الأرصدة الافتتاحية بنجاح واعتمادها في الدفاتر المحاسبية'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPosted = _existingOpeningBalance?.isPosted ?? false;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'الأرصدة الافتتاحية',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            if (!isPosted)
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded),
                tooltip: 'إضافة سطر حساب',
                onPressed: () => _addNewLine(),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Badge if Posted
                    if (isPosted) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_rounded,
                                color: AppColors.success, size: 24),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'تم ترحيل واعتماد الأرصدة الافتتاحية',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'الأرصدة مقيدة ومحمية ضد التعديل في الدفاتر المحاسبية الرسمية',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            if (_existingOpeningBalance?.journalEntryId != null)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.receipt_long_rounded,
                                    size: 16),
                                label: const Text('عرض القيد'),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => JournalEntryDetailsScreen(
                                        entryId: _existingOpeningBalance!
                                            .journalEntryId!,
                                        organizationId: _currentOrg!.id,
                                        baseCurrencyCode:
                                            _currentOrg!.baseCurrencyCode,
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Info Header Card
                    _buildHeaderCard(isPosted),
                    const SizedBox(height: 16),

                    // Balance Summary Card
                    _buildBalanceSummaryCard(isPosted),
                    const SizedBox(height: 16),

                    // Lines Header
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
                              'بنود الحسابات والأرصدة',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkNavy,
                              ),
                            ),
                          ],
                        ),
                        if (!isPosted)
                          TextButton.icon(
                            onPressed: () => _addNewLine(),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('إضافة حساب'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Lines
                    ...List.generate(_lines.length, (index) {
                      return _buildLineCard(index, isPosted);
                    }),

                    const SizedBox(height: 24),

                    // Action Buttons
                    if (!isPosted) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isSaving ? null : _saveDraft,
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('حفظ كمسودة',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _postBalances,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(
                                      Icons.check_circle_outline_rounded),
                              label: const Text('ترحيل الأرصدة',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderCard(bool isPosted) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _currentOrg?.name ?? 'المؤسسة',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNavy),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _currentOrg?.currencyLabel ?? 'YER',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _asOfDateController,
            enabled: !isPosted,
            decoration: const InputDecoration(
              labelText: 'تاريخ بدء الأرصدة الافتتاحية (YYYY-MM-DD) *',
              prefixIcon: Icon(Icons.calendar_today_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _notesController,
            enabled: !isPosted,
            decoration: const InputDecoration(
              labelText: 'ملاحظات وتفاصيل الدورة الافتتاحية',
              prefixIcon: Icon(Icons.notes_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSummaryCard(bool isPosted) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: _isBalanced ? AppColors.success : AppColors.warning),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryBox(
                  'إجمالي المدين',
                  '${(_totalBaseDebit / 100.0).toStringAsFixed(2)} ر.ي',
                  AppColors.primary),
              _summaryBox(
                  'إجمالي الدائن',
                  '${(_totalBaseCredit / 100.0).toStringAsFixed(2)} ر.ي',
                  AppColors.success),
              _summaryBox(
                'الفارق',
                '${(_imbalanceMinor / 100.0).toStringAsFixed(2)} ر.ي',
                _isBalanced ? AppColors.success : AppColors.danger,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _isBalanced
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded,
                    color: _isBalanced ? AppColors.success : AppColors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isBalanced
                        ? 'القيد الافتتاحي متزن تماماً'
                        : 'القيد الافتتاحي غير متزن (يوجد فارق)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color:
                          _isBalanced ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ],
              ),
              if (!_isBalanced && !isPosted && _imbalanceMinor > 0)
                TextButton.icon(
                  onPressed: _autoBalanceWithEquity,
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                  label: const Text('موازنة برأس المال',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryBox(String title, String value, Color color) {
    return Column(
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 11.5, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
              fontSize: 13.5, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildLineCard(int index, bool isPosted) {
    final line = _lines[index];
    final postableAccounts =
        _accounts.where((a) => !a.isHeaderAccount).toList();
    final isCustomerAcc = line.account?.accountCode.startsWith('1103') ?? false;
    final isSupplierAcc = line.account?.accountCode.startsWith('2101') ?? false;
    final filteredParties = isCustomerAcc
        ? _parties.where((p) => p.isCustomer).toList()
        : (isSupplierAcc
            ? _parties.where((p) => p.isSupplier).toList()
            : _parties);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              Text(
                'السطر رقم ${index + 1}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNavy),
              ),
              if (!isPosted && _lines.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.danger, size: 20),
                  onPressed: () => _removeLine(index),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Account selector
          DropdownButtonFormField<String>(
            value: postableAccounts.any((a) => a.id == line.account?.id)
                ? line.account?.id
                : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'الحساب المحاسبي *',
              prefixIcon: Icon(Icons.account_tree_rounded, size: 20),
            ),
            items: postableAccounts.map((a) {
              return DropdownMenuItem<String>(
                value: a.id,
                child: Text(
                    '${a.accountCode} - ${a.accountNameAr} (${a.natureNameAr})',
                    overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: isPosted
                ? null
                : (val) {
                    final sel =
                        postableAccounts.where((a) => a.id == val).firstOrNull;
                    setState(() {
                      line.account = sel;
                      line.party = null;
                    });
                  },
          ),

          // Subledger Party selector if customer or supplier account
          if (isCustomerAcc || isSupplierAcc) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: filteredParties.any((p) => p.id == line.party?.id)
                  ? line.party?.id
                  : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: isCustomerAcc
                    ? 'العميل المرتبط (الأستاذ المساعد) *'
                    : 'المورد المرتبط (الأستاذ المساعد) *',
                prefixIcon: const Icon(Icons.person_rounded, size: 20),
              ),
              items: filteredParties.map((p) {
                return DropdownMenuItem<String>(
                  value: p.id,
                  child: Text('${p.code} - ${p.nameAr}',
                      overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: isPosted
                  ? null
                  : (val) {
                      final selPrt =
                          filteredParties.where((p) => p.id == val).firstOrNull;
                      setState(() => line.party = selPrt);
                    },
            ),
          ],

          const SizedBox(height: 10),

          // Debit & Credit Row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: line.debitController,
                  enabled: !isPosted,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'مدين (Debit)',
                    suffixText: 'ر.ي',
                  ),
                  onChanged: (val) {
                    if (val.trim().isNotEmpty &&
                        line.creditController.text.isNotEmpty) {
                      line.creditController.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: line.creditController,
                  enabled: !isPosted,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'دائن (Credit)',
                    suffixText: 'ر.ي',
                  ),
                  onChanged: (val) {
                    if (val.trim().isNotEmpty &&
                        line.debitController.text.isNotEmpty) {
                      line.debitController.clear();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: line.descController,
            enabled: !isPosted,
            decoration: const InputDecoration(
              labelText: 'بيان السطر (اختياري)',
              hintText: 'رصيد افتتاحي...',
            ),
          ),
        ],
      ),
    );
  }
}
