import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Representation of a display transaction on the dashboard.
class TransactionItemData {
  final String id;
  final String title;
  final String subtitle;
  final String amount;
  final String currency;
  final bool isIncome; // true for credit/income (+), false for debit/expense (-)
  final String badgeText;
  final IconData icon;
  final String? entryType;

  const TransactionItemData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.currency = 'ر.ي',
    required this.isIncome,
    required this.badgeText,
    required this.icon,
    this.entryType,
  });
}

/// Displays the list of recent accounting transactions dynamically loaded from SQLite.
class RecentTransactionsSection extends StatelessWidget {
  final List<TransactionItemData> transactions;
  final bool isLoading;
  final VoidCallback onViewAllTap;
  final Function(TransactionItemData tx) onTransactionTap;

  const RecentTransactionsSection({
    super.key,
    this.transactions = const [],
    this.isLoading = false,
    required this.onViewAllTap,
    required this.onTransactionTap,
  });

  @override
  Widget build(BuildContext context) {
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
                  'آخر العمليات',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNavy,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: onViewAllTap,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'عرض الكل',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_back_ios_new_rounded, size: 12),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (isLoading)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (transactions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 36,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 8),
                const Text(
                  'لا توجد حركات مسجلة حديثاً في هذه المؤسسة',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: AppTheme.cardShadow,
            ),
            child: ListView.separated(
              itemCount: transactions.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final tx = transactions[index];
                return InkWell(
                  onTap: () => onTransactionTap(tx),
                  borderRadius: index == 0
                      ? const BorderRadius.vertical(top: Radius.circular(16))
                      : index == transactions.length - 1
                          ? const BorderRadius.vertical(
                              bottom: Radius.circular(16),
                            )
                          : BorderRadius.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        // Transaction icon
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: tx.isIncome
                                ? AppColors.successLight
                                : AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            tx.icon,
                            color: tx.isIncome
                                ? AppColors.success
                                : AppColors.danger,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Description and Subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx.title,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                tx.subtitle,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Amount and Badge
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${tx.amount} ${tx.currency}',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: tx.isIncome
                                    ? AppColors.success
                                    : AppColors.danger,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: tx.isIncome
                                    ? AppColors.successLight
                                    : AppColors.dangerLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tx.badgeText,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: tx.isIncome
                                      ? AppColors.success
                                      : AppColors.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
