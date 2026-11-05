import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/models/account_model.dart';
import '../data/fixed_asset_repository.dart';
import '../models/fixed_asset_model.dart';

/// Screen managing Fixed Assets Register, Net Book Value, and Depreciation Journal Postings.
class FixedAssetsScreen extends StatefulWidget {
  final String organizationId;
  final String baseCurrencyCode;

  const FixedAssetsScreen({
    super.key,
    required this.organizationId,
    required this.baseCurrencyCode,
  });

  @override
  State<FixedAssetsScreen> createState() => _FixedAssetsScreenState();
}

class _FixedAssetsScreenState extends State<FixedAssetsScreen> {
  final FixedAssetRepository _assetRepo = FixedAssetRepository();
  final AccountRepository _accountRepo = AccountRepository();

  List<FixedAssetModel> _assets = [];
  List<AccountModel> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final assets = await _assetRepo.getAssets(widget.organizationId);
      final accs = await _accountRepo.getAccountsFlat(widget.organizationId);
      if (!mounted) return;
      setState(() {
        _assets = assets;
        _accounts = accs.where((a) => a.isActive).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _totalPurchaseCost =>
      _assets.fold(0, (sum, a) => sum + a.purchaseCost);
  int get _totalAccumulatedDepreciation =>
      _assets.fold(0, (sum, a) => sum + a.accumulatedDepreciation);
  int get _totalNetBookValue =>
      _assets.fold(0, (sum, a) => sum + a.bookValue);

  Future<void> _openAddAssetDialog() async {
    final assetAccounts =
        _accounts.where((a) => a.accountType == 'ASSET').toList();
    final expenseAccounts =
        _accounts.where((a) => a.accountType == 'EXPENSE').toList();

    if (assetAccounts.isEmpty || expenseAccounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تهيئة دليل الحسابات أولاً لإضافة أصول ثابتة.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final code = await _assetRepo.getNextAssetCode(widget.organizationId);
    if (!mounted) return;

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final costController = TextEditingController();
    final salvageController = TextEditingController(text: '0');
    final lifeMonthsController = TextEditingController(text: '60'); // 5 years
    String purchaseDate = DateTime.now().toIso8601String().split('T').first;

    String selectedAssetAccId = assetAccounts.first.id;
    String selectedExpAccId = expenseAccounts.first.id;
    String selectedAccDepAccId = assetAccounts.first.id;

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'إضافة أصل ثابت جديد ($code)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkNavy,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(sheetCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Asset Name
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'اسم الأصل الثابت *',
                          hintText: 'مثال: سيارة توزيع تويوتا هايس',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'يرجى إدخال اسم الأصل'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Asset Account
                      DropdownButtonFormField<String>(
                        value: selectedAssetAccId,
                        decoration: InputDecoration(
                          labelText: 'حساب الأصل في دليل الحسابات *',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        items: assetAccounts.map((a) {
                          return DropdownMenuItem(
                            value: a.id,
                            child: Text('${a.accountCode} - ${a.accountNameAr}'),
                          );
                        }).toList(),
                        onChanged: (v) =>
                            setSheetState(() => selectedAssetAccId = v!),
                      ),
                      const SizedBox(height: 12),

                      // Expense Account
                      DropdownButtonFormField<String>(
                        value: selectedExpAccId,
                        decoration: InputDecoration(
                          labelText: 'حساب مصروف الإهلاك (أرباح وخسائر) *',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        items: expenseAccounts.map((a) {
                          return DropdownMenuItem(
                            value: a.id,
                            child: Text('${a.accountCode} - ${a.accountNameAr}'),
                          );
                        }).toList(),
                        onChanged: (v) =>
                            setSheetState(() => selectedExpAccId = v!),
                      ),
                      const SizedBox(height: 12),

                      // Accumulated Dep Account
                      DropdownButtonFormField<String>(
                        value: selectedAccDepAccId,
                        decoration: InputDecoration(
                          labelText: 'حساب مجمع الإهلاك المتراكم *',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        items: assetAccounts.map((a) {
                          return DropdownMenuItem(
                            value: a.id,
                            child: Text('${a.accountCode} - ${a.accountNameAr}'),
                          );
                        }).toList(),
                        onChanged: (v) =>
                            setSheetState(() => selectedAccDepAccId = v!),
                      ),
                      const SizedBox(height: 12),

                      // Cost & Useful Life
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: costController,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: InputDecoration(
                                labelText: 'تكلفة الشراء *',
                                suffixText: widget.baseCurrencyCode,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              validator: (v) {
                                final n = double.tryParse(v ?? '');
                                if (n == null || n <= 0) return 'مبلغ موجب';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: lifeMonthsController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'العمر الإنتاجي (أشهر) *',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              validator: (v) {
                                final n = int.tryParse(v ?? '');
                                if (n == null || n <= 0) return 'أشهر موجبة';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Salvage & Purchase Date
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: salvageController,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: InputDecoration(
                                labelText: 'القيمة التخريدية',
                                suffixText: widget.baseCurrencyCode,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              readOnly: true,
                              controller:
                                  TextEditingController(text: purchaseDate),
                              decoration: InputDecoration(
                                labelText: 'تاريخ الشراء',
                                prefixIcon: const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 18),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onTap: () async {
                                final p = await showDatePicker(
                                  context: ctx,
                                  initialDate: DateTime.tryParse(purchaseDate) ??
                                      DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2050),
                                );
                                if (p != null) {
                                  setSheetState(() => purchaseDate =
                                      p.toIso8601String().split('T').first);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final costMinor = ((double.tryParse(
                                          costController.text.trim()) ??
                                      0) *
                                  100)
                              .round();
                          final salvageMinor = ((double.tryParse(
                                          salvageController.text.trim()) ??
                                      0) *
                                  100)
                              .round();
                          final life = int.tryParse(
                                  lifeMonthsController.text.trim()) ??
                              60;

                          final newAsset = FixedAssetModel(
                            id: 'ast_${DateTime.now().millisecondsSinceEpoch}',
                            organizationId: widget.organizationId,
                            assetCode: code,
                            assetNameAr: nameController.text.trim(),
                            assetAccountId: selectedAssetAccId,
                            depreciationExpenseAccountId: selectedExpAccId,
                            accumulatedDepreciationAccountId:
                                selectedAccDepAccId,
                            purchaseDate: purchaseDate,
                            purchaseCost: costMinor,
                            salvageValue: salvageMinor,
                            usefulLifeMonths: life,
                            createdAt: DateTime.now().toIso8601String(),
                            updatedAt: DateTime.now().toIso8601String(),
                          );

                          await _assetRepo.createAsset(newAsset);
                          if (!mounted) return;
                          if (sheetCtx.mounted) {
                            Navigator.pop(sheetCtx);
                          }
                          _loadData();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('تم تسجيل الأصل الثابت $code بنجاح'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'حفظ الأصل الثابت في السجل',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handlePostDepreciation(FixedAssetModel asset) async {
    if (asset.remainingDepreciation <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم استهلاك هذا الأصل الثابت بالكامل ولا توجد مبالغ متبقية للإهلاك.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final defaultMonthlyMinor = asset.monthlyDepreciation;
    final defaultMonthlyMajor = (defaultMonthlyMinor / 100.0).toStringAsFixed(2);
    final amountController = TextEditingController(text: defaultMonthlyMajor);
    String depDate = DateTime.now().toIso8601String().split('T').first;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.calculate_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ترحيل قسط إهلاك: ${asset.assetNameAr}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'قسط الإهلاك الشهري المقترح: $defaultMonthlyMajor ${widget.baseCurrencyCode}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                Text(
                  'القيمة القابلة للإهلاك المتبقية: ${AppFormatters.formatCurrency(asset.remainingDepreciation, currencySymbol: widget.baseCurrencyCode)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'مبلغ قسط الإهلاك المراد ترحيله *',
                    suffixText: widget.baseCurrencyCode,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  readOnly: true,
                  controller: TextEditingController(text: depDate),
                  decoration: InputDecoration(
                    labelText: 'تاريخ احتساب الإهلاك *',
                    prefixIcon:
                        const Icon(Icons.calendar_today_rounded, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onTap: () async {
                    final p = await showDatePicker(
                      context: ctx,
                      initialDate:
                          DateTime.tryParse(depDate) ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2050),
                    );
                    if (p != null) {
                      depDate = p.toIso8601String().split('T').first;
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('ترحيل القيد المحاسبي',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );

    if (confirm != true) return;

    final double enteredMajor =
        double.tryParse(amountController.text.trim()) ?? 0.0;
    final int amountMinor = (enteredMajor * 100).round();

    if (amountMinor <= 0) return;

    try {
      final entryNumber = await _assetRepo.postDepreciation(
        assetId: asset.id,
        organizationId: widget.organizationId,
        amount: amountMinor,
        asOfDate: depDate,
        baseCurrencyCode: widget.baseCurrencyCode,
      );

      if (!mounted) return;
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم ترحيل قسط الإهلاك بنجاح بالقيد المحاسبي رقم $entryNumber بمبلغ ${AppFormatters.formatCurrency(amountMinor, currencySymbol: widget.baseCurrencyCode)}',
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ أثناء ترحيل قسط الإهلاك: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'سجل الأصول الثابتة والإهلاك',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.darkNavy,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Financial Summary Cards
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSummaryCol(
                              'إجمالي تكلفة الأصول',
                              _totalPurchaseCost,
                              AppColors.primary,
                            ),
                            Container(width: 1, height: 40, color: AppColors.border),
                            _buildSummaryCol(
                              'مجمع الإهلاك المتراكم',
                              _totalAccumulatedDepreciation,
                              AppColors.warning,
                            ),
                            Container(width: 1, height: 40, color: AppColors.border),
                            _buildSummaryCol(
                              'صافي القيمة الدفترية',
                              _totalNetBookValue,
                              AppColors.success,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'قائمة الأصول الثابتة (${_assets.length} أصل)',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkNavy,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (_assets.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 36, horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.domain_disabled_rounded,
                                size: 40,
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'لا توجد أصول ثابتة مسجلة لهذه المؤسسة',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'انقر على زر الإضافة أدناه لتسجيل السيارات، العقارات، الأجهزة، والأثاث',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _assets.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final asset = _assets[index];
                            final ratio = asset.depreciatedRatio;

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                                boxShadow: AppTheme.cardShadow,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryLight,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              asset.assetCode,
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            asset.assetNameAr,
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.darkNavy,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        AppFormatters.formatCurrency(
                                          asset.purchaseCost,
                                          currencySymbol:
                                              widget.baseCurrencyCode,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Progress of depreciation
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: ratio,
                                      minHeight: 6,
                                      backgroundColor: AppColors.background,
                                      color: ratio >= 1.0
                                          ? AppColors.danger
                                          : AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'صافي القيمة الدفترية: ${AppFormatters.formatCurrency(asset.bookValue, currencySymbol: widget.baseCurrencyCode)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.success,
                                        ),
                                      ),
                                      Text(
                                        'المستهلك: ${(ratio * 100).toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'قسط شهري: ${AppFormatters.formatCurrency(asset.monthlyDepreciation, currencySymbol: widget.baseCurrencyCode)}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: asset.remainingDepreciation > 0
                                            ? () => _handlePostDepreciation(asset)
                                            : null,
                                        icon: const Icon(
                                            Icons.post_add_rounded,
                                            size: 16),
                                        label: const Text(
                                          'ترحيل قسط إهلاك',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openAddAssetDialog,
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'أصل ثابت جديد',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCol(String title, int minorAmount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          AppFormatters.formatCurrency(minorAmount,
              currencySymbol: widget.baseCurrencyCode),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
