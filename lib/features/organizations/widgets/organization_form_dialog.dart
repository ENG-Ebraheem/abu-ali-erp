import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../data/organization_branding_service.dart';
import '../models/organization_model.dart';
import '../services/institution_logo_picker.dart';

/// Modal bottom sheet form for creating or editing an organization.
class OrganizationFormSheet extends StatefulWidget {
  final Organization? initialOrganization;
  final Future<void> Function(Organization organization) onSave;

  const OrganizationFormSheet({
    super.key,
    this.initialOrganization,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    Organization? organization,
    required Future<void> Function(Organization organization) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OrganizationFormSheet(
        initialOrganization: organization,
        onSave: onSave,
      ),
    );
  }

  @override
  State<OrganizationFormSheet> createState() => _OrganizationFormSheetState();
}

class _OrganizationFormSheetState extends State<OrganizationFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _businessTypeController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _notesController;

  String _selectedCurrency = 'YER';
  bool _isLoading = false;
  String? _logoPath;
  late final String _orgId;

  final List<String> _suggestedTypes = [
    'تجارة عامة واستيراد',
    'مقاولات وبناء',
    'تجارة تجزئة وجملة',
    'خدمات وتقنية معلومات',
    'صناعي وإنتاجي',
  ];

  @override
  void initState() {
    super.initState();
    final org = widget.initialOrganization;
    _orgId = org?.id ?? 'org_${DateTime.now().millisecondsSinceEpoch}';

    _nameController = TextEditingController(text: org?.name ?? '');
    _codeController =
        TextEditingController(text: org?.code ?? _generateDefaultCode());
    _businessTypeController =
        TextEditingController(text: org?.businessType ?? 'تجارة عامة واستيراد');
    _phoneController = TextEditingController(text: org?.phone ?? '');
    _addressController = TextEditingController(text: org?.address ?? '');
    _notesController = TextEditingController(text: org?.notes ?? '');

    if (org != null) {
      _selectedCurrency = org.baseCurrencyCode;
      _loadExistingLogo(org.id);
    }
  }

  Future<void> _loadExistingLogo(String orgId) async {
    try {
      final b = await OrganizationBrandingService.instance.getBranding(orgId);
      if (b.logoPath != null && File(b.logoPath!).existsSync()) {
        if (mounted) setState(() => _logoPath = b.logoPath);
      }
    } catch (_) {}
  }

  Future<void> _pickLogo() async {
    final path = await InstitutionLogoPicker.showPickerModal(
      context: context,
      organizationId: _orgId,
    );
    if (path != null && mounted) {
      setState(() => _logoPath = path);
    }
  }

  String _generateDefaultCode() {
    final now = DateTime.now();
    return 'ORG-${now.millisecondsSinceEpoch.toString().substring(8)}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _businessTypeController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final id = _orgId;

      final org = Organization(
        id: id,
        name: _nameController.text.trim(),
        code: _codeController.text.trim().toUpperCase(),
        baseCurrencyCode: _selectedCurrency,
        businessType: _businessTypeController.text.trim().isEmpty
            ? null
            : _businessTypeController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        isActive: widget.initialOrganization?.isActive ?? true,
        createdAt: widget.initialOrganization?.createdAt ?? now,
        updatedAt: now,
      );

      await widget.onSave(org);

      if (_logoPath != null) {
        try {
          final currentBranding =
              await OrganizationBrandingService.instance.getBranding(id);
          await OrganizationBrandingService.instance.saveBranding(
            currentBranding.copyWith(
              logoPath: _logoPath,
              showLogo: true,
            ),
          );
        } catch (_) {}
      }

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
    final isEditing = widget.initialOrganization != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
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
            const SizedBox(height: 16),

            // Sheet Header
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
                      child: Icon(
                        isEditing
                            ? Icons.edit_note_rounded
                            : Icons.add_business_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isEditing ? 'تعديل بيانات المؤسسة' : 'إضافة مؤسسة جديدة',
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
            const SizedBox(height: 12),
            const Divider(height: 1),

            // Form Fields in ScrollView
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 0. Logo Picker Row
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: _logoPath != null &&
                                      File(_logoPath!).existsSync()
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(11),
                                      child: Image.file(
                                        File(_logoPath!),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                          Icons.business_rounded,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.add_photo_alternate_outlined,
                                      color: AppColors.textMuted,
                                      size: 28,
                                    ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _logoPath != null
                                        ? 'تم اختيار شعار المنشأة'
                                        : 'شعار المنشأة (اختياري)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.darkNavy,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'يظهر في المستندات والفواتير والتقارير',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        icon: const Icon(
                                            Icons.photo_camera_rounded,
                                            size: 15),
                                        label: Text(
                                          _logoPath != null
                                              ? 'تغيير الشعار'
                                              : 'اختيار الشعار',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          visualDensity: VisualDensity.compact,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: _pickLogo,
                                      ),
                                      if (_logoPath != null) ...[
                                        const SizedBox(width: 8),
                                        TextButton(
                                          style: TextButton.styleFrom(
                                            visualDensity:
                                                VisualDensity.compact,
                                            foregroundColor: AppColors.danger,
                                          ),
                                          onPressed: () => setState(
                                              () => _logoPath = null),
                                          child: const Text('إزالة',
                                              style: TextStyle(fontSize: 12)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 1. Organization Name (Required)
                      const Text(
                        'اسم المؤسسة أو الشركة *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        textDirection: TextDirection.rtl,
                        decoration: _inputDecoration(
                          hint: 'مثال: مؤسسة النور التجارية',
                          icon: Icons.domain_rounded,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'يرجى إدخال اسم المؤسسة';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 2. Organization Code (Required & Unique)
                      const Text(
                        'رمز المؤسسة (كود فريد) *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: _inputDecoration(
                          hint: 'مثال: NOOR أو ORG-01',
                          icon: Icons.tag_rounded,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'يرجى إدخال رمز فريد للمؤسسة';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 3. Base Currency (Segmented selector)
                      const Text(
                        'العملة الأساسية للحسابات *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            _CurrencyOption(
                              label: 'ريال يمني (YER)',
                              code: 'YER',
                              isSelected: _selectedCurrency == 'YER',
                              onTap: isEditing
                                  ? null
                                  : () =>
                                      setState(() => _selectedCurrency = 'YER'),
                            ),
                            const SizedBox(width: 4),
                            _CurrencyOption(
                              label: 'دولار أمريكي (USD)',
                              code: 'USD',
                              isSelected: _selectedCurrency == 'USD',
                              onTap: isEditing
                                  ? null
                                  : () =>
                                      setState(() => _selectedCurrency = 'USD'),
                            ),
                            const SizedBox(width: 4),
                            _CurrencyOption(
                              label: 'ريال سعودي (SAR)',
                              code: 'SAR',
                              isSelected: _selectedCurrency == 'SAR',
                              onTap: isEditing
                                  ? null
                                  : () =>
                                      setState(() => _selectedCurrency = 'SAR'),
                            ),
                          ],
                        ),
                      ),
                      if (isEditing)
                        const Padding(
                          padding: EdgeInsets.only(top: 4, right: 4),
                          child: Text(
                            'ملاحظة: لا يمكن تغيير العملة الأساسية لمؤسسة مسجلة لضمان توازن القيود.',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textMuted),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // 4. Business Type
                      const Text(
                        'نوع النشاط التجاري',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _businessTypeController,
                        decoration: _inputDecoration(
                          hint: 'مثال: تجارة جملة وتجزئة، مقاولات، إلخ',
                          icon: Icons.storefront_outlined,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Suggested quick choices
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _suggestedTypes.map((type) {
                          return ActionChip(
                            label: Text(type,
                                style: const TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: AppColors.background,
                            side: const BorderSide(color: AppColors.border),
                            onPressed: () {
                              setState(() {
                                _businessTypeController.text = type;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // 5. Phone & Address (Optional)
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'رقم الهاتف',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.darkNavy,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: _inputDecoration(
                                    hint: '77xxxxxxx',
                                    icon: Icons.phone_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'العنوان / المقر',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.darkNavy,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _addressController,
                                  decoration: _inputDecoration(
                                    hint: 'صنعاء، عدن، إلخ',
                                    icon: Icons.location_on_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 6. Notes (Optional)
                      const Text(
                        'ملاحظات إضافية',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: _inputDecoration(
                          hint: 'أي بيانات أو ملاحظات تنظيمية أخرى...',
                          icon: Icons.note_alt_outlined,
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

            // Submit and Cancel Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
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
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isEditing ? 'حفظ التعديلات' : 'إضافة المؤسسة',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                            ),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    );
  }
}

class _CurrencyOption extends StatelessWidget {
  final String label;
  final String code;
  final bool isSelected;
  final VoidCallback? onTap;

  const _CurrencyOption({
    required this.label,
    required this.code,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            code,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
