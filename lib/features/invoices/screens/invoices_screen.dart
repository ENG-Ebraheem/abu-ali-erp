import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../organizations/data/organization_repository.dart';
import '../../organizations/models/organization_model.dart';
import '../data/invoice_repository.dart';
import '../models/invoice_model.dart';
import '../widgets/invoice_card.dart';
import 'create_invoice_screen.dart';
import 'invoice_details_screen.dart';

/// Screen managing Sales and Purchase invoices with payment tracking.
class InvoicesScreen extends StatefulWidget {
  final String? organizationId;
  final VoidCallback? onBackToDashboard;

  const InvoicesScreen({
    super.key,
    this.organizationId,
    this.onBackToDashboard,
  });

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final InvoiceRepository _invoiceRepo = InvoiceRepository();
  final OrganizationRepository _orgRepo = OrganizationRepository();

  Organization? _activeOrg;
  List<InvoiceModel> _invoices = [];
  bool _isLoading = true;

  String _selectedType = 'ALL'; // 'ALL', 'SALES', 'PURCHASE'
  String _selectedPaymentStatus =
      'ALL'; // 'ALL', 'UNPAID', 'PARTIALLY_PAID', 'PAID'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
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
        final list = await _invoiceRepo.getInvoices(
          organizationId: org.id,
          invoiceType: _selectedType == 'ALL' ? null : _selectedType,
          paymentStatus:
              _selectedPaymentStatus == 'ALL' ? null : _selectedPaymentStatus,
          query: _searchQuery.isEmpty ? null : _searchQuery,
        );
        if (mounted) {
          setState(() {
            _activeOrg = org;
            _invoices = list;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _activeOrg = null;
            _invoices = [];
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openCreateScreen() {
    if (_activeOrg == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد أو إنشاء مؤسسة أولاً'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final initialType = _selectedType == 'PURCHASE' ? 'PURCHASE' : 'SALES';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateInvoiceScreen(
          organizationId: _activeOrg!.id,
          baseCurrencyCode: _activeOrg!.baseCurrencyCode,
          initialType: initialType,
        ),
      ),
    ).then((created) {
      if (created == true) {
        _loadInvoices();
      }
    });
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
                'إدارة الفواتير',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkNavy,
                ),
              ),
              if (_activeOrg != null)
                Text(
                  _activeOrg!.name,
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
              onPressed: _loadInvoices,
              tooltip: 'تحديث',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: null,
          onPressed: _openCreateScreen,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_shopping_cart_rounded),
          label: const Text(
            'فاتورة جديدة',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: Column(
          children: [
            // Filter Pills & Search
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      _searchQuery = val;
                      _loadInvoices();
                    },
                    decoration: InputDecoration(
                      hintText: 'البحث برقم الفاتورة، الطرف، أو الملاحظات...',
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.textSecondary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _searchQuery = '';
                                _loadInvoices();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Main Type Tabs
                  Row(
                    children: [
                      _buildTypeFilterChip('ALL', 'الكل'),
                      const SizedBox(width: 8),
                      _buildTypeFilterChip('SALES', 'المبيعات'),
                      const SizedBox(width: 8),
                      _buildTypeFilterChip('PURCHASE', 'المشتريات'),
                      const Spacer(),
                      Text(
                        '${_invoices.length} فاتورة',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Payment Status Filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPaymentStatusChip('ALL', 'حالة السداد: الكل'),
                        const SizedBox(width: 6),
                        _buildPaymentStatusChip('UNPAID', 'غير مسددة'),
                        const SizedBox(width: 6),
                        _buildPaymentStatusChip(
                            'PARTIALLY_PAID', 'مسددة جزئياً'),
                        const SizedBox(width: 6),
                        _buildPaymentStatusChip('PAID', 'مسددة بالكامل'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Invoices List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _invoices.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadInvoices,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _invoices.length,
                            itemBuilder: (context, index) {
                              final invoice = _invoices[index];
                              return InvoiceCard(
                                invoice: invoice,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => InvoiceDetailsScreen(
                                        invoiceId: invoice.id,
                                        organizationId: invoice.organizationId,
                                        baseCurrencyCode:
                                            _activeOrg?.baseCurrencyCode ??
                                                'YER',
                                      ),
                                    ),
                                  ).then((_) => _loadInvoices());
                                },
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeFilterChip(String key, String title) {
    final isSelected = _selectedType == key;
    return InkWell(
      onTap: () {
        setState(() => _selectedType = key);
        _loadInvoices();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentStatusChip(String key, String title) {
    final isSelected = _selectedPaymentStatus == key;
    return InkWell(
      onTap: () {
        setState(() => _selectedPaymentStatus = key);
        _loadInvoices();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkNavy : AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.darkNavy : AppColors.border,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'لا توجد فواتير مسجلة بعد',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.darkNavy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'أنشئ فواتير المبيعات للعملاء وفواتير المشتريات من الموردين مع الترحيل التلقائي لدفتر الأستاذ.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _openCreateScreen,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إنشاء فاتورة جديدة'),
            ),
          ],
        ),
      ),
    );
  }
}
