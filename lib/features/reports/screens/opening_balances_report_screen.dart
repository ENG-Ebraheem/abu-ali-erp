import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../organizations/data/organization_branding_service.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/reports_repository.dart';
import 'report_document_preview_screen.dart';

/// Screen presenting the Opening Balances Report (تقرير الأرصدة الافتتاحية).
class OpeningBalancesReportScreen extends StatefulWidget {
  final String organizationId;
  final String baseCurrencyCode;

  const OpeningBalancesReportScreen({
    super.key,
    required this.organizationId,
    required this.baseCurrencyCode,
  });

  @override
  State<OpeningBalancesReportScreen> createState() =>
      _OpeningBalancesReportScreenState();
}

class _OpeningBalancesReportScreenState
    extends State<OpeningBalancesReportScreen> {
  final ReportsRepository _repo = ReportsRepository();

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
      final res = await _repo.getOpeningBalancesReport(widget.organizationId);
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

    final title = 'تقرير الأرصدة الافتتاحية التأسيسية';
    final headers = [
      'رمز الحساب',
      'اسم الحساب',
      'النوع',
      'العملة',
      'مدين أجنبي',
      'دائن أجنبي',
      'مدين (${widget.baseCurrencyCode})',
      'دائن (${widget.baseCurrencyCode})',
    ];

    final lines = (_data!['lines'] as List<dynamic>?) ?? [];
    final rows = <List<String>>[];

    for (final l in lines) {
      final map = l as Map<String, dynamic>;
      rows.add([
        map['account_code']?.toString() ?? '',
        map['account_name_ar']?.toString() ?? '',
        map['account_type']?.toString() ?? '',
        map['currency_code']?.toString() ?? widget.baseCurrencyCode,
        _formatMoney((map['foreign_debit'] as num?)?.toInt() ?? 0),
        _formatMoney((map['foreign_credit'] as num?)?.toInt() ?? 0),
        _formatMoney((map['base_debit'] as num?)?.toInt() ?? 0),
        _formatMoney((map['base_credit'] as num?)?.toInt() ?? 0),
      ]);
    }

    final totalDebit = (_data!['total_debit'] as num?)?.toInt() ?? 0;
    final totalCredit = (_data!['total_credit'] as num?)?.toInt() ?? 0;

    final totals = [
      'الإجمالي العام',
      '',
      '',
      '',
      '',
      '',
      _formatMoney(totalDebit),
      _formatMoney(totalCredit),
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
              periodOrDate: 'تاريخ بداية النشاط والتأسيس',
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
          title: const Text('تقرير الأرصدة الافتتاحية',
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
                    if (_data != null) ...[
                      // Summary Balance Card
                      _buildSummaryCard(),
                      const SizedBox(height: 18),

                      // Accounts List
                      _buildLinesList(),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalDebit = (_data!['total_debit'] as num?)?.toInt() ?? 0;
    final totalCredit = (_data!['total_credit'] as num?)?.toInt() ?? 0;
    final isBalanced = _data!['is_balanced'] as bool? ?? false;
    final imbalance = (_data!['imbalance'] as num?)?.toInt() ?? 0;

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
                'حالة توازن القيد الافتتاحي',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isBalanced
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isBalanced
                          ? Icons.check_circle_rounded
                          : Icons.warning_rounded,
                      size: 14,
                      color: isBalanced
                          ? const Color(0xFF059669)
                          : AppColors.danger,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isBalanced
                          ? 'متوازن محاسبياً'
                          : 'غير متوازن (${_formatMoney(imbalance)})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isBalanced
                            ? const Color(0xFF059669)
                            : AppColors.danger,
                      ),
                    ),
                  ],
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
                    const Text('إجمالي المدين الافتتاحي',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatMoney(totalDebit)} ${widget.baseCurrencyCode}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إجمالي الدائن الافتتاحي',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatMoney(totalCredit)} ${widget.baseCurrencyCode}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF059669),
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

  Widget _buildLinesList() {
    final lines = (_data!['lines'] as List<dynamic>?) ?? [];

    if (lines.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: const Text(
          'لم يتم ترحيل أرصدة افتتاحية لهذه المؤسسة بعد',
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
              'أرصدة الحسابات الافتتاحية (${lines.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...lines.map((l) {
          final map = l as Map<String, dynamic>;
          final debit = (map['base_debit'] as num?)?.toInt() ?? 0;
          final credit = (map['base_credit'] as num?)?.toInt() ?? 0;

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
                        '${map['account_code']} • ${map['account_name_ar']}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          map['account_type']?.toString() ?? '',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'سند رقم: ${map['entry_number']} • تاريخ: ${map['entry_date']}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (debit > 0)
                        Text(
                          'مدين: ${_formatMoney(debit)} ${widget.baseCurrencyCode}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      if (credit > 0)
                        Text(
                          'دائن: ${_formatMoney(credit)} ${widget.baseCurrencyCode}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
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
