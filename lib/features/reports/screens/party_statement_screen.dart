import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../organizations/data/organization_branding_service.dart';
import '../../organizations/data/organization_repository.dart';
import '../../parties/data/party_repository.dart';
import '../../parties/models/party_model.dart';
import '../data/reports_repository.dart';
import 'report_document_preview_screen.dart';

/// Screen presenting Customer or Supplier Statement of Account (كشف حساب عميل أو مورد).
class PartyStatementScreen extends StatefulWidget {
  final String organizationId;
  final String baseCurrencyCode;
  final bool
      isCustomer; // true = Customer Statement, false = Supplier Statement
  final String? initialPartyId;

  const PartyStatementScreen({
    super.key,
    required this.organizationId,
    required this.baseCurrencyCode,
    this.isCustomer = true,
    this.initialPartyId,
  });

  @override
  State<PartyStatementScreen> createState() => _PartyStatementScreenState();
}

class _PartyStatementScreenState extends State<PartyStatementScreen> {
  final ReportsRepository _reportsRepo = ReportsRepository();
  final PartyRepository _partyRepo = PartyRepository();

  List<PartyModel> _parties = [];
  PartyModel? _selectedParty;
  String _fromDate = DateTime.now()
      .subtract(const Duration(days: 90))
      .toIso8601String()
      .split('T')
      .first;
  String _toDate = DateTime.now().toIso8601String().split('T').first;

  Map<String, dynamic>? _reportData;
  bool _isLoadingParties = true;
  bool _isLoadingReport = false;

  @override
  void initState() {
    super.initState();
    _loadParties();
  }

  Future<void> _loadParties() async {
    setState(() => _isLoadingParties = true);
    try {
      final parties = await _partyRepo.getParties(
        organizationId: widget.organizationId,
        partyType: widget.isCustomer ? 'CUSTOMER' : 'SUPPLIER',
      );
      if (mounted) {
        setState(() {
          _parties = parties;
          if (widget.initialPartyId != null) {
            _selectedParty = parties.firstWhere(
              (p) => p.id == widget.initialPartyId,
              orElse: () => parties.isNotEmpty
                  ? parties.first
                  : PartyModel(
                      id: 'none',
                      organizationId: widget.organizationId,
                      code: '0',
                      nameAr: 'لا يوجد',
                      partyType: widget.isCustomer ? 'CUSTOMER' : 'SUPPLIER',
                      createdAt: DateTime.now().toIso8601String(),
                      updatedAt: DateTime.now().toIso8601String(),
                    ),
            );
          } else if (parties.isNotEmpty) {
            _selectedParty = parties.first;
          }
          _isLoadingParties = false;
        });

        if (_selectedParty != null && _selectedParty!.id != 'none') {
          _loadReport();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingParties = false);
    }
  }

  Future<void> _loadReport() async {
    if (_selectedParty == null || _selectedParty!.id == 'none') return;
    setState(() => _isLoadingReport = true);
    try {
      final res = widget.isCustomer
          ? await _reportsRepo.getCustomerStatement(
              widget.organizationId,
              _selectedParty!.id,
              fromDate: _fromDate,
              toDate: _toDate,
            )
          : await _reportsRepo.getSupplierStatement(
              widget.organizationId,
              _selectedParty!.id,
              fromDate: _fromDate,
              toDate: _toDate,
            );
      if (mounted) {
        setState(() {
          _reportData = res;
          _isLoadingReport = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingReport = false);
    }
  }

  String _formatMoney(int amountMinor) {
    final double val = amountMinor / 100.0;
    return val.toStringAsFixed(2);
  }

  Future<void> _exportReport() async {
    if (_reportData == null || _selectedParty == null) return;

    final title = widget.isCustomer
        ? 'كشف حساب عميل: ${_selectedParty!.nameAr}'
        : 'كشف حساب مورد: ${_selectedParty!.nameAr}';
    final headers = [
      'التاريخ',
      'رقم السند',
      'النوع',
      'البيان',
      'مدين (${widget.baseCurrencyCode})',
      'دائن (${widget.baseCurrencyCode})',
      'الرصيد (${widget.baseCurrencyCode})',
    ];

    final lines = (_reportData!['lines'] as List<dynamic>?) ?? [];
    final rows = <List<String>>[];

    // Add opening balance row
    final opening = (_reportData!['opening_balance'] as num?)?.toInt() ?? 0;
    rows.add([
      _fromDate,
      '-',
      'افتتاحي',
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
        map['description']?.toString() ?? '',
        _formatMoney((map['base_debit'] as num?)?.toInt() ?? 0),
        _formatMoney((map['base_credit'] as num?)?.toInt() ?? 0),
        _formatMoney((map['running_balance'] as num?)?.toInt() ?? 0),
      ]);
    }

    final pDebit = (_reportData!['period_debit'] as num?)?.toInt() ?? 0;
    final pCredit = (_reportData!['period_credit'] as num?)?.toInt() ?? 0;
    final closing = (_reportData!['closing_balance'] as num?)?.toInt() ?? 0;

    final totals = [
      'الإجمالي',
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
              title: title,
              organizationName: org?.name ?? 'المؤسسة',
              baseCurrency: widget.baseCurrencyCode,
              periodOrDate: 'من $_fromDate إلى $_toDate',
              headers: headers,
              rows: rows,
              totals: totals,
              subtitle: 'رمز الطرف: ${_selectedParty!.code}',
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
    final title = widget.isCustomer ? 'كشف حساب عميل' : 'كشف حساب مورد';

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
        body: _isLoadingParties
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : _parties.isEmpty
                ? Center(
                    child: Text(
                      widget.isCustomer
                          ? 'لا يوجد عملاء مسجلين حالياً'
                          : 'لا يوجد موردين مسجلين حالياً',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadReport,
                    color: AppColors.primary,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Party Selection Card
                        _buildPartySelector(),
                        const SizedBox(height: 12),

                        // Date Filter Card
                        _buildDateFilter(),
                        const SizedBox(height: 16),

                        // Balance Summary Card
                        if (_isLoadingReport)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(
                                  color: AppColors.primary),
                            ),
                          )
                        else if (_reportData != null) ...[
                          _buildSummaryCard(),
                          const SizedBox(height: 18),
                          _buildTransactionsList(),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildPartySelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            widget.isCustomer
                ? Icons.person_rounded
                : Icons.local_shipping_rounded,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<PartyModel>(
                isExpanded: true,
                value: _selectedParty,
                hint: Text(widget.isCustomer ? 'اختر العميل' : 'اختر المورد'),
                items: _parties.map((p) {
                  return DropdownMenuItem<PartyModel>(
                    value: p,
                    child: Text('${p.nameAr} (${p.code})'),
                  );
                }).toList(),
                onChanged: (p) {
                  setState(() => _selectedParty = p);
                  _loadReport();
                },
              ),
            ),
          ),
        ],
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
    final opening = (_reportData!['opening_balance'] as num?)?.toInt() ?? 0;
    final periodDebit = (_reportData!['period_debit'] as num?)?.toInt() ?? 0;
    final periodCredit = (_reportData!['period_credit'] as num?)?.toInt() ?? 0;
    final closing = (_reportData!['closing_balance'] as num?)?.toInt() ?? 0;

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
                widget.isCustomer
                    ? 'الرصيد المستحق على العميل'
                    : 'الرصيد المستحق للمورد',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: closing >= 0
                      ? AppColors.primaryLight
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_formatMoney(closing.abs())} ${widget.baseCurrencyCode}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: closing >= 0 ? AppColors.primary : AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              _buildMiniMetric('رصيد البداية', opening),
              _buildMiniMetric('حركات مدينة (+)', periodDebit,
                  color: AppColors.primary),
              _buildMiniMetric('حركات دائنة (-)', periodCredit,
                  color: const Color(0xFF059669)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, int amountMinor, {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            _formatMoney(amountMinor),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    final lines = (_reportData!['lines'] as List<dynamic>?) ?? [];

    if (lines.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: const Text(
          'لا توجد حركات مسجلة لهذا الطرف خلال الفترة المحددة',
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
              'حركات الحساب (${lines.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...lines.map((l) {
          final map = l as Map<String, dynamic>;
          final debit = (map['base_debit'] as num?)?.toInt() ?? 0;
          final credit = (map['base_credit'] as num?)?.toInt() ?? 0;
          final running = (map['running_balance'] as num?)?.toInt() ?? 0;

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
                        '${map['entry_number']} • ${map['entry_type']}',
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
                              color: AppColors.primary),
                        ),
                      if (credit > 0)
                        Text(
                          'دائن: ${_formatMoney(credit)} ${widget.baseCurrencyCode}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF059669)),
                        ),
                      Text(
                        'الرصيد: ${_formatMoney(running)} ${widget.baseCurrencyCode}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
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
