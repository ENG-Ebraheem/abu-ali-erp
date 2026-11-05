import 'package:flutter/material.dart';
import 'package:abu_ali/core/constants/app_colors.dart';
import 'package:abu_ali/core/theme/app_theme.dart';
import '../data/inventory_repository.dart';
import '../models/stocktaking_session_model.dart';
import 'stocktaking_session_screen.dart';

/// Screen listing physical stocktaking sessions and launching new counts.
class StocktakingListScreen extends StatefulWidget {
  final String organizationId;

  const StocktakingListScreen({
    super.key,
    required this.organizationId,
  });

  @override
  State<StocktakingListScreen> createState() => _StocktakingListScreenState();
}

class _StocktakingListScreenState extends State<StocktakingListScreen> {
  final InventoryRepository _repo = InventoryRepository();

  List<StocktakingSessionModel> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repo.getStocktakingSessions(
        organizationId: widget.organizationId,
      );
      if (mounted) {
        setState(() {
          _sessions = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل جلسات الجرد: $e')),
        );
      }
    }
  }

  void _openStartSessionDialog() async {
    final whs = await _repo.getWarehouses(widget.organizationId);
    final cats = await _repo.getCategories(widget.organizationId);

    if (whs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إضافة مستودع أولاً للبدء في الجرد')),
      );
      return;
    }

    String selectedWhId = whs.first.id;
    String? selectedCatId;
    final notesCtrl = TextEditingController();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('بدء دورة جرد جديدة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedWhId,
                    decoration: const InputDecoration(labelText: 'المستودع المطلوب جرده *'),
                    items: whs
                        .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedWhId = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: selectedCatId,
                    decoration: const InputDecoration(labelText: 'تصنيف معين (اختياري)'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('جرد شامل لجميع الأصناف'),
                      ),
                      ...cats.map((c) => DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text(c.nameAr),
                          )),
                    ],
                    onChanged: (v) => setDialogState(() => selectedCatId = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات وهدف الجرد',
                      hintText: 'مثال: جرد نهاية الربع الأول',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _isLoading = true);
                  try {
                    final session = await _repo.startStocktakingSession(
                      organizationId: widget.organizationId,
                      warehouseId: selectedWhId,
                      categoryId: selectedCatId,
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                    );
                    _loadSessions();
                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StocktakingSessionScreen(
                          organizationId: widget.organizationId,
                          sessionId: session.id,
                        ),
                      ),
                    );
                  } catch (e) {
                    if (mounted) {
                      setState(() => _isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('خطأ في بدء الجرد: $e'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                  }
                },
                child: const Text('بدء الجرد الآن'),
              ),
            ],
          ),
        ),
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
          title: const Text('الجرد الدوري والمطابقة الفعلية'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadSessions,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openStartSessionDialog,
          icon: const Icon(Icons.playlist_add_check_rounded),
          label: const Text('جلسة جرد جديدة'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _sessions.isEmpty
                ? const Center(
                    child: Text('لا توجد جلسات جرد سابقة'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final s = _sessions[index];

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
                                builder: (_) => StocktakingSessionScreen(
                                  organizationId: widget.organizationId,
                                  sessionId: s.id,
                                ),
                              ),
                            );
                            _loadSessions();
                          },
                          leading: CircleAvatar(
                            backgroundColor: s.isPosted
                                ? const Color(0xFFECFDF5)
                                : const Color(0xFFEFF6FF),
                            child: Icon(
                              Icons.checklist_rounded,
                              color: s.isPosted
                                  ? AppColors.success
                                  : AppColors.primary,
                            ),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                s.sessionNumber,
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
                                  color: s.isPosted
                                      ? const Color(0xFFECFDF5)
                                      : const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  s.statusLabelAr,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: s.isPosted
                                        ? AppColors.success
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'المستودع: ${s.warehouseName ?? "الكل"} • ${s.startedAt.split("T").first}',
                                style: const TextStyle(fontSize: 12.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'الأصناف المجرودة: ${s.countedItems} من ${s.totalItems}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          trailing: const Icon(
                            Icons.chevron_left_rounded,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
