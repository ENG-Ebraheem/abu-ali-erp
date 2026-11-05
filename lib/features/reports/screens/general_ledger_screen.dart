import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/models/account_model.dart';
import '../../organizations/data/organization_branding_service.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/reports_repository.dart';
import 'report_document_preview_screen.dart';

/// Screen presenting the General Ledger Account Statement (دفتر الأستاذ العام للحساب).
class GeneralLedgerScreen extends StatefulWidget {
  final String organizationId;
  final String baseCurrencyCode;
  final String? initialAccountId;

  const GeneralLedgerScreen({
    super.key,
    required this.organizationId,
    required this.baseCurrencyCode,
    this.initialAccountId,
  });

  @override
  State<GeneralLedgerScreen> createState() => _GeneralLedgerScreenState();
}

class _GeneralLedgerScreenState extends State<GeneralLedgerScreen> {
  final ReportsRepository _reportsRepo = ReportsRepository();
  final AccountRepository _accountRepo = AccountRepository();

  String? _selectedAccountId;
  late String _fromDate;
  late String _toDate;

  List<AccountModel> _accounts = [];
  Map<String, dynamic>? _ledgerData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedAccountId = widget.initialAccountId;
    final now = DateTime.now();
    _fromDate = '${now.year}-01-01';
    _toDate = now.toIso8601String().split('T').first;
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    try {
      final accs = await _accountRepo.getAccountsFlat(
        widget.organizationId,
        includeInactive: false,
      );
      if (mounted) {
        setState(() {
          _accounts = accs;
          if (_selectedAccountId == null && accs.isNotEmpty) {
            _selectedAccountId = accs.first.id;
          }
        });
        if (_selectedAccountId != null) {
          await _loadLedger();
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLedger() async {
    if (_selectedAccountId == null) return;
    setState(() => _isLoading = true);
    try {
      final res = await _reportsRepo.getAccountLedger(
        widget.organizationId,
        _selectedAccountId!,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      if (mounted) {
        setState(() {
          _ledgerData = res;
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
    if (_ledgerData == null) return;
    final selectedAcc =
        _accounts.where((a) => a.id == _selectedAccountId).firstOrNull;
    final accName = selectedAcc != null
        ? '${selectedAcc.accountCode} - ${selectedAcc.accountNameAr}'
        : 'الحساب';

    final lines = (_ledgerData!['lines'] as List<dynamic>?) ?? [];
    final headers = [
      'التاريخ',
      'رقم القيد',
      'النوع',
      'الطرف',
      'البيان',
      'مدين (${widget.baseCurrencyCode})',
      'دائن (${widget.baseCurrencyCode})',
      'الرصيد (${widget.baseCurrencyCode})',
    ];

    final rows = <List<String>>[];
    final opening = (_ledgerData!['opening_balance'] as num?)?.toInt() ?? 0;
    rows.add([
      _fromDate,
      '-',
      'افتتاحي',
      '-',
      'رصيد ما قبل الفترة',
      opening > 0 ? _formatMoney(opening) : '0.00',
      opening < 0 ? _formatMoney(opening.abs()) : '0.00',
      _formatMoney(opening),
    ]);

    for (final l in lines) {
      final map = l as Map<String, dynamic>;
      rows.add([
        map['entry_date']?.toString() ?? '',
        map['entry_number']?.toString() ?? '',
        map['entry_type']?.toString() ?? '',
        map['party_name_ar']?.toString() ?? '-',
        map['description']?.toString() ?? '',
        _formatMoney((map['base_debit'] as num?)?.toInt() ?? 0),
        _formatMoney((map['base_credit'] as num?)?.toInt() ?? 0),
        _formatMoney((map['running_balance'] as num?)?.toInt() ?? 0),
      ]);
    }

    final pDebit = (_ledgerData!['period_debit'] as num?)?.toInt() ?? 0;
    final pCredit = (_ledgerData!['period_credit'] as num?)?.toInt() ?? 0;
    final closing = (_ledgerData!['closing_balance'] as num?)?.toInt() ?? 0;

    final totals = [
      'الإجمالي العام',
      '',
      '',
      '',
      '',
      _formatMoney(pDebit),
      _formatMoney(pCredit),
      _formatMoney(closing),
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
              title: 'دفتر الأستاذ العام: $accName',
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
    final selectedAcc =
        _accounts.where((a) => a.id == _selectedAccountId).firstOrNull;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('دفتر الأستاذ العام',
              style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              onPressed: _exportPdf,
              tooltip: 'تصدير PDF',
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadLedger,
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: Column(
          children: [
            // 1. Selector Bar
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.surface,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedAccountId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'الحساب المحاسبي',
                      prefixIcon: Icon(Icons.account_tree_outlined, size: 20),
                    ),
                    items: _accounts.map((a) {
                      return DropdownMenuItem(
                        value: a.id,
                        child: Text('${a.accountCode} - ${a.accountNameAr}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedAccountId = val);
                      _loadLedger();
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الفترة: من $_fromDate إلى $_toDate',
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary),
                      ),
                      TextButton.icon(
                        icon:
                            const Icon(Icons.calendar_today_rounded, size: 14),
                        label: const Text('تغيير الفترة'),
                        onPressed: () async {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                            initialDateRange: DateTimeRange(
                              start: DateTime.tryParse(_fromDate) ??
                                  DateTime.now(),
                              end: DateTime.tryParse(_toDate) ?? DateTime.now(),
                            ),
                          );
                          if (range != null) {
                            setState(() {
                              _fromDate = range.start
                                  .toIso8601String()
                                  .split('T')
                                  .first;
                              _toDate =
                                  range.end.toIso8601String().split('T').first;
                            });
                            _loadLedger();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // 2. Ledger Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary))
                  : _ledgerData == null
                      ? const Center(
                          child: Text('اختر حساباً لعرض حركة دفتر الأستاذ'))
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Opening Balance Card
                            _buildBalanceCard(
                              'الرصيد الافتتاحي (قبل $_fromDate):',
                              _ledgerData!['opening_balance'] as int,
                              isOpening: true,
                            ),
                            const SizedBox(height: 14),

                            // Lines List
                            ...((_ledgerData!['lines'] as List)
                                    .cast<Map<String, dynamic>>())
                                .map((line) {
                              final isDebit = (line['base_debit'] as int) > 0;
                              final amount = isDebit
                                  ? line['base_debit'] as int
                                  : line['base_credit'] as int;
                              final runningBal = line['running_balance'] as int;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${line['entry_date']} • قيد رقم ${line['entry_number']}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                              fontFamily: 'monospace'),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDebit
                                                ? const Color(0xFFEFF6FF)
                                                : const Color(0xFFECFDF5),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            isDebit ? 'مدين' : 'دائن',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: isDebit
                                                  ? AppColors.primary
                                                  : AppColors.success,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            line['description'] != null &&
                                                    (line['description']
                                                            as String)
                                                        .isNotEmpty
                                                ? line['description'] as String
                                                : 'حركة محاسبية',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        Text(
                                          '${isDebit ? '+' : '-'}${_formatMoney(amount)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isDebit
                                                ? AppColors.primary
                                                : AppColors.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    const Divider(height: 1),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          'الرصيد التراكمي: ${_formatMoney(runningBal.abs())} ${selectedAcc?.accountNature == "DEBIT" ? (runningBal >= 0 ? "مدين" : "دائن") : (runningBal <= 0 ? "دائن" : "مدين")}',
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
                            const SizedBox(height: 14),

                            // Closing Balance Card
                            _buildBalanceCard(
                              'الرصيد الختامي (حتى $_toDate):',
                              _ledgerData!['closing_balance'] as int,
                              isOpening: false,
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(String title, int balance,
      {required bool isOpening}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isOpening ? AppColors.surface : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isOpening
                ? AppColors.border
                : AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isOpening ? AppColors.darkNavy : AppColors.primary,
            ),
          ),
          Text(
            '${_formatMoney(balance.abs())} ${widget.baseCurrencyCode}',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: isOpening ? AppColors.darkNavy : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
