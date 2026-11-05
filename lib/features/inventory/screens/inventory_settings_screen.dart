import 'package:flutter/material.dart';
import 'package:abu_ali/core/constants/app_colors.dart';
import 'package:abu_ali/features/accounts/data/account_repository.dart';
import 'package:abu_ali/features/accounts/models/account_model.dart';
import '../data/inventory_settings_repository.dart';
import '../models/inventory_settings_model.dart';

/// Screen for configuring organization-specific inventory settings and accounting accounts.
class InventorySettingsScreen extends StatefulWidget {
  final String organizationId;

  const InventorySettingsScreen({
    super.key,
    required this.organizationId,
  });

  @override
  State<InventorySettingsScreen> createState() =>
      _InventorySettingsScreenState();
}

class _InventorySettingsScreenState extends State<InventorySettingsScreen> {
  final InventorySettingsRepository _settingsRepo =
      InventorySettingsRepository();
  final AccountRepository _accountRepo = AccountRepository();

  InventorySettingsModel? _settings;
  List<AccountModel> _allAccounts = [];
  bool _isLoading = true;
  bool _isSaving = false;

  String? _assetAccountId;
  String? _adjAccountId;
  String? _cogsAccountId;
  String? _openingEquityAccountId;
  String _valuationMethod = 'WEIGHTED_AVERAGE';
  bool _isInventoryEnabled = true;
  bool _allowNegativeStock = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final s = await _settingsRepo.getSettings(widget.organizationId);
      final accs = await _accountRepo.getAccountsFlat(widget.organizationId);

      if (mounted) {
        setState(() {
          _settings = s;
          _allAccounts = accs;
          _assetAccountId = s.inventoryAssetAccountId;
          _adjAccountId = s.inventoryAdjustmentAccountId;
          _cogsAccountId = s.cogsAccountId;
          _openingEquityAccountId = s.openingEquityAccountId;
          _valuationMethod = s.defaultValuationMethod;
          _isInventoryEnabled = s.isInventoryEnabled;
          _allowNegativeStock = s.allowNegativeStock;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل إعدادات المخزون: $e')),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final updated = InventorySettingsModel(
        id: _settings?.id ?? 'inv_set_${widget.organizationId}',
        organizationId: widget.organizationId,
        isInventoryEnabled: _isInventoryEnabled,
        inventoryAssetAccountId: _assetAccountId,
        inventoryAdjustmentAccountId: _adjAccountId,
        cogsAccountId: _cogsAccountId,
        openingEquityAccountId: _openingEquityAccountId,
        defaultValuationMethod: _valuationMethod,
        allowNegativeStock: _allowNegativeStock,
        updatedAt: now,
      );

      await _settingsRepo.saveSettings(updated);
      await _loadSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ إعدادات المخزون والربط المحاسبي بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحفظ: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final assetAccounts =
        _allAccounts.where((a) => a.accountType == 'ASSET').toList();
    final expenseAccounts =
        _allAccounts.where((a) => a.accountType == 'EXPENSE').toList();
    final equityAccounts =
        _allAccounts.where((a) => a.accountType == 'EQUITY').toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('إعدادات المخزون والربط المحاسبي'),
          actions: [
            TextButton(
              onPressed: _isSaving ? null : _saveSettings,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('حفظ', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Activation Toggle
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: SwitchListTile(
                  title: const Text(
                    'تفعيل نظام المخزون لهذه المؤسسة',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'المؤسسات الخدمية يمكنها تعطيل المخزون دون التأثير على حساباتها',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _isInventoryEnabled,
                  onChanged: (v) => setState(() => _isInventoryEnabled = v),
                ),
              ),
              const SizedBox(height: 18),

              // Accounting Links
              _buildSectionHeader('الربط مع دليل الحسابات (شجرة الحسابات)'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    DropdownButtonFormField<String?>(
                      value: _assetAccountId,
                      decoration: const InputDecoration(
                        labelText: 'حساب المخزون السلعي (أصول متداولة) *',
                        prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                      ),
                      items: assetAccounts
                          .map((a) => DropdownMenuItem(
                                value: a.id,
                                child: Text('${a.accountNameAr} (${a.accountCode})'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _assetAccountId = v),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String?>(
                      value: _adjAccountId,
                      decoration: const InputDecoration(
                        labelText: 'حساب فروقات وعجز الجرد المخزني *',
                        prefixIcon: Icon(Icons.tune_rounded),
                      ),
                      items: expenseAccounts
                          .map((a) => DropdownMenuItem(
                                value: a.id,
                                child: Text('${a.accountNameAr} (${a.accountCode})'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _adjAccountId = v),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String?>(
                      value: _cogsAccountId,
                      decoration: const InputDecoration(
                        labelText: 'حساب تكلفة البضاعة المباعة (COGS) *',
                        prefixIcon: Icon(Icons.shopping_cart_outlined),
                      ),
                      items: expenseAccounts
                          .map((a) => DropdownMenuItem(
                                value: a.id,
                                child: Text('${a.accountNameAr} (${a.accountCode})'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _cogsAccountId = v),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String?>(
                      value: _openingEquityAccountId,
                      decoration: const InputDecoration(
                        labelText: 'حساب الأرصدة الافتتاحية المقابل (حقوق ملكية)',
                        prefixIcon: Icon(Icons.flag_rounded),
                      ),
                      items: equityAccounts
                          .map((a) => DropdownMenuItem(
                                value: a.id,
                                child: Text('${a.accountNameAr} (${a.accountCode})'),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _openingEquityAccountId = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              // Valuation & Policies
              _buildSectionHeader('سياسة التقييم والرصيد السالب'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _valuationMethod,
                      decoration: const InputDecoration(
                        labelText: 'طريقة التقييم الافتراضية',
                        prefixIcon: Icon(Icons.calculate_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'WEIGHTED_AVERAGE',
                          child: Text('المتوسط المرجح (Weighted Average)'),
                        ),
                        DropdownMenuItem(
                          value: 'FIFO',
                          child: Text('الوارد أولاً يصرف أولاً (FIFO)'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _valuationMethod = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('السماح بالرصيد المخزني السالب'),
                      subtitle: const Text(
                        'عند التعطيل، يمنع النظام صرف أي بضاعة تتجاوز الرصيد المتوفر في المستودع',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _allowNegativeStock,
                      onChanged: (v) => setState(() => _allowNegativeStock = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'حفظ إعدادات المخزون',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: AppColors.darkNavy,
      ),
    );
  }
}
