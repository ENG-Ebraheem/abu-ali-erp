import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/database_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/models/account_model.dart';
import '../../exchange_rates/data/exchange_rate_repository.dart';
import '../../parties/data/party_repository.dart';
import '../../parties/models/party_model.dart';
import '../data/journal_repository.dart';
import '../models/journal_entry_line_model.dart';
import '../models/journal_entry_model.dart';

/// Screen for creating and posting a multi-line double-entry journal entry.
class CreateJournalEntryScreen extends StatefulWidget {
  final String organizationId;
  final String baseCurrencyCode;
  final String initialEntryType;
  final JournalEntryModel? entryToEdit;

  const CreateJournalEntryScreen({
    super.key,
    required this.organizationId,
    required this.baseCurrencyCode,
    this.initialEntryType = 'GENERAL',
    this.entryToEdit,
  });

  @override
  State<CreateJournalEntryScreen> createState() =>
      _CreateJournalEntryScreenState();
}

class _LineItemDraft {
  String? accountId;
  String? partyId;
  String? description;
  String currencyCode;
  int exchangeRateScaled;
  final TextEditingController debitController = TextEditingController();
  final TextEditingController creditController = TextEditingController();

  _LineItemDraft({
    required this.currencyCode,
    required this.exchangeRateScaled,
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
  }
}

class _CreateJournalEntryScreenState extends State<CreateJournalEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _journalRepo = JournalRepository();
  final _accountRepo = AccountRepository();
  final _partyRepo = PartyRepository();
  final _rateRepo = ExchangeRateRepository();

  late String _entryType;
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _narrationController = TextEditingController();

  List<AccountModel> _accounts = [];
  List<PartyModel> _parties = [];
  final List<_LineItemDraft> _lines = [];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final edit = widget.entryToEdit;
    _entryType = edit?.entryType ?? widget.initialEntryType;
    _dateController.text =
        edit?.entryDate ?? DateTime.now().toIso8601String().split('T').first;
    _referenceController.text = edit?.reference ?? '';
    _narrationController.text = edit?.narration ?? '';
    _loadDependencies();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _referenceController.dispose();
    _narrationController.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDependencies() async {
    setState(() => _isLoading = true);
    try {
      final accs = await _accountRepo.getAccountsFlat(
        widget.organizationId,
        includeInactive: false,
      );
      final prts = await _partyRepo.getParties(
        organizationId: widget.organizationId,
        includeInactive: false,
      );

      if (mounted) {
        setState(() {
          _accounts = accs;
          _parties = prts;
          _isLoading = false;
        });

        if (_lines.isEmpty) {
          if (widget.entryToEdit != null &&
              widget.entryToEdit!.lines.isNotEmpty) {
            for (final sl in widget.entryToEdit!.lines) {
              final line = _LineItemDraft(
                currencyCode: sl.currencyCode,
                exchangeRateScaled: sl.exchangeRateScaled,
              );
              line.accountId = sl.accountId;
              line.partyId = sl.partyId;
              line.description = sl.description;
              if (sl.foreignDebit > 0) {
                line.debitController.text =
                    (sl.foreignDebit / 100.0).toStringAsFixed(2);
              }
              if (sl.foreignCredit > 0) {
                line.creditController.text =
                    (sl.foreignCredit / 100.0).toStringAsFixed(2);
              }
              line.debitController.addListener(() => setState(() {}));
              line.creditController.addListener(() => setState(() {}));
              _lines.add(line);
            }
          } else {
            _addLine();
            _addLine();
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addLine() {
    final line = _LineItemDraft(
      currencyCode: widget.baseCurrencyCode,
      exchangeRateScaled: DatabaseConstants.exchangeRateScale,
    );
    line.debitController.addListener(() => setState(() {}));
    line.creditController.addListener(() => setState(() {}));
    setState(() => _lines.add(line));
  }

  void _removeLine(int index) {
    if (_lines.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب أن يحتوي القيد على سطرين على الأقل'),
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
  bool get _isBalanced =>
      _totalBaseDebit == _totalBaseCredit && _totalBaseDebit > 0;

  Future<void> _updateCurrencyForLine(
      _LineItemDraft line, String newCurrency) async {
    int scaled = DatabaseConstants.exchangeRateScale;
    if (newCurrency != widget.baseCurrencyCode) {
      final rateModel = await _rateRepo.getLatestRate(
        organizationId: widget.organizationId,
        fromCurrency: newCurrency,
        toCurrency: widget.baseCurrencyCode,
        asOfDate: _dateController.text.trim(),
      );
      if (rateModel != null) {
        scaled = rateModel.rateScaled;
      }
    }

    setState(() {
      line.currencyCode = newCurrency;
      line.exchangeRateScaled = scaled;
    });
  }

  Future<void> _submit({required bool autoPost}) async {
    if (!_formKey.currentState!.validate()) return;

    if (_lines.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب أن يحتوي القيد على سطرين على الأقل.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    for (int i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      if (l.accountId == null || l.accountId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('يرجى اختيار الحساب في السطر رقم ${i + 1}'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      if (l.baseDebit == 0 && l.baseCredit == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('يرجى تحديد المبلغ (مدين أو دائن) في السطر رقم ${i + 1}'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      if (l.baseDebit > 0 && l.baseCredit > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('لا يمكن إدخال مدين ودائن معاً في نفس السطر (${i + 1})'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    }

    if (autoPost && !_isBalanced) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لا يمكن الترحيل لأن القيد غير متزن: المدين (${(_totalBaseDebit / 100.0).toStringAsFixed(2)}) والدائن (${(_totalBaseCredit / 100.0).toStringAsFixed(2)})',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final entryDate = _dateController.text.trim();
      final periodId = await _journalRepo.ensureFiscalPeriod(
        widget.organizationId,
        entryDate,
      );
      final entryNumber = widget.entryToEdit?.entryNumber ??
          await _journalRepo.getNextEntryNumber(
            widget.organizationId,
            _entryType,
          );
      final entryId = widget.entryToEdit?.id ??
          'je_${DateTime.now().millisecondsSinceEpoch}';

      final header = JournalEntryModel(
        id: entryId,
        organizationId: widget.organizationId,
        entryNumber: entryNumber,
        fiscalPeriodId: periodId,
        entryDate: entryDate,
        entryType: _entryType,
        status: autoPost ? 'POSTED' : 'DRAFT',
        reference: _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim(),
        narration: _narrationController.text.trim(),
        totalBaseDebit: _totalBaseDebit,
        totalBaseCredit: _totalBaseCredit,
      );

      final lineModels = <JournalEntryLineModel>[];
      for (int i = 0; i < _lines.length; i++) {
        final l = _lines[i];
        lineModels.add(
          JournalEntryLineModel(
            id: 'line_${entryId}_${i + 1}',
            organizationId: widget.organizationId,
            journalEntryId: entryId,
            lineNumber: i + 1,
            accountId: l.accountId!,
            partyId: l.partyId,
            description: l.description,
            currencyCode: l.currencyCode,
            exchangeRateScaled: l.exchangeRateScaled,
            foreignDebit: l.foreignDebit,
            foreignCredit: l.foreignCredit,
            baseDebit: l.baseDebit,
            baseCredit: l.baseCredit,
          ),
        );
      }

      await _journalRepo.saveEntry(
        entry: header,
        lines: lineModels,
        autoPost: autoPost,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              autoPost
                  ? 'تم ترحيل القيد $entryNumber بنجاح'
                  : 'تم حفظ مسودة القيد $entryNumber',
            ),
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'إنشاء قيد محاسبي',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'إضافة سطر',
              onPressed: _addLine,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Scrollable form contents
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // 1. Header Card
                          _buildHeaderCard(),
                          const SizedBox(height: 16),

                          // 2. Lines Section
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
                                    'أسطر القيد (المدين والدائن)',
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.darkNavy,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                onPressed: _addLine,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('إضافة سطر'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // 3. Line Item Cards
                          ...List.generate(_lines.length, (index) {
                            return _buildLineCard(index);
                          }),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),

                    // 4. Bottom Live Balance & Submit Bar
                    _buildBottomBar(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
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
            children: [
              // Entry Type
              Expanded(
                flex: 4,
                child: DropdownButtonFormField<String>(
                  value: _entryType,
                  decoration: const InputDecoration(labelText: 'نوع القيد'),
                  items: const [
                    DropdownMenuItem(value: 'GENERAL', child: Text('قيد عام')),
                    DropdownMenuItem(
                        value: 'OPENING', child: Text('قيد افتتاحي')),
                    DropdownMenuItem(value: 'SALES', child: Text('مبيعات')),
                    DropdownMenuItem(value: 'PURCHASE', child: Text('مشتريات')),
                    DropdownMenuItem(value: 'RECEIPT', child: Text('سند قبض')),
                    DropdownMenuItem(value: 'PAYMENT', child: Text('سند صرف')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _entryType = val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Entry Date
              Expanded(
                flex: 4,
                child: TextFormField(
                  controller: _dateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'تاريخ القيد *',
                    prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      _dateController.text =
                          picked.toIso8601String().split('T').first;
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Reference & Narration
          TextFormField(
            controller: _referenceController,
            decoration: const InputDecoration(
              labelText: 'المرجع / رقم السند (اختياري)',
              hintText: 'مثال: INV-104 / فاتورة رقم 44',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _narrationController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'البيان / الشرح *',
              hintText: 'أدخل بياناً واضحاً للعملية المحاسبية...',
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'يرجى إدخال بيان القيد' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildLineCard(int index) {
    final line = _lines[index];
    final isDebitActive = (double.tryParse(line.debitController.text) ?? 0) > 0;
    final isCreditActive =
        (double.tryParse(line.creditController.text) ?? 0) > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDebitActive
              ? AppColors.primaryLight
              : (isCreditActive ? const Color(0xFFD1FAE5) : AppColors.border),
          width: (isDebitActive || isCreditActive) ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Line number & Remove
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'السطر #${index + 1}',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkNavy,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.danger, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: () => _removeLine(index),
                tooltip: 'حذف السطر',
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Account picker
          DropdownButtonFormField<String>(
            value: line.accountId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'الحساب المحاسبي *',
              prefixIcon: Icon(Icons.account_tree_outlined, size: 18),
            ),
            items: _accounts.map((acc) {
              return DropdownMenuItem(
                value: acc.id,
                child: Text(
                  '${acc.accountCode} - ${acc.accountNameAr}',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (val) {
              setState(() => line.accountId = val);
            },
            validator: (v) => v == null ? 'مطلوب' : null,
          ),
          const SizedBox(height: 10),

          // Optional Party Picker & Currency row
          Row(
            children: [
              // Party picker
              Expanded(
                flex: 5,
                child: DropdownButtonFormField<String>(
                  value: line.partyId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'الطرف (اختياري)',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('بدون طرف')),
                    ..._parties.map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text('${p.code} - ${p.nameAr}'),
                        )),
                  ],
                  onChanged: (val) => setState(() => line.partyId = val),
                ),
              ),
              const SizedBox(width: 8),
              // Currency
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: line.currencyCode,
                  decoration: const InputDecoration(labelText: 'العملة'),
                  items: const [
                    DropdownMenuItem(value: 'YER', child: Text('YER')),
                    DropdownMenuItem(value: 'SAR', child: Text('SAR')),
                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                  ],
                  onChanged: (val) {
                    if (val != null) _updateCurrencyForLine(line, val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Debit & Credit Inputs
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: line.debitController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'مدين',
                    hintText: '0.00',
                    prefixIcon: Icon(Icons.arrow_upward_rounded,
                        color: AppColors.primary, size: 18),
                  ),
                  onChanged: (val) {
                    if (val.isNotEmpty &&
                        line.creditController.text.isNotEmpty) {
                      line.creditController.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: line.creditController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'دائن',
                    hintText: '0.00',
                    prefixIcon: Icon(Icons.arrow_downward_rounded,
                        color: AppColors.success, size: 18),
                  ),
                  onChanged: (val) {
                    if (val.isNotEmpty &&
                        line.debitController.text.isNotEmpty) {
                      line.debitController.clear();
                    }
                  },
                ),
              ),
            ],
          ),
          if (line.currencyCode != widget.baseCurrencyCode) ...[
            const SizedBox(height: 6),
            Text(
              'سعر الصرف المعتمد: ${(line.exchangeRateScaled / 1000000.0).toStringAsFixed(4)} (المعادل الأساس: ${((line.baseDebit > 0 ? line.baseDebit : line.baseCredit) / 100.0).toStringAsFixed(2)} ${widget.baseCurrencyCode})',
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final diff = (_totalBaseDebit - _totalBaseCredit).abs();
    final isBalanced = _isBalanced;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Live balancing info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مدين: ${(_totalBaseDebit / 100.0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'دائن: ${(_totalBaseCredit / 100.0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isBalanced
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isBalanced ? AppColors.success : AppColors.danger,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isBalanced
                            ? Icons.check_circle_rounded
                            : Icons.error_outline_rounded,
                        size: 16,
                        color:
                            isBalanced ? AppColors.success : AppColors.danger,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isBalanced
                            ? 'متزن (${widget.baseCurrencyCode})'
                            : 'فارق: ${(diff / 100.0).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color:
                              isBalanced ? AppColors.success : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Submit Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isSaving ? null : () => _submit(autoPost: false),
                    child: const Text('حفظ كمسودة'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving || !isBalanced
                        ? null
                        : () => _submit(autoPost: true),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('ترحيل القيد'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
