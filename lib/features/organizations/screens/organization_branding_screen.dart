import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../data/organization_branding_service.dart';
import '../models/organization_branding.dart';
import '../models/organization_model.dart';
import '../services/institution_logo_picker.dart';

/// Screen managing an organization's visual branding, logo storage, and document report customization.
class OrganizationBrandingScreen extends StatefulWidget {
  final Organization organization;

  const OrganizationBrandingScreen({
    super.key,
    required this.organization,
  });

  @override
  State<OrganizationBrandingScreen> createState() =>
      _OrganizationBrandingScreenState();
}

class _OrganizationBrandingScreenState
    extends State<OrganizationBrandingScreen> {
  final OrganizationBrandingService _service =
      OrganizationBrandingService.instance;

  late TextEditingController _businessActivityController;
  late TextEditingController _taxNumberController;
  late TextEditingController _footerController;
  late TextEditingController _additionalInfoController;
  late TextEditingController _customPathController;

  String? _logoPath;
  bool _showLogo = true;
  bool _showOrgInfo = true;
  bool _showFooter = true;
  String _headerLayout = 'MODERN';
  String _pageSize = 'A4';

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _businessActivityController =
        TextEditingController(text: widget.organization.businessType ?? '');
    _taxNumberController = TextEditingController();
    _footerController = TextEditingController();
    _additionalInfoController = TextEditingController();
    _customPathController = TextEditingController();

    _loadBranding();
  }

  Future<void> _loadBranding() async {
    setState(() => _isLoading = true);
    try {
      final b = await _service.getBranding(widget.organization.id);
      if (mounted) {
        setState(() {
          _logoPath = b.logoPath;
          if (b.businessActivity != null && b.businessActivity!.isNotEmpty) {
            _businessActivityController.text = b.businessActivity!;
          }
          if (b.taxNumber != null && b.taxNumber!.isNotEmpty) {
            _taxNumberController.text = b.taxNumber!;
          }
          if (b.documentFooter != null && b.documentFooter!.isNotEmpty) {
            _footerController.text = b.documentFooter!;
          }
          if (b.additionalInfo != null && b.additionalInfo!.isNotEmpty) {
            _additionalInfoController.text = b.additionalInfo!;
          }
          _showLogo = b.showLogo;
          _showOrgInfo = b.showOrgInfo;
          _showFooter = b.showFooter;
          _headerLayout = b.headerLayout;
          _pageSize = b.pageSize;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _businessActivityController.dispose();
    _taxNumberController.dispose();
    _footerController.dispose();
    _additionalInfoController.dispose();
    _customPathController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);

    try {
      final b = OrganizationBranding(
        organizationId: widget.organization.id,
        logoPath: _logoPath,
        businessActivity: _businessActivityController.text.trim(),
        taxNumber: _taxNumberController.text.trim(),
        documentFooter: _footerController.text.trim(),
        additionalInfo: _additionalInfoController.text.trim(),
        showLogo: _showLogo,
        showOrgInfo: _showOrgInfo,
        showFooter: _showFooter,
        headerLayout: _headerLayout,
        pageSize: _pageSize,
      );

      await _service.saveBranding(b);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ هوية المنشأة وإعدادات المستندات بنجاح.'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الحفظ: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handlePickLogo() async {
    final path = await InstitutionLogoPicker.showPickerModal(
      context: context,
      organizationId: widget.organization.id,
    );
    if (path != null && mounted) {
      setState(() {
        _logoPath = path;
        _showLogo = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم اختيار وتحديث شعار المنشأة بنجاح.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _handleApplyPresetBadge(String presetName) async {
    try {
      // Use master app logo as distinct preset
      final masterLogo = File('assets/images/app_logo.png');
      if (await masterLogo.exists()) {
        final bytes = await masterLogo.readAsBytes();
        final path = await _service.saveLogoBytes(
          organizationId: widget.organization.id,
          bytes: bytes,
        );
        setState(() => _logoPath = path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم تطبيق الشعار: $presetName'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء تعيين الشعار: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _handleRemoveLogo() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف شعار المنشأة'),
          content: const Text('هل أنت متأكد من حذف شعار هذه المنشأة؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await _service.removeLogo(widget.organization.id);
      setState(() => _logoPath = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'هوية ومستندات: ${widget.organization.name}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          actions: [
            TextButton.icon(
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded, color: Colors.white),
              label: const Text('حفظ',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _isSaving ? null : _handleSave,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Section 1: Logo Management Card
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.photo_library_rounded,
                                    color: AppColors.primary),
                                SizedBox(width: 8),
                                Text(
                                  'شعار المنشأة (Organization Logo)',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Logo Preview Row
                            Row(
                              children: [
                                Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: _logoPath != null &&
                                          File(_logoPath!).existsSync()
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          child: Image.file(
                                            File(_logoPath!),
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                              Icons.broken_image_rounded,
                                              color: AppColors.danger,
                                              size: 32,
                                            ),
                                          ),
                                        )
                                      : const Center(
                                          child: Icon(
                                            Icons.business_rounded,
                                            size: 40,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _logoPath != null &&
                                                File(_logoPath!).existsSync()
                                            ? 'تم تعيين شعار مخصص للمنشأة'
                                            : 'لم يتم تعيين شعار حتى الآن',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _logoPath ?? 'المسار: غير محدد',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Logo Actions
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(
                                      Icons.add_photo_alternate_rounded,
                                      size: 18),
                                  label: const Text('اختيار شعار (معرض / كاميرا)'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(
                                        color: AppColors.primary),
                                  ),
                                  onPressed: _handlePickLogo,
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.auto_awesome_rounded,
                                      size: 18),
                                  label: const Text('استخدام شعار رسمي جاهز'),
                                  onPressed: () => _handleApplyPresetBadge(
                                      'الشعار المالي الرسمي'),
                                ),
                                if (_logoPath != null)
                                  TextButton.icon(
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: AppColors.danger,
                                        size: 18),
                                    label: const Text('حذف الشعار',
                                        style:
                                            TextStyle(color: AppColors.danger)),
                                    onPressed: _handleRemoveLogo,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 2: Business & Tax Details
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.assignment_rounded,
                                    color: AppColors.primary),
                                SizedBox(width: 8),
                                Text(
                                  'بيانات النشاط والترخيص الضريبي',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Business Activity
                            TextField(
                              controller: _businessActivityController,
                              decoration: const InputDecoration(
                                labelText:
                                    'النشاط التجاري (مثل: تجارة عامة واستيراد)',
                                prefixIcon: Icon(Icons.storefront_rounded),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Tax Registration Number
                            TextField(
                              controller: _taxNumberController,
                              decoration: const InputDecoration(
                                labelText: 'الرقم الضريبي / السجل التجاري',
                                prefixIcon:
                                    Icon(Icons.confirmation_number_rounded),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Document Footer
                            TextField(
                              controller: _footerController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText:
                                    'تذييل المستند والتقارير المالية (Footer)',
                                hintText:
                                    'مثال: شكراً لتعاملكم معنا • وثيقة معتمدة ومطابقة للأصول المحاسبية',
                                prefixIcon: Icon(Icons.subtitles_rounded),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Additional Info
                            TextField(
                              controller: _additionalInfoController,
                              decoration: const InputDecoration(
                                labelText:
                                    'معلومات اتصال إضافية أو حساب بنكي للمستندات',
                                prefixIcon: Icon(Icons.info_outline_rounded),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 3: Document Display Controls
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.tune_rounded,
                                    color: AppColors.primary),
                                SizedBox(width: 8),
                                Text(
                                  'تخصيص نماذج التقارير والفواتير',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SwitchListTile(
                              title: const Text(
                                  'إظهار الشعار في التقارير والمستندات'),
                              subtitle: const Text(
                                  'تضمين شعار المنشأة في الترويسة العلوية'),
                              value: _showLogo,
                              onChanged: (val) =>
                                  setState(() => _showLogo = val),
                            ),
                            const Divider(),
                            SwitchListTile(
                              title:
                                  const Text('إظهار معلومات الاتصال والعنوان'),
                              subtitle: const Text(
                                  'عرض الهاتف والعنوان والرقم الضريبي في الترويسة'),
                              value: _showOrgInfo,
                              onChanged: (val) =>
                                  setState(() => _showOrgInfo = val),
                            ),
                            const Divider(),
                            SwitchListTile(
                              title:
                                  const Text('إظهار التذييل السفلي (Footer)'),
                              subtitle: const Text(
                                  'عرض تذييل المستند في أسفل كل صفحة مطبوعة'),
                              value: _showFooter,
                              onChanged: (val) =>
                                  setState(() => _showFooter = val),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.save_rounded, color: Colors.white),
                      label: const Text(
                        'حفظ هوية المنشأة والمستندات',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      onPressed: _isSaving ? null : _handleSave,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
