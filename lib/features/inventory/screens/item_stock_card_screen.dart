import 'package:flutter/material.dart';
import 'package:abu_ali/core/constants/app_colors.dart';
import 'package:abu_ali/core/constants/database_constants.dart';
import 'package:abu_ali/core/theme/app_theme.dart';
import '../data/inventory_reports_repository.dart';
import '../data/inventory_repository.dart';
import '../models/item_model.dart';
import '../models/warehouse_model.dart';

/// Screen displaying the detailed Stock Card (أستاذ الصنف / كارت الصنف) with running balance.
class ItemStockCardScreen extends StatefulWidget {
  final String organizationId;
  final ItemModel item;

  const ItemStockCardScreen({
    super.key,
    required this.organizationId,
    required this.item,
  });

  @override
  State<ItemStockCardScreen> createState() => _ItemStockCardScreenState();
}

class _ItemStockCardScreenState extends State<ItemStockCardScreen> {
  final InventoryReportsRepository _reportsRepo = InventoryReportsRepository();
  final InventoryRepository _invRepo = InventoryRepository();

  List<Map<String, dynamic>> _movements = [];
  List<WarehouseModel> _warehouses = [];
  String? _selectedWarehouseId;
  bool _isLoading = true;

  int _currentStock = 0;
  int _currentWac = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final whs = await _invRepo.getWarehouses(widget.organizationId);
      final movs = await _reportsRepo.getItemStockCard(
        organizationId: widget.organizationId,
        itemId: widget.item.id,
        warehouseId: _selectedWarehouseId,
      );
      final stock = await _invRepo.getItemStock(
        widget.item.id,
        widget.organizationId,
        warehouseId: _selectedWarehouseId,
      );
      final wac = await _invRepo.getItemWeightedAverageCost(
        widget.item.id,
        widget.organizationId,
      );

      if (mounted) {
        setState(() {
          _warehouses = whs;
          _movements = movs;
          _currentStock = stock;
          _currentWac = wac;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل كارت الصنف: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalValue =
        ((_currentStock * _currentWac) / DatabaseConstants.quantityScale)
            .round();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('كارت الصنف: ${widget.item.nameAr}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadData,
            ),
          ],
        ),
        body: Column(
          children: [
            // Header summary card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.nameAr,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkNavy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'كود الصنف: ${widget.item.itemCode} • الوحدة: ${widget.item.baseUnitSymbol ?? widget.item.baseUnitNameAr ?? ""}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.item.itemTypeLabelAr,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem(
                        title: 'الرصيد الفعلي الحالي',
                        value: (_currentStock / 1000.0).toStringAsFixed(2),
                        color: _currentStock > 0
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                      _buildSummaryItem(
                        title: 'متوسط التكلفة المرجح',
                        value: (_currentWac / 100.0).toStringAsFixed(2),
                        color: AppColors.primary,
                      ),
                      _buildSummaryItem(
                        title: 'إجمالي قيمة المخزون',
                        value: (totalValue / 100.0).toStringAsFixed(2),
                        color: AppColors.darkNavy,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Filter by Warehouse
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text(
                    'تصفية حسب المستودع: ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String?>(
                      value: _selectedWarehouseId,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('كافة المستودعات'),
                        ),
                        ..._warehouses.map((w) => DropdownMenuItem<String?>(
                              value: w.id,
                              child: Text(w.name),
                            )),
                      ],
                      onChanged: (v) {
                        setState(() => _selectedWarehouseId = v);
                        _loadData();
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),

            // Movements list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _movements.isEmpty
                      ? const Center(
                          child: Text('لا توجد حركات مخزنية مسجلة لهذا الصنف'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _movements.length,
                          itemBuilder: (context, index) {
                            final m = _movements[index];
                            final qIn = (m['quantity_in'] as num).toInt();
                            final qOut = (m['quantity_out'] as num).toInt();
                            final isIncoming = qIn > 0;
                            final cost = (m['unit_cost'] as num).toInt();
                            final runningQty =
                                (m['running_quantity'] as num).toInt();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'سند: ${m['document_number']} (${m['movement_type']})',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      Text(
                                        m['movement_date'] as String,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'المستودع: ${m['warehouse_name']}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            isIncoming
                                                ? Icons.arrow_downward_rounded
                                                : Icons.arrow_upward_rounded,
                                            size: 16,
                                            color: isIncoming
                                                ? AppColors.success
                                                : AppColors.danger,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isIncoming
                                                ? '+${(qIn / 1000.0).toStringAsFixed(2)}'
                                                : '-${(qOut / 1000.0).toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: isIncoming
                                                  ? AppColors.success
                                                  : AppColors.danger,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'تكلفة الوحدة: ${(cost / 100.0).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        'الرصيد بعد الحركة: ${(runningQty / 1000.0).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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

  Widget _buildSummaryItem({
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
