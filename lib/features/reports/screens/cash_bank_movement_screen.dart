import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../organizations/data/organization_branding_service.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/reports_repository.dart';
import 'report_document_preview_screen.dart';

/// Screen presenting Cash and Bank account movements and live balances.
class CashBankMovementScreen extends StatefulWidget {
  final String organizationId;
  final String baseCurrencyCode;

  const CashBankMovementScreen({
    super.key,
    required this.organizationId,
    required this.baseCurrencyCode,
  });

  @override
  State<CashBankMovementScreen> createState() => _CashBankMovementScreenState();
}

class _CashBankMovementScreenState extends State<CashBankMovementScreen> {
  final ReportsRepository _repo = ReportsRepository();
  List<Map<String, dynamic>> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repo.getCashBankMovements(widget.organizationId);
      if (mounted) {
        setState(() {
          _accounts = list;
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
    final headers = [
      'رمز الحساب',
      'اسم الصندوق / البنك',
      'العملة',
      'إجمالي المقبوضات (مدين)',
      'إجمالي المدفوعات (دائن)',
      'الرصيد الصافي (${widget.baseCurrencyCode})',
    ];

    final rows = <List<String>>[];
    int totalLiquidity = 0;
    for (final a in _accounts) {
      final net = (a['net_balance'] as num).toInt();
      totalLiquidity += net;
      rows.add([
        a['account_code']?.toString() ?? '',
        a['account_name_ar']?.toString() ?? '',
        a['currency_code']?.toString() ?? widget.baseCurrencyCode,
        _formatMoney((a['total_inflow'] as num).toInt()),
        _formatMoney((a['total_outflow'] as num).toInt()),
        _formatMoney(net),
      ]);
    }

    final totals = [
      'إجمالي السيولة النقدية',
      '',
      '',
      '',
      '',
      _formatMoney(totalLiquidity),
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
              title: 'تقرير حركة الصناديق والبنوك والسيولة',
              organizationName: org?.name ?? 'المؤسسة',
              baseCurrency: widget.baseCurrencyCode,
              periodOrDate:
                  'حتى تاريخ ${DateTime.now().toIso8601String().split('T').first}',
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
    int totalLiquidity = 0;
    for (final a in _accounts) {
      totalLiquidity += (a['net_balance'] as num).toInt();
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('حركة الصندوق والبنوك',
              style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              onPressed: _exportPdf,
              tooltip: 'تصدير PDF',
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadData,
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.primary,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Total Liquidity Banner
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'إجمالي السيولة النقدية المتاحة',
                            style:
                                TextStyle(fontSize: 13, color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                _formatMoney(totalLiquidity),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.baseCurrencyCode,
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Cash & Bank Accounts List
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
                          'صناديق وحسابات البنوك (${_accounts.length})',
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkNavy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_accounts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Center(
                          child: Text(
                            'لم يتم تحديد أي حساب كصندوق أو بنك في دليل الحسابات بعد',
                            style: TextStyle(
                                fontSize: 13.5, color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else
                      ..._accounts.map((acc) {
                        final net = (acc['net_balance'] as num).toInt();
                        final inflow = (acc['total_inflow'] as num).toInt();
                        final outflow = (acc['total_outflow'] as num).toInt();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.account_balance_wallet_rounded,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          acc['account_name_ar'] as String,
                                          style: const TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.darkNavy,
                                          ),
                                        ),
                                        Text(
                                          '${acc['account_code']} • العملة: ${acc['currency_code'] ?? widget.baseCurrencyCode}',
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
                                        _formatMoney(net),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: net >= 0
                                              ? AppColors.success
                                              : AppColors.danger,
                                        ),
                                      ),
                                      Text(
                                        widget.baseCurrencyCode,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'إجمالي المقبوضات: ${_formatMoney(inflow)}',
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.success),
                                  ),
                                  Text(
                                    'إجمالي المدفوعات: ${_formatMoney(outflow)}',
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.danger),
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
}
