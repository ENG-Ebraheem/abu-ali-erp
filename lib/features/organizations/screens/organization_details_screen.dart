import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../accounts/screens/accounts_screen.dart';
import '../../exchange_rates/screens/exchange_rates_screen.dart';
import '../../invoices/screens/invoices_screen.dart';
import '../../journal/screens/journal_entries_screen.dart';
import '../../opening_balances/screens/opening_balances_screen.dart';
import '../../parties/screens/parties_screen.dart';
import '../../payments/screens/payments_screen.dart';
import '../../inventory/screens/inventory_hub_screen.dart';
import '../data/organization_branding_service.dart';
import '../data/organization_repository.dart';
import '../models/organization_model.dart';
import '../widgets/organization_form_dialog.dart';
import 'organization_branding_screen.dart';

/// Comprehensive financial and operational details for an organization.
class OrganizationDetailsScreen extends StatefulWidget {
  final Organization organization;
  final VoidCallback? onOrganizationUpdated;

  const OrganizationDetailsScreen({
    super.key,
    required this.organization,
    this.onOrganizationUpdated,
  });

  @override
  State<OrganizationDetailsScreen> createState() =>
      _OrganizationDetailsScreenState();
}

class _OrganizationDetailsScreenState extends State<OrganizationDetailsScreen> {
  final OrganizationRepository _repository = OrganizationRepository();
  late Organization _org;
  bool _isLoading = true;
  bool _hasTransactions = false;
  String? _logoPath;

  @override
  void initState() {
    super.initState();
    _org = widget.organization;
    _checkTransactions();
  }

  Future<void> _checkTransactions() async {
    setState(() => _isLoading = true);
    try {
      final hasTx = await _repository.hasTransactions(_org.id);
      final refreshed = await _repository.getOrganizationById(_org.id);
      String? foundLogo;
      try {
        final b = await OrganizationBrandingService.instance.getBranding(_org.id);
        if (b.logoPath != null && File(b.logoPath!).existsSync()) {
          foundLogo = b.logoPath;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _hasTransactions = hasTx;
          _logoPath = foundLogo;
          if (refreshed != null) _org = refreshed;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openEdit() {
    OrganizationFormSheet.show(
      context: context,
      organization: _org,
      onSave: (updatedOrg) async {
        await _repository.updateOrganization(updatedOrg);
        await _checkTransactions();
        widget.onOrganizationUpdated?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم تحديث بيانات "${updatedOrg.name}"'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
    );
  }

  Future<void> _toggleArchive() async {
    final newStatus = !_org.isActive;
    await _repository.setOrganizationActiveStatus(_org.id, newStatus);
    await _checkTransactions();
    widget.onOrganizationUpdated?.call();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus
                ? 'تم تنشيط المؤسسة بنجاح'
                : 'تمت أرشفة المؤسسة لحفظ السجلات',
          ),
          backgroundColor: newStatus ? AppColors.success : AppColors.warning,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_org.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      OrganizationBrandingScreen(organization: _org),
                ),
              ).then((_) => _checkTransactions());
            },
            tooltip: 'الهوية البصرية والمستندات',
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _openEdit,
            tooltip: 'تعديل البيانات',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: _checkTransactions,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Organization Header Card
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  gradient: _logoPath == null
                                      ? const LinearGradient(
                                          colors: [
                                            AppColors.primary,
                                            AppColors.secondary
                                          ],
                                        )
                                      : null,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _logoPath != null
                                        ? AppColors.border
                                        : Colors.transparent,
                                  ),
                                ),
                                child: _logoPath != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(15),
                                        child: Image.file(
                                          File(_logoPath!),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                            Icons.domain_rounded,
                                            color: AppColors.primary,
                                            size: 30,
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.domain_rounded,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _org.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.darkNavy,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'كود المؤسسة: ${_org.code}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _org.isActive
                                      ? AppColors.successLight
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _org.isActive ? 'نشطة' : 'مؤرشفة',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _org.isActive
                                        ? AppColors.success
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _infoColumn(
                                'العملة الأساسية',
                                _org.currencyLabel,
                                Icons.payments_outlined,
                              ),
                              _infoColumn(
                                'النشاط',
                                _org.businessType ?? 'عام',
                                Icons.storefront_outlined,
                              ),
                              _infoColumn(
                                'الحركات المالية',
                                _hasTransactions ? 'يوجد قيود' : 'لا يوجد',
                                Icons.receipt_long_outlined,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Contact & Location Card
                    const Text(
                      'بيانات التواصل والمقر',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkNavy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _contactRow(
                            Icons.phone_outlined,
                            'الهاتف',
                            _org.phone?.isNotEmpty == true
                                ? _org.phone!
                                : 'غير محدد',
                          ),
                          const Divider(height: 20),
                          _contactRow(
                            Icons.location_on_outlined,
                            'المقر / العنوان',
                            _org.address?.isNotEmpty == true
                                ? _org.address!
                                : 'غير محدد',
                          ),
                          const Divider(height: 20),
                          _contactRow(
                            Icons.notes_rounded,
                            'ملاحظات',
                            _org.notes?.isNotEmpty == true
                                ? _org.notes!
                                : 'لا توجد ملاحظات مسجلة',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Financial Setup Shortcuts
                    const Text(
                      'الدليل والبيانات المالية',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkNavy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDF4FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.branding_watermark_rounded,
                                color: Color(0xFFC026D3),
                                size: 20,
                              ),
                            ),
                            title: const Text(
                              'الهوية البصرية وشعار المستندات والتقارير',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text(
                              'شعار المنشأة، الرقم الضريبي، تذييل المستند وتخصيص النماذج',
                              style: TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OrganizationBrandingScreen(
                                    organization: _org,
                                  ),
                                ),
                              ).then((_) => _checkTransactions());
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.account_tree_outlined,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            title: const Text(
                              'دليل الحسابات (شجرة الحسابات)',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text(
                              'الأصول، الخصوم، حقوق الملكية، الإيرادات والمصروفات',
                              style: TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AccountsScreen(
                                    organizationId: _org.id,
                                  ),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.people_outline_rounded,
                                color: Color(0xFF2563EB),
                                size: 20,
                              ),
                            ),
                            title: const Text(
                              'العملاء والموردون',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text(
                              'إدارة أطراف التعامل، الأرصدة، وسقوف الائتمان',
                              style: TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PartiesScreen(
                                    organizationId: _org.id,
                                  ),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.currency_exchange_rounded,
                                color: Color(0xFFD97706),
                                size: 20,
                              ),
                            ),
                            title: const Text(
                              'أسعار صرف العملات الأجنبية',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text(
                              'تسجيل وتحديث أسعار صرف USD و SAR وحاسبة التحويل',
                              style: TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ExchangeRatesScreen(
                                    organizationId: _org.id,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Accounting Operations Shortcuts
                    const Text(
                      'العمليات المحاسبية والدفاتر',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkNavy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_outlined,
                                color: Color(0xFF16A34A),
                                size: 20,
                              ),
                            ),
                            title: const Text(
                              'الأرصدة الافتتاحية',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text(
                              'إدخال وموازنة وترحيل الأرصدة الافتتاحية للسنة المالية',
                              style: TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OpeningBalancesScreen(
                                    organizationId: _org.id,
                                  ),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            title: const Text(
                              'دفتر اليومية العامة',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text(
                              'تسجيل وترحيل قيود اليومية وفق القيد المزدوج',
                              style: TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => JournalEntriesScreen(
                                    organizationId: _org.id,
                                  ),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.shopping_bag_outlined,
                                color: Color(0xFF2563EB),
                                size: 20,
                              ),
                            ),
                            title: const Text(
                              'الفواتير (مبيعات ومشتريات)',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text(
                              'إصدار الفواتير وترحيلها التلقائي ومتابعة السداد',
                              style: TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => InvoicesScreen(
                                    organizationId: _org.id,
                                  ),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.payments_rounded,
                                color: Color(0xFF059669),
                                size: 20,
                              ),
                            ),
                            title: const Text(
                              'سندات القبض والصرف',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text(
                              'تسجيل المقبوضات والمدفوعات وتخصيص الفواتير',
                              style: TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PaymentsScreen(
                                    organizationId: _org.id,
                                  ),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.inventory_2_rounded,
                                  color: AppColors.primary, size: 20),
                            ),
                            title: const Text(
                              'المخزون والمستودعات',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text(
                              'إدارة الأصناف، المستودعات، السندات، والجرد والتقارير',
                              style: TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => InventoryHubScreen(
                                    organizationId: _org.id,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Operations & Security Controls Card
                    const Text(
                      'الإجراءات الإدارية والمحاسبية',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkNavy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _org.isActive
                                    ? AppColors.warningLight
                                    : AppColors.successLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _org.isActive
                                    ? Icons.archive_outlined
                                    : Icons.unarchive_outlined,
                                color: _org.isActive
                                    ? AppColors.warning
                                    : AppColors.success,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              _org.isActive
                                  ? 'أرشفة المؤسسة'
                                  : 'تنشيط واستعادة المؤسسة',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              _org.isActive
                                  ? 'تجميد العمليات المالية الجديدة مع حفظ الدفاتر السابقة'
                                  : 'إتاحة المؤسسة لإدخال المعاملات والقيود اليومية',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14),
                            onTap: _toggleArchive,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _infoColumn(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: AppColors.darkNavy,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _contactRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.darkNavy,
            ),
            textDirection: TextDirection.rtl,
          ),
        ),
      ],
    );
  }
}
