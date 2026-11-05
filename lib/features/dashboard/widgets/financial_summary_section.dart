import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

/// Financial metrics summary section showing Assets, Liabilities, Revenue, and Expenses
/// computed directly from the active organization's posted General Ledger in SQLite.
class FinancialSummarySection extends StatelessWidget {
  final int totalAssets;
  final int totalLiabilities;
  final int totalRevenue;
  final int totalExpense;
  final String currencySymbol;
  final bool isLoading;
  final VoidCallback? onCardTap;

  const FinancialSummarySection({
    super.key,
    this.totalAssets = 0,
    this.totalLiabilities = 0,
    this.totalRevenue = 0,
    this.totalExpense = 0,
    this.currencySymbol = 'ر.ي',
    this.isLoading = false,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    final assetsText = isLoading
        ? '...'
        : AppFormatters.formatMinorUnits(totalAssets);
    final liabilitiesText = isLoading
        ? '...'
        : AppFormatters.formatMinorUnits(totalLiabilities);
    final revenueText = isLoading
        ? '...'
        : AppFormatters.formatMinorUnits(totalRevenue);
    final expenseText = isLoading
        ? '...'
        : AppFormatters.formatMinorUnits(totalExpense);

    return Column(
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
                  'المؤشرات المالية',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNavy,
                  ),
                ),
              ],
            ),
            if (isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 1: Assets & Liabilities
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'إجمالي الأصول',
                amount: assetsText,
                currency: currencySymbol,
                icon: Icons.account_balance_rounded,
                accentColor: AppColors.primary,
                backgroundColor: AppColors.primaryLight,
                onTap: onCardTap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'إجمالي الالتزامات',
                amount: liabilitiesText,
                currency: currencySymbol,
                icon: Icons.assignment_late_rounded,
                accentColor: AppColors.warning,
                backgroundColor: AppColors.warningLight,
                onTap: onCardTap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 2: Revenue & Expenses
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'الإيرادات',
                amount: revenueText,
                currency: currencySymbol,
                icon: Icons.trending_up_rounded,
                accentColor: AppColors.success,
                backgroundColor: AppColors.successLight,
                onTap: onCardTap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'المصروفات',
                amount: expenseText,
                currency: currencySymbol,
                icon: Icons.trending_down_rounded,
                accentColor: AppColors.danger,
                backgroundColor: AppColors.dangerLight,
                onTap: onCardTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String amount;
  final String currency;
  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.title,
    required this.amount,
    required this.currency,
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppTheme.cardShadow,
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: accentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    amount,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkNavy,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    currency,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
