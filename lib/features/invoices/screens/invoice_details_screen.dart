import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../journal/screens/journal_entry_details_screen.dart';
import '../../organizations/data/organization_branding_service.dart';
import '../../organizations/data/organization_repository.dart';
import '../../payments/screens/payment_details_screen.dart';
import '../../reports/screens/report_document_preview_screen.dart';
import '../data/invoice_repository.dart';
import '../models/invoice_model.dart';
import 'create_invoice_screen.dart';

/// Screen displaying complete invoice details, line items breakdown, GL linkage,
/// linked payment allocations, and document preview actions.
class InvoiceDetailsScreen extends StatefulWidget {
  final String invoiceId;
  final String organizationId;
  final String baseCurrencyCode;

  const InvoiceDetailsScreen({
    super.key,
    required this.invoiceId,
    required this.organizationId,
    required this.baseCurrencyCode,
  });

  @override
  State<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends State<InvoiceDetailsScreen> {
  final InvoiceRepository _invoiceRepo = InvoiceRepository();
  InvoiceModel? _invoice;
  List<Map<String, dynamic>> _allocations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    setState(() => _isLoading = true);
    try {
      final inv = await _invoiceRepo.getInvoiceById(
        widget.invoiceId,
        widget.organizationId,
      );
      List<Map<String, dynamic>> allocs = [];
      if (inv != null) {
        allocs = await _invoiceRepo.getInvoiceAllocations(
          inv.id,
          inv.organizationId,
        );
      }
      if (mounted) {
        setState(() {
          _invoice = inv;
          _allocations = allocs;
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

  Future<void> _postInvoice() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _invoiceRepo.postInvoice(widget.invoiceId, widget.organizationId);
      await _loadInvoice();
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('تم ترحيل الفاتورة وتوليد القيد المحاسبي بنجاح'),
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

  Future<void> _cancelInvoice() async {
    final reasonController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد إلغاء الفاتورة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'هل أنت متأكد من إلغاء الفاتورة؟ سيتم عكس القيد المحاسبي المرتبط بها في دفتر الأستاذ العام.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'سبب الإلغاء *',
                hintText: 'مثال: إلغاء الطلب / خطأ في الأسعار',
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
                await _invoiceRepo.cancelInvoice(
                  widget.invoiceId,
                  widget.organizationId,
                  reason,
                );
                await _loadInvoice();
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('تم إلغاء الفاتورة وعكس قيدها المحاسبي'),
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
        content: const Text('هل أنت متأكد من رغبتك في حذف مسودة هذه الفاتورة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await _invoiceRepo.deleteDraftInvoice(
                  widget.invoiceId,
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
    if (_invoice == null) return;
    final inv = _invoice!;

    try {
      final orgRepo = OrganizationRepository();
      final org = await orgRepo.getOrganizationById(widget.organizationId);
      final branding = await OrganizationBrandingService.instance
          .getBranding(widget.organizationId);

      final headers = [
        '#',
        'البيان والتفاصيل',
        'الكمية',
        'السعر',
        'الخصم',
        'الضريبة',
        'الإجمالي'
      ];
      final rows = inv.lines.map((l) {
        return [
          l.lineNumber.toString(),
          l.itemDescription,
          l.quantityDouble.toStringAsFixed(2),
          _formatMoney(l.unitPrice),
          _formatMoney(l.discountAmount),
          _formatMoney(l.taxAmount),
          _formatMoney(l.lineTotal),
        ];
      }).toList();

      final totals = [
        'الإجمالي الصافي:',
        '',
        '',
        '',
        _formatMoney(inv.discountAmount),
        _formatMoney(inv.taxAmount),
        '${_formatMoney(inv.totalAmount)} ${inv.currencyCode}',
      ];

      final subtitle =
          'الطرف: ${inv.partyNameAr ?? "طرف نقدي"} | حالة السداد: ${inv.paymentStatusLabel} | تاريخ الاستحقاق: ${inv.dueDate}';

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportDocumentPreviewScreen(
              title: inv.typeLabel,
              organizationName: org?.name ?? 'المؤسسة',
              baseCurrency: inv.currencyCode,
              periodOrDate: inv.issueDate,
              documentNumber: inv.invoiceNumber,
              headers: headers,
              rows: rows,
              totals: totals,
              subtitle: subtitle,
              branding: branding,
              notes: inv.notes,
              isInvoiceOrVoucher: true,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء تجهيز المستند: $e')),
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

    if (_invoice == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الفاتورة')),
        body: const Center(child: Text('لم يتم العثور على الفاتورة')),
      );
    }

    final inv = _invoice!;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            inv.invoiceNumber,
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
              onPressed: _loadInvoice,
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Header Information Card
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inv.typeLabel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkNavy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'تاريخ الإصدار: ${inv.issueDate} • الاستحقاق: ${inv.dueDate}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: inv.isPosted
                              ? const Color(0xFFECFDF5)
                              : (inv.isDraft
                                  ? const Color(0xFFFFFBEB)
                                  : const Color(0xFFFEF2F2)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          inv.statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: inv.isPosted
                                ? const Color(0xFF059669)
                                : (inv.isDraft
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFFDC2626)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.person_rounded,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'الطرف: ${inv.partyNameAr ?? ""}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkNavy,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'العملة: ${inv.currencyCode}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Linked Journal Entry Banner (if posted)
            if (inv.isPosted && inv.journalEntryId != null) ...[
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => JournalEntryDetailsScreen(
                        entryId: inv.journalEntryId!,
                        organizationId: inv.organizationId,
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
                          'تم إنشاء قيد اليومية العام تلقائياً وترحيله للأستاذ العام. اضغط للعرض.',
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

            // 3. Line Items
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
                  'بنود الفاتورة (${inv.lines.length})',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNavy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            ...inv.lines.map((l) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.itemDescription,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkNavy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'الكمية: ${l.quantityDouble} × ${_formatMoney(l.unitPrice)} ${inv.currencyCode}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (l.discountAmount > 0 || l.taxAmount > 0)
                            Text(
                              'خصم: ${_formatMoney(l.discountAmount)} • ضريبة: ${_formatMoney(l.taxAmount)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${_formatMoney(l.lineTotal)} ${inv.currencyCode}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkNavy,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 14),

            // 4. Financial Summary Card
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
                  _summaryRow('المجموع قبل الضريبة والخصم:',
                      _formatMoney(inv.subtotal), inv.currencyCode),
                  if (inv.discountAmount > 0) ...[
                    const SizedBox(height: 6),
                    _summaryRow(
                        'الخصم:',
                        '-${_formatMoney(inv.discountAmount)}',
                        inv.currencyCode,
                        highlightColor: AppColors.danger),
                  ],
                  if (inv.taxAmount > 0) ...[
                    const SizedBox(height: 6),
                    _summaryRow('الضريبة:', '+${_formatMoney(inv.taxAmount)}',
                        inv.currencyCode,
                        highlightColor: AppColors.warning),
                  ],
                  const Divider(height: 16),
                  _summaryRow(
                    'الإجمالي النهائي:',
                    _formatMoney(inv.totalAmount),
                    inv.currencyCode,
                    isBold: true,
                    highlightColor: AppColors.primary,
                  ),
                  const SizedBox(height: 6),
                  _summaryRow('المسدد:', _formatMoney(inv.paidAmount),
                      inv.currencyCode),
                  const SizedBox(height: 6),
                  _summaryRow(
                    'المتبقي للسداد:',
                    _formatMoney(inv.remainingAmount),
                    inv.currencyCode,
                    isBold: true,
                    highlightColor: inv.remainingAmount > 0
                        ? AppColors.danger
                        : AppColors.success,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 5. Linked Payments Section (if any payments allocated)
            if (_allocations.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'سندات السداد والتحصيل (${_allocations.length})',
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkNavy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...List.generate(_allocations.length, (idx) {
                final alloc = _allocations[idx];
                final String payId = alloc['payment_id'] as String;
                final String payNum = alloc['payment_number'] as String;
                final String payDate = alloc['payment_date'] as String;
                final int allocAmount =
                    (alloc['allocated_amount'] as num).toInt();
                final int fxDiff =
                    (alloc['realized_forex_gain_loss'] as num?)?.toInt() ?? 0;

                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaymentDetailsScreen(
                          paymentId: payId,
                          organizationId: widget.organizationId,
                          baseCurrencyCode: widget.baseCurrencyCode,
                        ),
                      ),
                    ).then((_) => _loadInvoice());
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            color: AppColors.success, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'سند رقم $payNum',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              Text(
                                'تاريخ: $payDate',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${_formatMoney(allocAmount)} ${inv.currencyCode}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkNavy,
                              ),
                            ),
                            if (fxDiff != 0)
                              Text(
                                'فروق صرف: ${_formatMoney(fxDiff.abs())}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: fxDiff > 0
                                      ? AppColors.success
                                      : AppColors.danger,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 14, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 14),
            ],

            // 6. Actions
            if (inv.isDraft) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _postInvoice,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('ترحيل الفاتورة وتوليد القيد المحاسبي'),
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
                        builder: (_) => CreateInvoiceScreen(
                          organizationId: inv.organizationId,
                          baseCurrencyCode: widget.baseCurrencyCode,
                          invoiceToEdit: inv,
                        ),
                      ),
                    );
                    if (res == true) _loadInvoice();
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('تعديل مسودة الفاتورة'),
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
            ] else if (inv.isPosted && inv.paidAmount == 0) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _cancelInvoice,
                  icon: const Icon(Icons.cancel_outlined,
                      color: AppColors.danger),
                  label: const Text(
                    'إلغاء الفاتورة وعكس القيد',
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

  Widget _summaryRow(
    String label,
    String value,
    String currency, {
    bool isBold = false,
    Color? highlightColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 14 : 13,
            color: isBold ? AppColors.darkNavy : AppColors.textSecondary,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Row(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: isBold ? 15 : 13.5,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: highlightColor ?? AppColors.darkNavy,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              currency,
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}
