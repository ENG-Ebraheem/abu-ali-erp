import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../organizations/data/organization_repository.dart';
import '../../organizations/models/organization_model.dart';
import '../data/party_repository.dart';
import '../models/party_model.dart';
import '../widgets/party_card.dart';
import '../widgets/party_form_sheet.dart';
import 'party_details_screen.dart';

/// Screen managing Customers and Suppliers for the active organization.
class PartiesScreen extends StatefulWidget {
  final String? organizationId;
  final VoidCallback? onBackToDashboard;

  const PartiesScreen({
    super.key,
    this.organizationId,
    this.onBackToDashboard,
  });

  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen> {
  final PartyRepository _partyRepo = PartyRepository();
  final OrganizationRepository _orgRepo = OrganizationRepository();

  Organization? _activeOrg;
  List<PartyModel> _parties = [];
  bool _isLoading = true;
  String _selectedFilter = 'ALL'; // 'ALL', 'CUSTOMER', 'SUPPLIER'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadParties();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadParties() async {
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
        final list = await _partyRepo.getParties(
          organizationId: org.id,
          partyType: _selectedFilter == 'ALL' ? null : _selectedFilter,
          query: _searchQuery.isEmpty ? null : _searchQuery,
          includeInactive: true,
        );
        if (mounted) {
          setState(() {
            _activeOrg = org;
            _parties = list;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _activeOrg = null;
            _parties = [];
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openAddSheet() {
    if (_activeOrg == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد أو إنشاء مؤسسة أولاً'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final initialType = _selectedFilter == 'SUPPLIER' ? 'SUPPLIER' : 'CUSTOMER';

    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PartyFormSheet(
        organizationId: _activeOrg!.id,
        baseCurrencyCode: _activeOrg!.baseCurrencyCode,
        initialType: initialType,
      ),
    ).then((added) {
      if (added == true) {
        _loadParties();
      }
    });
  }

  void _openEditSheet(PartyModel party) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PartyFormSheet(
        organizationId: party.organizationId,
        baseCurrencyCode: _activeOrg?.baseCurrencyCode ?? 'YER',
        partyToEdit: party,
      ),
    ).then((updated) {
      if (updated == true) {
        _loadParties();
      }
    });
  }

  Future<void> _toggleActive(PartyModel party) async {
    try {
      await _partyRepo.togglePartyActive(
        party.id,
        party.organizationId,
        !party.isActive,
      );
      await _loadParties();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              party.isActive
                  ? 'تم أرشفة "${party.nameAr}"'
                  : 'تم إعادة تفعيل "${party.nameAr}"',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(PartyModel party) async {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد حذف الطرف المحاسبي'),
        content:
            Text('هل أنت متأكد من رغبتك في حذف "${party.nameAr}" نهائياً؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await _partyRepo.deleteParty(party.id, party.organizationId);
                await _loadParties();
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('تم حذف "${party.nameAr}" بنجاح'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
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
                'العملاء والموردون',
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
              onPressed: _loadParties,
              tooltip: 'تحديث',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: null,
          onPressed: _openAddSheet,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.person_add_rounded),
          label: const Text(
            'إضافة طرف',
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
                  // Search TextField
                  TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      _searchQuery = val;
                      _loadParties();
                    },
                    decoration: InputDecoration(
                      hintText: 'البحث بالاسم، الرمز، أو الهاتف...',
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.textSecondary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _searchQuery = '';
                                _loadParties();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filter tabs
                  Row(
                    children: [
                      _buildFilterChip('ALL', 'الكل'),
                      const SizedBox(width: 8),
                      _buildFilterChip('CUSTOMER', 'العملاء'),
                      const SizedBox(width: 8),
                      _buildFilterChip('SUPPLIER', 'الموردون'),
                      const Spacer(),
                      Text(
                        '${_parties.length} سجل',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Content List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _parties.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadParties,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _parties.length,
                            itemBuilder: (context, index) {
                              final party = _parties[index];
                              return PartyCard(
                                party: party,
                                baseCurrencyCode:
                                    _activeOrg?.baseCurrencyCode ?? 'YER',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PartyDetailsScreen(
                                        party: party,
                                        baseCurrencyCode:
                                            _activeOrg?.baseCurrencyCode ??
                                                'YER',
                                      ),
                                    ),
                                  ).then((_) => _loadParties());
                                },
                                onEdit: () => _openEditSheet(party),
                                onDelete: () => _confirmDelete(party),
                                onToggleActive: () => _toggleActive(party),
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

  Widget _buildFilterChip(String key, String title) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () {
        setState(() => _selectedFilter = key);
        _loadParties();
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
                Icons.people_outline_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'لا يوجد عملاء أو موردون بعد',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.darkNavy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'أضف العملاء والموردين لإدارة الأرصدة، الفواتير، وسندات الصرف والقبض.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _openAddSheet,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة عميل أو مورد'),
            ),
          ],
        ),
      ),
    );
  }
}
