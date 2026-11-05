import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../organizations/data/organization_branding_service.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/reports_repository.dart';
import 'report_document_preview_screen.dart';

/// Screen presenting the Income Statement (قائمة الدخل والأرباح والخسائر).
class IncomeStatementScreen extends StatefulWidget {
  final String organizationId;
  final String baseCurrencyCode;

  const IncomeStatementScreen({
    super.key,
    required this.organizationId,
    required this.baseCurrencyCode,
  });

  @override
  State<IncomeStatementScreen> createState() => _IncomeStatementScreenState();
}

class _IncomeStatementScreenState extends State<IncomeStatementScreen> {
  final ReportsRepository _repo = ReportsRepository();

  late String _fromDate;
  late String _toDate;
  Map<String, dynamic>? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = '${now.year}-01-01';
    _toDate = now.toIso8601String().split('T').first;
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final res = await _repo.getIncomeStatement(
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

  Future<void> _exportPdf() async {
    if (_data == null) return;

    final revenues = (_data!['revenues'] as List<dynamic>?) ?? [];
    final expenses = (_data!['expenses'] as List<dynamic>?) ?? [];
    final totalRev = (_data!['total_revenue'] as num?)?.toInt() ?? 0;
    final totalExp = (_data!['total_expense'] as num?)?.toInt() ?? 0;
    final net = (_data!['net_profit_loss'] as num?)?.toInt() ?? 0;

    final headers = [
      'النوع / التصنيف',
      'رمز الحساب',
      'اسم الحساب',
      'المبلغ (${widget.baseCurrencyCode})'
    ];
    final rows = <List<String>>[];

    for (final r in revenues) {
      final map = r as Map<String, dynamic>;
      rows.add([
        'إيرادات',
        map['code']?.toString() ?? '',
        map['name']?.toString() ?? '',
        _formatMoney((map['amount'] as num?)?.toInt() ?? 0),
      ]);
    }
    rows.add(['إجمالي الإيرادات', '', '', _formatMoney(totalRev)]);

    for (final e in expenses) {
      final map = e as Map<String, dynamic>;
      rows.add([
        'مصروفات',
        map['code']?.toString() ?? '',
        map['name']?.toString() ?? '',
        _formatMoney((map['amount'] as num?)?.toInt() ?? 0),
      ]);
    }
    rows.add(['إجمالي المصروفات', '', '', _formatMoney(totalExp)]);

    final totals = [
      net >= 0 ? 'صافي الربح' : 'صافي الخسارة',
      '',
      '',
      _formatMoney(net),
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
              title: 'قائمة الدخل (الأرباح والخسائر)',
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
    final int netProfit = (_data?['net_profit_loss'] as num?)?.toInt() ?? 0;
    final int totalRev = (_data?['total_revenue'] as num?)?.toInt() ?? 0;
    final int totalExp = (_data?['total_expense'] as num?)?.toInt() ?? 0;
    final bool isProfit = netProfit >= 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('قائمة الدخل',
              style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              onPressed: _exportPdf,
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
                    // 1. Period Selector Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
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
                                  setState(() => _fromDate =
                                      d.toIso8601String().split('T').first);
                                  _loadReport();
                                }
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('من تاريخ:',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text(_fromDate,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.darkNavy)),
                                ],
                              ),
                            ),
                          ),
                          Container(
                              height: 28, width: 1, color: AppColors.border),
                          const SizedBox(width: 14),
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
                                  setState(() => _toDate =
                                      d.toIso8601String().split('T').first);
                                  _loadReport();
                                }
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('إلى تاريخ:',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text(_toDate,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.darkNavy)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Summary Card: Net Profit / Loss
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isProfit
                              ? [
                                  const Color(0xFF059669),
                                  const Color(0xFF10B981)
                                ]
                              : [
                                  const Color(0xFFDC2626),
                                  const Color(0xFFEF4444)
                                ],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: (isProfit
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFDC2626))
                                .withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            isProfit
                                ? 'صافي الربح للفترة'
                                : 'صافي الخسارة للفترة',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_formatMoney(netProfit.abs())} ${widget.baseCurrencyCode}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Text('إجمالي الإيرادات',
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          color: Colors.white70)),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatMoney(totalRev),
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                  ),
                                ],
                              ),
                              Container(
                                  height: 20, width: 1, color: Colors.white24),
                              Column(
                                children: [
                                  const Text('إجمالي المصروفات',
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          color: Colors.white70)),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatMoney(totalExp),
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. Revenues List
                    _buildSectionHeader('الإيرادات', const Color(0xFF059669)),
                    const SizedBox(height: 8),
                    _buildAccountsList(
                        (_data?['revenues'] as List?)
                                ?.cast<Map<String, dynamic>>() ??
                            [],
                        isRevenue: true),
                    const SizedBox(height: 16),

                    // 4. Expenses List
                    _buildSectionHeader(
                        'المصروفات والتكاليف', const Color(0xFFDC2626)),
                    const SizedBox(height: 8),
                    _buildAccountsList(
                        (_data?['expenses'] as List?)
                                ?.cast<Map<String, dynamic>>() ??
                            [],
                        isRevenue: false),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.darkNavy,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountsList(List<Map<String, dynamic>> items,
      {required bool isRevenue}) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text(
            isRevenue ? 'لا توجد إيرادات مسجلة' : 'لا توجد مصروفات مسجلة',
            style:
                const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      children: items.map((it) {
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${it['name']} (${it['code']})',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkNavy),
              ),
              Text(
                '${_formatMoney(it['amount'] as int)} ${widget.baseCurrencyCode}',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: isRevenue
                      ? const Color(0xFF059669)
                      : const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
