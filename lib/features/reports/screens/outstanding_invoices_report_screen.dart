import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../organizations/data/organization_branding_service.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/reports_repository.dart';
import 'report_document_preview_screen.dart';

/// Screen presenting Outstanding Receivables (الذمم المدينة المستحقة)
/// or Outstanding Payables (الذمم الدائنة المستحقة) with aging buckets.
class OutstandingInvoicesReportScreen extends StatefulWidget {
  final String organizationId;
  final String baseCurrencyCode;
  final bool
      isReceivable; // true = Receivables (Sales), false = Payables (Purchases)

  const OutstandingInvoicesReportScreen({
    super.key,
    required this.organizationId,
    required this.baseCurrencyCode,
    this.isReceivable = true,
  });

  @override
  State<OutstandingInvoicesReportScreen> createState() =>
      _OutstandingInvoicesReportScreenState();
}

class _OutstandingInvoicesReportScreenState
    extends State<OutstandingInvoicesReportScreen> {
  final ReportsRepository _repo = ReportsRepository();
  String _asOfDate = DateTime.now().toIso8601String().split('T').first;

  Map<String, dynamic>? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final res = widget.isReceivable
          ? await _repo.getOutstandingReceivables(
              widget.organizationId,
              asOfDate: _asOfDate,
            )
          : await _repo.getOutstandingPayables(
              widget.organizationId,
              asOfDate: _asOfDate,
            );
      if (mounted) {
        setState(() {
          _data = res;
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

  Future<void> _exportReport() async {
    if (_data == null) return;

    final title = widget.isReceivable
        ? 'تقرير الذمم المدينة وأعمار الديون (العملاء)'
        : 'تقرير الذمم الدائنة وأعمار الديون (الموردين)';

    final headers = [
      'رقم الفاتورة',
      widget.isReceivable ? 'العميل' : 'المورد',
      'تاريخ الإصدار',
      'العمر (أيام)',
      'فئة العمر',
      'الإجمالي',
      'المسدد',
      'المتبقي المستحق',
    ];

    final invoices = (_data!['invoices'] as List<dynamic>?) ?? [];
    final rows = <List<String>>[];

    for (final inv in invoices) {
      final map = inv as Map<String, dynamic>;
      rows.add([
        map['invoice_number']?.toString() ?? '',
        map['party_name']?.toString() ?? '',
        map['issue_date']?.toString() ?? '',
        map['age_days']?.toString() ?? '0',
        map['aging_bucket']?.toString() ?? '',
        _formatMoney((map['total_amount'] as num?)?.toInt() ?? 0),
        _formatMoney((map['paid_amount'] as num?)?.toInt() ?? 0),
        _formatMoney((map['remaining_amount'] as num?)?.toInt() ?? 0),
      ]);
    }

    final total = widget.isReceivable
        ? ((_data!['total_receivables'] as num?)?.toInt() ?? 0)
        : ((_data!['total_payables'] as num?)?.toInt() ?? 0);

    final totals = [
      'الإجمالي المستحق',
      '',
      '',
      '',
      '',
      '',
      '',
      _formatMoney(total),
    ];

    try {
      final orgRepo = OrganizationRepository();
      final org = await orgRepo.getOrganizationById(widget.organizationId);
      final branding = await OrganizationBrandingService.instance
          .getBranding(widget.organizationId);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportDocumentPreviewScreen(
              title: title,
              organizationName: org?.name ?? 'المؤسسة',
              baseCurrency: widget.baseCurrencyCode,
              periodOrDate: 'حتى تاريخ $_asOfDate',
              headers: headers,
              rows: rows,
              totals: totals,
              branding: branding,
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
    final title = widget.isReceivable
        ? 'الذمم المدينة المستحقة (العملاء)'
        : 'الذمم الدائنة المستحقة (الموردين)';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              onPressed: _exportReport,
              tooltip: 'تصدير PDF',
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadReport,
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                onRefresh: _loadReport,
                color: AppColors.primary,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Date Selector
                    _buildDateSelector(),
                    const SizedBox(height: 16),

                    if (_data != null) ...[
                      // Aging Summary Cards
                      _buildAgingBucketsCard(),
                      const SizedBox(height: 18),

                      // Invoices List
                      _buildInvoicesList(),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('الأرصدة حتى تاريخ:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime.parse(_asOfDate),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (d != null) {
                setState(
                    () => _asOfDate = d.toIso8601String().split('T').first);
                _loadReport();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _asOfDate,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgingBucketsCard() {
    final total = widget.isReceivable
        ? ((_data!['total_receivables'] as num?)?.toInt() ?? 0)
        : ((_data!['total_payables'] as num?)?.toInt() ?? 0);
    final b0To30 = (_data!['bucket_0_30'] as num?)?.toInt() ?? 0;
    final b31To60 = (_data!['bucket_31_60'] as num?)?.toInt() ?? 0;
    final b61To90 = (_data!['bucket_61_90'] as num?)?.toInt() ?? 0;
    final b90Plus = (_data!['bucket_90_plus'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.isReceivable
                    ? 'إجمالي الذمم المدينة المستحقة'
                    : 'إجمالي الذمم الدائنة المستحقة',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                '${_formatMoney(total)} ${widget.baseCurrencyCode}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              _buildBucketCol('0-30 يوم', b0To30, const Color(0xFF059669)),
              _buildBucketCol('31-60 يوم', b31To60, const Color(0xFF2563EB)),
              _buildBucketCol('61-90 يوم', b61To90, const Color(0xFFD97706)),
              _buildBucketCol('+90 يوم', b90Plus, AppColors.danger),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBucketCol(String label, int amount, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            _formatMoney(amount),
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicesList() {
    final invoices = (_data!['invoices'] as List<dynamic>?) ?? [];

    if (invoices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Text(
          widget.isReceivable
              ? 'لا توجد فواتير مبيعات آجلة غير مسددة حتى هذا التاريخ'
              : 'لا توجد فواتير مشتريات آجلة غير مسددة حتى هذا التاريخ',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'الفواتير المستحقة (${invoices.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...invoices.map((inv) {
          final map = inv as Map<String, dynamic>;
          final total = (map['total_amount'] as num?)?.toInt() ?? 0;
          final remaining = (map['remaining_amount'] as num?)?.toInt() ?? 0;
          final ageDays = (map['age_days'] as num?)?.toInt() ?? 0;
          final bucket = map['aging_bucket']?.toString() ?? '';

          Color ageColor = const Color(0xFF059669);
          if (ageDays > 90) {
            ageColor = AppColors.danger;
          } else if (ageDays > 60) {
            ageColor = const Color(0xFFD97706);
          } else if (ageDays > 30) {
            ageColor = const Color(0xFF2563EB);
          }

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'فاتورة رقم: ${map['invoice_number']}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: ageColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: ageColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '$ageDays يوم ($bucket)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: ageColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'الطرف: ${map['party_name']} (${map['party_code']})',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'تاريخ الإصدار: ${map['issue_date']} • الاستحقاق: ${map['due_date']}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الإجمالي: ${_formatMoney(total)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Text(
                        'المتبقي المستحق: ${_formatMoney(remaining)} ${widget.baseCurrencyCode}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: widget.isReceivable
                              ? AppColors.primary
                              : const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
