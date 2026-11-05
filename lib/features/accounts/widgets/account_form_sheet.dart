import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/account_model.dart';

/// Modal bottom sheet form for adding or editing a Chart of Accounts entry.
class AccountFormSheet extends StatefulWidget {
  final String organizationId;
  final String defaultCurrency;
  final AccountModel? initialAccount;
  final List<AccountModel> availableParents;
  final Future<void> Function(AccountModel account) onSave;

  const AccountFormSheet({
    super.key,
    required this.organizationId,
    required this.defaultCurrency,
    this.initialAccount,
    required this.availableParents,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    required String organizationId,
    required String defaultCurrency,
    AccountModel? account,
    required List<AccountModel> availableParents,
    required Future<void> Function(AccountModel account) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AccountFormSheet(
        organizationId: organizationId,
        defaultCurrency: defaultCurrency,
        initialAccount: account,
        availableParents: availableParents,
        onSave: onSave,
      ),
    );
  }

  @override
  State<AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends State<AccountFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _codeController;
  late TextEditingController _nameArController;
  late TextEditingController _nameEnController;

  String _selectedType = 'ASSET';
  String _selectedNature = 'DEBIT';
  String? _selectedParentId;
  String? _selectedCurrency;
  bool _isCashBank = false;
  bool _isReconcilable = false;
  bool _isLoading = false;

  final Map<String, String> _typeNames = {
    'ASSET': 'أصول (Assets)',
    'LIABILITY': 'خصوم (Liabilities)',
    'EQUITY': 'حقوق ملكية (Equity)',
    'REVENUE': 'إيرادات (Revenue)',
    'EXPENSE': 'مصروفات (Expenses)',
  };

  @override
  void initState() {
    super.initState();
    final acc = widget.initialAccount;

    _codeController = TextEditingController(text: acc?.accountCode ?? '');
    _nameArController = TextEditingController(text: acc?.accountNameAr ?? '');
    _nameEnController = TextEditingController(text: acc?.accountNameEn ?? '');

    if (acc != null) {
      _selectedType = acc.accountType;
      _selectedNature = acc.accountNature;
      _selectedParentId = acc.parentId;
      _selectedCurrency = acc.currencyCode;
      _isCashBank = acc.isCashBank;
      _isReconcilable = acc.isReconcilable;
    } else {
      _selectedCurrency = widget.defaultCurrency;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameArController.dispose();
    _nameEnController.dispose();
    super.dispose();
  }

  void _onTypeChanged(String newType) {
    setState(() {
      _selectedType = newType;
      // Set default accounting nature automatically based on standard rules
      if (newType == 'ASSET' || newType == 'EXPENSE') {
        _selectedNature = 'DEBIT';
      } else {
        _selectedNature = 'CREDIT';
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isCashBank &&
        (_selectedCurrency == null || _selectedCurrency!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('حسابات الصناديق والبنوك تتطلب تعيين عملة محددة للحساب.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final id = widget.initialAccount?.id ??
          '${widget.organizationId}_${_codeController.text.trim()}';

      final account = AccountModel(
        id: id,
        organizationId: widget.organizationId,
        accountCode: _codeController.text.trim(),
        accountNameAr: _nameArController.text.trim(),
        accountNameEn: _nameEnController.text.trim().isEmpty
            ? null
            : _nameEnController.text.trim(),
        accountType: _selectedType,
        accountNature: _selectedNature,
        parentId: _selectedParentId,
        currencyCode: _selectedCurrency,
        isCashBank: _isCashBank,
        isReconcilable: _isReconcilable,
        isActive: widget.initialAccount?.isActive ?? true,
        isSystem: widget.initialAccount?.isSystem ?? false,
        createdAt: widget.initialAccount?.createdAt ?? now,
      );

      await widget.onSave(account);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialAccount != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isEditing ? 'تعديل بيانات الحساب' : 'إضافة حساب جديد',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkNavy,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textSecondary),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),

            // Form Content
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Account Code & Name
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'رقم الحساب *',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.darkNavy,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _codeController,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration(
                                    hint: 'مثال: 1113',
                                    icon: Icons.tag_rounded,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'مطلوب';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'اسم الحساب (بالعربية) *',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.darkNavy,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _nameArController,
                                  textDirection: TextDirection.rtl,
                                  decoration: _inputDecoration(
                                    hint: 'مثال: بنك التضامن الإسلامي',
                                    icon: Icons.title_rounded,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'يرجى إدخال اسم الحساب';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 2. Account Classification / Type
                      const Text(
                        'تصنيف الحساب الرئيسي *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: _inputDecoration(
                            hint: '', icon: Icons.category_outlined),
                        items: _typeNames.entries.map((e) {
                          return DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value,
                                style: const TextStyle(fontSize: 13.5)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) _onTypeChanged(val);
                        },
                      ),
                      const SizedBox(height: 14),

                      // 3. Normal Accounting Nature (Debit vs Credit)
                      const Text(
                        'طبيعة الرصيد المحاسبي *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('مدين (Debit)',
                                  style: TextStyle(fontSize: 13)),
                              value: 'DEBIT',
                              groupValue: _selectedNature,
                              contentPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              onChanged: (v) =>
                                  setState(() => _selectedNature = v!),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('دائن (Credit)',
                                  style: TextStyle(fontSize: 13)),
                              value: 'CREDIT',
                              groupValue: _selectedNature,
                              contentPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              onChanged: (v) =>
                                  setState(() => _selectedNature = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 4. Parent Account (Optional)
                      const Text(
                        'الحساب الأب (الحساب الرئيسي)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String?>(
                        value: _selectedParentId,
                        decoration: _inputDecoration(
                          hint: 'حساب جذري مستقل (بدون أب)',
                          icon: Icons.account_tree_outlined,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('حساب جذري مستقل',
                                style: TextStyle(fontSize: 13)),
                          ),
                          ...widget.availableParents
                              .where((p) => p.id != widget.initialAccount?.id)
                              .map((p) {
                            return DropdownMenuItem<String?>(
                              value: p.id,
                              child: Text(
                                '${p.accountCode} - ${p.accountNameAr}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedParentId = val),
                      ),
                      const SizedBox(height: 14),

                      // 5. Account Currency
                      const Text(
                        'عملة الحساب',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String?>(
                        value: _selectedCurrency,
                        decoration: _inputDecoration(
                          hint: 'عملة المنشأة الأساسية (أو متعدد العملات)',
                          icon: Icons.monetization_on_outlined,
                        ),
                        items: const [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('متعدد العملات / العملة الأساسية',
                                style: TextStyle(fontSize: 13)),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'YER',
                            child: Text('ريال يمني (YER)',
                                style: TextStyle(fontSize: 13)),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'USD',
                            child: Text('دولار أمريكي (USD)',
                                style: TextStyle(fontSize: 13)),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'SAR',
                            child: Text('ريال سعودي (SAR)',
                                style: TextStyle(fontSize: 13)),
                          ),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedCurrency = val),
                      ),
                      const SizedBox(height: 14),

                      // 6. Cash / Bank Account Toggle
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: SwitchListTile(
                          title: const Text(
                            'حساب صندوق نقدية أو بنك',
                            style: TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            'يتيح استخدام الحساب في سندات القبض والصرف والدفعات',
                            style: TextStyle(
                                fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                          value: _isCashBank,
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            setState(() {
                              _isCashBank = val;
                              if (val && _selectedCurrency == null) {
                                _selectedCurrency = widget.defaultCurrency;
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Submit Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isEditing ? 'حفظ التعديلات' : 'إضافة الحساب',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
      prefixIcon: Icon(icon, size: 19, color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}
