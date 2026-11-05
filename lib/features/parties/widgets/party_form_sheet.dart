import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../data/party_repository.dart';
import '../models/party_model.dart';

/// Modal bottom sheet form for adding or editing a customer or supplier.
class PartyFormSheet extends StatefulWidget {
  final String organizationId;
  final String baseCurrencyCode;
  final PartyModel? partyToEdit;
  final String initialType; // 'CUSTOMER', 'SUPPLIER', 'BOTH'

  const PartyFormSheet({
    super.key,
    required this.organizationId,
    required this.baseCurrencyCode,
    this.partyToEdit,
    this.initialType = 'CUSTOMER',
  });

  @override
  State<PartyFormSheet> createState() => _PartyFormSheetState();
}

class _PartyFormSheetState extends State<PartyFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _partyRepo = PartyRepository();

  late String _selectedType;
  late TextEditingController _codeController;
  late TextEditingController _nameArController;
  late TextEditingController _nameEnController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _taxNumberController;
  late TextEditingController _creditLimitController;
  late String _selectedCurrency;

  bool _isSaving = false;
  bool _autoCodeLoading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.partyToEdit;
    _selectedType = p?.partyType ?? widget.initialType;
    _codeController = TextEditingController(text: p?.code ?? '');
    _nameArController = TextEditingController(text: p?.nameAr ?? '');
    _nameEnController = TextEditingController(text: p?.nameEn ?? '');
    _phoneController = TextEditingController(text: p?.phone ?? '');
    _emailController = TextEditingController(text: p?.email ?? '');
    _addressController = TextEditingController(text: p?.address ?? '');
    _taxNumberController = TextEditingController(text: p?.taxNumber ?? '');
    _creditLimitController = TextEditingController(
      text: p != null && p.creditLimit > 0
          ? (p.creditLimit / 100.0).toStringAsFixed(2)
          : '',
    );
    _selectedCurrency = p?.defaultCurrencyCode ?? widget.baseCurrencyCode;

    if (p == null) {
      _generateNextCode();
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameArController.dispose();
    _nameEnController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _taxNumberController.dispose();
    _creditLimitController.dispose();
    super.dispose();
  }

  Future<void> _generateNextCode() async {
    setState(() => _autoCodeLoading = true);
    try {
      final code = await _partyRepo.getNextPartyCode(
        widget.organizationId,
        _selectedType,
      );
      if (mounted) {
        setState(() {
          _codeController.text = code;
          _autoCodeLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _autoCodeLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final double limitNum =
          double.tryParse(_creditLimitController.text.trim()) ?? 0.0;
      final int creditLimitMinor = (limitNum * 100).round();

      if (widget.partyToEdit == null) {
        // Create
        final newId = 'party_${DateTime.now().millisecondsSinceEpoch}';
        final newParty = PartyModel(
          id: newId,
          organizationId: widget.organizationId,
          code: _codeController.text.trim(),
          partyType: _selectedType,
          nameAr: _nameArController.text.trim(),
          nameEn: _nameEnController.text.trim().isEmpty
              ? null
              : _nameEnController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          address: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          taxNumber: _taxNumberController.text.trim().isEmpty
              ? null
              : _taxNumberController.text.trim(),
          creditLimit: creditLimitMinor,
          defaultCurrencyCode: _selectedCurrency,
          createdAt: '',
          updatedAt: '',
        );

        await _partyRepo.createParty(newParty);
      } else {
        // Update
        final updated = widget.partyToEdit!.copyWith(
          code: _codeController.text.trim(),
          partyType: _selectedType,
          nameAr: _nameArController.text.trim(),
          nameEn: _nameEnController.text.trim().isEmpty
              ? null
              : _nameEnController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          address: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          taxNumber: _taxNumberController.text.trim().isEmpty
              ? null
              : _taxNumberController.text.trim(),
          creditLimit: creditLimitMinor,
          defaultCurrencyCode: _selectedCurrency,
        );

        await _partyRepo.updateParty(updated);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('UNIQUE')
                  ? 'رمز الطرف مسجل مسبقاً لمؤسسة أخرى أو لهذا الحساب'
                  : 'خطأ أثناء الحفظ: ${e.toString().replaceAll("Exception: ", "")}',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.partyToEdit != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? 'تعديل بيانات الطرف' : 'إضافة طرف جديد',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkNavy,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            // Form body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Party Type Segmented
                      const Text(
                        'نوع الطرف المحاسبي *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildTypeOption(
                              'CUSTOMER', 'عميل', Icons.person_rounded),
                          const SizedBox(width: 8),
                          _buildTypeOption(
                              'SUPPLIER', 'مورد', Icons.storefront_rounded),
                          const SizedBox(width: 8),
                          _buildTypeOption(
                              'BOTH', 'عميل ومورد', Icons.swap_horiz_rounded),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 2. Code & Name Ar
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: TextFormField(
                              controller: _codeController,
                              textDirection: TextDirection.ltr,
                              decoration: InputDecoration(
                                labelText: 'الرمز *',
                                hintText: 'CUST-001',
                                suffixIcon: _autoCodeLoading
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      )
                                    : null,
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'مطلوب'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 7,
                            child: TextFormField(
                              controller: _nameArController,
                              decoration: const InputDecoration(
                                labelText: 'الاسم بالعربية *',
                                hintText: 'مثال: شركة الأمل التجارية',
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'مطلوب'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 3. Name En
                      TextFormField(
                        controller: _nameEnController,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'الاسم بالإنجليزية (اختياري)',
                          hintText: 'e.g. Al-Amal Trading Co.',
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 4. Phone & Email
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              textDirection: TextDirection.ltr,
                              decoration: const InputDecoration(
                                labelText: 'رقم الهاتف',
                                hintText: '777 000 000',
                                prefixIcon:
                                    Icon(Icons.phone_outlined, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textDirection: TextDirection.ltr,
                              decoration: const InputDecoration(
                                labelText: 'البريد الإلكتروني',
                                hintText: 'info@example.com',
                                prefixIcon:
                                    Icon(Icons.email_outlined, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 5. Address & Tax Number
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'العنوان / الموقع',
                          hintText: 'صنعاء - شارع الزبيري',
                          prefixIcon:
                              Icon(Icons.location_on_outlined, size: 20),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _taxNumberController,
                              textDirection: TextDirection.ltr,
                              decoration: const InputDecoration(
                                labelText: 'الرقم الضريبي / السجل',
                                hintText: '10023455',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _creditLimitController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              textDirection: TextDirection.ltr,
                              decoration: const InputDecoration(
                                labelText: 'سقف الائتمان',
                                hintText: '0.00',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 6. Currency Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedCurrency,
                        decoration: const InputDecoration(
                          labelText: 'العملة الافتراضية للتعامل',
                          prefixIcon:
                              Icon(Icons.monetization_on_outlined, size: 20),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'YER',
                            child: Text('ريال يمني (YER)'),
                          ),
                          DropdownMenuItem(
                            value: 'SAR',
                            child: Text('ريال سعودي (SAR)'),
                          ),
                          DropdownMenuItem(
                            value: 'USD',
                            child: Text('دولار أمريكي (USD)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCurrency = val);
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom Action Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(isEditing ? 'حفظ التعديلات' : 'إضافة الطرف'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption(String type, String title, IconData icon) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedType = type;
            if (widget.partyToEdit == null) {
              _generateNextCode();
            }
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color:
                      isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
