import 'package:flutter/material.dart';
import 'package:abu_ali/core/constants/app_colors.dart';
import 'package:abu_ali/core/theme/app_theme.dart';
import 'inventory_report_viewer_screen.dart';

/// Hub screen displaying all 12 Inventory Reports grouped into 3 operational sections.
class InventoryReportsHubScreen extends StatelessWidget {
  final String organizationId;

  const InventoryReportsHubScreen({
    super.key,
    required this.organizationId,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('تقارير المخزون والمستودعات'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Section 1: Balances & Valuation
            _buildSectionHeader(
              title: 'تقارير الأرصدة وتقييم المخزون',
              subtitle: 'أرصدة الأصناف، القيمة الإجمالية، وتوزيع المخازن',
              icon: Icons.account_balance_wallet_rounded,
            ),
            const SizedBox(height: 10),
            _buildReportCard(
              context,
              id: 'current_stock',
              title: 'تقرير المخزون الحالي (Current Stock)',
              desc: 'كشف بأرصدة جميع الأصناف والمواد عبر المستودعات مع متوسط التكلفة.',
              icon: Icons.inventory_2_rounded,
              color: AppColors.primary,
            ),
            _buildReportCard(
              context,
              id: 'valuation',
              title: 'تقرير تقييم المخزون (Inventory Valuation)',
              desc: 'تقييم شامل للمخزون بالمتوسط المرجح وسعر البيع لحساب هامش الربح المتوقع.',
              icon: Icons.monetization_on_rounded,
              color: AppColors.success,
            ),
            _buildReportCard(
              context,
              id: 'by_warehouse',
              title: 'تقرير المخزون حسب المستودع (By Warehouse)',
              desc: 'توزيع كميات وقيم البضائع والمواد المخزنة لكل مستودع ومخزن على حدة.',
              icon: Icons.warehouse_rounded,
              color: const Color(0xFF0284C7),
            ),
            _buildReportCard(
              context,
              id: 'by_category',
              title: 'تقرير المخزون حسب التصنيف (By Category)',
              desc: 'إجمالي البضائع والتقييم المالي مصنفاً حسب المجموعات السلعية.',
              icon: Icons.category_rounded,
              color: const Color(0xFF7C3AED),
            ),

            const SizedBox(height: 20),
            // Section 2: Movements & Tracking
            _buildSectionHeader(
              title: 'تقارير الحركة وتتبع المواد',
              subtitle: 'سجلات الإدخال، الإخراج، والمناقلات بين المخازن',
              icon: Icons.swap_horiz_rounded,
            ),
            const SizedBox(height: 10),
            _buildReportCard(
              context,
              id: 'movements',
              title: 'تقرير حركة المخزون الشامل (Stock Movements)',
              desc: 'سجل زمني لجميع الحركات المخزنية الواردة والصادرة مع السندات المرجعية.',
              icon: Icons.history_rounded,
              color: const Color(0xFFD97706),
            ),
            _buildReportCard(
              context,
              id: 'receipts',
              title: 'تقرير سندات الإدخال المخزني (Stock Receipts)',
              desc: 'كشف باستلامات البضائع والمشتريات وتكاليفها والموردين.',
              icon: Icons.call_received_rounded,
              color: AppColors.success,
            ),
            _buildReportCard(
              context,
              id: 'issues',
              title: 'تقرير سندات الإخراج والصرف (Stock Issues)',
              desc: 'كشف بالمواد المصروفة للاستهلاك والتالف وتكاليفها وحساباتها المقابلة.',
              icon: Icons.call_made_rounded,
              color: AppColors.danger,
            ),
            _buildReportCard(
              context,
              id: 'transfers',
              title: 'تقرير مناقلات المستودعات (Warehouse Transfers)',
              desc: 'حركات تحويل البضائع بين المستودعات المختلفة داخل المؤسسة.',
              icon: Icons.compare_arrows_rounded,
              color: AppColors.primary,
            ),

            const SizedBox(height: 20),
            // Section 3: Control & Stocktaking
            _buildSectionHeader(
              title: 'تقارير الرقابة والنواقص والجرد',
              subtitle: 'حدود الطلب، الأصناف المنتهية، وفروقات الجرد الفعلي',
              icon: Icons.fact_check_rounded,
            ),
            const SizedBox(height: 10),
            _buildReportCard(
              context,
              id: 'low_stock',
              title: 'تقرير النواقص وحد إعادة الطلب (Low Stock)',
              desc: 'الأصناف التي وصلت كمياتها للحد الأدنى وتتطلب الشراء الفوري.',
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFDC2626),
            ),
            _buildReportCard(
              context,
              id: 'out_of_stock',
              title: 'تقرير الأصناف المنتهية (Out of Stock)',
              desc: 'الأصناف التي نفد رصيدها تماماً في المستودعات (رصيد صفر أو سالب).',
              icon: Icons.remove_circle_outline_rounded,
              color: const Color(0xFF991B1B),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkNavy,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportCard(
    BuildContext context, {
    required String id,
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InventoryReportViewerScreen(
                organizationId: organizationId,
                reportId: id,
                reportTitle: title,
                reportDescription: desc,
              ),
            ),
          );
        },
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14.5,
            color: AppColors.darkNavy,
          ),
        ),
        subtitle: Text(
          desc,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_left_rounded,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
