import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/settings_repository.dart';

/// Screen for managing Accountant / User Profile in Abu-Ali accounting system.
class AccountantProfileScreen extends StatefulWidget {
  final String? organizationId;

  const AccountantProfileScreen({super.key, this.organizationId});

  @override
  State<AccountantProfileScreen> createState() =>
      _AccountantProfileScreenState();
}

class _AccountantProfileScreenState extends State<AccountantProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _settingsRepo = SettingsRepository();

  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _licenseController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _licenseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final orgId = widget.organizationId;

    try {
      _nameController.text = await _settingsRepo
              .getAppSetting('accountant_name', organizationId: orgId) ??
          'أبو علي';
      _titleController.text = await _settingsRepo
              .getAppSetting('accountant_title', organizationId: orgId) ??
          'المحاسب المعتمد';
      _phoneController.text = await _settingsRepo
              .getAppSetting('accountant_phone', organizationId: orgId) ??
          '';
      _emailController.text = await _settingsRepo
              .getAppSetting('accountant_email', organizationId: orgId) ??
          '';
      _licenseController.text = await _settingsRepo
              .getAppSetting('accountant_license', organizationId: orgId) ??
          '';
      _notesController.text = await _settingsRepo
              .getAppSetting('accountant_notes', organizationId: orgId) ??
          'أقر بصحة واكتمال جميع القيود والبيانات المحاسبية المسجلة وفق المعايير المالية.';
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final orgId = widget.organizationId;

    try {
      await _settingsRepo.saveAppSetting(
          'accountant_name', _nameController.text.trim(),
          organizationId: orgId);
      await _settingsRepo.saveAppSetting(
          'accountant_title', _titleController.text.trim(),
          organizationId: orgId);
      await _settingsRepo.saveAppSetting(
          'accountant_phone', _phoneController.text.trim(),
          organizationId: orgId);
      await _settingsRepo.saveAppSetting(
          'accountant_email', _emailController.text.trim(),
          organizationId: orgId);
      await _settingsRepo.saveAppSetting(
          'accountant_license', _licenseController.text.trim(),
          organizationId: orgId);
      await _settingsRepo.saveAppSetting(
          'accountant_notes', _notesController.text.trim(),
          organizationId: orgId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ بيانات الملف المهني بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء الحفظ: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
            'الملف المهني للمحاسب',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkNavy,
            ),
          ),
          actions: [
            if (!_isLoading)
              IconButton(
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      )
                    : const Icon(Icons.check_rounded, color: AppColors.primary),
                onPressed: _isSaving ? null : _saveProfile,
              ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Header Avatar Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: AppColors.primaryLight,
                              child: const Icon(
                                Icons.person_rounded,
                                size: 40,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _nameController.text.isNotEmpty
                                        ? _nameController.text
                                        : 'المحاسب المسؤول',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.darkNavy,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _titleController.text.isNotEmpty
                                        ? _titleController.text
                                        : 'محاسب عام معتمد',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'حساب معتمد محلياً',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Form Fields Card
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
                              'البيانات المهنية والتواصل',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkNavy,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Name
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'اسم المحاسب الكامل *',
                                prefixIcon: Icon(Icons.badge_rounded),
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'يرجى إدخال اسم المحاسب';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Title
                            TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'المسمى المهني / الوظيفي *',
                                prefixIcon: Icon(Icons.work_outline_rounded),
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'يرجى إدخال المسمى المهني';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Phone
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'رقم الهاتف / الواتساب',
                                prefixIcon: Icon(Icons.phone_rounded),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Email
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'البريد الإلكتروني',
                                prefixIcon: Icon(Icons.email_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // License / ID
                            TextFormField(
                              controller: _licenseController,
                              decoration: const InputDecoration(
                                labelText: 'رقم الترخيص المهني أو الهوية',
                                prefixIcon: Icon(Icons.card_membership_rounded),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Notes / Declaration
                            TextFormField(
                              controller: _notesController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText:
                                    'إقرار المحاسب القانوني أو ملاحظات التقارير',
                                alignLabelWithHint: true,
                                prefixIcon: Padding(
                                  padding: EdgeInsets.only(bottom: 45),
                                  child: Icon(Icons.edit_note_rounded),
                                ),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveProfile,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save_rounded,
                                  color: Colors.white),
                          label: Text(
                            _isSaving ? 'جارِ الحفظ...' : 'حفظ بيانات المحاسب',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
