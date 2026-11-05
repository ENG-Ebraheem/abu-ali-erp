import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/models/account_model.dart';
import '../../organizations/data/organization_branding_service.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/reports_repository.dart';
import 'report_document_preview_screen.dart';

/// Screen presenting Account Activity Report (تقرير حركة الحساب / كشف العمليات).
class AccountActivityScreen extends StatefulWidget {
  final String organizationId;
  final String baseCurrencyCode;
  final String? initialAccountId;

  const AccountActivityScreen({
    super.key,
    required this.organizationId,
    required this.baseCurrencyCode,
    this.initialAccountId,
  });

  @override
  State<AccountActivityScreen> createState() => _AccountActivityScreenState();
}

class _AccountActivityScreenState extends State<AccountActivityScreen> {
  final ReportsRepository _reportsRepo = ReportsRepository();
  final AccountRepository _accountRepo = AccountRepository();

  List<AccountModel> _accounts = [];
  AccountModel? _selectedAccount;
  String? _selectedEntryType;
  String _fromDate = DateTime.now()
      .subtract(const Duration(days: 30))
      .toIso8601String()
      .split('T')
      .first;
  String _toDate = DateTime.now().toIso8601String().split('T').first;

  Map<String, dynamic>? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    try {
      final list = await _accountRepo.getAccountsFlat(widget.organizationId);
      if (mounted) {
        setState(() {
          _accounts = list;
          if (widget.initialAccountId != null) {
            _selectedAccount = list.firstWhere(
              (a) => a.id == widget.initialAccountId,
              orElse: () => list.isNotEmpty
                  ? list.first
                  : AccountModel(
                      id: 'none',
                      organizationId: widget.organizationId,
                      accountCode: '0',
                      accountNameAr: 'جميع الحسابات',
                      accountType: 'ASSET',
                      accountNature: 'DEBIT',
                      createdAt: DateTime.now(),
                    ),
            );
          }
        });
        await _loadReport();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final res = await _reportsRepo.getAccountActivity(
        widget.organizationId,
        accountId: _selectedAccount?.id,
        entryType: _selectedEntryType,
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

  Future<void> _exportReport() async {
    if (_data == null) return;

    final title = _selectedAccount != null
        ? 'تقرير حركة الحساب: ${_selectedAccount!.accountNameAr}'
        : 'تقرير حركة الحسابات العامة والعمليات';

    final headers = [
      'التاريخ',
      'رقم السند',
      'النوع',
      'الحساب',
      'الطرف',
      'البيان',
      'مدين (${widget.baseCurrencyCode})',
      'دائن (${widget.baseCurrencyCode})',
    ];

    final rowsList = (_data!['rows'] as List<dynamic>?) ?? [];
    final rows = <List<String>>[];

    for (final r in rowsList) {
      final map = r as Map<String, dynamic>;
      rows.add([
        map['entry_date']?.toString() ?? '',
        map['entry_number']?.toString() ?? '',
        map['entry_type']?.toString() ?? '',
        '${map['account_code']} - ${map['account_name_ar']}',
        map['party_name_ar']?.toString() ?? '-',
        map['description']?.toString() ?? '',
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
          title: const Text('حركة الحساب والعمليات',
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
                    // Account Selector
                    _buildAccountSelector(),
                    const SizedBox(height: 10),

                    // Date & Type Filter
                    _buildFilterCard(),
                    const SizedBox(height: 16),

                    if (_data != null) ...[
                      // Summary Card
                      _buildSummaryCard(),
                      const SizedBox(height: 18),

                      // Transactions List
                      _buildTransactionsList(),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAccountSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_tree_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AccountModel?>(
                isExpanded: true,
                value: _selectedAccount,
                hint: const Text('جميع الحسابات (شامل)'),
                items: [
                  const DropdownMenuItem<AccountModel?>(
                    value: null,
                    child: Text('جميع الحسابات (شامل)'),
                  ),
                  ..._accounts.map((a) {
                    return DropdownMenuItem<AccountModel?>(
                      value: a,
                      child: Text('${a.accountCode} - ${a.accountNameAr}'),
                    );
                  }),
                ],
                onChanged: (a) {
                  setState(() => _selectedAccount = a);
                  _loadReport();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
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
                      setState(() =>
                          _fromDate = d.toIso8601String().split('T').first);
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
          const Divider(height: 16),
          Row(
            children: [
              const Text('نوع السند:',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    isDense: true,
                    value: _selectedEntryType,
                    hint: const Text('جميع الأنواع'),
                    items: const [
                      DropdownMenuItem(
                          value: null, child: Text('جميع الأنواع')),
                      DropdownMenuItem(
                          value: 'GENERAL', child: Text('قيد يومية عام')),
                      DropdownMenuItem(
                          value: 'OPENING', child: Text('قيد افتتاحي')),
                      DropdownMenuItem(
                          value: 'SALES', child: Text('فاتورة مبيعات')),
                      DropdownMenuItem(
                          value: 'PURCHASE', child: Text('فاتورة مشتريات')),
                      DropdownMenuItem(
                          value: 'RECEIPT', child: Text('سند قبض')),
                      DropdownMenuItem(
                          value: 'PAYMENT', child: Text('سند صرف')),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedEntryType = val);
                      _loadReport();
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final debit = (_data!['total_debit'] as num?)?.toInt() ?? 0;
    final credit = (_data!['total_credit'] as num?)?.toInt() ?? 0;
    final net = (_data!['net_balance'] as num?)?.toInt() ?? 0;
    final count = (_data!['count'] as num?)?.toInt() ?? 0;

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
                'إجمالي العمليات المطابقة ($count حركة)',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                'الصافي: ${_formatMoney(net)} ${widget.baseCurrencyCode}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.primary),
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
                    const Text('إجمالي المدين',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      _formatMoney(debit),
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
                    const Text('إجمالي الدائن',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      _formatMoney(credit),
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

  Widget _buildTransactionsList() {
    final rows = (_data!['rows'] as List<dynamic>?) ?? [];

    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: const Text(
          'لا توجد عمليات مسجلة تطابق الشروط المحددة',
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
              'تفاصيل الحركات (${rows.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...rows.map((r) {
          final map = r as Map<String, dynamic>;
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
                      Text(
                        map['entry_date']?.toString() ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${map['entry_number']} • نوع السند: ${map['entry_type']}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  if (map['party_name_ar'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'الطرف: ${map['party_name_ar']}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.primary),
                    ),
                  ],
                  if (map['description'] != null &&
                      map['description'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      map['description'].toString(),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ],
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
