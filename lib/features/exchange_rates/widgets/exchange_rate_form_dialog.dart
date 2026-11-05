import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/database_constants.dart';
import '../data/exchange_rate_repository.dart';
import '../models/exchange_rate_model.dart';

/// Dialog to add or update an exchange rate.
class ExchangeRateFormDialog extends StatefulWidget {
  final String organizationId;
  final String baseCurrencyCode;

  const ExchangeRateFormDialog({
    super.key,
    required this.organizationId,
    required this.baseCurrencyCode,
  });

  @override
  State<ExchangeRateFormDialog> createState() => _ExchangeRateFormDialogState();
}

class _ExchangeRateFormDialogState extends State<ExchangeRateFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _repo = ExchangeRateRepository();

  late String _fromCurrency;
  late String _toCurrency;
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fromCurrency = widget.baseCurrencyCode == 'USD' ? 'YER' : 'USD';
    _toCurrency = widget.baseCurrencyCode;
    _dateController.text = DateTime.now().toIso8601String().split('T').first;
  }

  @override
  void dispose() {
    _rateController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fromCurrency == _toCurrency) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن تحديد نفس العملة للتحويل'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final double? rateVal = double.tryParse(_rateController.text.trim());
    if (rateVal == null || rateVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال سعر صرف صحيح أكبر من الصفر'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final int scaled =
          (rateVal * DatabaseConstants.exchangeRateScale).round();
      final rateModel = ExchangeRateModel(
        id: 'fx_${DateTime.now().millisecondsSinceEpoch}',
        organizationId: widget.organizationId,
        fromCurrencyCode: _fromCurrency,
        toCurrencyCode: _toCurrency,
        rateScaled: scaled,
        rateDate: _dateController.text.trim(),
        createdAt: DateTime.now().toIso8601String(),
      );

      await _repo.saveRate(rateModel);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حفظ سعر الصرف: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.currency_exchange_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'تسجيل سعر صرف',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 340,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Currency pair
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _fromCurrency,
                        decoration: const InputDecoration(labelText: 'من عملة'),
                        items: const [
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                          DropdownMenuItem(value: 'SAR', child: Text('SAR')),
                          DropdownMenuItem(value: 'YER', child: Text('YER')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _fromCurrency = val);
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward_rounded,
                          color: AppColors.textSecondary),
                    ),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _toCurrency,
                        decoration:
                            const InputDecoration(labelText: 'إلى عملة'),
                        items: const [
                          DropdownMenuItem(value: 'YER', child: Text('YER')),
                          DropdownMenuItem(value: 'SAR', child: Text('SAR')),
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _toCurrency = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Rate Input
                TextFormField(
                  controller: _rateController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'سعر الصرف *',
                    hintText: 'مثال: 535.50',
                    prefixIcon: const Icon(Icons.show_chart_rounded, size: 20),
                    helperText: '1 $_fromCurrency = [السعر] $_toCurrency',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'مطلوب' : null,
                ),
                const SizedBox(height: 14),

                // Date Picker Input
                TextFormField(
                  controller: _dateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'تاريخ الصرف',
                    prefixIcon: Icon(Icons.calendar_today_rounded, size: 20),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      _dateController.text =
                          picked.toIso8601String().split('T').first;
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
