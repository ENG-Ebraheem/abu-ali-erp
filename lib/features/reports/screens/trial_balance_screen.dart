import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../organizations/data/organization_branding_service.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/reports_repository.dart';
import 'report_document_preview_screen.dart';

/// Screen presenting the Trial Balance (ميزان المراجعة).
class TrialBalanceScreen extends StatefulWidget {
  final String organizationId;
  final String baseCurrencyCode;

  const TrialBalanceScreen({
    super.key,
    required this.organizationId,
    required this.baseCurrencyCode,
  });

  @override
  State<TrialBalanceScreen> createState() => _TrialBalanceScreenState();
}

class _TrialBalanceScreenState extends State<TrialBalanceScreen> {
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
      final res = await _repo.getTrialBalance(
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

    final accounts = (_data!['accounts'] as List<dynamic>?) ?? [];
    final headers = [
      'رمز الحساب',
      'اسم الحساب',
      'مجموع مدين',
      'مجموع دائن',
      'رصيد مدين',
      'رصيد دائن',
    ];

    final rows = <List<String>>[];
    for (final acc in accounts) {
      final map = acc as Map<String, dynamic>;
      rows.add([
        map['account_code']?.toString() ?? '',
        map['account_name_ar']?.toString() ?? '',
        _formatMoney((map['total_debit'] as num?)?.toInt() ?? 0),
        _formatMoney((map['total_credit'] as num?)?.toInt() ?? 0),
        _formatMoney((map['net_debit'] as num?)?.toInt() ?? 0),
        _formatMoney((map['net_credit'] as num?)?.toInt() ?? 0),
      ]);
    }

    final sumTotalDebit = (_data!['sum_total_debit'] as num?)?.toInt() ?? 0;
    final sumTotalCredit = (_data!['sum_total_credit'] as num?)?.toInt() ?? 0;
    final sumNetDebit = (_data!['sum_net_debit'] as num?)?.toInt() ?? 0;
    final sumNetCredit = (_data!['sum_net_credit'] as num?)?.toInt() ?? 0;

    final totals = [
      'الإجمالي العام',
      '',
      _formatMoney(sumTotalDebit),
      _formatMoney(sumTotalCredit),
      _formatMoney(sumNetDebit),
      _formatMoney(sumNetCredit),
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
              title: 'ميزان المراجعة بالمجاميع والأرصدة',
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('ميزان المراجعة',
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
                    // 1. Date Filter Bar
                    _buildDateSelector(),
                    const SizedBox(height: 16),

                    // 2. Balancing Summary Card
                    _buildSummaryCard(),
                    const SizedBox(height: 18),

                    // 3. Accounts List
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
                          'أرصدة ومجاميع الحسابات (${(_data?['accounts'] as List?)?.length ?? 0})',
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkNavy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if ((_data?['accounts'] as List?)?.isEmpty ?? true)
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Center(
                          child: Text(
                            'لا توجد حركات محاسبية مرحّلة حتى هذا التاريخ',
                            style: TextStyle(
                                fontSize: 13.5, color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else
                      ...((_data?['accounts'] as List)
                              .cast<Map<String, dynamic>>())
                          .map((acc) {
                        final netDebit = acc['net_debit'] as int;
                        final netCredit = acc['net_credit'] as int;
                        final hasNetDebit = netDebit > 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      acc['account_name_ar'] as String,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.darkNavy,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${acc['account_code']} • مجاميع: مدين ${_formatMoney(acc['total_debit'])} / دائن ${_formatMoney(acc['total_credit'])}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatMoney(
                                        hasNetDebit ? netDebit : netCredit),
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: hasNetDebit
                                          ? AppColors.primary
                                          : AppColors.success,
                                    ),
                                  ),
                                  Text(
                                    hasNetDebit ? 'رصيد مدين' : 'رصيد دائن',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
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
              Text(
                'الأرصدة والمجاميع حتى:',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkNavy,
                ),
              ),
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
                setState(() {
                  _asOfDate = picked.toIso8601String().split('T').first;
                });
                _loadReport();
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    );
  }

  Widget _buildSummaryCard() {
    final isBalanced = _data?['is_balanced'] as bool? ?? false;
    final totalDebit = _data?['sum_total_debit'] as int? ?? 0;
    final totalCredit = _data?['sum_total_credit'] as int? ?? 0;
    final netDebit = _data?['sum_net_debit'] as int? ?? 0;
    final netCredit = _data?['sum_net_credit'] as int? ?? 0;

    return Container(
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isBalanced
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.danger.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isBalanced ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: isBalanced ? AppColors.success : AppColors.danger,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isBalanced
                      ? 'ميزان المراجعة متوازن تماماً محاسبياً'
                      : 'تحذير: يوجد فارق محاسبي في التوازن!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isBalanced ? AppColors.success : AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('مجموع المدين (الحركات):',
                        style: TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary)),
                    Text(
                      '${_formatMoney(totalDebit)} ${widget.baseCurrencyCode}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkNavy),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('مجموع الدائن (الحركات):',
                        style: TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary)),
                    Text(
                      '${_formatMoney(totalCredit)} ${widget.baseCurrencyCode}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkNavy),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('صافي الأرصدة المدينة:',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                    Text(
                      '${_formatMoney(netDebit)} ${widget.baseCurrencyCode}',
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('صافي الأرصدة الدائنة:',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success)),
                    Text(
                      '${_formatMoney(netCredit)} ${widget.baseCurrencyCode}',
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
