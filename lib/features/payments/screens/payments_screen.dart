import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../organizations/data/organization_repository.dart';
import '../../organizations/models/organization_model.dart';
import '../data/payment_repository.dart';
import '../models/payment_model.dart';
import '../widgets/payment_card.dart';
import 'create_payment_screen.dart';
import 'payment_details_screen.dart';

/// Screen managing Payment Vouchers (Receipts and Disbursements) with GL tracking.
class PaymentsScreen extends StatefulWidget {
  final String? organizationId;
  final VoidCallback? onBackToDashboard;

  const PaymentsScreen({
    super.key,
    this.organizationId,
    this.onBackToDashboard,
  });

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final PaymentRepository _paymentRepo = PaymentRepository();
  final OrganizationRepository _orgRepo = OrganizationRepository();

  Organization? _activeOrg;
  List<PaymentModel> _payments = [];
  bool _isLoading = true;

  String _selectedType = 'ALL'; // 'ALL', 'RECEIPT', 'PAYMENT'
  String _selectedStatus = 'ALL'; // 'ALL', 'POSTED', 'DRAFT', 'VOIDED'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPayments() async {
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
        final list = await _paymentRepo.getPayments(
          organizationId: org.id,
          paymentType: _selectedType == 'ALL' ? null : _selectedType,
          status: _selectedStatus == 'ALL' ? null : _selectedStatus,
          query: _searchQuery.isEmpty ? null : _searchQuery,
        );
        if (mounted) {
          setState(() {
            _activeOrg = org;
            _payments = list;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _activeOrg = null;
            _payments = [];
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

    final initialType = _selectedType == 'PAYMENT' ? 'PAYMENT' : 'RECEIPT';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePaymentScreen(
          organizationId: _activeOrg!.id,
          baseCurrencyCode: _activeOrg!.baseCurrencyCode,
          initialType: initialType,
        ),
      ),
    ).then((created) {
      if (created == true) {
        _loadPayments();
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
                'سندات القبض والصرف',
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
              onPressed: _loadPayments,
              tooltip: 'تحديث',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: null,
          onPressed: _openCreateScreen,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.payments_rounded),
          label: const Text(
            'سند جديد',
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
                      _loadPayments();
                    },
                    decoration: InputDecoration(
                      hintText: 'البحث برقم السند، الطرف، أو المرجع...',
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.textSecondary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _searchQuery = '';
                                _loadPayments();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filter Type Pills
                  Row(
                    children: [
                      _buildTypeFilterChip('ALL', 'الكل'),
                      const SizedBox(width: 8),
                      _buildTypeFilterChip('RECEIPT', 'سندات قبض'),
                      const SizedBox(width: 8),
                      _buildTypeFilterChip('PAYMENT', 'سندات صرف'),
                      const Spacer(),
                      Text(
                        '${_payments.length} سند',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Status Pills
                  Row(
                    children: [
                      _buildStatusFilterChip('ALL', 'الحالة: الكل'),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip('POSTED', 'المرحّلة'),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip('DRAFT', 'المسودات'),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip('VOIDED', 'الملغية'),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Payments List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _payments.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadPayments,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _payments.length,
                            itemBuilder: (context, index) {
                              final payment = _payments[index];
                              return PaymentCard(
                                payment: payment,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PaymentDetailsScreen(
                                        paymentId: payment.id,
                                        organizationId: payment.organizationId,
                                        baseCurrencyCode:
                                            _activeOrg?.baseCurrencyCode ??
                                                'YER',
                                      ),
                                    ),
                                  ).then((_) => _loadPayments());
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
        _loadPayments();
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

  Widget _buildStatusFilterChip(String key, String title) {
    final isSelected = _selectedStatus == key;
    return InkWell(
      onTap: () {
        setState(() => _selectedStatus = key);
        _loadPayments();
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
                Icons.payments_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'لا توجد سندات قبض أو صرف بعد',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.darkNavy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'سجل مقبوضات العملاء ومصروفات الموردين وخصصها للفواتير غير المسددة مع الترحيل التلقائي.',
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
              label: const Text('تسجيل سند جديد'),
            ),
          ],
        ),
      ),
    );
  }
}
