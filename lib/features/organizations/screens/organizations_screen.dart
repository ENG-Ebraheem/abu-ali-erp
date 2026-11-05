import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../data/organization_repository.dart';
import '../models/organization_model.dart';
import '../widgets/organization_card.dart';
import '../widgets/organization_form_dialog.dart';
import 'organization_details_screen.dart';

/// Screen managing multi-tenant independent organizations with SQLite synchronization.
class OrganizationsScreen extends StatefulWidget {
  final VoidCallback? onBackToDashboard;
  final Function(Organization selectedOrg)? onOrganizationSelected;

  const OrganizationsScreen({
    super.key,
    this.onBackToDashboard,
    this.onOrganizationSelected,
  });

  @override
  State<OrganizationsScreen> createState() => _OrganizationsScreenState();
}

class _OrganizationsScreenState extends State<OrganizationsScreen> {
  final OrganizationRepository _repository = OrganizationRepository();

  List<Organization> _organizations = [];
  String? _activeOrganizationId;
  bool _isLoading = true;
  String _filter = 'ALL'; // 'ALL', 'ACTIVE', 'ARCHIVED'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repository.getAllOrganizations(includeArchived: true);
      final activeId = await _repository.getActiveOrganizationId();

      if (mounted) {
        setState(() {
          _organizations = list;
          _activeOrganizationId =
              activeId ?? (list.isNotEmpty ? list.first.id : null);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل المؤسسات: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  List<Organization> get _filteredOrganizations {
    switch (_filter) {
      case 'ACTIVE':
        return _organizations.where((org) => org.isActive).toList();
      case 'ARCHIVED':
        return _organizations.where((org) => !org.isActive).toList();
      default:
        return _organizations;
    }
  }

  Future<void> _selectActiveOrganization(Organization org) async {
    try {
      await _repository.setActiveOrganizationId(org.id);
      setState(() => _activeOrganizationId = org.id);

      widget.onOrganizationSelected?.call(org);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('تم تعيين "${org.name}" كمؤسسة نشطة'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('تعذر تعيين المؤسسة: $e'),
              backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _openAddOrganization() {
    OrganizationFormSheet.show(
      context: context,
      onSave: (newOrg) async {
        await _repository.createOrganization(newOrg);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تمت إضافة مؤسسة "${newOrg.name}" بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
    );
  }

  void _openEditOrganization(Organization org) {
    OrganizationFormSheet.show(
      context: context,
      organization: org,
      onSave: (updatedOrg) async {
        await _repository.updateOrganization(updatedOrg);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم تحديث بيانات "${updatedOrg.name}" بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
    );
  }

  Future<void> _toggleArchive(Organization org) async {
    final newStatus = !org.isActive;
    try {
      await _repository.setOrganizationActiveStatus(org.id, newStatus);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? 'تمت استعادة مؤسسة "${org.name}" وتفعيلها'
                  : 'تمت أرشفة مؤسسة "${org.name}" بنجاح',
            ),
            backgroundColor: newStatus ? AppColors.success : AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('تعذر تعديل الحالة: $e'),
              backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _confirmDelete(Organization org) async {
    final hasTx = await _repository.hasTransactions(org.id);

    if (!mounted) return;

    if (hasTx) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: AppColors.warning, size: 26),
              SizedBox(width: 8),
              Text('لا يمكن الحذف النهائي', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Text(
            'مؤسسة "${org.name}" تحتوي على قيود محاسبية أو فواتير مسجلة في النظام.\n\nوفقاً لمعايير المحاسبة، لا يمكن حذف سجل مالي مسجل. يمكنك أرشفتها بدلاً من الحذف لمنع المعاملات الجديدة مع الاحتفاظ بالبيانات التاريخية.',
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _toggleArchive(org);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
              ),
              child: const Text('أرشفة المؤسسة الآن'),
            ),
          ],
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    // Zero transactions: Confirm permanent delete
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded,
                color: AppColors.danger, size: 26),
            SizedBox(width: 8),
            Text('تأكيد الحذف النهائي', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف مؤسسة "${org.name}" بشكل نهائي؟\nهذا الإجراء لا يمكن التراجع عنه.',
          style: const TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await _repository.deleteOrganization(org.id);
                await _loadData();
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('تم حذف مؤسسة "${org.name}" بنجاح'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceAll('Exception: ', '')),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('نعم، حذف نهائي'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredOrganizations;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('المؤسسات والشركات'),
        leading: widget.onBackToDashboard != null
            ? IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                onPressed: widget.onBackToDashboard,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
            tooltip: 'تحديث البيانات',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _openAddOrganization,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text(
          'إضافة مؤسسة',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  // Filter Chips & Summary count
                  Row(
                    children: [
                      _FilterChip(
                        label: 'الكل (${_organizations.length})',
                        isSelected: _filter == 'ALL',
                        onTap: () => setState(() => _filter = 'ALL'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label:
                            'النشطة (${_organizations.where((o) => o.isActive).length})',
                        isSelected: _filter == 'ACTIVE',
                        onTap: () => setState(() => _filter = 'ACTIVE'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label:
                            'المؤرشفة (${_organizations.where((o) => !o.isActive).length})',
                        isSelected: _filter == 'ARCHIVED',
                        onTap: () => setState(() => _filter = 'ARCHIVED'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Empty State or List
                  if (list.isEmpty)
                    _buildEmptyState()
                  else
                    ...list.map((org) {
                      final isSelected = org.id == _activeOrganizationId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: OrganizationCard(
                          organization: org,
                          isSelected: isSelected,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrganizationDetailsScreen(
                                  organization: org,
                                  onOrganizationUpdated: _loadData,
                                ),
                              ),
                            );
                          },
                          onSelectAsActive: () =>
                              _selectActiveOrganization(org),
                          onEdit: () => _openEditOrganization(org),
                          onToggleArchive: () => _toggleArchive(org),
                          onDelete: () => _confirmDelete(org),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    final isFiltered = _filter != 'ALL';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              isFiltered
                  ? Icons.filter_list_off_rounded
                  : Icons.domain_disabled_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isFiltered
                ? 'لا توجد مؤسسات مطابقة للفلتر'
                : 'لا توجد مؤسسات مسجلة بعد',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.darkNavy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered
                ? 'جرّب تغيير خيار التصفية لعرض باقي المؤسسات.'
                : 'ابدأ بإضافة مؤسستك التجارية الأولى لإنشاء دفاتر الحسابات ودليل شجرة الحسابات.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          if (!isFiltered)
            ElevatedButton.icon(
              onPressed: _openAddOrganization,
              icon: const Icon(Icons.add_business_rounded, size: 18),
              label: const Text('إضافة مؤسسة الآن'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
