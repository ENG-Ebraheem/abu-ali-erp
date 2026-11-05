import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../organizations/data/organization_repository.dart';
import '../../organizations/models/organization_model.dart';
import '../data/journal_repository.dart';
import '../models/journal_entry_model.dart';
import '../widgets/journal_entry_card.dart';
import 'create_journal_entry_screen.dart';
import 'journal_entry_details_screen.dart';

/// Screen managing general ledger journal entries, drafts, and postings.
class JournalEntriesScreen extends StatefulWidget {
  final String? organizationId;
  final VoidCallback? onBackToDashboard;

  const JournalEntriesScreen({
    super.key,
    this.organizationId,
    this.onBackToDashboard,
  });

  @override
  State<JournalEntriesScreen> createState() => _JournalEntriesScreenState();
}

class _JournalEntriesScreenState extends State<JournalEntriesScreen> {
  final JournalRepository _journalRepo = JournalRepository();
  final OrganizationRepository _orgRepo = OrganizationRepository();

  Organization? _activeOrg;
  List<JournalEntryModel> _entries = [];
  bool _isLoading = true;
  String _selectedStatus = 'ALL'; // 'ALL', 'POSTED', 'DRAFT', 'VOIDED'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
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
        final list = await _journalRepo.getJournalEntries(
          organizationId: org.id,
          status: _selectedStatus == 'ALL' ? null : _selectedStatus,
          query: _searchQuery.isEmpty ? null : _searchQuery,
        );
        if (mounted) {
          setState(() {
            _activeOrg = org;
            _entries = list;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _activeOrg = null;
            _entries = [];
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateJournalEntryScreen(
          organizationId: _activeOrg!.id,
          baseCurrencyCode: _activeOrg!.baseCurrencyCode,
        ),
      ),
    ).then((created) {
      if (created == true) {
        _loadEntries();
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
                'دفتر اليومية العامة',
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
              onPressed: _loadEntries,
              tooltip: 'تحديث',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: null,
          onPressed: _openCreateScreen,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.post_add_rounded),
          label: const Text(
            'قيد جديد',
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
                      _loadEntries();
                    },
                    decoration: InputDecoration(
                      hintText: 'البحث برقم القيد، البيان، أو المرجع...',
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.textSecondary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _searchQuery = '';
                                _loadEntries();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildFilterChip('ALL', 'الكل'),
                      const SizedBox(width: 8),
                      _buildFilterChip('POSTED', 'المرحّلة'),
                      const SizedBox(width: 8),
                      _buildFilterChip('DRAFT', 'المسودات'),
                      const SizedBox(width: 8),
                      _buildFilterChip('VOIDED', 'الملغية'),
                      const Spacer(),
                      Text(
                        '${_entries.length} قيد',
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

            // Entries List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _entries.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadEntries,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _entries.length,
                            itemBuilder: (context, index) {
                              final entry = _entries[index];
                              return JournalEntryCard(
                                entry: entry,
                                baseCurrencyCode:
                                    _activeOrg?.baseCurrencyCode ?? 'YER',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => JournalEntryDetailsScreen(
                                        entryId: entry.id,
                                        organizationId: entry.organizationId,
                                        baseCurrencyCode:
                                            _activeOrg?.baseCurrencyCode ??
                                                'YER',
                                      ),
                                    ),
                                  ).then((_) => _loadEntries());
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

  Widget _buildFilterChip(String key, String title) {
    final isSelected = _selectedStatus == key;
    return InkWell(
      onTap: () {
        setState(() => _selectedStatus = key);
        _loadEntries();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
            fontSize: 12,
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
                Icons.receipt_long_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'لا توجد قيود يومية مسجلة بعد',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.darkNavy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'سجل قيودك المحاسبية وفق نظام القيد المزدوج. يمكنك إنشاء قيود عامة، افتتاحية، أو تسويات.',
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
              label: const Text('إنشاء أول قيد يومية'),
            ),
          ],
        ),
      ),
    );
  }
}
