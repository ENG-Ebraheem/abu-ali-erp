import 'package:flutter/material.dart';
import 'package:abu_ali/core/constants/app_colors.dart';
import 'package:abu_ali/core/constants/database_constants.dart';
import 'package:abu_ali/core/theme/app_theme.dart';
import '../data/inventory_repository.dart';
import '../models/stock_document_model.dart';
import 'create_stock_document_screen.dart';
import 'stock_document_details_screen.dart';

/// Screen listing stock documents (Receipt, Issue, Transfer, Adjustment, Opening).
class StockDocumentsScreen extends StatefulWidget {
  final String organizationId;
  final String? initialDocType;

  const StockDocumentsScreen({
    super.key,
    required this.organizationId,
    this.initialDocType,
  });

  @override
  State<StockDocumentsScreen> createState() => _StockDocumentsScreenState();
}

class _StockDocumentsScreenState extends State<StockDocumentsScreen> {
  final InventoryRepository _repo = InventoryRepository();

  String _selectedDocType = 'ALL';
  final String _selectedStatus = 'ALL';
  List<StockDocumentModel> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialDocType != null) {
      _selectedDocType = widget.initialDocType!;
    }
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repo.getStockDocuments(
        organizationId: widget.organizationId,
        docType: _selectedDocType == 'ALL' ? null : _selectedDocType,
        status: _selectedStatus == 'ALL' ? null : _selectedStatus,
      );
      if (mounted) {
        setState(() {
          _documents = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل السندات: $e')),
        );
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
          title: const Text('العمليات والسندات المخزنية'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadDocuments,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final res = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateStockDocumentScreen(
                  organizationId: widget.organizationId,
                  initialDocType: _selectedDocType != 'ALL'
                      ? _selectedDocType
                      : StockDocumentType.receipt,
                ),
              ),
            );
            if (res == true) _loadDocuments();
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('سند مخزني جديد'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            // Filters bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.surface,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('الكل', 'ALL'),
                    const SizedBox(width: 8),
                    _buildFilterChip('سندات إدخال', StockDocumentType.receipt),
                    const SizedBox(width: 8),
                    _buildFilterChip('سندات إخراج', StockDocumentType.issue),
                    const SizedBox(width: 8),
                    _buildFilterChip('مناقلات', StockDocumentType.transfer),
                    const SizedBox(width: 8),
                    _buildFilterChip('تسويات جردية', StockDocumentType.adjustment),
                    const SizedBox(width: 8),
                    _buildFilterChip('أرصدة افتتاحية', StockDocumentType.opening),
                  ],
                ),
              ),
            ),

            // Documents List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _documents.isEmpty
                      ? const Center(
                          child: Text('لا توجد سندات مخزنية مسجلة'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          itemCount: _documents.length,
                          itemBuilder: (context, index) {
                            final doc = _documents[index];
                            final total = doc.totalCost / 100.0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                                boxShadow: AppTheme.cardShadow,
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(14),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StockDocumentDetailsScreen(
                                        organizationId: widget.organizationId,
                                        documentId: doc.id,
                                      ),
                                    ),
                                  );
                                  _loadDocuments();
                                },
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _getDocTypeColor(doc.documentType)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _getDocTypeIcon(doc.documentType),
                                    color: _getDocTypeColor(doc.documentType),
                                  ),
                                ),
                                title: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      doc.documentNumber,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: doc.isPosted
                                            ? const Color(0xFFECFDF5)
                                            : const Color(0xFFFFFBEB),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        doc.statusLabelAr,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: doc.isPosted
                                              ? AppColors.success
                                              : const Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      '${doc.documentTypeLabelAr} • ${doc.documentDate}',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    if (doc.destinationWarehouseName != null)
                                      Text(
                                        'إلى: ${doc.destinationWarehouseName}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    if (doc.sourceWarehouseName != null)
                                      Text(
                                        'من: ${doc.sourceWarehouseName}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                  ],
                                ),
                                trailing: Text(
                                  total.toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
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

  Widget _buildFilterChip(String label, String docType) {
    final isSelected = _selectedDocType == docType;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.darkNavy,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12.5,
      ),
      onSelected: (val) {
        if (val) {
          setState(() => _selectedDocType = docType);
          _loadDocuments();
        }
      },
    );
  }

  Color _getDocTypeColor(String type) {
    switch (type) {
      case StockDocumentType.receipt:
        return AppColors.success;
      case StockDocumentType.issue:
        return AppColors.danger;
      case StockDocumentType.transfer:
        return AppColors.primary;
      case StockDocumentType.adjustment:
        return const Color(0xFFD97706);
      case StockDocumentType.opening:
        return const Color(0xFF7C3AED);
      default:
        return AppColors.primary;
    }
  }

  IconData _getDocTypeIcon(String type) {
    switch (type) {
      case StockDocumentType.receipt:
        return Icons.call_received_rounded;
      case StockDocumentType.issue:
        return Icons.call_made_rounded;
      case StockDocumentType.transfer:
        return Icons.compare_arrows_rounded;
      case StockDocumentType.adjustment:
        return Icons.tune_rounded;
      case StockDocumentType.opening:
        return Icons.flag_rounded;
      default:
        return Icons.inventory_2_rounded;
    }
  }
}
