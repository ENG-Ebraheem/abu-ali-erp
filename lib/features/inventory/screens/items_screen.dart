import 'package:flutter/material.dart';
import 'package:abu_ali/core/constants/app_colors.dart';
import 'package:abu_ali/core/theme/app_theme.dart';
import '../data/inventory_repository.dart';
import '../models/item_category_model.dart';
import '../models/item_model.dart';
import 'item_form_screen.dart';
import 'item_stock_card_screen.dart';

/// Screen listing products and materials with search, filtering, and stock levels.
class ItemsScreen extends StatefulWidget {
  final String organizationId;

  const ItemsScreen({
    super.key,
    required this.organizationId,
  });

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final InventoryRepository _repo = InventoryRepository();

  List<ItemModel> _items = [];
  List<ItemCategoryModel> _categories = [];
  String? _selectedCategoryId;
  String _searchQuery = '';
  bool _lowStockOnly = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final cats = await _repo.getCategories(widget.organizationId);
      final list = await _repo.getItems(
        organizationId: widget.organizationId,
        categoryId: _selectedCategoryId,
        query: _searchQuery,
        lowStockOnly: _lowStockOnly,
      );

      if (mounted) {
        setState(() {
          _categories = cats;
          _items = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الأصناف: $e')),
        );
      }
    }
  }

  Future<void> _deleteItem(ItemModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد حذف الصنف'),
          content: Text('هل أنت متأكد من حذف الصنف "${item.nameAr}" (${item.itemCode})؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('حذف نهائي'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        await _repo.deleteItem(item.id, widget.organizationId);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف الصنف بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: AppColors.danger,
            ),
          );
        }
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
          title: const Text('دليل الأصناف والمواد'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadData,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final res = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ItemFormScreen(organizationId: widget.organizationId),
              ),
            );
            if (res == true) _loadData();
          },
          icon: const Icon(Icons.add_box_rounded),
          label: const Text('صنف جديد'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            // Search and Category Filter Bar
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.surface,
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'بحث باسم الصنف، الرمز، أو الباركود...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) {
                      _searchQuery = v;
                      _loadData();
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _selectedCategoryId,
                          isDense: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          hint: const Text('كافة التصنيفات'),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('كافة التصنيفات'),
                            ),
                            ..._categories.map((c) => DropdownMenuItem<String?>(
                                  value: c.id,
                                  child: Text(c.nameAr),
                                )),
                          ],
                          onChanged: (v) {
                            setState(() => _selectedCategoryId = v);
                            _loadData();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('النواقص فقط'),
                        selected: _lowStockOnly,
                        selectedColor: const Color(0xFFFEF2F2),
                        checkmarkColor: AppColors.danger,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: _lowStockOnly
                              ? AppColors.danger
                              : AppColors.textSecondary,
                          fontWeight: _lowStockOnly
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        onSelected: (val) {
                          setState(() => _lowStockOnly = val);
                          _loadData();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Items List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? const Center(
                          child: Text('لا توجد أصناف مطابقة لبحثك'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final it = _items[index];
                            final stock = it.currentStock / 1000.0;
                            final cost = it.currentAverageCost / 100.0;
                            final sell = it.sellingPrice / 100.0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                                boxShadow: AppTheme.cardShadow,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    it.nameAr,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: AppColors.darkNavy,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFF1F5F9),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Text(
                                                      it.itemCode,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${it.categoryNameAr ?? "غير مصنف"} • ${it.itemTypeLabelAr}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        _buildStockBadge(it),
                                      ],
                                    ),
                                    const Divider(height: 18),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildPriceColumn(
                                          label: 'الرصيد المتوفر',
                                          value:
                                              '${stock.toStringAsFixed(1)} ${it.baseUnitSymbol ?? it.baseUnitNameAr ?? ""}',
                                          color: it.currentStock > 0
                                              ? AppColors.darkNavy
                                              : AppColors.danger,
                                        ),
                                        _buildPriceColumn(
                                          label: 'متوسط التكلفة',
                                          value: cost.toStringAsFixed(2),
                                          color: AppColors.primary,
                                        ),
                                        _buildPriceColumn(
                                          label: 'سعر البيع',
                                          value: sell.toStringAsFixed(2),
                                          color: AppColors.success,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ItemStockCardScreen(
                                                  organizationId:
                                                      widget.organizationId,
                                                  item: it,
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.receipt_long_rounded,
                                            size: 16,
                                          ),
                                          label: const Text('كارت الصنف'),
                                          style: OutlinedButton.styleFrom(
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined,
                                              size: 20,
                                              color: AppColors.primary),
                                          onPressed: () async {
                                            final res = await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => ItemFormScreen(
                                                  organizationId:
                                                      widget.organizationId,
                                                  item: it,
                                                ),
                                              ),
                                            );
                                            if (res == true) _loadData();
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 20,
                                              color: AppColors.danger),
                                          onPressed: () => _deleteItem(it),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockBadge(ItemModel it) {
    if (!it.trackInventory || it.isService) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'غير مخزني',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    }

    if (it.currentStock <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'منتهي الرصيد',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.danger,
          ),
        ),
      );
    }

    if (it.isLowStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'وصل حد الطلب',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFFB45309),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'متوفر',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.success,
        ),
      ),
    );
  }

  Widget _buildPriceColumn({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
