import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../invoices/screens/invoice_details_screen.dart';
import '../../journal/screens/journal_entry_details_screen.dart';
import '../../organizations/data/organization_branding_service.dart';
import '../../organizations/data/organization_repository.dart';
import '../../reports/screens/report_document_preview_screen.dart';
import '../data/payment_repository.dart';
import '../models/payment_model.dart';
import 'create_payment_screen.dart';

/// Screen displaying complete payment voucher, allocations, GL linkage, document preview, and voiding actions.
class PaymentDetailsScreen extends StatefulWidget {
  final String paymentId;
  final String organizationId;
  final String baseCurrencyCode;

  const PaymentDetailsScreen({
    super.key,
    required this.paymentId,
    required this.organizationId,
    required this.baseCurrencyCode,
  });

  @override
  State<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  final PaymentRepository _paymentRepo = PaymentRepository();
  PaymentModel? _payment;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPayment();
  }

  Future<void> _loadPayment() async {
    setState(() => _isLoading = true);
    try {
      final pay = await _paymentRepo.getPaymentById(
        widget.paymentId,
        widget.organizationId,
      );
      if (mounted) {
        setState(() {
          _payment = pay;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatMoney(int amountMinor) {
    final double val = amountMinor / 100.0;
    return val.toStringAsFixed(2);
  }

  Future<void> _postPayment() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _paymentRepo.postPayment(widget.paymentId, widget.organizationId);
      await _loadPayment();
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('تم ترحيل سند الدفع وتوليد القيد المحاسبي بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _voidPayment() async {
    final reasonController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد إلغاء سند الدفع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سيتم عكس القيد المحاسبي المرتبط بالسند واستعادة مبالغ الفواتير المخصصة كفواتير غير مسددة.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'سبب الإلغاء *',
                hintText: 'مثال: شيك مرتجع / خطأ في المبلغ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(dialogContext);

              try {
                await _paymentRepo.voidPayment(
                  widget.paymentId,
                  widget.organizationId,
                  reason,
                );
                await _loadPayment();
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content:
                          Text('تم إلغاء السند وإعادة مبالغ الفواتير المخصصة'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDraft() async {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد حذف المسودة'),
        content: const Text('هل أنت متأكد من حذف مسودة هذا السند؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await _paymentRepo.deleteDraftPayment(
                  widget.paymentId,
                  widget.organizationId,
                );
                if (mounted) {
                  Navigator.pop(context, true);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف المسودة بنجاح'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPrintPreviewDialog() async {
    if (_payment == null) return;
    final pay = _payment!;

    try {
      final orgRepo = OrganizationRepository();
      final org = await orgRepo.getOrganizationById(widget.organizationId);
      final branding = await OrganizationBrandingService.instance
          .getBranding(widget.organizationId);

      final baseAmount =
          (pay.amount * pay.exchangeRateScaled ~/ 1000000);

      final headers = [
        'رقم السند',
        'الطرف المستفيد/المسدد',
        'طريقة الدفع',
        'حساب الصندوق/البنك',
        'المبلغ بالعملة',
        'المبلغ الأساسي'
      ];
      final rows = [
        [
          pay.paymentNumber,
          pay.partyNameAr ?? 'طرف عام نقدي',
          pay.methodLabel,
          pay.cashBankAccountNameAr ?? 'الصندوق الرئيسي',
          '${_formatMoney(pay.amount)} ${pay.currencyCode}',
          '${_formatMoney(baseAmount)} ${widget.baseCurrencyCode}',
        ]
      ];

      final totals = [
        'الإجمالي الصافي:',
        '',
        '',
        '',
        '${_formatMoney(pay.amount)} ${pay.currencyCode}',
        '${_formatMoney(baseAmount)} ${widget.baseCurrencyCode}',
      ];

      final subtitle =
          'النوع: ${pay.typeLabel} | الحالة: ${pay.statusLabel} | الرقم المرجعي: ${pay.referenceNumber ?? "لا يوجد"}';

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportDocumentPreviewScreen(
              title: pay.typeLabel,
              organizationName: org?.name ?? 'المؤسسة',
              baseCurrency: pay.currencyCode,
              periodOrDate: pay.paymentDate,
              documentNumber: pay.paymentNumber,
              headers: headers,
              rows: rows,
              totals: totals,
              subtitle: subtitle,
              branding: branding,
              notes: pay.notes,
              isInvoiceOrVoucher: true,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء تجهيز السند: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_payment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل السند')),
        body: const Center(child: Text('لم يتم العثور على سند الدفع')),
      );
    }

    final pay = _payment!;
    final bool isReceipt = pay.isReceipt;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            pay.paymentNumber,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.print_outlined),
              tooltip: 'معاينة وطباعة',
              onPressed: _showPrintPreviewDialog,
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadPayment,
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Amount Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isReceipt
                      ? [const Color(0xFF065F46), const Color(0xFF047857)]
                      : [const Color(0xFF991B1B), const Color(0xFFB91C1C)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isReceipt ? 'المبلغ المقبوض' : 'المبلغ المصروف',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.white70),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          pay.statusLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _formatMoney(pay.amount),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        pay.currencyCode,
                        style: const TextStyle(
                            fontSize: 15, color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Info Details Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  _infoRow(
                    icon: Icons.person_rounded,
                    label: isReceipt ? 'العميل' : 'المورد',
                    value: pay.partyNameAr ?? 'الطرف المحاسبي',
                  ),
                  const Divider(height: 18),
                  _infoRow(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'حساب الصندوق / البنك',
                    value: pay.cashBankAccountNameAr ?? 'صندوق',
                  ),
                  const Divider(height: 18),
                  _infoRow(
                    icon: Icons.payment_rounded,
                    label: 'طريقة الدفع',
                    value: pay.methodLabel,
                  ),
                  const Divider(height: 18),
                  _infoRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'تاريخ السند',
                    value: pay.paymentDate,
                  ),
                  if (pay.referenceNumber != null &&
                      pay.referenceNumber!.isNotEmpty) ...[
                    const Divider(height: 18),
                    _infoRow(
                      icon: Icons.link_rounded,
                      label: 'رقم المرجع / الشيك',
                      value: pay.referenceNumber!,
                    ),
                  ],
                  if (pay.notes != null && pay.notes!.isNotEmpty) ...[
                    const Divider(height: 18),
                    _infoRow(
                      icon: Icons.notes_rounded,
                      label: 'ملاحظات',
                      value: pay.notes!,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. GL Entry Link Banner
            if (pay.isPosted && pay.journalEntryId != null) ...[
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => JournalEntryDetailsScreen(
                        entryId: pay.journalEntryId!,
                        organizationId: pay.organizationId,
                        baseCurrencyCode: widget.baseCurrencyCode,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_stories_rounded,
                          color: AppColors.primary, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'تم ترحيل القيد في دفتر الأستاذ العام تلقائياً. اضغط لعرض القيد المحاسبي.',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 14, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 4. Invoices Allocations
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
                Text(
                  'الفواتير المسددة بهذا السند (${pay.allocations.length})',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNavy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (pay.allocations.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Text(
                    'هذا السند دفعة مقدمة على الحساب ولم يتم تخصيصه لفواتير محددة',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ...pay.allocations.map((alloc) {
                final int fxDiff = alloc.realizedForexGainLoss;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: const Icon(Icons.receipt_outlined,
                        color: AppColors.primary, size: 22),
                    title: Text(
                      'فاتورة رقم ${alloc.invoiceNumber ?? alloc.invoiceId}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    subtitle: fxDiff != 0
                        ? Text(
                            fxDiff > 0
                                ? 'أرباح فروق صرف: +${_formatMoney(fxDiff)}'
                                : 'خسائر فروق صرف: -${_formatMoney(fxDiff.abs())}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: fxDiff > 0
                                  ? AppColors.success
                                  : AppColors.danger,
                            ),
                          )
                        : null,
                    trailing: Text(
                      '${_formatMoney(alloc.allocatedAmount)} ${pay.currencyCode}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InvoiceDetailsScreen(
                            invoiceId: alloc.invoiceId,
                            organizationId: pay.organizationId,
                            baseCurrencyCode: widget.baseCurrencyCode,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            const SizedBox(height: 24),

            // 5. Action Buttons
            if (pay.isDraft) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _postPayment,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('ترحيل السند وتحديث الأرصدة'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final res = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreatePaymentScreen(
                          organizationId: pay.organizationId,
                          baseCurrencyCode: widget.baseCurrencyCode,
                          paymentToEdit: pay,
                        ),
                      ),
                    );
                    if (res == true) _loadPayment();
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('تعديل مسودة السند'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _deleteDraft,
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.danger),
                  label: const Text('حذف المسودة',
                      style: TextStyle(color: AppColors.danger)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.danger)),
                ),
              ),
            ] else if (pay.isPosted) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _voidPayment,
                  icon: const Icon(Icons.cancel_outlined,
                      color: AppColors.danger),
                  label: const Text(
                    'إلغاء وعكس السند المحاسبي',
                    style: TextStyle(
                        color: AppColors.danger, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.danger)),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: AppColors.darkNavy,
          ),
        ),
      ],
    );
  }
}
