import 'package:flutter/material.dart';
import 'package:abu_ali/core/constants/app_colors.dart';
import 'package:abu_ali/features/organizations/data/organization_branding_service.dart';
import 'package:abu_ali/features/organizations/data/organization_repository.dart';
import 'package:abu_ali/features/reports/screens/report_document_preview_screen.dart';
import '../data/inventory_repository.dart';
import '../models/stock_document_model.dart';
import 'create_stock_document_screen.dart';

/// Screen displaying the details of a stock document with posting, printing, and sharing.
class StockDocumentDetailsScreen extends StatefulWidget {
  final String organizationId;
  final String documentId;

  const StockDocumentDetailsScreen({
    super.key,
    required this.organizationId,
    required this.documentId,
  });

  @override
  State<StockDocumentDetailsScreen> createState() =>
      _StockDocumentDetailsScreenState();
}

class _StockDocumentDetailsScreenState
    extends State<StockDocumentDetailsScreen> {
  final InventoryRepository _repo = InventoryRepository();
  final OrganizationRepository _orgRepo = OrganizationRepository();
  final OrganizationBrandingService _brandingService =
      OrganizationBrandingService.instance;

  StockDocumentModel? _doc;
  bool _isLoading = true;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    setState(() => _isLoading = true);
    try {
      final d = await _repo.getStockDocumentById(
          widget.documentId, widget.organizationId);
      if (mounted) {
        setState(() {
          _doc = d;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل بيانات السند: $e')),
        );
      }
    }
  }

  Future<void> _postDocument() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الترحيل للمخازن'),
          content: Text(
            'هل أنت متأكد من ترحيل السند رقم "${_doc?.documentNumber}"؟ سيتم توليد حركات المخزون والقيود المحاسبية ولا يمكن التراجع بعد الترحيل.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('تأكيد الترحيل'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _isPosting = true);
    try {
      await _repo.postStockDocument(widget.documentId, widget.organizationId);
      await _loadDocument();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم ترحيل السند المخزني والقيد المحاسبي بنجاح!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _openPreviewScreen() async {
    if (_doc == null) return;
    final org = await _orgRepo.getOrganizationById(widget.organizationId);
    final branding = await _brandingService.getBranding(widget.organizationId);

    final headers = ['#', 'رمز الصنف', 'اسم الصنف', 'الكمية', 'التكلفة', 'الإجمالي'];
    final rows = _doc!.lines.map((l) {
      final qty = (l.baseQuantity / 1000.0).toStringAsFixed(2);
      final cost = (l.unitCost / 100.0).toStringAsFixed(2);
      final total = (l.totalCost / 100.0).toStringAsFixed(2);
      return [
        l.lineNumber.toString(),
        l.itemCode ?? '',
        l.itemNameAr ?? '',
        '$qty ${l.unitSymbol ?? ""}',
        cost,
        total,
      ];
    }).toList();

    if (!mounted) return;

    final docTitle = '${_doc!.documentTypeLabelAr} رقم ${_doc!.documentNumber}';
    final subtitle =
        'المستودع: ${_doc!.destinationWarehouseName ?? _doc!.sourceWarehouseName ?? ""} • التاريخ: ${_doc!.documentDate}';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportDocumentPreviewScreen(
          title: docTitle,
          subtitle: subtitle,
          organizationName: org?.name ?? '',
          baseCurrency: org?.baseCurrencyCode ?? 'YER',
          periodOrDate: _doc!.documentDate,
          headers: headers,
          rows: rows,
          totals: [
            'الإجمالي العام',
            '',
            '',
            '',
            '',
            '${(_doc!.totalCost / 100.0).toStringAsFixed(2)} ${org?.baseCurrencyCode ?? "YER"}',
          ],
          branding: branding,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_doc == null) {
      return const Scaffold(
        body: Center(child: Text('السند غير موجود')),
      );
    }

    final d = _doc!;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('${d.documentTypeLabelAr}: ${d.documentNumber}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.print_rounded),
              tooltip: 'معاينة وطباعة المستند',
              onPressed: _openPreviewScreen,
            ),
          ],
        ),
        bottomNavigationBar: d.isDraft
            ? Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.surface,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final res = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreateStockDocumentScreen(
                                organizationId: widget.organizationId,
                                existingDocument: d,
                              ),
                            ),
                          );
                          if (res == true) _loadDocument();
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('تعديل المسودة'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isPosting ? null : _postDocument,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: _isPosting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('ترحيل السند للمخازن والقيود'),
                      ),
                    ),
                  ],
                ),
              )
            : null,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.documentNumber,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkNavy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'التاريخ: ${d.documentDate}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: d.isPosted
                                ? const Color(0xFFECFDF5)
                                : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            d.statusLabelAr,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: d.isPosted
                                  ? AppColors.success
                                  : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildInfoRow('نوع السند', d.documentTypeLabelAr),
                    if (d.sourceWarehouseName != null)
                      _buildInfoRow('مستودع المصدر', d.sourceWarehouseName!),
                    if (d.destinationWarehouseName != null)
                      _buildInfoRow(
                          'مستودع الوجهة / المستلم', d.destinationWarehouseName!),
                    if (d.partyNameAr != null)
                      _buildInfoRow('المورد / العميل', d.partyNameAr!),
                    if (d.referenceNumber != null &&
                        d.referenceNumber!.isNotEmpty)
                      _buildInfoRow('رقم المرجع', d.referenceNumber!),
                    if (d.notes != null && d.notes!.isNotEmpty)
                      _buildInfoRow('ملاحظات', d.notes!),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Text(
                'بنود السند والمواد المسجلة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkNavy,
                ),
              ),
              const SizedBox(height: 8),

              // Lines Table
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    ...d.lines.map((l) {
                      final qty = l.baseQuantity / 1000.0;
                      final cost = l.unitCost / 100.0;
                      final total = l.totalCost / 100.0;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFFEFF6FF),
                              child: Text(
                                '${l.lineNumber}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.itemNameAr ?? l.itemId,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${l.itemCode ?? ""} • ${l.unitNameAr ?? ""}',
                                    style: const TextStyle(
                                      fontSize: 12,
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
                                  '${qty.toStringAsFixed(2)} ${l.unitSymbol ?? ""}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${cost.toStringAsFixed(2)} × = ${total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'الإجمالي العام للسند:',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkNavy,
                            ),
                          ),
                          Text(
                            (d.totalCost / 100.0).toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
