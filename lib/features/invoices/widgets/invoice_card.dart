import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../models/invoice_model.dart';

/// Card displaying an invoice overview with payment status pill.
class InvoiceCard extends StatelessWidget {
  final InvoiceModel invoice;
  final VoidCallback onTap;

  const InvoiceCard({
    super.key,
    required this.invoice,
    required this.onTap,
  });

  String _formatMoney(int amountMinor) {
    final double val = amountMinor / 100.0;
    return val.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    Color payBgColor;
    Color payTextColor;

    if (invoice.isPaid) {
      payBgColor = const Color(0xFFECFDF5);
      payTextColor = const Color(0xFF059669);
    } else if (invoice.isPartiallyPaid) {
      payBgColor = const Color(0xFFEFF6FF);
      payTextColor = const Color(0xFF2563EB);
    } else {
      payBgColor = const Color(0xFFFFFBEB);
      payTextColor = const Color(0xFFD97706);
    }

    final bool isSales = invoice.isSales;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Type avatar, Number & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSales
                                ? const Color(0xFFEFF6FF)
                                : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isSales
                                ? Icons.shopping_bag_outlined
                                : Icons.shopping_cart_outlined,
                            color: isSales
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFD97706),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              invoice.invoiceNumber,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkNavy,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${invoice.typeLabel} • ${invoice.issueDate}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: payBgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: payTextColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        invoice.paymentStatusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: payTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Party Name
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      invoice.partyNameAr ?? 'الطرف المحاسبي',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkNavy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 10),

                // Amount row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Status
                    Text(
                      'الحالة: ${invoice.statusLabel}',
                      style: TextStyle(
                        fontSize: 12,
                        color: invoice.isPosted
                            ? AppColors.success
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Total Amount
                    Row(
                      children: [
                        const Text(
                          'المبلغ: ',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          _formatMoney(invoice.totalAmount),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkNavy,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          invoice.currencyCode,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (invoice.paidAmount > 0 && !invoice.isPaid) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'المسدد: ${_formatMoney(invoice.paidAmount)} • المتبقي: ${_formatMoney(invoice.remainingAmount)} ${invoice.currencyCode}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
