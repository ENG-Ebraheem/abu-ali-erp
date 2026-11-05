import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../organizations/data/organization_repository.dart';
import '../../organizations/models/organization_model.dart';
import '../data/exchange_rate_repository.dart';
import '../models/exchange_rate_model.dart';
import '../widgets/exchange_rate_form_dialog.dart';

/// Screen for managing foreign currency exchange rates and instant currency conversion calculator.
class ExchangeRatesScreen extends StatefulWidget {
  final String? organizationId;
  final VoidCallback? onBackToDashboard;

  const ExchangeRatesScreen({
    super.key,
    this.organizationId,
    this.onBackToDashboard,
  });

  @override
  State<ExchangeRatesScreen> createState() => _ExchangeRatesScreenState();
}

class _ExchangeRatesScreenState extends State<ExchangeRatesScreen> {
  final ExchangeRateRepository _repo = ExchangeRateRepository();
  final OrganizationRepository _orgRepo = OrganizationRepository();

  Organization? _activeOrg;
  List<ExchangeRateModel> _rates = [];
  bool _isLoading = true;

  // Converter state
  final TextEditingController _calcAmountController =
      TextEditingController(text: '100');
  String _calcFromCurrency = 'USD';
  String _calcToCurrency = 'YER';
  double _calcResult = 0.0;
  double _calcAppliedRate = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _calcAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      Organization? org;
      if (widget.organizationId != null) {
        org = await _orgRepo.getOrganizationById(widget.organizationId!);
      } else {
        final activeId = await _orgRepo.getActiveOrganizationId();
        if (activeId != null) {
          org = await _orgRepo.getOrganizationById(activeId);
        } else {
          final list =
              await _orgRepo.getAllOrganizations(includeArchived: false);
          if (list.isNotEmpty) org = list.first;
        }
      }

      if (org != null) {
        final ratesList = await _repo.getExchangeRates(org.id);
        if (mounted) {
          setState(() {
            _activeOrg = org;
            _rates = ratesList;
            _isLoading = false;
          });
          _recalculate();
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _recalculate() async {
    if (_activeOrg == null) return;
    final double amount =
        double.tryParse(_calcAmountController.text.trim()) ?? 0.0;
    final rateModel = await _repo.getLatestRate(
      organizationId: _activeOrg!.id,
      fromCurrency: _calcFromCurrency,
      toCurrency: _calcToCurrency,
    );

    if (mounted) {
      setState(() {
        if (rateModel != null) {
          _calcAppliedRate = rateModel.rateAsDouble;
          _calcResult = amount * _calcAppliedRate;
        } else {
          _calcAppliedRate = 0.0;
          _calcResult = 0.0;
        }
      });
    }
  }

  void _openAddDialog() {
    if (_activeOrg == null) return;

    showDialog<bool>(
      context: context,
      builder: (_) => ExchangeRateFormDialog(
        organizationId: _activeOrg!.id,
        baseCurrencyCode: _activeOrg!.baseCurrencyCode,
      ),
    ).then((added) {
      if (added == true) {
        _loadData();
      }
    });
  }

  Future<void> _deleteRate(ExchangeRateModel rate) async {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد حذف سعر الصرف'),
        content: Text(
          'هل تريد حذف سعر الصرف ${rate.fromCurrencyCode} / ${rate.toCurrencyCode} بتاريخ ${rate.rateDate}؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await _repo.deleteRate(rate.id, rate.organizationId);
                await _loadData();
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف سعر الصرف بنجاح'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('خطأ: ${e.toString()}'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: widget.onBackToDashboard != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: widget.onBackToDashboard,
                )
              : null,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'أسعار صرف العملات',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkNavy,
                ),
              ),
              if (_activeOrg != null)
                Text(
                  '${_activeOrg!.name} • الأساس: ${_activeOrg!.baseCurrencyCode}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadData,
              tooltip: 'تحديث',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: null,
          onPressed: _openAddDialog,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'تسجيل سعر صرف',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.primary,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 1. Converter Calculator Card
                    _buildConverterCard(),
                    const SizedBox(height: 20),

                    // 2. Historical / Current Rates List Header
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
                          'سجل أسعار الصرف المسجلة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkNavy,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_rates.length} تسعيرة',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 3. Rates List or Empty State
                    if (_rates.isEmpty)
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
                              Icons.currency_exchange_rounded,
                              size: 40,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'لا توجد أسعار صرف مسجلة لهذه المؤسسة',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkNavy,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'سجل أسعار صرف العملات الأجنبية (USD, SAR) مقابل العملة المحلية لاستخدامها في القيود والفواتير وإعادة التقييم.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._rates.map((rate) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.candlestick_chart_rounded,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '1 ${rate.fromCurrencyCode}',
                                          style: const TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.darkNavy,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${rate.formattedRate} ${rate.toCurrencyCode}',
                                          style: const TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'تاريخ التطبيق: ${rate.rateDate}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.danger,
                                  size: 20,
                                ),
                                onPressed: () => _deleteRate(rate),
                                tooltip: 'حذف',
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

  Widget _buildConverterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calculate_outlined,
                  color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'حاسبة تحويل العملات اللحظية',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Amount field
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _calcAmountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  onChanged: (_) => _recalculate(),
                  decoration: const InputDecoration(
                    labelText: 'المبلغ',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // From currency
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: _calcFromCurrency,
                  decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                    DropdownMenuItem(value: 'SAR', child: Text('SAR')),
                    DropdownMenuItem(value: 'YER', child: Text('YER')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _calcFromCurrency = val);
                      _recalculate();
                    }
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 16, color: AppColors.textSecondary),
              ),
              // To currency
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: _calcToCurrency,
                  decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'YER', child: Text('YER')),
                    DropdownMenuItem(value: 'SAR', child: Text('SAR')),
                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _calcToCurrency = val);
                      _recalculate();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Calculation Result Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _calcAppliedRate > 0
                      ? 'الناتج المقدر: ${_calcResult.toStringAsFixed(2)} $_calcToCurrency'
                      : 'لا يوجد سعر صرف مسجل لهذا الزوج',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: _calcAppliedRate > 0
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
                if (_calcAppliedRate > 0)
                  Text(
                    'السعر: ${_calcAppliedRate.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
