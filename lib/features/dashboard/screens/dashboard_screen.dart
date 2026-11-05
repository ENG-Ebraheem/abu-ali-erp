import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../accounts/screens/accounts_screen.dart';
import '../../accounts/screens/bank_transfer_screen.dart';
import '../../invoices/screens/create_invoice_screen.dart';
import '../../journal/data/journal_repository.dart';
import '../../journal/screens/create_journal_entry_screen.dart';
import '../../journal/screens/journal_entries_screen.dart';
import '../../journal/screens/journal_entry_details_screen.dart';
import '../../opening_balances/screens/opening_balances_screen.dart';
import '../../organizations/data/organization_repository.dart';
import '../../organizations/models/organization_model.dart';
import '../../organizations/screens/organizations_screen.dart';
import '../../payments/screens/create_payment_screen.dart';
import '../../reports/data/reports_repository.dart';
import '../../reports/screens/reports_hub_screen.dart';
import '../../inventory/screens/inventory_hub_screen.dart';
import '../../settings/screens/accountant_profile_screen.dart';
import '../../settings/screens/notifications_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/organization_selector_card.dart';
import '../widgets/financial_summary_section.dart';
import '../widgets/quick_actions_section.dart';
import '../widgets/recent_transactions_section.dart';
import '../widgets/dashboard_bottom_nav.dart';

/// The main dashboard screen for the Abu-Ali accounting system.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final OrganizationRepository _orgRepo = OrganizationRepository();
  final ReportsRepository _reportsRepo = ReportsRepository();
  final JournalRepository _journalRepo = JournalRepository();

  int _currentNavIndex = 0;
  Organization? _activeOrg;
  String _selectedOrganization = 'جارِ التحميل...';
  String _selectedCurrency = 'ريال يمني (YER)';

  // Financial Metrics State
  int _totalAssets = 0;
  int _totalLiabilities = 0;
  int _totalRevenue = 0;
  int _totalExpense = 0;
  bool _isLoadingMetrics = true;

  // Recent Transactions State
  List<TransactionItemData> _recentTransactions = [];
  bool _isLoadingTransactions = true;

  @override
  void initState() {
    super.initState();
    _loadActiveOrganization();
  }

  Future<void> _loadActiveOrganization() async {
    try {
      Organization? org;
      final activeId = await _orgRepo.getActiveOrganizationId();
      if (activeId != null) {
        org = await _orgRepo.getOrganizationById(activeId);
      }

      if (org == null) {
        final list = await _orgRepo.getAllOrganizations(includeArchived: false);
        if (list.isNotEmpty) {
          org = list.first;
          await _orgRepo.setActiveOrganizationId(org.id);
        }
      }

      if (org != null && mounted) {
        setState(() {
          _activeOrg = org;
          _selectedOrganization = org!.name;
          _selectedCurrency = org.currencyLabel;
        });

        // Load metrics and transactions in parallel
        await Future.wait([
          _loadMetrics(org.id),
          _loadRecentTransactions(org.id),
        ]);
        return;
      }

      if (mounted) {
        setState(() {
          _activeOrg = null;
          _selectedOrganization = 'لا توجد مؤسسة مسجلة';
          _selectedCurrency = 'YER';
          _isLoadingMetrics = false;
          _isLoadingTransactions = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingMetrics = false;
          _isLoadingTransactions = false;
        });
      }
    }
  }

  Future<void> _loadMetrics(String orgId) async {
    setState(() => _isLoadingMetrics = true);
    try {
      final metrics = await _reportsRepo.getDashboardMetrics(orgId);
      if (!mounted) return;
      setState(() {
        _totalAssets = metrics['total_assets'] as int? ?? 0;
        _totalLiabilities = metrics['total_liabilities'] as int? ?? 0;
        _totalRevenue = metrics['total_revenue'] as int? ?? 0;
        _totalExpense = metrics['total_expense'] as int? ?? 0;
        _isLoadingMetrics = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMetrics = false);
    }
  }

  Future<void> _loadRecentTransactions(String orgId) async {
    setState(() => _isLoadingTransactions = true);
    try {
      final entries = await _journalRepo.getJournalEntries(
        organizationId: orgId,
        limit: 5,
      );

      final items = entries.map((entry) {
        final isIncome = entry.entryType == 'RECEIPT' || entry.entryType == 'SALES';
        final amountPrefix = isIncome ? '+ ' : '- ';
        final amountFormatted = (entry.totalBaseDebit / 100.0).toStringAsFixed(2);

        IconData iconData = Icons.receipt_long_rounded;
        if (entry.entryType == 'SALES') {
          iconData = Icons.point_of_sale_rounded;
        } else if (entry.entryType == 'PURCHASE') {
          iconData = Icons.shopping_bag_outlined;
        } else if (entry.entryType == 'RECEIPT') {
          iconData = Icons.call_received_rounded;
        } else if (entry.entryType == 'PAYMENT') {
          iconData = Icons.call_made_rounded;
        } else if (entry.entryType == 'OPENING') {
          iconData = Icons.account_balance_wallet_outlined;
        }

        final title = entry.narration.trim().isNotEmpty
            ? entry.narration
            : '${entry.typeLabel} #${entry.entryNumber}';

        return TransactionItemData(
          id: entry.id,
          title: title,
          subtitle: '${entry.entryNumber} • ${entry.entryDate}',
          amount: '$amountPrefix$amountFormatted',
          currency: _activeOrg?.baseCurrencyCode ?? 'ر.ي',
          isIncome: isIncome,
          badgeText: entry.typeLabel,
          icon: iconData,
          entryType: entry.entryType,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _recentTransactions = items;
        _isLoadingTransactions = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingTransactions = false);
    }
  }

  void _showComingSoonSnackBar(String featureName) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'ميزة "$featureName" ستكون متاحة قريباً',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.darkNavy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openOrganizationSelector() async {
    List<Organization> orgs = [];
    try {
      orgs = await _orgRepo.getAllOrganizations(includeArchived: false);
    } catch (_) {}

    if (!mounted) return;

    if (orgs.isEmpty) {
      setState(() => _currentNavIndex = 1);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'تبديل المؤسسة',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkNavy,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'اختر المؤسسة النشطة للوصول إلى دفاترها المحاسبية',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ...orgs.map((org) {
                final isSelected = org.name == _selectedOrganization;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryLight
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color:
                            isSelected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.domain_rounded,
                        color:
                            isSelected ? Colors.white : AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      org.name,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                        color:
                            isSelected ? AppColors.primary : AppColors.darkNavy,
                      ),
                    ),
                    subtitle: Text(
                      '${org.code} • ${org.currencyLabel}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primary,
                            size: 22,
                          )
                        : null,
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _orgRepo.setActiveOrganizationId(org.id);
                      if (!mounted) return;
                      await _loadActiveOrganization();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('تم التبديل إلى: ${org.name}'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _onBottomNavTapped(int index) {
    setState(() => _currentNavIndex = index);
  }

  Future<void> _handleQuickAction(String actionTitle) async {
    if (actionTitle == 'إضافة حساب') {
      setState(() => _currentNavIndex = 2);
      return;
    }

    final currentOrg = _activeOrg;
    if (currentOrg == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى تحديد أو إنشاء مؤسسة أولاً'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    if (actionTitle == 'قيد يومية جديد') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateJournalEntryScreen(
            organizationId: currentOrg.id,
            baseCurrencyCode: currentOrg.baseCurrencyCode,
          ),
        ),
      );
      _loadActiveOrganization();
    } else if (actionTitle == 'فاتورة مبيعات' || actionTitle == 'فاتورة جديدة') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateInvoiceScreen(
            organizationId: currentOrg.id,
            baseCurrencyCode: currentOrg.baseCurrencyCode,
            initialType: 'SALES',
          ),
        ),
      );
      _loadActiveOrganization();
    } else if (actionTitle == 'فاتورة مشتريات') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateInvoiceScreen(
            organizationId: currentOrg.id,
            baseCurrencyCode: currentOrg.baseCurrencyCode,
            initialType: 'PURCHASE',
          ),
        ),
      );
      _loadActiveOrganization();
    } else if (actionTitle == 'سند قبض') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreatePaymentScreen(
            organizationId: currentOrg.id,
            baseCurrencyCode: currentOrg.baseCurrencyCode,
            initialType: 'RECEIPT',
          ),
        ),
      );
      _loadActiveOrganization();
    } else if (actionTitle == 'سند صرف') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreatePaymentScreen(
            organizationId: currentOrg.id,
            baseCurrencyCode: currentOrg.baseCurrencyCode,
            initialType: 'PAYMENT',
          ),
        ),
      );
      _loadActiveOrganization();
    } else if (actionTitle == 'تحويل نقدي') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BankTransferScreen(
            organizationId: currentOrg.id,
            baseCurrencyCode: currentOrg.baseCurrencyCode,
          ),
        ),
      );
      _loadActiveOrganization();
    } else if (actionTitle == 'أرصدة افتتاحية') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OpeningBalancesScreen(
            organizationId: currentOrg.id,
          ),
        ),
      );
      _loadActiveOrganization();
    } else {
      _showComingSoonSnackBar(actionTitle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeId = _activeOrg?.id ?? 'none';

    return PopScope(
      canPop: _currentNavIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentNavIndex != 0) {
          setState(() => _currentNavIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(
          index: _currentNavIndex,
          children: [
            // Index 0: Main Dashboard
            _buildDashboardContent(),
            // Index 1: Organizations Management
            OrganizationsScreen(
              key: ValueKey('orgs_$activeId'),
              onBackToDashboard: () => setState(() => _currentNavIndex = 0),
              onOrganizationSelected: (org) async {
                await _orgRepo.setActiveOrganizationId(org.id);
                if (mounted) {
                  await _loadActiveOrganization();
                }
              },
            ),
            // Index 2: Chart of Accounts
            AccountsScreen(
              key: ValueKey('accounts_$activeId'),
              organizationId: _activeOrg?.id,
              onBackToDashboard: () => setState(() => _currentNavIndex = 0),
            ),
            // Index 3: Financial Reports Hub
            ReportsHubScreen(
              key: ValueKey('reports_$activeId'),
              onBackToDashboard: () => setState(() => _currentNavIndex = 0),
            ),
            // Index 4: System Settings
            SettingsScreen(
              key: ValueKey('settings_$activeId'),
              onBackToDashboard: () => setState(() => _currentNavIndex = 0),
            ),
          ],
        ),
        bottomNavigationBar: DashboardBottomNav(
          currentIndex: _currentNavIndex,
          onTap: _onBottomNavTapped,
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await _loadActiveOrganization();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث بيانات لوحة التحكم'),
              duration: Duration(seconds: 1),
            ),
          );
        },
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A. Header
              DashboardHeader(
                onNotificationTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                },
                onProfileTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AccountantProfileScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),

              // B. Organization Selector
              OrganizationSelectorCard(
                organizationName: _selectedOrganization,
                baseCurrency: _selectedCurrency,
                onSwitchTap: _openOrganizationSelector,
                onManageTap: () => setState(() => _currentNavIndex = 1),
              ),
              const SizedBox(height: 20),

              // C. Financial Summary (Live SQLite GL Metrics)
              FinancialSummarySection(
                totalAssets: _totalAssets,
                totalLiabilities: _totalLiabilities,
                totalRevenue: _totalRevenue,
                totalExpense: _totalExpense,
                currencySymbol: _activeOrg?.baseCurrencyCode ?? 'ر.ي',
                isLoading: _isLoadingMetrics,
                onCardTap: () => setState(() => _currentNavIndex = 3),
              ),
              const SizedBox(height: 16),

              // Inventory & Warehouses Banner Card
              InkWell(
                onTap: () async {
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InventoryHubScreen(
                        organizationId: _activeOrg?.id,
                      ),
                    ),
                  ).then((_) => _loadActiveOrganization());
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.warehouse_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إدارة المخزون والمستودعات',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkNavy,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'الأصناف، المستودعات، السندات، والجرد والتقارير الـ 12',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.chevron_left_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // D. Quick Actions
              QuickActionsSection(
                onActionTap: _handleQuickAction,
              ),
              const SizedBox(height: 20),

              // E. Recent Transactions (Live SQLite Journal Entries)
              RecentTransactionsSection(
                transactions: _recentTransactions,
                isLoading: _isLoadingTransactions,
                onViewAllTap: () {
                  if (_activeOrg != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JournalEntriesScreen(
                          organizationId: _activeOrg!.id,
                        ),
                      ),
                    ).then((_) => _loadActiveOrganization());
                  }
                },
                onTransactionTap: (tx) {
                  if (_activeOrg != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JournalEntryDetailsScreen(
                          entryId: tx.id,
                          organizationId: _activeOrg!.id,
                          baseCurrencyCode: _activeOrg!.baseCurrencyCode,
                        ),
                      ),
                    ).then((_) => _loadActiveOrganization());
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
