import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../journal/data/journal_repository.dart';
import '../../journal/models/journal_entry_line_model.dart';
import '../../journal/models/journal_entry_model.dart';
import '../data/account_repository.dart';
import '../models/account_model.dart';

/// Screen for transferring funds between cash and bank accounts (مناقلة بنكية ونقدية).
/// Creates and posts an atomic, balanced General Ledger Journal Entry.
class BankTransferScreen extends StatefulWidget {
  final String organizationId;
  final String baseCurrencyCode;

  const BankTransferScreen({
    super.key,
    required this.organizationId,
    required this.baseCurrencyCode,
  });

  @override
  State<BankTransferScreen> createState() => _BankTransferScreenState();
}

class _BankTransferScreenState extends State<BankTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountRepo = AccountRepository();
  final _journalRepo = JournalRepository();

  List<AccountModel> _cashBankAccounts = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  AccountModel? _sourceAccount;
  AccountModel? _destinationAccount;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dateController.text = DateTime.now().toIso8601String().split('T').first;
    _loadAccounts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dateController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    try {
      final list = await _accountRepo.getCashBankAccounts(widget.organizationId);
      if (!mounted) return;
      setState(() {
        _cashBankAccounts = list;
        _isLoading = false;
        if (list.length >= 2) {
          _sourceAccount = list[0];
          _destinationAccount = list[1];
        } else if (list.length == 1) {
          _sourceAccount = list[0];
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحميل حسابات الصناديق والبنوك: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _handleExecuteTransfer() async {
    if (!_formKey.currentState!.validate()) return;

    if (_sourceAccount == null || _destinationAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد حساب المصدر وحساب الوجهة للتحويل.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_sourceAccount!.id == _destinationAccount!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن التحويل من وإلى نفس الحساب!'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final double enteredAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (enteredAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال مبلغ تحويل صحيح أكبر من صفر.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final int minorAmount = (enteredAmount * 100).round();

    setState(() => _isSubmitting = true);

    try {
      final periodId = await _journalRepo.ensureFiscalPeriod(
        widget.organizationId,
        _dateController.text.trim(),
      );

      final entryNumber = await _journalRepo.getNextEntryNumber(
        widget.organizationId,
        'GENERAL',
      );

      final entryId = 'je_trf_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now().toIso8601String();

      final narration = _notesController.text.trim().isNotEmpty
          ? 'تحويل مالي من [${_sourceAccount!.accountNameAr}] إلى [${_destinationAccount!.accountNameAr}]: ${_notesController.text.trim()}'
          : 'تحويل مالي من [${_sourceAccount!.accountNameAr}] إلى [${_destinationAccount!.accountNameAr}]';

      final journalEntry = JournalEntryModel(
        id: entryId,
        organizationId: widget.organizationId,
        entryNumber: entryNumber,
        fiscalPeriodId: periodId,
        entryDate: _dateController.text.trim(),
        entryType: 'GENERAL',
        status: 'POSTED',
        reference: _referenceController.text.trim().isNotEmpty
            ? _referenceController.text.trim()
            : null,
        narration: narration,
        totalBaseDebit: minorAmount,
        totalBaseCredit: minorAmount,
        postedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      // Line 1: Debit Destination (زيادة الوجهة)
      final debitLine = JournalEntryLineModel(
        id: 'line_${entryId}_1',
        organizationId: widget.organizationId,
        journalEntryId: entryId,
        lineNumber: 1,
        accountId: _destinationAccount!.id,
        partyId: null,
        description: 'إيداع محول من ${_sourceAccount!.accountNameAr}',
        currencyCode: widget.baseCurrencyCode,
        exchangeRateScaled: 1000000,
        foreignDebit: minorAmount,
        foreignCredit: 0,
        baseDebit: minorAmount,
        baseCredit: 0,
        createdAt: now,
      );

      // Line 2: Credit Source (تخفيض المصدر)
      final creditLine = JournalEntryLineModel(
        id: 'line_${entryId}_2',
        organizationId: widget.organizationId,
        journalEntryId: entryId,
        lineNumber: 2,
        accountId: _sourceAccount!.id,
        partyId: null,
        description: 'تحويل منصرف إلى ${_destinationAccount!.accountNameAr}',
        currencyCode: widget.baseCurrencyCode,
        exchangeRateScaled: 1000000,
        foreignDebit: 0,
        foreignCredit: minorAmount,
        baseDebit: 0,
        baseCredit: minorAmount,
        createdAt: now,
      );

      await _journalRepo.saveEntry(
        entry: journalEntry,
        lines: [debitLine, creditLine],
        autoPost: true,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تنفيذ التحويل بنجاح بقيد رقم $entryNumber بمبلغ ${AppFormatters.formatCurrency(minorAmount, currencySymbol: widget.baseCurrencyCode)}',
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ أثناء تنفيذ التحويل: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
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
            'تحويل نقدي وبنكي (مناقلة)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: AppColors.darkNavy,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Overview card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFEFF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.swap_horiz_rounded,
                                color: Color(0xFF0891B2),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'مناقلة مالية بين الصناديق والبنوك',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.darkNavy,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'يتم توليد وترحيل قيد محاسبي مزدوج ومتوازن آلياً',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Accounts Selection Card
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
                            const Text(
                              'أطراف التحويل',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkNavy,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Source account dropdown
                            DropdownButtonFormField<String>(
                              value: _sourceAccount?.id,
                              decoration: InputDecoration(
                                labelText: 'من حساب (المصدر - دائن) *',
                                prefixIcon: const Icon(Icons.outbox_rounded, color: AppColors.danger),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: _cashBankAccounts.map((a) {
                                return DropdownMenuItem<String>(
                                  value: a.id,
                                  child: Text(
                                    '${a.accountCode} - ${a.accountNameAr}',
                                    style: const TextStyle(fontSize: 13.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _sourceAccount = _cashBankAccounts.firstWhere((a) => a.id == val);
                                });
                              },
                              validator: (v) => v == null ? 'يرجى اختيار حساب المصدر' : null,
                            ),
                            const SizedBox(height: 16),

                            // Destination account dropdown
                            DropdownButtonFormField<String>(
                              value: _destinationAccount?.id,
                              decoration: InputDecoration(
                                labelText: 'إلى حساب (الوجهة - مدين) *',
                                prefixIcon: const Icon(Icons.move_to_inbox_rounded, color: AppColors.success),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: _cashBankAccounts.map((a) {
                                return DropdownMenuItem<String>(
                                  value: a.id,
                                  child: Text(
                                    '${a.accountCode} - ${a.accountNameAr}',
                                    style: const TextStyle(fontSize: 13.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _destinationAccount = _cashBankAccounts.firstWhere((a) => a.id == val);
                                });
                              },
                              validator: (v) => v == null ? 'يرجى اختيار حساب الوجهة' : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Transfer Details Card
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
                            const Text(
                              'بيانات العملية',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkNavy,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Amount
                            TextFormField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'المبلغ المحول *',
                                suffixText: widget.baseCurrencyCode,
                                prefixIcon: const Icon(Icons.attach_money_rounded, color: AppColors.primary),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'يرجى إدخال المبلغ';
                                final num = double.tryParse(v.trim());
                                if (num == null || num <= 0) return 'يرجى إدخال رقم موجب صحيح';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Date
                            TextFormField(
                              controller: _dateController,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'تاريخ التحويل *',
                                prefixIcon: const Icon(Icons.calendar_today_rounded),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onTap: () async {
                                final initial = DateTime.tryParse(_dateController.text) ?? DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: initial,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2050),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _dateController.text = picked.toIso8601String().split('T').first;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 14),

                            // Reference
                            TextFormField(
                              controller: _referenceController,
                              decoration: InputDecoration(
                                labelText: 'رقم المرجع / الشيك / الحوالة (اختياري)',
                                prefixIcon: const Icon(Icons.tag_rounded),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Notes
                            TextFormField(
                              controller: _notesController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: 'البيان / ملاحظات التحويل',
                                prefixIcon: const Icon(Icons.notes_rounded),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit button
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleExecuteTransfer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'تنفيذ التحويل وترحيل القيد المحاسبي',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
