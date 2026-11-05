import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../organizations/data/organization_repository.dart';
import '../../organizations/models/organization_model.dart';
import '../data/account_repository.dart';
import '../models/account_model.dart';
import '../widgets/account_card.dart';
import '../widgets/account_form_sheet.dart';
import 'account_details_screen.dart';

/// Screen managing the organization's Chart of Accounts (COA) with tree and flat views.
class AccountsScreen extends StatefulWidget {
  final String? organizationId;
  final VoidCallback? onBackToDashboard;

  const AccountsScreen({
    super.key,
    this.organizationId,
    this.onBackToDashboard,
  });

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final AccountRepository _accountRepo = AccountRepository();
  final OrganizationRepository _orgRepo = OrganizationRepository();

  Organization? _activeOrg;
  List<AccountModel> _accounts = [];
  bool _isLoading = true;
  String _selectedCategory =
      'ALL'; // ALL, ASSET, LIABILITY, EQUITY, REVENUE, EXPENSE
  bool _isTreeView = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
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
        final type = _selectedCategory == 'ALL' ? null : _selectedCategory;
        final accList = _isTreeView
            ? await _accountRepo.getAccountsTree(org.id, type: type)
            : await _accountRepo.getAccountsFlat(org.id, type: type);

        if (mounted) {
          setState(() {
            _activeOrg = org;
            _accounts = accList;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _activeOrg = null;
            _accounts = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الحسابات: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  List<AccountModel> get _filteredList {
    if (_searchQuery.trim().isEmpty) return _accounts;
    final query = _searchQuery.trim().toLowerCase();
    return _accounts.where((a) {
      return a.accountCode.toLowerCase().contains(query) ||
          a.accountNameAr.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _seedDefaultCOA() async {
    if (_activeOrg == null) return;
    setState(() => _isLoading = true);
    try {
      await _accountRepo.seedStandardChartOfAccounts(
        _activeOrg!.id,
        _activeOrg!.baseCurrencyCode,
      );
      await _loadAccounts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت تهيئة شجرة الحسابات المحاسبية بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ في التهيئة: $e'),
              backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _openAddAccount() async {
    if (_activeOrg == null) return;
    final all = await _accountRepo.getAccountsFlat(_activeOrg!.id);
    if (!mounted) return;

    AccountFormSheet.show(
      context: context,
      organizationId: _activeOrg!.id,
      defaultCurrency: _activeOrg!.baseCurrencyCode,
      availableParents: all,
      onSave: (newAcc) async {
        await _accountRepo.createAccount(newAcc);
        await _loadAccounts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تمت إضافة حساب "${newAcc.accountNameAr}" بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
    );
  }

  void _openEditAccount(AccountModel acc) async {
    final all = await _accountRepo.getAccountsFlat(acc.organizationId);
    if (!mounted) return;

    AccountFormSheet.show(
      context: context,
      organizationId: acc.organizationId,
      defaultCurrency: _activeOrg?.baseCurrencyCode ?? 'YER',
      account: acc,
      availableParents: all,
      onSave: (updated) async {
        await _accountRepo.updateAccount(updated);
        await _loadAccounts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم تحديث "${updated.accountNameAr}" بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
    );
  }

  Future<void> _toggleActive(AccountModel acc) async {
    final newStatus = !acc.isActive;
    await _accountRepo.toggleAccountActive(
        acc.id, acc.organizationId, newStatus);
    await _loadAccounts();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus ? 'تم تفعيل الحساب' : 'تم تعطيل الحساب'),
          backgroundColor: newStatus ? AppColors.success : AppColors.warning,
        ),
      );
    }
  }

  Future<void> _confirmDelete(AccountModel acc) async {
    final hasTx =
        await _accountRepo.hasPostedTransactions(acc.id, acc.organizationId);
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
                  color: AppColors.warning, size: 24),
              SizedBox(width: 8),
              Text('لا يمكن الحذف'),
            ],
          ),
          content: Text(
            'حساب "${acc.accountNameAr}" يحتوي على حركات وقيود مرحلة.\nوفقاً للأصول المحاسبية لا يمكن حذف حساب يحتوي على حركات مالية.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد حذف الحساب'),
        content:
            Text('هل أنت متأكد من رغبتك في حذف حساب "${acc.accountNameAr}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await _accountRepo.deleteAccount(acc.id, acc.organizationId);
                await _loadAccounts();
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('تم حذف حساب "${acc.accountNameAr}" بنجاح'),
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
            child: const Text('حذف الحساب'),
          ),
        ],
      ),
    );
  }

  void _openDetails(AccountModel acc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountDetailsScreen(
          account: acc,
          onAccountChanged: _loadAccounts,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('دليل الحسابات (شجرة الحسابات)',
                style: TextStyle(fontSize: 18)),
            if (_activeOrg != null)
              Text(
                'المؤسسة: ${_activeOrg!.name}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
          ],
        ),
        leading: widget.onBackToDashboard != null
            ? IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                onPressed: widget.onBackToDashboard,
              )
            : null,
        actions: [
          // View Switcher (Tree vs Flat)
          IconButton(
            icon: Icon(_isTreeView
                ? Icons.list_alt_rounded
                : Icons.account_tree_rounded),
            tooltip: _isTreeView ? 'عرض كقائمة مسطحة' : 'عرض كشجرة هرمية',
            onPressed: () {
              setState(() => _isTreeView = !_isTreeView);
              _loadAccounts();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAccounts,
            tooltip: 'تحديث الحسابات',
          ),
        ],
      ),
      floatingActionButton: _activeOrg != null
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: _openAddAccount,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'إضافة حساب',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: _loadAccounts,
              color: AppColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  // Search Box
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(
                        hintText: 'البحث برقم الحساب أو الاسم...',
                        hintStyle:
                            TextStyle(fontSize: 13, color: AppColors.textMuted),
                        border: InputBorder.none,
                        icon: Icon(Icons.search_rounded,
                            color: AppColors.textSecondary),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _CategoryChip(
                          label: 'الكل',
                          isSelected: _selectedCategory == 'ALL',
                          onTap: () {
                            setState(() => _selectedCategory = 'ALL');
                            _loadAccounts();
                          },
                        ),
                        const SizedBox(width: 8),
                        _CategoryChip(
                          label: '1 الأصول',
                          isSelected: _selectedCategory == 'ASSET',
                          onTap: () {
                            setState(() => _selectedCategory = 'ASSET');
                            _loadAccounts();
                          },
                        ),
                        const SizedBox(width: 8),
                        _CategoryChip(
                          label: '2 الخصوم',
                          isSelected: _selectedCategory == 'LIABILITY',
                          onTap: () {
                            setState(() => _selectedCategory = 'LIABILITY');
                            _loadAccounts();
                          },
                        ),
                        const SizedBox(width: 8),
                        _CategoryChip(
                          label: '3 حقوق الملكية',
                          isSelected: _selectedCategory == 'EQUITY',
                          onTap: () {
                            setState(() => _selectedCategory = 'EQUITY');
                            _loadAccounts();
                          },
                        ),
                        const SizedBox(width: 8),
                        _CategoryChip(
                          label: '4 الإيرادات',
                          isSelected: _selectedCategory == 'REVENUE',
                          onTap: () {
                            setState(() => _selectedCategory = 'REVENUE');
                            _loadAccounts();
                          },
                        ),
                        const SizedBox(width: 8),
                        _CategoryChip(
                          label: '5 المصروفات',
                          isSelected: _selectedCategory == 'EXPENSE',
                          onTap: () {
                            setState(() => _selectedCategory = 'EXPENSE');
                            _loadAccounts();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Empty State or Account List
                  if (_filteredList.isEmpty)
                    _buildEmptyState()
                  else
                    ..._buildAccountWidgets(_filteredList),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildAccountWidgets(List<AccountModel> list) {
    if (_isTreeView) {
      final widgets = <Widget>[];
      for (final root in list) {
        _renderTreeNode(root, 0, widgets);
      }
      return widgets;
    } else {
      return list.map((acc) {
        return AccountCard(
          account: acc,
          depth: 0,
          onTap: () => _openDetails(acc),
          onEdit: () => _openEditAccount(acc),
          onToggleActive: () => _toggleActive(acc),
          onDelete: () => _confirmDelete(acc),
        );
      }).toList();
    }
  }

  void _renderTreeNode(AccountModel node, int depth, List<Widget> out) {
    out.add(
      AccountCard(
        account: node,
        depth: depth,
        onTap: () => _openDetails(node),
        onEdit: () => _openEditAccount(node),
        onToggleActive: () => _toggleActive(node),
        onDelete: () => _confirmDelete(node),
      ),
    );
    for (final child in node.children) {
      _renderTreeNode(child, depth + 1, out);
    }
  }

  Widget _buildEmptyState() {
    final hasNoAccountsAtAll = _accounts.isEmpty && _selectedCategory == 'ALL';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.account_balance_outlined,
              size: 38,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasNoAccountsAtAll
                ? 'دليل الحسابات فارغ حالياً'
                : 'لا توجد حسابات مطابقة لمعايير البحث',
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.bold,
              color: AppColors.darkNavy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasNoAccountsAtAll
                ? 'يمكنك إنشاء شجرة الحسابات المحاسبية المعيارية بنقرة واحدة أو إضافة حساباتك يدوياً.'
                : 'جرّب البحث باسم آخر أو إزالة التصفية.',
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (hasNoAccountsAtAll && _activeOrg != null) ...[
            ElevatedButton.icon(
              onPressed: _seedDefaultCOA,
              icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
              label: const Text('تهيئة شجرة الحسابات الافتراضية'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _openAddAccount,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('إضافة حساب يدوياً'),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkNavy : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.darkNavy : AppColors.border,
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
