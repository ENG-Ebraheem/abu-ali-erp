import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Quick action shortcuts for frequent accounting workflows.
class QuickActionsSection extends StatelessWidget {
  final Function(String title) onActionTap;

  const QuickActionsSection({
    super.key,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'إجراءات سريعة',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.darkNavy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: AppTheme.cardShadow,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Column(
            children: [
              // Row 1
              Row(
                children: [
                  Expanded(
                    child: _ActionItem(
                      title: 'قيد يومية',
                      icon: Icons.post_add_rounded,
                      iconColor: const Color(0xFF2563EB),
                      bgColor: const Color(0xFFEFF6FF),
                      onTap: () => onActionTap('قيد يومية جديد'),
                    ),
                  ),
                  Expanded(
                    child: _ActionItem(
                      title: 'فاتورة جديدة',
                      icon: Icons.point_of_sale_rounded,
                      iconColor: const Color(0xFF0284C7),
                      bgColor: const Color(0xFFF0F9FF),
                      onTap: () => onActionTap('فاتورة مبيعات'),
                    ),
                  ),
                  Expanded(
                    child: _ActionItem(
                      title: 'تسجيل دفعة',
                      icon: Icons.payments_rounded,
                      iconColor: const Color(0xFF059669),
                      bgColor: const Color(0xFFECFDF5),
                      onTap: () => onActionTap('تسجيل دفعة'),
                    ),
                  ),
                  Expanded(
                    child: _ActionItem(
                      title: 'إضافة حساب',
                      icon: Icons.account_tree_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      bgColor: const Color(0xFFF5F3FF),
                      onTap: () => onActionTap('إضافة حساب'),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Divider(height: 1, color: AppColors.border),
              ),
              // Row 2
              Row(
                children: [
                  Expanded(
                    child: _ActionItem(
                      title: 'فاتورة مشتريات',
                      icon: Icons.shopping_cart_checkout_rounded,
                      iconColor: const Color(0xFFEA580C),
                      bgColor: const Color(0xFFFFF7ED),
                      onTap: () => onActionTap('فاتورة مشتريات'),
                    ),
                  ),
                  Expanded(
                    child: _ActionItem(
                      title: 'سند صرف',
                      icon: Icons.call_made_rounded,
                      iconColor: const Color(0xFFDC2626),
                      bgColor: const Color(0xFFFEF2F2),
                      onTap: () => onActionTap('سند صرف'),
                    ),
                  ),
                  Expanded(
                    child: _ActionItem(
                      title: 'تحويل نقدي',
                      icon: Icons.swap_horiz_rounded,
                      iconColor: const Color(0xFF0891B2),
                      bgColor: const Color(0xFFECFEFF),
                      onTap: () => onActionTap('تحويل نقدي'),
                    ),
                  ),
                  Expanded(
                    child: _ActionItem(
                      title: 'أرصدة افتتاحية',
                      icon: Icons.account_balance_wallet_rounded,
                      iconColor: const Color(0xFFD97706),
                      bgColor: const Color(0xFFFFFBEB),
                      onTap: () => onActionTap('أرصدة افتتاحية'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final VoidCallback onTap;

  const _ActionItem({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: iconColor.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
