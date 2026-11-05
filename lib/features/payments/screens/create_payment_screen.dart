import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/database_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/models/account_model.dart';
import '../../exchange_rates/data/exchange_rate_repository.dart';
import '../../parties/data/party_repository.dart';
import '../../parties/models/party_model.dart';
import '../../parties/widgets/party_form_sheet.dart';
import '../data/payment_repository.dart';
import '../models/payment_allocation_model.dart';
import '../models/payment_model.dart';

/// Screen for recording receipt or disbursement payment vouchers and allocating against invoices.
class CreatePaymentScreen extends StatefulWidget {
  final String organizationId;
  final String baseCurrencyCode;
  final String initialType; // 'RECEIPT' or 'PAYMENT'
  final PaymentModel? paymentToEdit;

  const CreatePaymentScreen({
    super.key,
    required this.organizationId,
    required this.baseCurrencyCode,
    this.initialType = 'RECEIPT',
    this.paymentToEdit,
  });

  @override
  State<CreatePaymentScreen> createState() => _CreatePaymentScreenState();
}

class _AllocationDraft {
  final String invoiceId;
  final String invoiceNumber;
  final int totalAmount;
  final int remainingAmount;
  final TextEditingController controller = TextEditingController();

  _AllocationDraft({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.totalAmount,
    required this.remainingAmount,
  });

  int get allocatedMinor {
    final val = double.tryParse(controller.text.trim()) ?? 0.0;
    return (val * 100).round();
  }

  void dispose() {
    controller.dispose();
  }
}

class _CreatePaymentScreenState extends State<CreatePaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _paymentRepo = PaymentRepository();
  final _partyRepo = PartyRepository();
  final _accountRepo = AccountRepository();
  final _rateRepo = ExchangeRateRepository();

  late String _paymentType; // 'RECEIPT' or 'PAYMENT'
  String? _selectedPartyId;
  String? _selectedCashAccountId;
  String _paymentMethod = 'CASH';
  late String _currencyCode;
  int _exchangeRateScaled = DatabaseConstants.exchangeRateScale;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _refController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<PartyModel> _parties = [];
  List<AccountModel> _cashAccounts = [];
  List<_AllocationDraft> _allocations = [];

  bool _isLoading = true;
  bool _isLoadingInvoices = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final edit = widget.paymentToEdit;
    if (edit != null) {
      _paymentType = edit.paymentType;
      _currencyCode = edit.currencyCode;
      _selectedPartyId = edit.partyId;
      _selectedCashAccountId = edit.cashBankAccountId;
      _exchangeRateScaled = edit.exchangeRateScaled;
      _amountController.text = (edit.amount / 100.0).toStringAsFixed(2);
      _dateController.text = edit.paymentDate;
      _refController.text = edit.referenceNumber ?? '';
      _notesController.text = edit.notes ?? '';
      _paymentMethod = edit.paymentMethod;
    } else {
      _paymentType = widget.initialType;
      _currencyCode = widget.baseCurrencyCode;
      _dateController.text = DateTime.now().toIso8601String().split('T').first;
    }

    _loadDependencies();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dateController.dispose();
    _refController.dispose();
    _notesController.dispose();
    for (final a in _allocations) {
      a.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDependencies() async {
    setState(() => _isLoading = true);
    try {
      final prts = await _partyRepo.getParties(
        organizationId: widget.organizationId,
        includeInactive: false,
      );
      final accs = await _accountRepo.getAccountsFlat(
        widget.organizationId,
        includeInactive: false,
      );
      final cashAccs = accs.where((a) => a.isCashBank).toList();

      if (mounted) {
        setState(() {
          _parties = prts;
          _cashAccounts = cashAccs;
          if (_selectedCashAccountId == null && cashAccs.isNotEmpty) {
            _selectedCashAccountId = cashAccs.first.id;
          }
          _isLoading = false;
        });

        if (_selectedPartyId != null) {
          _loadUnpaidInvoices(_selectedPartyId!);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUnpaidInvoices(String partyId) async {
    setState(() => _isLoadingInvoices = true);
    try {
      for (final a in _allocations) {
        a.dispose();
      }
      _allocations.clear();

      final list = await _paymentRepo.getUnpaidInvoicesForParty(
        organizationId: widget.organizationId,
        partyId: partyId,
        paymentType: _paymentType,
      );

      final drafts = list.map((inv) {
        final d = _AllocationDraft(
          invoiceId: inv['id'] as String,
          invoiceNumber: inv['invoice_number'] as String,
          totalAmount: (inv['total_amount'] as num).toInt(),
          remainingAmount: (inv['remaining_amount'] as num).toInt(),
        );

        // Pre-fill existing allocation if editing
        if (widget.paymentToEdit != null) {
          final existing = widget.paymentToEdit!.allocations
              .where((a) => a.invoiceId == d.invoiceId)
              .firstOrNull;
          if (existing != null) {
            d.controller.text =
                (existing.allocatedAmount / 100.0).toStringAsFixed(2);
          }
        }

        d.controller.addListener(() => setState(() {}));
        return d;
      }).toList();

      if (mounted) {
        setState(() {
          _allocations = drafts;
          _isLoadingInvoices = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingInvoices = false);
    }
  }

  void _autoAllocate() {
    final double amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    int remainingToAllocate = (amount * 100).round();

    for (final a in _allocations) {
      if (remainingToAllocate <= 0) {
        a.controller.clear();
      } else if (remainingToAllocate >= a.remainingAmount) {
        a.controller.text = (a.remainingAmount / 100.0).toStringAsFixed(2);
        remainingToAllocate -= a.remainingAmount;
      } else {
        a.controller.text = (remainingToAllocate / 100.0).toStringAsFixed(2);
        remainingToAllocate = 0;
      }
    }
    setState(() {});
  }

  int get _paymentAmountMinor {
    final d = double.tryParse(_amountController.text.trim()) ?? 0.0;
    return (d * 100).round();
  }

  int get _totalAllocatedMinor =>
      _allocations.fold(0, (sum, a) => sum + a.allocatedMinor);

  int get _unallocatedMinor {
    final diff = _paymentAmountMinor - _totalAllocatedMinor;
    return diff > 0 ? diff : 0;
  }

  Future<void> _updateCurrency(String newCode) async {
    int scaled = DatabaseConstants.exchangeRateScale;
    if (newCode != widget.baseCurrencyCode) {
      final rateModel = await _rateRepo.getLatestRate(
        organizationId: widget.organizationId,
        fromCurrency: newCode,
        toCurrency: widget.baseCurrencyCode,
        asOfDate: _dateController.text.trim(),
      );
      if (rateModel != null) {
        scaled = rateModel.rateScaled;
      }
    }

    setState(() {
      _currencyCode = newCode;
      _exchangeRateScaled = scaled;
    });
  }

  List<PartyModel> get _filteredParties {
    if (_paymentType == 'RECEIPT') {
      return _parties.where((p) => p.isCustomer).toList();
    } else {
      return _parties.where((p) => p.isSupplier).toList();
    }
  }

  Future<void> _openQuickAddParty() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PartyFormSheet(
        organizationId: widget.organizationId,
        baseCurrencyCode: widget.baseCurrencyCode,
        initialType: _paymentType == 'RECEIPT' ? 'CUSTOMER' : 'SUPPLIER',
      ),
    );

    if (created == true) {
      final prts = await _partyRepo.getParties(
        organizationId: widget.organizationId,
        includeInactive: false,
      );
      if (mounted) {
        setState(() {
          _parties = prts;
          final list = _filteredParties;
          if (list.isNotEmpty) {
            _selectedPartyId = list.last.id;
            _loadUnpaidInvoices(_selectedPartyId!);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _paymentType == 'RECEIPT'
                  ? 'تمت إضافة واختيار العميل بنجاح'
                  : 'تمت إضافة واختيار المورد بنجاح',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _submit({required bool autoPost}) async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPartyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار العميل أو المورد'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_selectedCashAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار حساب الصندوق أو البنك'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final amountMinor = _paymentAmountMinor;
    if (amountMinor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال مبلغ صحيح أكبر من الصفر'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_totalAllocatedMinor > amountMinor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('إجمالي المبالغ المخصصة للفواتير أكبر من مبلغ السند!'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final isEditing = widget.paymentToEdit != null;
      final paymentNumber = isEditing
          ? widget.paymentToEdit!.paymentNumber
          : await _paymentRepo.getNextPaymentNumber(
              widget.organizationId,
              _paymentType,
            );
      final paymentId = isEditing
          ? widget.paymentToEdit!.id
          : 'pay_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now().toIso8601String();

      final payment = PaymentModel(
        id: paymentId,
        organizationId: widget.organizationId,
        partyId: _selectedPartyId!,
        cashBankAccountId: _selectedCashAccountId!,
        paymentType: _paymentType,
        paymentNumber: paymentNumber,
        paymentDate: _dateController.text.trim(),
        paymentMethod: _paymentMethod,
        currencyCode: _currencyCode,
        exchangeRateScaled: _exchangeRateScaled,
        amount: amountMinor,
        allocatedAmount: _totalAllocatedMinor,
        unallocatedAmount: amountMinor - _totalAllocatedMinor,
        referenceNumber: _refController.text.trim().isEmpty
            ? null
            : _refController.text.trim(),
        status: autoPost ? 'POSTED' : 'DRAFT',
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      final allocationModels = <PaymentAllocationModel>[];
      for (final a in _allocations) {
        if (a.allocatedMinor > 0) {
          allocationModels.add(
            PaymentAllocationModel(
              id: 'alloc_${paymentId}_${a.invoiceId}',
              organizationId: widget.organizationId,
              paymentId: paymentId,
              invoiceId: a.invoiceId,
              allocatedAmount: a.allocatedMinor,
              allocationDate: _dateController.text.trim(),
              createdAt: now,
            ),
          );
        }
      }

      await _paymentRepo.savePayment(
        payment: payment,
        allocations: allocationModels,
        autoPost: autoPost,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              autoPost
                  ? 'تم ترحيل سند الدفع $paymentNumber وتحديث الأرصدة بنجاح'
                  : 'تم حفظ مسودة سند الدفع $paymentNumber',
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
    final isReceipt = _paymentType == 'RECEIPT';
    final partyList = _filteredParties;
    final isEditing = widget.paymentToEdit != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            isEditing
                ? 'تعديل مسودة ${widget.paymentToEdit!.paymentNumber}'
                : (isReceipt ? 'سند قبض جديد' : 'سند صرف جديد'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // 1. Header & Party Card
                          _buildHeaderCard(partyList, isReceipt),
                          const SizedBox(height: 16),

                          // 2. Invoices Allocation Card
                          _buildAllocationCard(),
                        ],
                      ),
                    ),

                    // 3. Bottom Submit Bar
                    _buildBottomBar(isReceipt),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderCard(List<PartyModel> partyList, bool isReceipt) {
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
          // Type Toggle
          Row(
            children: [
              Expanded(
                child: _buildTypeToggle(
                  'RECEIPT',
                  'سند قبض (استلام)',
                  Icons.arrow_downward_rounded,
                  AppColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTypeToggle(
                  'PAYMENT',
                  'سند صرف (دفع)',
                  Icons.arrow_upward_rounded,
                  AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Party Row with Quick Add
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isReceipt ? 'المستلم منه (العميل) *' : 'المدفوع له (المورد) *',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkNavy,
                ),
              ),
              TextButton.icon(
                onPressed: _openQuickAddParty,
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: Text(
                  isReceipt ? 'إضافة عميل جديد' : 'إضافة مورد جديد',
                  style: const TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Party Dropdown
          if (partyList.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isReceipt
                          ? 'لا يوجد عملاء مسجلون لهذه المؤسسة'
                          : 'لا يوجد موردون مسجلون لهذه المؤسسة',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E)),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _openQuickAddParty,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      isReceipt ? '+ إضافة عميل' : '+ إضافة مورد',
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            )
          else
            DropdownButtonFormField<String>(
              value: partyList.any((p) => p.id == _selectedPartyId)
                  ? _selectedPartyId
                  : null,
              isExpanded: true,
              decoration: InputDecoration(
                hintText: isReceipt ? 'اختر العميل...' : 'اختر المورد...',
                prefixIcon: const Icon(Icons.person_rounded, size: 20),
              ),
              items: partyList.map((p) {
                return DropdownMenuItem(
                  value: p.id,
                  child: Text('${p.code} - ${p.nameAr}'),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedPartyId = val);
                if (val != null) _loadUnpaidInvoices(val);
              },
              validator: (v) => v == null ? 'يرجى تحديد الطرف' : null,
            ),
          const SizedBox(height: 12),

          // Cash/Bank Account Dropdown
          DropdownButtonFormField<String>(
            value: _selectedCashAccountId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'حساب الصندوق / البنك *',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined, size: 20),
            ),
            items: _cashAccounts.map((a) {
              return DropdownMenuItem(
                value: a.id,
                child: Text('${a.accountCode} - ${a.accountNameAr}'),
              );
            }).toList(),
            onChanged: (val) => setState(() => _selectedCashAccountId = val),
            validator: (v) => v == null ? 'يرجى تحديد حساب النقدية' : null,
          ),
          const SizedBox(height: 12),

          // Amount, Currency & Payment Method Row
          Row(
            children: [
              Expanded(
                flex: 4,
                child: TextFormField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'مبلغ السند *',
                    hintText: '0.00',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'مطلوب';
                    final numVal = double.tryParse(v.trim());
                    if (numVal == null || numVal <= 0) return 'مبلغ غير صالح';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _currencyCode,
                  decoration: const InputDecoration(labelText: 'العملة'),
                  items: const [
                    DropdownMenuItem(value: 'YER', child: Text('YER')),
                    DropdownMenuItem(value: 'SAR', child: Text('SAR')),
                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                  ],
                  onChanged: (val) {
                    if (val != null) _updateCurrency(val);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                  items: const [
                    DropdownMenuItem(value: 'CASH', child: Text('نقداً')),
                    DropdownMenuItem(
                        value: 'BANK_TRANSFER', child: Text('تحويل بنكي')),
                    DropdownMenuItem(value: 'CHEQUE', child: Text('شيك')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _paymentMethod = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Date & Reference Row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _dateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'تاريخ السند',
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
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _refController,
                  decoration: const InputDecoration(
                    labelText: 'الرقم المرجعي / الشيك',
                    hintText: 'اختياري',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'ملاحظات السند (اختياري)',
              hintText: 'بيان إضافي للعملية...',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeToggle(
      String type, String title, IconData icon, Color activeColor) {
    final isSelected = _paymentType == type;
    return InkWell(
      onTap: () {
        setState(() {
          _paymentType = type;
          _selectedPartyId = null;
          _allocations.clear();
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? activeColor : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationCard() {
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
                    'تخصيص السداد للفواتير المستحقة',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkNavy,
                    ),
                  ),
                ],
              ),
              if (_allocations.isNotEmpty)
                TextButton.icon(
                  onPressed: _autoAllocate,
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                  label: const Text('تخصيص تلقائي',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isLoadingInvoices)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (_selectedPartyId == null)
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: const Text(
                'اختر الطرف أعلاه لعرض الفواتير المستحقة وتخصيص السداد لها',
                style:
                    TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            )
          else if (_allocations.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      color: AppColors.success, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'لا توجد فواتير غير مسددة لهذا الطرف حالياً. سيتم قيد المبلغ كدفعة مقدمة على الحساب.',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkNavy),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            ...List.generate(_allocations.length, (i) {
              final a = _allocations[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.invoiceNumber,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'المتبقي: ${(a.remainingAmount / 100.0).toStringAsFixed(2)} $_currencyCode',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: a.controller,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          hintText: '0.00',
                          suffixText: _currencyCode,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.done_all_rounded,
                          size: 18, color: AppColors.primary),
                      tooltip: 'سداد كامل المتبقي',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        a.controller.text =
                            (a.remainingAmount / 100.0).toStringAsFixed(2);
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isReceipt) {
    final int amountMinor = _paymentAmountMinor;
    final int allocatedMinor = _totalAllocatedMinor;
    final int unallocatedMinor = _unallocatedMinor;

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'المخصص للفواتير:',
                  style:
                      TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
                Text(
                  '${(allocatedMinor / 100.0).toStringAsFixed(2)} $_currencyCode',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (unallocatedMinor > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'دفعة مقدمة (غير مخصصة):',
                    style: TextStyle(fontSize: 12.5, color: AppColors.primary),
                  ),
                  Text(
                    '${(unallocatedMinor / 100.0).toStringAsFixed(2)} $_currencyCode',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
                  ),
                ],
              ),
            ],
            const Divider(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isReceipt ? 'إجمالي المقبوض:' : 'إجمالي المصروف:',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNavy,
                  ),
                ),
                Text(
                  '${(amountMinor / 100.0).toStringAsFixed(2)} $_currencyCode',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
                    onPressed: _isSaving ? null : () => _submit(autoPost: true),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('ترحيل السند'),
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
