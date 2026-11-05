import 'package:flutter/material.dart';
import 'package:abu_ali/core/constants/app_colors.dart';
import 'package:abu_ali/core/theme/app_theme.dart';
import 'package:abu_ali/features/organizations/data/organization_branding_service.dart';
import 'package:abu_ali/features/organizations/data/organization_repository.dart';
import 'package:abu_ali/features/reports/screens/report_document_preview_screen.dart';
import '../data/inventory_reports_repository.dart';
import '../data/inventory_repository.dart';
import '../models/warehouse_model.dart';

/// Comprehensive viewer and export screen for the 12 Inventory Reports.
class InventoryReportViewerScreen extends StatefulWidget {
  final String organizationId;
  final String reportId;
  final String reportTitle;
  final String reportDescription;

  const InventoryReportViewerScreen({
    super.key,
    required this.organizationId,
    required this.reportId,
    required this.reportTitle,
    required this.reportDescription,
  });

  @override
  State<InventoryReportViewerScreen> createState() =>
      _InventoryReportViewerScreenState();
}

class _InventoryReportViewerScreenState
    extends State<InventoryReportViewerScreen> {
  final InventoryReportsRepository _reportsRepo = InventoryReportsRepository();
  final InventoryRepository _invRepo = InventoryRepository();
  final OrganizationRepository _orgRepo = OrganizationRepository();
  final OrganizationBrandingService _brandingService =
      OrganizationBrandingService.instance;

  List<Map<String, dynamic>> _data = [];
  List<WarehouseModel> _warehouses = [];
  String? _selectedWarehouseId;
  final String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    try {
      final whs = await _invRepo.getWarehouses(widget.organizationId);
      List<Map<String, dynamic>> res = [];

      switch (widget.reportId) {
        case 'current_stock':
          res = await _reportsRepo.getCurrentStockReport(
            organizationId: widget.organizationId,
            warehouseId: _selectedWarehouseId,
            query: _searchQuery,
          );
          break;
        case 'valuation':
          res = await _reportsRepo.getInventoryValuationReport(
            organizationId: widget.organizationId,
            warehouseId: _selectedWarehouseId,
          );
          break;
        case 'by_warehouse':
          res = await _reportsRepo
              .getStockByWarehouseReport(widget.organizationId);
          break;
        case 'by_category':
          res = await _reportsRepo
              .getStockByCategoryReport(widget.organizationId);
          break;
        case 'movements':
          res = await _reportsRepo.getStockMovementsReport(
            organizationId: widget.organizationId,
            warehouseId: _selectedWarehouseId,
          );
          break;
        case 'low_stock':
          res = await _reportsRepo.getLowStockReport(widget.organizationId);
          break;
        case 'out_of_stock':
          res = await _reportsRepo.getOutOfStockReport(widget.organizationId);
          break;
        case 'receipts':
          res = await _reportsRepo.getStockReceiptsReport(
              organizationId: widget.organizationId);
          break;
        case 'issues':
          res = await _reportsRepo.getStockIssuesReport(
              organizationId: widget.organizationId);
          break;
        case 'transfers':
          res = await _reportsRepo.getWarehouseTransfersReport(
              organizationId: widget.organizationId);
          break;
        default:
          res = await _reportsRepo.getCurrentStockReport(
              organizationId: widget.organizationId);
      }

      if (mounted) {
        setState(() {
          _warehouses = whs;
          _data = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في استخراج التقرير: $e')),
        );
      }
    }
  }

  Future<void> _openReportPreview() async {
    final org = await _orgRepo.getOrganizationById(widget.organizationId);
    final branding = await _brandingService.getBranding(widget.organizationId);

    final headers = _getReportHeaders();
    final rows = _data.map((r) => _getReportRowValues(r)).toList();

    if (!mounted) return;

    final today = DateTime.now().toIso8601String().split('T').first;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportDocumentPreviewScreen(
          title: widget.reportTitle,
          subtitle: widget.reportDescription,
          organizationName: org?.name ?? '',
          baseCurrency: org?.baseCurrencyCode ?? 'YER',
          periodOrDate: 'حتى تاريخ $today',
          headers: headers,
          rows: rows,
          branding: branding,
        ),
      ),
    );
  }

  List<String> _getReportHeaders() {
    switch (widget.reportId) {
      case 'current_stock':
        return [
          'الرمز',
          'اسم الصنف',
          'التصنيف',
          'الرصيد المتوفر',
          'متوسط التكلفة',
          'القيمة الإجمالية'
        ];
      case 'valuation':
        return [
          'الرمز',
          'اسم الصنف',
          'الرصيد',
          'تكلفة الوحدة',
          'القيمة بالتكلفة',
          'القيمة بالبيع'
        ];
      case 'by_warehouse':
        return [
          'رمز المستودع',
          'اسم المستودع',
          'عدد الأصناف',
          'إجمالي الكميات',
          'القيمة الإجمالية'
        ];
      case 'by_category':
        return [
          'رمز التصنيف',
          'اسم التصنيف',
          'عدد الأصناف',
          'إجمالي الكميات',
          'القيمة التقديرية'
        ];
      case 'movements':
        return [
          'التاريخ',
          'رقم السند',
          'نوع الحركة',
          'المستودع',
          'الصنف',
          'وارد',
          'صادر'
        ];
      case 'low_stock':
        return [
          'الرمز',
          'اسم الصنف',
          'الرصيد الحالي',
          'حد الطلب',
          'العجز المطلوب'
        ];
      case 'out_of_stock':
        return ['الرمز', 'اسم الصنف', 'التصنيف', 'الرصيد الحالي', 'سعر البيع'];
      case 'receipts':
        return [
          'رقم السند',
          'التاريخ',
          'المورد',
          'المستودع',
          'الأصناف',
          'الإجمالي'
        ];
      case 'issues':
        return ['رقم السند', 'التاريخ', 'المستودع', 'الأصناف', 'الإجمالي'];
      case 'transfers':
        return ['رقم السند', 'التاريخ', 'المصدر', 'الوجهة', 'عدد الأصناف'];
      default:
        return ['الرمز', 'البيان', 'الرصيد', 'القيمة'];
    }
  }

  List<String> _getReportRowValues(Map<String, dynamic> r) {
    switch (widget.reportId) {
      case 'current_stock':
        final stock = ((r['current_stock'] as num?)?.toInt() ?? 0) / 1000.0;
        final cost = ((r['unit_cost'] as num?)?.toInt() ?? 0) / 100.0;
        final total = ((r['total_value'] as num?)?.toInt() ?? 0) / 100.0;
        return [
          r['item_code']?.toString() ?? '',
          r['name_ar']?.toString() ?? '',
          r['category_name']?.toString() ?? 'عام',
          '${stock.toStringAsFixed(1)} ${r['unit_symbol'] ?? ""}',
          cost.toStringAsFixed(2),
          total.toStringAsFixed(2),
        ];
      case 'valuation':
        final stock = ((r['current_stock'] as num?)?.toInt() ?? 0) / 1000.0;
        final cost = ((r['unit_cost'] as num?)?.toInt() ?? 0) / 100.0;
        final costVal = ((r['cost_valuation'] as num?)?.toInt() ?? 0) / 100.0;
        final retailVal =
            ((r['retail_valuation'] as num?)?.toInt() ?? 0) / 100.0;
        return [
          r['item_code']?.toString() ?? '',
          r['name_ar']?.toString() ?? '',
          stock.toStringAsFixed(1),
          cost.toStringAsFixed(2),
          costVal.toStringAsFixed(2),
          retailVal.toStringAsFixed(2),
        ];
      case 'by_warehouse':
        final qty = ((r['total_quantity'] as num?)?.toInt() ?? 0) / 1000.0;
        final val = ((r['total_valuation'] as num?)?.toInt() ?? 0) / 100.0;
        return [
          r['warehouse_code']?.toString() ?? '',
          r['warehouse_name']?.toString() ?? '',
          r['distinct_items']?.toString() ?? '0',
          qty.toStringAsFixed(1),
          val.toStringAsFixed(2),
        ];
      case 'by_category':
        final qty = ((r['total_quantity'] as num?)?.toInt() ?? 0) / 1000.0;
        final val = ((r['total_valuation'] as num?)?.toInt() ?? 0) / 100.0;
        return [
          r['category_code']?.toString() ?? '',
          r['category_name']?.toString() ?? '',
          r['item_count']?.toString() ?? '0',
          qty.toStringAsFixed(1),
          val.toStringAsFixed(2),
        ];
      case 'movements':
        final qIn = ((r['quantity_in'] as num?)?.toInt() ?? 0) / 1000.0;
        final qOut = ((r['quantity_out'] as num?)?.toInt() ?? 0) / 1000.0;
        return [
          r['movement_date']?.toString() ?? '',
          r['document_number']?.toString() ?? '',
          r['movement_type']?.toString() ?? '',
          r['warehouse_name']?.toString() ?? '',
          r['item_name_ar']?.toString() ?? '',
          qIn > 0 ? qIn.toStringAsFixed(1) : '-',
          qOut > 0 ? qOut.toStringAsFixed(1) : '-',
        ];
      case 'low_stock':
        final cur = ((r['current_stock'] as num?)?.toInt() ?? 0) / 1000.0;
        final reo = ((r['reorder_level'] as num?)?.toInt() ?? 0) / 1000.0;
        final short = ((r['shortage_quantity'] as num?)?.toInt() ?? 0) / 1000.0;
        return [
          r['item_code']?.toString() ?? '',
          r['name_ar']?.toString() ?? '',
          cur.toStringAsFixed(1),
          reo.toStringAsFixed(1),
          short.toStringAsFixed(1),
        ];
      case 'out_of_stock':
        final cur = ((r['current_stock'] as num?)?.toInt() ?? 0) / 1000.0;
        final sell = ((r['selling_price'] as num?)?.toInt() ?? 0) / 100.0;
        return [
          r['item_code']?.toString() ?? '',
          r['name_ar']?.toString() ?? '',
          r['category_name']?.toString() ?? 'عام',
          cur.toStringAsFixed(1),
          sell.toStringAsFixed(2),
        ];
      case 'receipts':
        final tot = ((r['total_cost'] as num?)?.toInt() ?? 0) / 100.0;
        return [
          r['document_number']?.toString() ?? '',
          r['document_date']?.toString() ?? '',
          r['supplier_name']?.toString() ?? 'غير محدد',
          r['warehouse_name']?.toString() ?? '',
          r['item_count']?.toString() ?? '0',
          tot.toStringAsFixed(2),
        ];
      case 'issues':
        final tot = ((r['total_cost'] as num?)?.toInt() ?? 0) / 100.0;
        return [
          r['document_number']?.toString() ?? '',
          r['document_date']?.toString() ?? '',
          r['warehouse_name']?.toString() ?? '',
          r['item_count']?.toString() ?? '0',
          tot.toStringAsFixed(2),
        ];
      case 'transfers':
        return [
          r['document_number']?.toString() ?? '',
          r['document_date']?.toString() ?? '',
          r['source_warehouse_name']?.toString() ?? '',
          r['destination_warehouse_name']?.toString() ?? '',
          r['item_count']?.toString() ?? '0',
        ];
      default:
        return [
          r['item_code']?.toString() ?? '',
          r['name_ar']?.toString() ?? '',
          '0',
          '0.00',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(widget.reportTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.print_rounded),
              tooltip: 'معاينة المستند وطباعة PDF',
              onPressed: _openReportPreview,
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadReportData,
            ),
          ],
        ),
        body: Column(
          children: [
            // Filter Header
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.surface,
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _selectedWarehouseId,
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'المستودع',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
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
                        _loadReportData();
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Report Table
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _data.isEmpty
                      ? const Center(
                          child: Text('لا توجد بيانات مسجلة لهذا التقرير'))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                                boxShadow: AppTheme.cardShadow,
                              ),
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  const Color(0xFFEFF6FF),
                                ),
                                columns: _getReportHeaders()
                                    .map((h) => DataColumn(
                                          label: Text(
                                            h,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.darkNavy,
                                            ),
                                          ),
                                        ))
                                    .toList(),
                                rows: _data.map((r) {
                                  final vals = _getReportRowValues(r);
                                  return DataRow(
                                    cells: vals
                                        .map((v) => DataCell(Text(v)))
                                        .toList(),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
