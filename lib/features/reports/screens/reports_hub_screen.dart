import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../fixed_assets/screens/fixed_assets_screen.dart';
import '../../organizations/data/organization_repository.dart';
import '../../organizations/models/organization_model.dart';
import 'account_activity_screen.dart';
import 'audit_log_screen.dart';
import 'balance_sheet_screen.dart';
import 'bank_reconciliation_screen.dart';
import 'cash_bank_movement_screen.dart';
import 'general_ledger_screen.dart';
import 'income_statement_screen.dart';
import 'opening_balances_report_screen.dart';
import 'outstanding_invoices_report_screen.dart';
import 'party_statement_screen.dart';
import 'realized_forex_report_screen.dart';
import 'trial_balance_screen.dart';

/// Screen presenting the main Reports Hub (Tab 3 in bottom navigation).
/// Groups all 12 core financial reports into clear, logical accounting sections.
class ReportsHubScreen extends StatefulWidget {
  final VoidCallback? onBackToDashboard;

  const ReportsHubScreen({
    super.key,
    this.onBackToDashboard,
  });

  @override
  State<ReportsHubScreen> createState() => _ReportsHubScreenState();
}

class _ReportsHubScreenState extends State<ReportsHubScreen> {
  final OrganizationRepository _orgRepo = OrganizationRepository();
  Organization? _activeOrg;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrg();
  }

  Future<void> _loadOrg() async {
    setState(() => _isLoading = true);
    try {
      final activeId = await _orgRepo.getActiveOrganizationId();
      Organization? org;
      if (activeId != null) {
        org = await _orgRepo.getOrganizationById(activeId);
      } else {
        final list = await _orgRepo.getAllOrganizations(includeArchived: false);
        if (list.isNotEmpty) org = list.first;
      }
      if (mounted) {
        setState(() {
          _activeOrg = org ??
              Organization(
                id: 'default',
                name: 'المؤسسة النشطة',
                code: 'MAIN',
                baseCurrencyCode: 'YER',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _activeOrg = Organization(
            id: 'default',
            name: 'المؤسسة النشطة',
            code: 'MAIN',
            baseCurrencyCode: 'YER',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          _isLoading = false;
        });
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
                'التقارير والقوائم المالية',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkNavy,
                ),
              ),
              if (_activeOrg != null)
                Text(
                  '${_activeOrg!.name} • العملة: ${_activeOrg!.currencyLabel}',
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
              onPressed: _loadOrg,
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : _activeOrg == null
                ? const Center(child: Text('يرجى تحديد أو إنشاء مؤسسة أولاً'))
                : RefreshIndicator(
                    onRefresh: _loadOrg,
                    color: AppColors.primary,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Header Banner
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color:
                                    AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.analytics_rounded,
                                  color: AppColors.primary, size: 28),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'تُحسب جميع القوائم والتقارير المالية لحظياً وتلقائياً من واقع القيود المحاسبية المرحّلة في دفتر الأستاذ العام.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Section 1: Financial Statements (القوائم المالية الأساسية)
                        _buildSectionHeader(
                            'القوائم المالية الأساسية', AppColors.primary),
                        const SizedBox(height: 10),

                        // 1. Trial Balance
                        _buildReportTile(
                          title: 'ميزان المراجعة',
                          subtitle:
                              'إجمالي الحركات والأرصدة المدينة والدائنة والتحقق من التوازن',
                          icon: Icons.scale_rounded,
                          color: const Color(0xFF2563EB),
                          bgColor: const Color(0xFFEFF6FF),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TrialBalanceScreen(
                                  organizationId: _activeOrg!.id,
                                  baseCurrencyCode:
                                      _activeOrg!.baseCurrencyCode,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),

                        // 2. Income Statement
                        _buildReportTile(
                          title: 'قائمة الدخل (الأرباح والخسائر)',
                          subtitle:
                              'الإيرادات، المصروفات، وتحديد صافي نتيجة النشاط',
                          icon: Icons.trending_up_rounded,
                          color: const Color(0xFF059669),
                          bgColor: const Color(0xFFECFDF5),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => IncomeStatementScreen(
                                  organizationId: _activeOrg!.id,
                                  baseCurrencyCode:
                                      _activeOrg!.baseCurrencyCode,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),

                        // 3. Balance Sheet
                        _buildReportTile(
                          title: 'الميزانية العمومية (المركز المالي)',
                          subtitle:
                              'الأصول، الخصوم، حقوق الملكية ومعادلة المركز المالي',
                          icon: Icons.account_balance_rounded,
                          color: const Color(0xFF7C3AED),
                          bgColor: const Color(0xFFF5F3FF),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BalanceSheetScreen(
                                  organizationId: _activeOrg!.id,
                                  baseCurrencyCode:
                                      _activeOrg!.baseCurrencyCode,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // Section 2: Ledgers and Movements (الدفاتر والحركات المحاسبية التفصيلية)
                        _buildSectionHeader(
                            'الدفاتر والحركات المحاسبية التفصيلية',
                            const Color(0xFFD97706)),
                        const SizedBox(height: 10),

                        // 4. General Ledger
                        _buildReportTile(
                          title: 'دفتر الأستاذ العام',
                          subtitle:
                              'كشف حركة الحسابات التفصيلي والرصيد التراكمي التاريخي',
                          icon: Icons.menu_book_rounded,
                          color: const Color(0xFFD97706),
                          bgColor: const Color(0xFFFFFBEB),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GeneralLedgerScreen(
                                  organizationId: _activeOrg!.id,
                                  baseCurrencyCode:
                                      _activeOrg!.baseCurrencyCode,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),

                        // 5. Cash and Bank Movements
                        _buildReportTile(
                          title: 'حركة الصندوق والبنوك',
                          subtitle:
                              'متابعة السيولة النقدية، المقبوضات والمدفوعات اللحظية',
                          icon: Icons.account_balance_wallet_rounded,
                          color: const Color(0xFF0284C7),
                          bgColor: const Color(0xFFF0F9FF),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CashBankMovementScreen(
                                  organizationId: _activeOrg!.id,
                                  baseCurrencyCode:
                                      _activeOrg!.baseCurrencyCode,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),

                        // 6. Bank Reconciliation
                        _buildReportTile(
                          title: 'التسوية البنكية (Bank Reconciliation)',
                          subtitle:
                              'مطابقة كشف حساب البنك مع الحركات الدفترية واحتساب الفارق',
                          icon: Icons.fact_check_rounded,
                          color: const Color(0xFF0D9488),
                          bgColor: const Color(0xFFF0FDFA),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BankReconciliationScreen(
                                  organizationId: _activeOrg!.id,
                                  baseCurrencyCode:
                                      _activeOrg!.baseCurrencyCode,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),

                        // 7. Audit Trail
                        _buildReportTile(
                          title: 'سجل التدقيق والرقابة المالية',
                          subtitle:
                              'توثيق عمليات الترحيل والإلغاء والتعديلات لضمان النزاهة',
                          icon: Icons.security_rounded,
                          color: const Color(0xFF475569),
                          bgColor: const Color(0xFFF1F5F9),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AuditLogScreen(
                                  organizationId: _activeOrg!.id,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),

                        // 7. Account Activity
                        _buildReportTile(
                          title: 'تقرير حركة الحساب والعمليات',
                          subtitle:
                              'فلترة حركات الحسابات حسب الطرف، التاريخ، ونوع السند المحاسبي',
                          icon: Icons.swap_horiz_rounded,
                          color: const Color(0xFF4F46E5),
                          bgColor: const Color(0xFFEEF2FF),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AccountActivityScreen(
                                  organizationId: _activeOrg!.id,
                                  baseCurrencyCode:
                                      _activeOrg!.baseCurrencyCode,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),

                        // 8. Opening Balances
                        _buildReportTile(
                          title: 'تقرير الأرصدة الافتتاحية التأسيسية',
                          subtitle:
                              'أرصدة بداية النشاط والحسابات التأسيسية وتوازن القيد الافتتاحي',
                          icon: Icons.flag_rounded,
                          color: const Color(0xFF6366F1),
                          bgColor: const Color(0xFFEEF2FF),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OpeningBalancesReportScreen(
                                  organizationId: _activeOrg!.id,
                                  baseCurrencyCode:
                                      _activeOrg!.baseCurrencyCode,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // Section 3: Customers, Suppliers & Outstanding (العملاء والموردين والذمم)
                        _buildSectionHeader('تقارير العملاء والموردين والذمم',
                            const Color(0xFF0D9488)),
                        const SizedBox(height: 10),

                        // 9. Customer Statements
                        _buildReportTile(
                          title: 'كشوف حسابات العملاء',
                          subtitle:
                              'كشف حركة حساب العميل التفصيلي، الفواتير والسندات والرصيد المستحق',
                          icon: Icons.people_alt_rounded,
                          color: const Color(0xFF0D9488),
                          bgColor: const Color(0xFFF0FDFA),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PartyStatementScreen(
                                  organizationId: _activeOrg!.id,
                                  baseCurrencyCode:
                                      _activeOrg!.baseCurrencyCode,
                                  isCustomer: true,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),

                        // 10. Supplier Statements
                        _buildReportTile(
                          title: 'كشوف حسابات الموردين',
                          subtitle:
                              'كشف حساب المورد، فواتير المشتريات والمدفوعات والمستحقات',
                          icon: Icons.local_shipping_rounded,
                          color: const Color(0xFF0284C7),
                          bgColor: const Color(0xFFF0F9FF),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PartyStatementScreen(
                                  organizationId: _activeOrg!.id,
                                  baseCurrencyCode:
                                      _activeOrg!.baseCurrencyCode,
                                  isCustomer: false,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),

                        // 11. Outstanding Receivables
                        _buildReportTile(
                          title: 'الذمم المدينة المستحقة وأعمار الديون',
                          subtitle:
                              'فواتير المبيعات الآجلة غير المسددة وتحليل أعمار الديون (30/60/90+ يوم)',
                          icon: Icons.pending_actions_rounded,
                          color: const Color(0xFFE11D48),
                          bgColor: const Color(0xFFFFF1F2),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OutstandingInvoicesReportScreen(
                                  organizationId: _activeOrg!.id,
                                  baseCurrencyCode:
                                      _activeOrg!.baseCurrencyCode,
                                  isReceivable: true,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),

                        // 12. Outstanding Payables
                        _buildReportTile(
                          title: 'الذمم الدائنة المستحقة للموردين',
                          subtitle:
                              'فواتير المشتريات الآجلة غير المسددة وجداول استحقاق الموردين',
                          icon: Icons.receipt_long_rounded,
                          color: const Color(0xFFD97706),
                          bgColor: const Color(0xFFFFFBEB),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OutstandingInvoicesReportScreen(
                                  organizationId: _activeOrg!.id,
                                  baseCurrencyCode:
                                      _activeOrg!.baseCurrencyCode,
                                  isReceivable: false,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // Section 4: Forex & Currency Differences (أرباح وخسائر فروق العملة)
                        _buildSectionHeader('فروق أسعار الصرف والعملات',
                            const Color(0xFFB45309)),
                        const SizedBox(height: 10),

                        // Realized Forex Report
                        _buildReportTile(
                          title: 'أرباح وخسائر فروق العملة المحققة',
                          subtitle:
                              'فروقات أسعار الصرف الناتجة عن تسوية الفواتير والسندات بالعملات الأجنبية',
                          icon: Icons.currency_exchange_rounded,
                          color: const Color(0xFFB45309),
                          bgColor: const Color(0xFFFEF3C7),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RealizedForexReportScreen(
                                  organizationId: _activeOrg!.id,
                                  baseCurrencyCode:
                                      _activeOrg!.baseCurrencyCode,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // Section 5: Fixed Assets & Depreciation
                        _buildSectionHeader(
                            'الأصول الثابتة والإهلاك', const Color(0xFF0F766E)),
                        const SizedBox(height: 10),

                        _buildReportTile(
                          title: 'سجل الأصول الثابتة ومجمع الإهلاك',
                          subtitle:
                              'إدارة الأصول، احتساب القسط الثابت، وترحيل قيود الإهلاك آلياً',
                          icon: Icons.account_balance_rounded,
                          color: const Color(0xFF0F766E),
                          bgColor: const Color(0xFFF0FDFA),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FixedAssetsScreen(
                                  organizationId: _activeOrg!.id,
                                  baseCurrencyCode:
                                      _activeOrg!.baseCurrencyCode,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.darkNavy,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
