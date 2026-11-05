import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../organizations/data/organization_branding_service.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/reports_repository.dart';
import 'report_document_preview_screen.dart';

/// Screen presenting Realized Forex Gains and Losses report (أرباح وخسائر فروق العملة المحققة).
class RealizedForexReportScreen extends StatefulWidget {
  final String organizationId;
  final String baseCurrencyCode;

  const RealizedForexReportScreen({
    super.key,
    required this.organizationId,
    required this.baseCurrencyCode,
  });

  @override
  State<RealizedForexReportScreen> createState() =>
      _RealizedForexReportScreenState();
}

class _RealizedForexReportScreenState extends State<RealizedForexReportScreen> {
  final ReportsRepository _repo = ReportsRepository();
  String _fromDate = DateTime.now()
      .subtract(const Duration(days: 90))
      .toIso8601String()
      .split('T')
      .first;
  String _toDate = DateTime.now().toIso8601String().split('T').first;

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
      final res = await _repo.getRealizedForexReport(
        widget.organizationId,
        fromDate: _fromDate,
        toDate: _toDate,
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

  String _formatRate(int rateScaled) {
    final double val = rateScaled / 1000000.0;
    return val.toStringAsFixed(4);
  }

  Future<void> _exportReport() async {
    if (_data == null) return;

    final title = 'تقرير أرباح وخسائر فروق العملة المحققة';
    final headers = [
      'التاريخ',
      'سند الصرف/القبض',
      'الفاتورة المرتبطة',
      'الطرف',
      'المبلغ المسدد',
      'سعر الفاتورة',
      'سعر السند',
      'فرق العملة المحقق',
    ];

    final allocations = (_data!['allocations'] as List<dynamic>?) ?? [];
    final rows = <List<String>>[];

    for (final alloc in allocations) {
      final map = alloc as Map<String, dynamic>;
      final diff = (map['realized_forex_gain_loss'] as num?)?.toInt() ?? 0;
      rows.add([
        map['allocation_date']?.toString() ?? '',
        map['payment_number']?.toString() ?? '',
        map['invoice_number']?.toString() ?? '',
        map['party_name']?.toString() ?? '',
        _formatMoney((map['allocated_amount'] as num?)?.toInt() ?? 0),
        _formatRate((map['invoice_rate'] as num?)?.toInt() ?? 1000000),
        _formatRate((map['payment_rate'] as num?)?.toInt() ?? 1000000),
        '${diff >= 0 ? "+" : ""}${_formatMoney(diff)}',
      ]);
    }

    final netDiff = (_data!['net_forex_gain_loss'] as num?)?.toInt() ?? 0;
    final totals = [
      'الصافي المحقق',
      '',
      '',
      '',
      '',
      '',
      '',
      '${netDiff >= 0 ? "+" : ""}${_formatMoney(netDiff)} ${widget.baseCurrencyCode}',
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
              periodOrDate: 'من $_fromDate إلى $_toDate',
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('أرباح وخسائر فروق العملة',
              style: TextStyle(fontWeight: FontWeight.bold)),
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
                    // Date Filter
                    _buildDateFilter(),
                    const SizedBox(height: 16),

                    if (_data != null) ...[
                      // Summary Card
                      _buildSummaryCard(),
                      const SizedBox(height: 18),

                      // Allocations List
                      _buildAllocationsList(),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDateFilter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.parse(_fromDate),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (d != null) {
                  setState(
                      () => _fromDate = d.toIso8601String().split('T').first);
                  _loadReport();
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('من تاريخ',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(_fromDate,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(height: 30, width: 1, color: AppColors.border),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.parse(_toDate),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (d != null) {
                  setState(
                      () => _toDate = d.toIso8601String().split('T').first);
                  _loadReport();
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('إلى تاريخ',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(_toDate,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final gains = (_data!['total_realized_gains'] as num?)?.toInt() ?? 0;
    final losses = (_data!['total_realized_losses'] as num?)?.toInt() ?? 0;
    final net = (_data!['net_forex_gain_loss'] as num?)?.toInt() ?? 0;

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
              const Text(
                'صافي فروق أسعار الصرف المحققة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: net >= 0
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${net >= 0 ? "+" : ""}${_formatMoney(net)} ${widget.baseCurrencyCode}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        net >= 0 ? const Color(0xFF059669) : AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('أرباح فروق عملة (+)',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      '+${_formatMoney(gains)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('خسائر فروق عملة (-)',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      '-${_formatMoney(losses)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllocationsList() {
    final allocations = (_data!['allocations'] as List<dynamic>?) ?? [];

    if (allocations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: const Text(
          'لا توجد فروق عملة محققة خلال الفترة المحددة',
          style: TextStyle(color: AppColors.textSecondary),
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
              'حركات التسوية بفروق العملة (${allocations.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...allocations.map((alloc) {
          final map = alloc as Map<String, dynamic>;
          final diff = (map['realized_forex_gain_loss'] as num?)?.toInt() ?? 0;
          final isGain = diff >= 0;
          final color = isGain ? const Color(0xFF059669) : AppColors.danger;

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
                        'سند: ${map['payment_number']} ⟵ فاتورة: ${map['invoice_number']}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          isGain ? 'ربح محقق' : 'خسارة محققة',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: color),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'الطرف: ${map['party_name']} • التاريخ: ${map['allocation_date']}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'سعر صرف الفاتورة: ${_formatRate((map['invoice_rate'] as num?)?.toInt() ?? 1000000)}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'سعر صرف السند: ${_formatRate((map['payment_rate'] as num?)?.toInt() ?? 1000000)}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'المبلغ المسدد: ${_formatMoney((map['allocated_amount'] as num?)?.toInt() ?? 0)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Text(
                        'فارق العملة: ${isGain ? "+" : ""}${_formatMoney(diff)} ${widget.baseCurrencyCode}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: color,
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
