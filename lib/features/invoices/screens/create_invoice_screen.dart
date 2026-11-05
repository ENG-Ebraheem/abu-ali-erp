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
import '../data/invoice_repository.dart';
import '../models/invoice_line_model.dart';
import '../models/invoice_model.dart';

/// Screen for creating, editing, and itemizing sales or purchase invoices (cash and credit).
class CreateInvoiceScreen extends StatefulWidget {
  final String organizationId;
  final String baseCurrencyCode;
  final String initialType; // 'SALES' or 'PURCHASE'
  final InvoiceModel? invoiceToEdit;

  const CreateInvoiceScreen({
    super.key,
    required this.organizationId,
    required this.baseCurrencyCode,
    this.initialType = 'SALES',
    this.invoiceToEdit,
  });

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _InvoiceLineDraft {
  final TextEditingController descController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController priceController = TextEditingController();
  final TextEditingController discountController =
      TextEditingController(text: '0');
  final TextEditingController taxController = TextEditingController(text: '0');
  String? accountId;

  _InvoiceLineDraft({this.accountId});

  double get quantity => double.tryParse(qtyController.text.trim()) ?? 1.0;
  double get unitPrice => double.tryParse(priceController.text.trim()) ?? 0.0;
  double get discount => double.tryParse(discountController.text.trim()) ?? 0.0;
  double get tax => double.tryParse(taxController.text.trim()) ?? 0.0;

  int get quantityScaled => (quantity * 1000).round();
  int get unitPriceMinor => (unitPrice * 100).round();
  int get discountMinor => (discount * 100).round();
  int get taxMinor => (tax * 100).round();

  int get grossMinor => ((quantityScaled * unitPriceMinor) / 1000).round();

  int get lineTotalMinor {
    final net = grossMinor - discountMinor + taxMinor;
    return net > 0 ? net : 0;
  }

  void dispose() {
    descController.dispose();
    qtyController.dispose();
    priceController.dispose();
    discountController.dispose();
    taxController.dispose();
  }
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceRepo = InvoiceRepository();
  final _partyRepo = PartyRepository();
  final _accountRepo = AccountRepository();
  final _rateRepo = ExchangeRateRepository();

  late String _invoiceType;
  bool _isCash = false;
  String? _selectedPartyId;
  String? _selectedCashAccountId;
  late String _currencyCode;
  int _exchangeRateScaled = DatabaseConstants.exchangeRateScale;

  final TextEditingController _issueDateController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<PartyModel> _parties = [];
  List<AccountModel> _accounts = [];
  List<AccountModel> _cashAccounts = [];
  final List<_InvoiceLineDraft> _lines = [];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final edit = widget.invoiceToEdit;
    if (edit != null) {
      _invoiceType = edit.invoiceType;
      _currencyCode = edit.currencyCode;
      _selectedPartyId = edit.partyId;
      _exchangeRateScaled = edit.exchangeRateScaled;
      _issueDateController.text = edit.issueDate;
      _dueDateController.text = edit.dueDate;
      _notesController.text = edit.notes ?? '';
    } else {
      _invoiceType = widget.initialType;
      _currencyCode = widget.baseCurrencyCode;
      _issueDateController.text =
          DateTime.now().toIso8601String().split('T').first;
      _dueDateController.text = DateTime.now()
          .add(const Duration(days: 30))
          .toIso8601String()
          .split('T')
          .first;
    }

    _loadDependencies();
  }

  @override
  void dispose() {
    _issueDateController.dispose();
    _dueDateController.dispose();
    _notesController.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  bool get _isSalesKind =>
      _invoiceType == 'SALES' || _invoiceType == 'SALES_RETURN';

  String get _appBarTitle {
    if (widget.invoiceToEdit != null) {
      return 'تعديل مسودة الفاتورة ${widget.invoiceToEdit!.invoiceNumber}';
    }
    switch (_invoiceType) {
      case 'SALES':
        return 'فاتورة مبيعات جديدة';
      case 'PURCHASE':
        return 'فاتورة مشتريات جديدة';
      case 'SALES_RETURN':
        return 'إشعار مردود مبيعات جديد';
      case 'PURCHASE_RETURN':
        return 'إشعار مردود مشتريات جديد';
      default:
        return 'فاتورة جديدة';
    }
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
          _accounts = accs;
          _cashAccounts = cashAccs;
          if (cashAccs.isNotEmpty) {
            _selectedCashAccountId ??= cashAccs.first.id;
          }
          _isLoading = false;
        });

        // Initialize lines if editing
        if (widget.invoiceToEdit != null &&
            widget.invoiceToEdit!.lines.isNotEmpty &&
            _lines.isEmpty) {
          for (final l in widget.invoiceToEdit!.lines) {
            final draft = _InvoiceLineDraft(accountId: l.accountId);
            draft.descController.text = l.itemDescription;
            draft.qtyController.text = l.quantityDouble.toString();
            draft.priceController.text =
                (l.unitPrice / 100.0).toStringAsFixed(2);
            draft.discountController.text =
                (l.discountAmount / 100.0).toStringAsFixed(2);
            draft.taxController.text = (l.taxAmount / 100.0).toStringAsFixed(2);
            _bindLineListeners(draft);
            _lines.add(draft);
          }
        } else if (_lines.isEmpty) {
          _addLine();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _bindLineListeners(_InvoiceLineDraft line) {
    line.qtyController.addListener(() => setState(() {}));
    line.priceController.addListener(() => setState(() {}));
    line.discountController.addListener(() => setState(() {}));
    line.taxController.addListener(() => setState(() {}));
  }

  void _addLine() {
    String? defaultAccId;
    if (_isSalesKind) {
      defaultAccId = _accounts
          .where((a) => a.accountCode == '4101' || a.accountType == 'REVENUE')
          .map((a) => a.id)
          .firstOrNull;
    } else {
      defaultAccId = _accounts
          .where((a) => a.accountCode == '5101' || a.accountType == 'EXPENSE')
          .map((a) => a.id)
          .firstOrNull;
    }
    defaultAccId ??= _accounts.firstOrNull?.id;

    final line = _InvoiceLineDraft(accountId: defaultAccId);
    _bindLineListeners(line);
    setState(() => _lines.add(line));
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب أن تحتوي الفاتورة على بند واحد على الأقل'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    final removed = _lines.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  int get _subtotalGrossMinor => _lines.fold(0, (sum, l) => sum + l.grossMinor);
  int get _totalDiscountMinor =>
      _lines.fold(0, (sum, l) => sum + l.discountMinor);
  int get _totalTaxMinor => _lines.fold(0, (sum, l) => sum + l.taxMinor);
  int get _totalFinalMinor =>
      _lines.fold(0, (sum, l) => sum + l.lineTotalMinor);

  Future<void> _updateCurrency(String newCode) async {
    int scaled = DatabaseConstants.exchangeRateScale;
    if (newCode != widget.baseCurrencyCode) {
      final rateModel = await _rateRepo.getLatestRate(
        organizationId: widget.organizationId,
        fromCurrency: newCode,
        toCurrency: widget.baseCurrencyCode,
        asOfDate: _issueDateController.text.trim(),
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
    if (_isSalesKind) {
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
        initialType: _isSalesKind ? 'CUSTOMER' : 'SUPPLIER',
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
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isSalesKind
                  ? 'تمت إضافة واختيار العميل بنجاح'
                  : 'تمت إضافة واختيار المورد بنجاح',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _seedDefaultCOA() async {
    setState(() => _isLoading = true);
    try {
      await _accountRepo.seedStandardChartOfAccounts(
        widget.organizationId,
        widget.baseCurrencyCode,
      );
      final accs = await _accountRepo.getAccountsFlat(
        widget.organizationId,
        includeInactive: false,
      );
      final cashAccs = accs.where((a) => a.isCashBank).toList();

      if (mounted) {
        setState(() {
          _accounts = accs;
          _cashAccounts = cashAccs;
          if (cashAccs.isNotEmpty) {
            _selectedCashAccountId ??= cashAccs.first.id;
          }
          _isLoading = false;
        });

        if (_lines.isNotEmpty && _lines.first.accountId == null) {
          final defaultAccId = _isSalesKind
              ? _accounts
                  .where((a) =>
                      a.accountCode == '4101' || a.accountType == 'REVENUE')
                  .map((a) => a.id)
                  .firstOrNull
              : _accounts
                  .where((a) =>
                      a.accountCode == '5101' || a.accountType == 'EXPENSE')
                  .map((a) => a.id)
                  .firstOrNull;
          _lines.first.accountId = defaultAccId ?? _accounts.firstOrNull?.id;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت تهيئة شجرة الحسابات الافتراضية بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تهيئة الحسابات: $e'),
            backgroundColor: AppColors.danger,
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

    if (_isCash && _selectedCashAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار حساب الصندوق أو البنك للسداد النقدي'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إضافة بند واحد على الأقل إلى الفاتورة'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    for (int i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      if (l.descController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('يرجى كتابة وصف الصنف في البند رقم ${i + 1}'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      if (l.unitPriceMinor <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('يرجى تحديد سعر الوحدة في البند رقم ${i + 1}'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      if (l.accountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('يرجى تحديد حساب الإيراد/المصروف في البند رقم ${i + 1}'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final String invId = widget.invoiceToEdit?.id ??
          'inv_${DateTime.now().millisecondsSinceEpoch}';
      final String invoiceNumber = widget.invoiceToEdit?.invoiceNumber ??
          await _invoiceRepo.getNextInvoiceNumber(
            widget.organizationId,
            _invoiceType,
          );

      final header = InvoiceModel(
        id: invId,
        organizationId: widget.organizationId,
        partyId: _selectedPartyId!,
        invoiceType: _invoiceType,
        invoiceNumber: invoiceNumber,
        issueDate: _issueDateController.text.trim(),
        dueDate: _dueDateController.text.trim(),
        currencyCode: _currencyCode,
        exchangeRateScaled: _exchangeRateScaled,
        subtotal: _subtotalGrossMinor,
        taxAmount: _totalTaxMinor,
        discountAmount: _totalDiscountMinor,
        totalAmount: _totalFinalMinor,
        status: autoPost ? 'POSTED' : 'DRAFT',
        paymentStatus: _isCash && autoPost ? 'PAID' : 'UNPAID',
        paidAmount: _isCash && autoPost ? _totalFinalMinor : 0,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      final lineModels = <InvoiceLineModel>[];
      for (int i = 0; i < _lines.length; i++) {
        final l = _lines[i];
        lineModels.add(
          InvoiceLineModel(
            id: 'line_${invId}_${i + 1}',
            organizationId: widget.organizationId,
            invoiceId: invId,
            lineNumber: i + 1,
            accountId: l.accountId!,
            itemDescription: l.descController.text.trim(),
            quantityScaled: l.quantityScaled,
            unitPrice: l.unitPriceMinor,
            discountAmount: l.discountMinor,
            taxAmount: l.taxMinor,
            lineTotal: l.lineTotalMinor,
          ),
        );
      }

      await _invoiceRepo.saveInvoice(
        invoice: header,
        lines: lineModels,
        autoPost: autoPost,
        cashBankAccountId: _isCash ? _selectedCashAccountId : null,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              autoPost
                  ? 'تم ترحيل الفاتورة $invoiceNumber بنجاح'
                  : 'تم حفظ مسودة الفاتورة $invoiceNumber',
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
    final partyList = _filteredParties;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            _appBarTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'إضافة بند',
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
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (_accounts.isEmpty) ...[
                            _buildMissingAccountsBanner(),
                            const SizedBox(height: 12),
                          ],
                          // 1. Header Card
                          _buildHeaderCard(partyList),
                          const SizedBox(height: 16),

                          // 2. Line Items Header
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
                                    'بنود الفاتورة',
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
                                label: const Text('إضافة بند'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // 3. Line Items List
                          ...List.generate(_lines.length, (index) {
                            return _buildLineCard(index);
                          }),
                        ],
                      ),
                    ),

                    // 4. Bottom Total & Submit Bar
                    _buildBottomBar(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMissingAccountsBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_tree_outlined,
              color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'شجرة الحسابات غير مهيأة لهذه المؤسسة. قم بتهيئتها لربط بنود الفاتورة بحسابات الإيراد والمصروف.',
              style: TextStyle(fontSize: 12, color: AppColors.darkNavy),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _seedDefaultCOA,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('تهيئة الآن', style: TextStyle(fontSize: 11.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(List<PartyModel> partyList) {
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
          // Type Toggle (Sales vs Purchase vs Returns)
          Row(
            children: [
              Expanded(
                child: _buildTypeToggle(
                    'SALES', 'فاتورة مبيعات', Icons.shopping_bag_outlined),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTypeToggle(
                    'PURCHASE', 'فاتورة مشتريات', Icons.shopping_cart_outlined),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildTypeToggle(
                    'SALES_RETURN', 'مردود مبيعات', Icons.assignment_return_outlined),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTypeToggle(
                    'PURCHASE_RETURN', 'مردود مشتريات', Icons.assignment_returned_outlined),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Cash vs Credit Toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isCash = false),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color:
                            !_isCash ? AppColors.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: !_isCash ? AppTheme.cardShadow : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 16,
                            color: !_isCash
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'آجل (ذمم مدينة/دائنة)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: !_isCash
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: !_isCash
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isCash = true),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _isCash ? AppColors.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _isCash ? AppTheme.cardShadow : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            size: 16,
                            color: _isCash
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'نقداً (صندوق / بنك)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  _isCash ? FontWeight.bold : FontWeight.normal,
                              color: _isCash
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // If Cash, Cash/Bank Account Dropdown
          if (_isCash) ...[
            DropdownButtonFormField<String>(
              value: _selectedCashAccountId,
              decoration: const InputDecoration(
                labelText: 'حساب الصندوق / البنك المسدد إليه *',
                prefixIcon:
                    Icon(Icons.account_balance_wallet_outlined, size: 20),
              ),
              items: _cashAccounts.map((a) {
                return DropdownMenuItem(
                  value: a.id,
                  child: Text('${a.accountCode} - ${a.accountNameAr}'),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedCashAccountId = val),
              validator: (v) =>
                  _isCash && v == null ? 'يرجى تحديد حساب النقدية' : null,
            ),
            const SizedBox(height: 12),
          ],

          // Party Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isSalesKind ? 'العميل *' : 'المورد *',
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
                  _isSalesKind
                      ? 'إضافة عميل جديد'
                      : 'إضافة مورد جديد',
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

          // Party Dropdown or Empty State
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
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFFD97706),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isSalesKind
                          ? 'لا يوجد عملاء مسجلون لهذه المؤسسة بعد'
                          : 'لا يوجد موردون مسجلون لهذه المؤسسة بعد',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
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
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _isSalesKind ? '+ إضافة عميل' : '+ إضافة مورد',
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
                hintText: _isSalesKind
                    ? 'اختر العميل...'
                    : 'اختر المورد...',
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
              },
              validator: (v) => v == null ? 'يرجى تحديد الطرف' : null,
            ),
          const SizedBox(height: 12),

          // Dates & Currency Row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _issueDateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'تاريخ الإصدار',
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
                      _issueDateController.text =
                          picked.toIso8601String().split('T').first;
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
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
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'ملاحظات الفاتورة (اختياري)',
              hintText: 'شروط الدفع أو تفاصيل إضافية...',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeToggle(String type, String title, IconData icon) {
    final isSelected = _invoiceType == type;
    return InkWell(
      onTap: () {
        setState(() {
          _invoiceType = type;
          _selectedPartyId = null;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineCard(int index) {
    final line = _lines[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'البند #${index + 1}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkNavy,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.danger, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: () => _removeLine(index),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Description
          TextFormField(
            controller: line.descController,
            decoration: const InputDecoration(
              labelText: 'وصف السلعة / الخدمة *',
              hintText: 'مثال: توريد بضاعة / خدمات استشارية',
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
          ),
          const SizedBox(height: 10),

          // Account selector for line item
          DropdownButtonFormField<String>(
            value: line.accountId,
            decoration: InputDecoration(
              labelText: _isSalesKind
                  ? 'حساب الإيراد / المبيعات *'
                  : 'حساب المصروف أو الأصل أو المشتريات *',
            ),
            items: _accounts
                .where((a) => _isSalesKind
                    ? a.accountType == 'REVENUE'
                    : (a.accountType == 'EXPENSE' || a.accountType == 'ASSET'))
                .map((a) => DropdownMenuItem(
                      value: a.id,
                      child: Text('${a.accountCode} - ${a.accountNameAr}'),
                    ))
                .toList(),
            onChanged: (val) => setState(() => line.accountId = val),
            validator: (v) => v == null ? 'يرجى تحديد الحساب' : null,
          ),
          const SizedBox(height: 10),

          // Quantity, Price, Discount, and Tax Row
          Row(
            children: [
              // Quantity
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: line.qtyController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'الكمية',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Unit Price
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: line.priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'سعر الوحدة',
                    suffixText: _currencyCode,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Discount
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: line.discountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'الخصم',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Tax
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: line.taxController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'الضريبة',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Line total footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'إجمالي البند (شامل الضريبة والخصم):',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              Text(
                '${(line.lineTotalMinor / 100.0).toStringAsFixed(2)} $_currencyCode',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
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
                  'المجموع قبل الضريبة والخصم:',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  '${(_subtotalGrossMinor / 100.0).toStringAsFixed(2)} $_currencyCode',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (_totalDiscountMinor > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'إجمالي الخصم:',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  Text(
                    '-${(_totalDiscountMinor / 100.0).toStringAsFixed(2)} $_currencyCode',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger),
                  ),
                ],
              ),
            ],
            if (_totalTaxMinor > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'إجمالي الضريبة:',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  Text(
                    '+${(_totalTaxMinor / 100.0).toStringAsFixed(2)} $_currencyCode',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning),
                  ),
                ],
              ),
            ],
            const Divider(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'إجمالي الفاتورة الصافي:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNavy,
                  ),
                ),
                Text(
                  '${(_totalFinalMinor / 100.0).toStringAsFixed(2)} $_currencyCode',
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
                        : const Text('ترحيل الفاتورة'),
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
