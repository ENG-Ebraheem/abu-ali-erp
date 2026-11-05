import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../models/account_model.dart';

/// Card/Row widget representing an account in the Chart of Accounts list or tree.
class AccountCard extends StatelessWidget {
  final AccountModel account;
  final int depth;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const AccountCard({
    super.key,
    required this.account,
    this.depth = 0,
    required this.onTap,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  Color get _typeColor {
    switch (account.accountType) {
      case 'ASSET':
        return AppColors.primary;
      case 'LIABILITY':
        return AppColors.warning;
      case 'EQUITY':
        return const Color(0xFF7C3AED);
      case 'REVENUE':
        return AppColors.success;
      case 'EXPENSE':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

  Color get _typeBgColor {
    switch (account.accountType) {
      case 'ASSET':
        return AppColors.primaryLight;
      case 'LIABILITY':
        return AppColors.warningLight;
      case 'EQUITY':
        return const Color(0xFFF5F3FF);
      case 'REVENUE':
        return AppColors.successLight;
      case 'EXPENSE':
        return AppColors.dangerLight;
      default:
        return AppColors.background;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBalance = account.baseBalance != 0;
    final isNegative = account.baseBalance < 0;

    return Padding(
      padding: EdgeInsets.only(
        right: depth * 14.0,
        bottom: 8.0,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: account.isActive
                  ? AppColors.border
                  : AppColors.border.withValues(alpha: 0.5),
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Code indicator container
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: _typeBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  account.accountCode,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _typeColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Account Name, Badges, and Type
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            account.accountNameAr,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: account.isHeaderAccount
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: account.isActive
                                  ? AppColors.darkNavy
                                  : AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (account.isCashBank) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.savings_outlined,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ],
                        if (!account.isActive) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'معطل',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          '${account.typeNameAr} • ${account.natureNameAr}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (account.currencyCode != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(${account.currencyCode})',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Balance Display
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${hasBalance ? (account.baseBalance / 100).toStringAsFixed(2) : "0.00"} ر.ي',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isNegative
                          ? AppColors.danger
                          : (hasBalance
                              ? AppColors.darkNavy
                              : AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'الرصيد',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),

              // Action button
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (val) {
                  if (val == 'edit') onEdit();
                  if (val == 'toggle') onToggleActive();
                  if (val == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('تعديل الحساب'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          account.isActive
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: AppColors.warning,
                        ),
                        SizedBox(width: 8),
                        Text(
                            account.isActive ? 'تعطيل الحساب' : 'تفعيل الحساب'),
                      ],
                    ),
                  ),
                  if (!account.isSystem)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 18, color: AppColors.danger),
                          SizedBox(width: 8),
                          Text('حذف الحساب',
                              style: TextStyle(color: AppColors.danger)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
