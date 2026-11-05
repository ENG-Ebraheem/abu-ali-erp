import 'package:flutter/material.dart';
import 'package:abu_ali/core/constants/app_colors.dart';
import 'package:abu_ali/core/constants/database_constants.dart';
import 'package:abu_ali/core/theme/app_theme.dart';
import 'package:abu_ali/features/organizations/data/organization_repository.dart';
import 'package:abu_ali/features/organizations/models/organization_model.dart';
import '../data/inventory_reports_repository.dart';
import '../data/inventory_repository.dart';
import 'categories_screen.dart';
import 'create_stock_document_screen.dart';
import 'inventory_reports_hub_screen.dart';
import 'inventory_settings_screen.dart';
import 'items_screen.dart';
import 'stock_documents_screen.dart';
import 'stocktaking_list_screen.dart';
import 'units_screen.dart';
import 'warehouses_screen.dart';

/// Central Inventory & Warehouse Management Hub.
class InventoryHubScreen extends StatefulWidget {
  final String? organizationId;
  final VoidCallback? onBackToDashboard;

  const InventoryHubScreen({
    super.key,
    this.organizationId,
    this.onBackToDashboard,
  });

  @override
  State<InventoryHubScreen> createState() => _InventoryHubScreenState();
}

class _InventoryHubScreenState extends State<InventoryHubScreen> {
  final OrganizationRepository _orgRepo = OrganizationRepository();
  final InventoryRepository _invRepo = InventoryRepository();
  final InventoryReportsRepository _reportsRepo = InventoryReportsRepository();

  Organization? _activeOrg;
  bool _isLoading = true;

  int _totalItemsCount = 0;
  int _lowStockCount = 0;
  int _warehousesCount = 0;
  int _totalValuation = 0;

  @override
  void initState() {
    super.initState();
    _loadHubData();
  }

  Future<void> _loadHubData() async {
    setState(() => _isLoading = true);
    try {
      String? orgId = widget.organizationId;
      if (orgId == null) {
        orgId = await _orgRepo.getActiveOrganizationId();
        if (orgId == null) {
          final list = await _orgRepo.getAllOrganizations(includeArchived: false);
          if (list.isNotEmpty) orgId = list.first.id;
        }
      }

      if (orgId != null) {
        final org = await _orgRepo.getOrganizationById(orgId);
        final items = await _invRepo.getItems(organizationId: orgId);
        final whs = await _invRepo.getWarehouses(orgId);
        final valuationRows =
            await _reportsRepo.getInventoryValuationReport(organizationId: orgId);

        int totalVal = 0;
        for (final r in valuationRows) {
          totalVal += (r['cost_valuation'] as num?)?.toInt() ?? 0;
        }

        final lowCount = items.where((i) => i.isLowStock || i.isOutOfStock).length;

        if (mounted) {
          setState(() {
            _activeOrg = org;
            _totalItemsCount = items.length;
            _lowStockCount = lowCount;
            _warehousesCount = whs.length;
            _totalValuation = totalVal;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل بيانات المخزون: $e')),
        );
      }
    }
  }

  void _navigateTo(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    _loadHubData();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('إدارة المخزون والمستودعات'),
          leading: widget.onBackToDashboard != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: widget.onBackToDashboard,
                )
              : null,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'إعدادات المخزون',
              onPressed: _activeOrg != null
                  ? () => _navigateTo(
                        InventorySettingsScreen(
                          organizationId: _activeOrg!.id,
                        ),
                      )
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadHubData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _activeOrg == null
                ? const Center(child: Text('يرجى تحديد مؤسسة نشطة أولاً'))
                : RefreshIndicator(
                    onRefresh: _loadHubData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. KPI Cards Grid
                          _buildKpiSection(),
                          const SizedBox(height: 20),

                          // 2. Quick Operations
                          _buildQuickOperations(),
                          const SizedBox(height: 24),

                          // 3. Main Sections List
                          const Text(
                            'الأقسام والوحدات المخزنية',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkNavy,
                            ),
                          ),
                          const SizedBox(height: 12),

                          _buildModuleCard(
                            title: 'دليل الأصناف والمواد',
                            subtitle:
                                'إدارة قائمة البضائع، المواد الخام، الأسعار، وكروت الأصناف',
                            icon: Icons.inventory_2_rounded,
                            color: AppColors.primary,
                            badge: '$_totalItemsCount صنف',
                            onTap: () => _navigateTo(
                              ItemsScreen(organizationId: _activeOrg!.id),
                            ),
                          ),
                          _buildModuleCard(
                            title: 'العمليات والسندات المخزنية',
                            subtitle:
                                'سندات الإدخال، الإخراج، المناقلات، والتسويات الجردية',
                            icon: Icons.receipt_long_rounded,
                            color: const Color(0xFF0284C7),
                            onTap: () => _navigateTo(
                              StockDocumentsScreen(organizationId: _activeOrg!.id),
                            ),
                          ),
                          _buildModuleCard(
                            title: 'إدارة المستودعات والمخازن',
                            subtitle:
                                'المستودع الرئيسي، الفروع، والمواقع التخزينية',
                            icon: Icons.warehouse_rounded,
                            color: const Color(0xFF059669),
                            badge: '$_warehousesCount مستودع',
                            onTap: () => _navigateTo(
                              WarehousesScreen(organizationId: _activeOrg!.id),
                            ),
                          ),
                          _buildModuleCard(
                            title: 'الجرد الدوري والمطابقة الفعلية',
                            subtitle:
                                'تسجيل العد الفعلي، احتساب الفروقات، وتوليد القيود',
                            icon: Icons.fact_check_rounded,
                            color: const Color(0xFFD97706),
                            onTap: () => _navigateTo(
                              StocktakingListScreen(
                                  organizationId: _activeOrg!.id),
                            ),
                          ),
                          _buildModuleCard(
                            title: 'تصنيفات الأصناف والمواد',
                            subtitle: 'هيكل المجموعات الشجرية والتصنيفات الفرعية',
                            icon: Icons.category_rounded,
                            color: const Color(0xFF7C3AED),
                            onTap: () => _navigateTo(
                              CategoriesScreen(organizationId: _activeOrg!.id),
                            ),
                          ),
                          _buildModuleCard(
                            title: 'وحدات القياس والتحويل',
                            subtitle:
                                'حبة، كرتون، كجم، لتر ومعاملات التحويل بين الوحدات',
                            icon: Icons.straighten_rounded,
                            color: const Color(0xFF64748B),
                            onTap: () => _navigateTo(
                              UnitsScreen(organizationId: _activeOrg!.id),
                            ),
                          ),
                          _buildModuleCard(
                            title: 'مركز تقارير المخزون (12 تقريراً)',
                            subtitle:
                                'المخزون الحالي، التقييم، حركة المواد، والنواقص مع PDF',
                            icon: Icons.analytics_rounded,
                            color: AppColors.primary,
                            badge: '12 تقريراً',
                            onTap: () => _navigateTo(
                              InventoryReportsHubScreen(
                                  organizationId: _activeOrg!.id),
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

  Widget _buildKpiSection() {
    final currency = _activeOrg?.baseCurrencyCode ?? 'YER';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'إجمالي الأصناف',
                value: '$_totalItemsCount',
                icon: Icons.inventory_2_outlined,
                color: AppColors.primary,
                bgColor: const Color(0xFFEFF6FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: 'نواقص / حد الطلب',
                value: '$_lowStockCount',
                icon: Icons.warning_amber_rounded,
                color: _lowStockCount > 0 ? AppColors.danger : AppColors.success,
                bgColor: _lowStockCount > 0
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFECFDF5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'المستودعات النشطة',
                value: '$_warehousesCount',
                icon: Icons.warehouse_outlined,
                color: const Color(0xFF0284C7),
                bgColor: const Color(0xFFF0F9FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: 'تقييم المخزون ($currency)',
                value: (_totalValuation / 100.0).toStringAsFixed(0),
                icon: Icons.account_balance_wallet_outlined,
                color: AppColors.success,
                bgColor: const Color(0xFFECFDF5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickOperations() {
    return Container(
      padding: const EdgeInsets.all(14),
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
            'عمليات مخزنية سريعة',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.darkNavy,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickOpButton(
                label: 'إدخال مخزني',
                icon: Icons.call_received_rounded,
                color: AppColors.success,
                onTap: () => _navigateTo(
                  CreateStockDocumentScreen(
                    organizationId: _activeOrg!.id,
                    initialDocType: StockDocumentType.receipt,
                  ),
                ),
              ),
              _buildQuickOpButton(
                label: 'إخراج مخزني',
                icon: Icons.call_made_rounded,
                color: AppColors.danger,
                onTap: () => _navigateTo(
                  CreateStockDocumentScreen(
                    organizationId: _activeOrg!.id,
                    initialDocType: StockDocumentType.issue,
                  ),
                ),
              ),
              _buildQuickOpButton(
                label: 'مناقلة',
                icon: Icons.compare_arrows_rounded,
                color: AppColors.primary,
                onTap: () => _navigateTo(
                  CreateStockDocumentScreen(
                    organizationId: _activeOrg!.id,
                    initialDocType: StockDocumentType.transfer,
                  ),
                ),
              ),
              _buildQuickOpButton(
                label: 'تسوية جردية',
                icon: Icons.tune_rounded,
                color: const Color(0xFFD97706),
                onTap: () => _navigateTo(
                  CreateStockDocumentScreen(
                    organizationId: _activeOrg!.id,
                    initialDocType: StockDocumentType.adjustment,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickOpButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    String? badge,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.darkNavy,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: const Icon(
          Icons.chevron_left_rounded,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
