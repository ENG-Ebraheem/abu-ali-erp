import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../organizations/data/organization_branding_service.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/reports_repository.dart';
import 'report_document_preview_screen.dart';

/// Screen presenting the Balance Sheet (الميزانية العمومية والمركز المالي).
class BalanceSheetScreen extends StatefulWidget {
  final String organizationId;
  final String baseCurrencyCode;

  const BalanceSheetScreen({
    super.key,
    required this.organizationId,
    required this.baseCurrencyCode,
  });

  @override
  State<BalanceSheetScreen> createState() => _BalanceSheetScreenState();
}

class _BalanceSheetScreenState extends State<BalanceSheetScreen> {
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
      final res = await _repo.getBalanceSheet(
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

  Future<void> _exportPdf() async {
    if (_data == null) return;

    final assets = (_data!['assets'] as List<dynamic>?) ?? [];
    final liabilities = (_data!['liabilities'] as List<dynamic>?) ?? [];
    final equity = (_data!['equity'] as List<dynamic>?) ?? [];
    final totalAssets = (_data!['total_assets'] as num?)?.toInt() ?? 0;
    final totalLiabilities =
        (_data!['total_liabilities'] as num?)?.toInt() ?? 0;
    final totalEquity = (_data!['total_equity'] as num?)?.toInt() ?? 0;

    final headers = [
      'القسم',
      'رمز الحساب',
      'اسم الحساب',
      'المبلغ (${widget.baseCurrencyCode})'
    ];
    final rows = <List<String>>[];

    for (final a in assets) {
      final map = a as Map<String, dynamic>;
      rows.add([
        'الأصول',
        map['code']?.toString() ?? '',
        map['name']?.toString() ?? '',
        _formatMoney((map['amount'] as num?)?.toInt() ?? 0),
      ]);
    }
    rows.add(['إجمالي الأصول', '', '', _formatMoney(totalAssets)]);

    for (final l in liabilities) {
      final map = l as Map<String, dynamic>;
      rows.add([
        'الخصوم والالتزامات',
        map['code']?.toString() ?? '',
        map['name']?.toString() ?? '',
        _formatMoney((map['amount'] as num?)?.toInt() ?? 0),
      ]);
    }
    rows.add(['إجمالي الالتزامات', '', '', _formatMoney(totalLiabilities)]);

    for (final eq in equity) {
      final map = eq as Map<String, dynamic>;
      rows.add([
        'حقوق الملكية',
        map['code']?.toString() ?? '',
        map['name']?.toString() ?? '',
        _formatMoney((map['amount'] as num?)?.toInt() ?? 0),
      ]);
    }
    rows.add(['إجمالي حقوق الملكية', '', '', _formatMoney(totalEquity)]);

    final totals = [
      'معادلة المركز المالي',
      'الأصول: ${_formatMoney(totalAssets)}',
      'الخصوم + الملكية: ${_formatMoney(totalLiabilities + totalEquity)}',
      totalAssets == (totalLiabilities + totalEquity)
          ? 'متوازنة'
          : 'فارق توازن',
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
              title: 'الميزانية العمومية (قائمة المركز المالي)',
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
    final int totalAssets = (_data?['total_assets'] as num?)?.toInt() ?? 0;
    final int totalLiabilities =
        (_data?['total_liabilities'] as num?)?.toInt() ?? 0;
    final int totalEquity = (_data?['total_equity'] as num?)?.toInt() ?? 0;
    final bool isBalanced = _data?['is_balanced'] == true;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('الميزانية العمومية',
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
                    // 1. Date filter bar
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  size: 18, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text('المركز المالي حتى:',
                                  style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.darkNavy)),
                            ],
                          ),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.parse(_asOfDate),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setState(() => _asOfDate =
                                    picked.toIso8601String().split('T').first);
                                _loadReport();
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _asOfDate,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Balance Verification Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isBalanced
                              ? AppColors.success.withValues(alpha: 0.3)
                              : AppColors.danger.withValues(alpha: 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                isBalanced
                                    ? Icons.check_circle_rounded
                                    : Icons.error_rounded,
                                color: isBalanced
                                    ? AppColors.success
                                    : AppColors.danger,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isBalanced
                                    ? 'معادلة المركز المالي متطابقة (الأصول = الخصوم + الملكية)'
                                    : 'معادلة المركز المالي غير متطابقة!',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: isBalanced
                                      ? AppColors.success
                                      : AppColors.danger,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Text('إجمالي الأصول',
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textSecondary)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_formatMoney(totalAssets)} ${widget.baseCurrencyCode}',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary),
                                  ),
                                ],
                              ),
                              const Text('=',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary)),
                              Column(
                                children: [
                                  const Text('الخصوم + حقوق الملكية',
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textSecondary)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_formatMoney(totalLiabilities + totalEquity)} ${widget.baseCurrencyCode}',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF7C3AED)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. Assets Section
                    _buildSectionHeader(
                        'الأصول (الموجودات)', AppColors.primary),
                    const SizedBox(height: 8),
                    _buildAccountsList(
                        (_data?['assets'] as List?)
                                ?.cast<Map<String, dynamic>>() ??
                            [],
                        color: AppColors.primary),
                    const SizedBox(height: 16),

                    // 4. Liabilities Section
                    _buildSectionHeader(
                        'الخصوم والالتزامات', const Color(0xFFD97706)),
                    const SizedBox(height: 8),
                    _buildAccountsList(
                        (_data?['liabilities'] as List?)
                                ?.cast<Map<String, dynamic>>() ??
                            [],
                        color: const Color(0xFFD97706)),
                    const SizedBox(height: 16),

                    // 5. Equity Section
                    _buildSectionHeader(
                        'حقوق الملكية والأرباح', const Color(0xFF7C3AED)),
                    const SizedBox(height: 8),
                    _buildAccountsList(
                        (_data?['equity'] as List?)
                                ?.cast<Map<String, dynamic>>() ??
                            [],
                        color: const Color(0xFF7C3AED)),
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
      {required Color color}) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            'لا توجد حسابات بأرصدة في هذا القسم',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
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
                  color: color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
