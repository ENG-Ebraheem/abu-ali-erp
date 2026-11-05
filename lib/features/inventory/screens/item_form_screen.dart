import 'package:flutter/material.dart';
import 'package:abu_ali/core/constants/app_colors.dart';
import 'package:abu_ali/core/constants/database_constants.dart';
import '../data/inventory_repository.dart';
import '../models/item_category_model.dart';
import '../models/item_model.dart';
import '../models/item_unit_model.dart';
import '../models/unit_of_measure_model.dart';
import '../models/warehouse_model.dart';

/// Screen for creating and editing a product/material with multi-units.
class ItemFormScreen extends StatefulWidget {
  final String organizationId;
  final ItemModel? item;

  const ItemFormScreen({
    super.key,
    required this.organizationId,
    this.item,
  });

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final InventoryRepository _repo = InventoryRepository();

  late final TextEditingController _codeCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _nameArCtrl;
  late final TextEditingController _nameEnCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _purchasePriceCtrl;
  late final TextEditingController _sellingPriceCtrl;
  late final TextEditingController _minStockCtrl;
  late final TextEditingController _reorderCtrl;

  String? _selectedCategoryId;
  String _selectedItemType = ItemType.merchandise;
  String? _selectedBaseUnitId;
  String? _selectedDefaultWarehouseId;
  String _selectedValuationMethod = 'WEIGHTED_AVERAGE';
  bool _trackInventory = true;
  bool _isActive = true;

  List<ItemCategoryModel> _categories = [];
  List<UnitOfMeasureModel> _units = [];
  List<WarehouseModel> _warehouses = [];
  List<ItemUnitModel> _itemUnits = [];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _codeCtrl = TextEditingController(text: it?.itemCode ?? '');
    _barcodeCtrl = TextEditingController(text: it?.barcode ?? '');
    _nameArCtrl = TextEditingController(text: it?.nameAr ?? '');
    _nameEnCtrl = TextEditingController(text: it?.nameEn ?? '');
    _descCtrl = TextEditingController(text: it?.description ?? '');
    _purchasePriceCtrl = TextEditingController(
      text: it != null ? (it.purchasePrice / 100.0).toStringAsFixed(2) : '0.00',
    );
    _sellingPriceCtrl = TextEditingController(
      text: it != null ? (it.sellingPrice / 100.0).toStringAsFixed(2) : '0.00',
    );
    _minStockCtrl = TextEditingController(
      text: it != null ? (it.minStockLevel / 1000.0).toString() : '0',
    );
    _reorderCtrl = TextEditingController(
      text: it != null ? (it.reorderLevel / 1000.0).toString() : '0',
    );

    _selectedCategoryId = it?.categoryId;
    _selectedItemType = it?.itemType ?? ItemType.merchandise;
    _selectedBaseUnitId = it?.baseUnitId;
    _selectedDefaultWarehouseId = it?.defaultWarehouseId;
    _selectedValuationMethod = it?.valuationMethod ?? 'WEIGHTED_AVERAGE';
    _trackInventory = it?.trackInventory ?? true;
    _isActive = it?.isActive ?? true;

    _loadData();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _barcodeCtrl.dispose();
    _nameArCtrl.dispose();
    _nameEnCtrl.dispose();
    _descCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _sellingPriceCtrl.dispose();
    _minStockCtrl.dispose();
    _reorderCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final cats = await _repo.getCategories(widget.organizationId);
      final units = await _repo.getUnitsOfMeasure(widget.organizationId);
      final whs = await _repo.getWarehouses(widget.organizationId);

      List<ItemUnitModel> subUnits = [];
      if (widget.item != null) {
        subUnits = await _repo.getItemUnits(widget.item!.id);
      }

      if (mounted) {
        setState(() {
          _categories = cats;
          _units = units;
          _warehouses = whs;
          _itemUnits = subUnits;

          if (_selectedBaseUnitId == null && _units.isNotEmpty) {
            _selectedBaseUnitId = _units.first.id;
          }
          if (_selectedDefaultWarehouseId == null && _warehouses.isNotEmpty) {
            _selectedDefaultWarehouseId = _warehouses.first.id;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل البيانات الأساسية: $e')),
        );
      }
    }
  }

  void _addUnitConversionDialog() {
    if (_selectedBaseUnitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد الوحدة الأساسية أولاً')),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    String? additionalUnitId;
    final factorCtrl = TextEditingController(text: '12'); // Example: 1 carton = 12 pcs
    final sellCtrl = TextEditingController();

    final availableUnits =
        _units.where((u) => u.id != _selectedBaseUnitId).toList();

    if (availableUnits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد وحدات قياس أخرى متاحة للتحويل')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إضافة وحدة تحويل إضافية'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: additionalUnitId,
                    decoration: const InputDecoration(labelText: 'الوحدة الإضافية *'),
                    items: availableUnits
                        .map((u) => DropdownMenuItem(
                              value: u.id,
                              child: Text('${u.nameAr} (${u.symbol ?? u.code})'),
                            ))
                        .toList(),
                    onChanged: (v) => setDlgState(() => additionalUnitId = v),
                    validator: (v) => v == null ? 'يرجى اختيار الوحدة' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: factorCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'معامل التحويل للوحدة الأساسية *',
                      hintText: 'كم وحدة أساسية تحتوي هذه الوحدة؟ (مثال: 12)',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'يرجى إدخال المعامل';
                      final numVal = double.tryParse(v);
                      if (numVal == null || numVal <= 0) {
                        return 'يجب أن يكون المعامل أكبر من صفر';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: sellCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'سعر البيع لهذه الوحدة (اختياري)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  final factorNum = double.parse(factorCtrl.text.trim());
                  final factorScaled = (factorNum * 1000).round();
                  final sellPrice = sellCtrl.text.trim().isEmpty
                      ? null
                      : (double.parse(sellCtrl.text.trim()) * 100).round();

                  final uObj = _units.firstWhere((u) => u.id == additionalUnitId);

                  setState(() {
                    _itemUnits.add(ItemUnitModel(
                      id: 'iu_${DateTime.now().millisecondsSinceEpoch}',
                      organizationId: widget.organizationId,
                      itemId: widget.item?.id ?? '',
                      unitId: additionalUnitId!,
                      conversionFactor: factorScaled,
                      sellingPrice: sellPrice,
                      createdAt: DateTime.now().toUtc().toIso8601String(),
                      unitNameAr: uObj.nameAr,
                      unitSymbol: uObj.symbol,
                    ));
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('إضافة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBaseUnitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد الوحدة الأساسية للصنف')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final itemId = widget.item?.id ??
          'item_${widget.organizationId}_${DateTime.now().millisecondsSinceEpoch}';

      final purchase =
          (double.tryParse(_purchasePriceCtrl.text.trim()) ?? 0.0) * 100;
      final selling =
          (double.tryParse(_sellingPriceCtrl.text.trim()) ?? 0.0) * 100;
      final minStock =
          (double.tryParse(_minStockCtrl.text.trim()) ?? 0.0) * 1000;
      final reorder =
          (double.tryParse(_reorderCtrl.text.trim()) ?? 0.0) * 1000;

      final itemModel = ItemModel(
        id: itemId,
        organizationId: widget.organizationId,
        itemCode: _codeCtrl.text.trim().toUpperCase(),
        barcode: _barcodeCtrl.text.trim().isEmpty
            ? null
            : _barcodeCtrl.text.trim(),
        nameAr: _nameArCtrl.text.trim(),
        nameEn: _nameEnCtrl.text.trim().isEmpty
            ? null
            : _nameEnCtrl.text.trim(),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        categoryId: _selectedCategoryId,
        itemType: _selectedItemType,
        baseUnitId: _selectedBaseUnitId!,
        purchasePrice: purchase.round(),
        sellingPrice: selling.round(),
        minStockLevel: minStock.round(),
        reorderLevel: reorder.round(),
        trackInventory: _selectedItemType == ItemType.service
            ? false
            : _trackInventory,
        isActive: _isActive,
        defaultWarehouseId: _selectedDefaultWarehouseId,
        valuationMethod: _selectedValuationMethod,
        createdAt: widget.item?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.item == null) {
        await _repo.createItem(itemModel);
      } else {
        await _repo.updateItem(itemModel);
      }

      // Save additional units
      for (final iu in _itemUnits) {
        await _repo.addItemUnit(iu.copyWith(
          itemId: itemId,
          organizationId: widget.organizationId,
        ));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.item == null
                  ? 'تمت إضافة الصنف "${itemModel.nameAr}" بنجاح'
                  : 'تم تحديث الصنف بنجاح',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(isEditing ? 'تعديل الصنف' : 'إضافة صنف / مادة جديدة'),
          actions: [
            TextButton(
              onPressed: _isSaving ? null : _submit,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'حفظ الصنف',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section 1: Basic Information
                      _buildSectionHeader('المعلومات الأساسية', Icons.info_outline_rounded),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _codeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'رمز الصنف (SKU) *',
                                hintText: 'مثال: PRD-001',
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'يرجى إدخال الرمز'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _barcodeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'الباركود (اختياري)',
                                hintText: 'مسح أو إدخال الباركود',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameArCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اسم الصنف بالعربية *',
                          hintText: 'مثال: سكر برازيلي 50 كجم',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'يرجى إدخال اسم الصنف'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameEnCtrl,
                        decoration: const InputDecoration(
                          labelText: 'الاسم بالإنجليزية (اختياري)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              value: _selectedCategoryId,
                              decoration: const InputDecoration(labelText: 'التصنيف'),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('عام (بدون تصنيف)'),
                                ),
                                ..._categories.map((c) => DropdownMenuItem<String?>(
                                      value: c.id,
                                      child: Text(c.nameAr),
                                    )),
                              ],
                              onChanged: (v) =>
                                  setState(() => _selectedCategoryId = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedItemType,
                              decoration: const InputDecoration(labelText: 'نوع الصنف *'),
                              items: const [
                                DropdownMenuItem(
                                  value: ItemType.merchandise,
                                  child: Text('بضاعة تجارية'),
                                ),
                                DropdownMenuItem(
                                  value: ItemType.rawMaterial,
                                  child: Text('مواد خام'),
                                ),
                                DropdownMenuItem(
                                  value: ItemType.finishedProduct,
                                  child: Text('منتج تام الصنع'),
                                ),
                                DropdownMenuItem(
                                  value: ItemType.semiFinished,
                                  child: Text('نصف مصنع'),
                                ),
                                DropdownMenuItem(
                                  value: ItemType.consumable,
                                  child: Text('مواد استهلاكية'),
                                ),
                                DropdownMenuItem(
                                  value: ItemType.service,
                                  child: Text('خدمة (غير مخزنية)'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _selectedItemType = v);
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      // Section 2: Units & Pricing
                      _buildSectionHeader('الوحدات والأسعار', Icons.price_change_outlined),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedBaseUnitId,
                              decoration: const InputDecoration(
                                labelText: 'الوحدة الأساسية الصغرى *',
                              ),
                              items: _units
                                  .map((u) => DropdownMenuItem(
                                        value: u.id,
                                        child: Text('${u.nameAr} (${u.symbol ?? u.code})'),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedBaseUnitId = v),
                              validator: (v) =>
                                  v == null ? 'يرجى اختيار الوحدة' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedDefaultWarehouseId,
                              decoration: const InputDecoration(
                                labelText: 'المستودع الافتراضي',
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('بدون تحديد'),
                                ),
                                ..._warehouses.map((w) => DropdownMenuItem(
                                      value: w.id,
                                      child: Text(w.name),
                                    )),
                              ],
                              onChanged: (v) =>
                                  setState(() => _selectedDefaultWarehouseId = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _purchasePriceCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'سعر الشراء الافتراضي',
                                prefixIcon: Icon(Icons.shopping_bag_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _sellingPriceCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'سعر البيع الافتراضي',
                                prefixIcon: Icon(Icons.sell_outlined),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Multi-units list
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'وحدات التحويل الإضافية (كرتون، طرد، درزن...):',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkNavy,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addUnitConversionDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('إضافة وحدة'),
                          ),
                        ],
                      ),
                      if (_itemUnits.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Text(
                            'يتم التعامل بالوحدة الأساسية فقط. يمكنك إضافة وحدات كبرى مثل كرتون = 12 حبة.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        )
                      else
                        ..._itemUnits.map((iu) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '1 ${iu.unitNameAr ?? iu.unitId} = ${(iu.conversionFactor / 1000.0).toString()} وحدة أساسية',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        size: 18, color: AppColors.danger),
                                    onPressed: () {
                                      setState(() => _itemUnits.remove(iu));
                                    },
                                  ),
                                ],
                              ),
                            )),

                      const SizedBox(height: 24),
                      // Section 3: Stock Control
                      _buildSectionHeader('الرقابة وضوابط المخزون', Icons.inventory_rounded),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _reorderCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'حد إعادة الطلب (نواقص)',
                                hintText: 'الكمية التي ينبغي الشراء عندها',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _minStockCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'الحد الأدنى للأمان',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('تتبع المخزون وحساب الحركات'),
                        subtitle: const Text('إلغاء التفعيل يمنع إنشاء حركات مخزنية لهذا الصنف'),
                        value: _selectedItemType == ItemType.service
                            ? false
                            : _trackInventory,
                        onChanged: _selectedItemType == ItemType.service
                            ? null
                            : (v) => setState(() => _trackInventory = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        title: const Text('الصنف نشط ومتاح للعمليات'),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                        contentPadding: EdgeInsets.zero,
                      ),

                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          isEditing ? 'حفظ تعديلات الصنف' : 'إضافة الصنف إلى الدليل',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.darkNavy,
          ),
        ),
      ],
    );
  }
}
extension on ItemUnitModel {
  ItemUnitModel copyWith({
    String? id,
    String? organizationId,
    String? itemId,
    String? unitId,
    int? conversionFactor,
    int? purchasePrice,
    int? sellingPrice,
    String? barcode,
    String? createdAt,
  }) {
    return ItemUnitModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      itemId: itemId ?? this.itemId,
      unitId: unitId ?? this.unitId,
      conversionFactor: conversionFactor ?? this.conversionFactor,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      barcode: barcode ?? this.barcode,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
