import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../invoices/data/invoice_repository.dart';
import '../../invoices/models/invoice_model.dart';
import '../../invoices/screens/invoice_details_screen.dart';
import '../../payments/screens/create_payment_screen.dart';
import '../data/party_repository.dart';
import '../models/party_model.dart';
import '../widgets/party_form_sheet.dart';

/// Screen displaying detailed profile, financial standing, outstanding invoices,
/// and ledger statement with running balance for a party.
class PartyDetailsScreen extends StatefulWidget {
  final PartyModel party;
  final String baseCurrencyCode;

  const PartyDetailsScreen({
    super.key,
    required this.party,
    required this.baseCurrencyCode,
  });

  @override
  State<PartyDetailsScreen> createState() => _PartyDetailsScreenState();
}

class _PartyDetailsScreenState extends State<PartyDetailsScreen> {
  final PartyRepository _partyRepo = PartyRepository();
  final InvoiceRepository _invoiceRepo = InvoiceRepository();

  late PartyModel _currentParty;
  List<Map<String, dynamic>> _transactions = [];
  List<InvoiceModel> _outstandingInvoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentParty = widget.party;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final updatedParty = await _partyRepo.getPartyById(
        _currentParty.id,
        _currentParty.organizationId,
      );
      final txList = await _partyRepo.getPartyTransactions(
        _currentParty.id,
        _currentParty.organizationId,
      );
      final outInvoices = await _invoiceRepo.getOutstandingInvoicesForParty(
        organizationId: _currentParty.organizationId,
        partyId: _currentParty.id,
      );

      if (mounted) {
        setState(() {
          if (updatedParty != null) _currentParty = updatedParty;
          _transactions = txList;
          _outstandingInvoices = outInvoices;
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

  void _openEditSheet() {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PartyFormSheet(
        organizationId: _currentParty.organizationId,
        baseCurrencyCode: widget.baseCurrencyCode,
        partyToEdit: _currentParty,
      ),
    ).then((updated) {
      if (updated == true) {
        _loadData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isCustomer = _currentParty.partyType == 'CUSTOMER';
    final balanceVal = _currentParty.balanceBase;
    final bool hasBalance = balanceVal != 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            _currentParty.nameAr,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'تعديل البيانات',
              onPressed: _openEditSheet,
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث',
              onPressed: _loadData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 1. Balance Summary Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isCustomer
                              ? [
                                  AppColors.darkNavy,
                                  const Color(0xFF1E3A8A),
                                ]
                              : [
                                  const Color(0xFF831843),
                                  const Color(0xFF9D174D),
                                ],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _currentParty.typeLabel,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _currentParty.isActive ? 'نشط' : 'معطل',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _currentParty.isActive
                                        ? Colors.white
                                        : Colors.white60,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isCustomer
                                ? (balanceVal >= 0
                                    ? 'المستحق على العميل (رصيد مدين):'
                                    : 'مستحق للعميل (رصيد دائن):')
                                : (balanceVal >= 0
                                    ? 'المستحق للمورد (رصيد دائن):'
                                    : 'مستحق على المورد (رصيد مدين):'),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                _formatMoney(balanceVal.abs()),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.baseCurrencyCode,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                !hasBalance
                                    ? 'خالص الحساب'
                                    : (isCustomer
                                        ? (balanceVal > 0
                                            ? 'مدين لنا'
                                            : 'دائن لنا')
                                        : (balanceVal > 0
                                            ? 'دائن له'
                                            : 'مدين له')),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: !hasBalance
                                      ? Colors.white70
                                      : (balanceVal > 0
                                          ? const Color(0xFF93C5FD)
                                          : const Color(0xFFFCA5A5)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Info details card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            icon: Icons.tag_rounded,
                            label: 'رمز الطرف',
                            value: _currentParty.code,
                            isMonospace: true,
                          ),
                          if (_currentParty.nameEn != null &&
                              _currentParty.nameEn!.isNotEmpty) ...[
                            const Divider(height: 16, color: AppColors.border),
                            _buildDetailRow(
                              icon: Icons.translate_rounded,
                              label: 'الاسم اللاتيني',
                              value: _currentParty.nameEn!,
                            ),
                          ],
                          const Divider(height: 16, color: AppColors.border),
                          _buildDetailRow(
                            icon: Icons.phone_outlined,
                            label: 'رقم الهاتف',
                            value: _currentParty.phone ?? 'غير محدد',
                            isLtr: true,
                          ),
                          const Divider(height: 16, color: AppColors.border),
                          _buildDetailRow(
                            icon: Icons.credit_card_rounded,
                            label: 'سقف الائتمان',
                            value: _currentParty.creditLimit > 0
                                ? '${_formatMoney(_currentParty.creditLimit)} ${widget.baseCurrencyCode}'
                                : 'غير محدد',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. Outstanding Invoices Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 18,
                              decoration: BoxDecoration(
                                color: AppColors.warning,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'الفواتير المستحقة (${_outstandingInvoices.length})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkNavy,
                              ),
                            ),
                          ],
                        ),
                        if (_outstandingInvoices.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CreatePaymentScreen(
                                    organizationId:
                                        _currentParty.organizationId,
                                    baseCurrencyCode: widget.baseCurrencyCode,
                                    initialType:
                                        isCustomer ? 'RECEIPT' : 'PAYMENT',
                                  ),
                                ),
                              ).then((_) => _loadData());
                            },
                            icon: const Icon(Icons.payment_rounded, size: 16),
                            label: Text(
                              isCustomer ? 'قبض دفعة' : 'صرف دفعة',
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_outstandingInvoices.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                color: AppColors.success, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'لا توجد فواتير غير مسددة لهذا الطرف حالياً',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._outstandingInvoices.map((inv) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 4),
                            leading: const Icon(Icons.receipt_outlined,
                                color: AppColors.warning, size: 22),
                            title: Text(
                              'فاتورة رقم ${inv.invoiceNumber}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            subtitle: Text(
                              'تاريخ: ${inv.issueDate} • استحقاق: ${inv.dueDate}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textSecondary),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'المتبقي: ${_formatMoney(inv.remainingAmount)} ${inv.currencyCode}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.danger,
                                  ),
                                ),
                                Text(
                                  'الإجمالي: ${_formatMoney(inv.totalAmount)}',
                                  style: const TextStyle(
                                      fontSize: 10.5,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => InvoiceDetailsScreen(
                                    invoiceId: inv.id,
                                    organizationId: inv.organizationId,
                                    baseCurrencyCode: widget.baseCurrencyCode,
                                  ),
                                ),
                              ).then((_) => _loadData());
                            },
                          ),
                        );
                      }),
                    const SizedBox(height: 20),

                    // 4. Transactions / Statement header
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
                        const Text(
                          'كشف الحساب والعمليات المرحّلة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkNavy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 5. Transactions list or empty state
                    if (_transactions.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 44,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'لا توجد عمليات مرحّلة مسجلة لهذا الطرف',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'ستظهر الفواتير والقيود اليومية والدفعات المرحّلة هنا تلقائياً',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...List.generate(_transactions.length, (index) {
                        final tx = _transactions[index];
                        final isDebit = (tx['base_debit'] as num? ?? 0) > 0;
                        final amount = isDebit
                            ? (tx['base_debit'] as num).toInt()
                            : (tx['base_credit'] as num).toInt();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: isDebit
                                      ? AppColors.primaryLight
                                      : const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isDebit
                                      ? Icons.arrow_outward_rounded
                                      : Icons.arrow_downward_rounded,
                                  color: isDebit
                                      ? AppColors.primary
                                      : AppColors.success,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx['description'] != null &&
                                              (tx['description'] as String)
                                                  .isNotEmpty
                                          ? tx['description']
                                          : 'قيد محاسبي رقم ${tx['entry_number']}',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.darkNavy,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${tx['entry_date']} • ${tx['entry_number']}',
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
                                    '${isDebit ? '+' : '-'}${_formatMoney(amount)}',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDebit
                                          ? AppColors.primary
                                          : AppColors.success,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isDebit ? 'مدين' : 'دائن',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
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

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isLtr = false,
    bool isMonospace = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Directionality(
          textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.darkNavy,
              fontFamily: isMonospace ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }
}
