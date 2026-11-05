import 'package:flutter/material.dart';
import 'package:abu_ali/core/constants/app_colors.dart';
import 'package:abu_ali/core/theme/app_theme.dart';
import '../data/inventory_repository.dart';
import '../models/stocktaking_session_model.dart';
import 'stock_document_details_screen.dart';

/// Screen for conducting a physical stocktaking session and entering item counts.
class StocktakingSessionScreen extends StatefulWidget {
  final String organizationId;
  final String sessionId;

  const StocktakingSessionScreen({
    super.key,
    required this.organizationId,
    required this.sessionId,
  });

  @override
  State<StocktakingSessionScreen> createState() =>
      _StocktakingSessionScreenState();
}

class _StocktakingSessionScreenState extends State<StocktakingSessionScreen> {
  final InventoryRepository _repo = InventoryRepository();

  StocktakingSessionModel? _session;
  final Map<String, TextEditingController> _countControllers = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  void dispose() {
    for (final c in _countControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSession() async {
    setState(() => _isLoading = true);
    try {
      final s = await _repo.getStocktakingSessionById(
          widget.sessionId, widget.organizationId);
      if (mounted) {
        setState(() {
          _session = s;
          if (s != null) {
            for (final l in s.lines) {
              _countControllers[l.id] = TextEditingController(
                text: l.countedQuantity != null
                    ? (l.countedQuantity! / 1000.0).toString()
                    : '',
              );
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل جلسة الجرد: $e')),
        );
      }
    }
  }

  Future<void> _saveAllCounts() async {
    if (_session == null) return;
    setState(() => _isSaving = true);

    try {
      for (final l in _session!.lines) {
        final ctrl = _countControllers[l.id];
        if (ctrl != null && ctrl.text.trim().isNotEmpty) {
          final countedNum = double.tryParse(ctrl.text.trim()) ?? 0.0;
          final countedScaled = (countedNum * 1000).round();
          await _repo.updateStocktakingCount(
            lineId: l.id,
            organizationId: widget.organizationId,
            countedQuantity: countedScaled,
          );
        }
      }
      await _loadSession();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الكميات المجرودة بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحفظ: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _markCompleted() async {
    try {
      await _saveAllCounts();
      await _repo.completeStocktakingSession(
          widget.sessionId, widget.organizationId);
      await _loadSession();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنهاء جلسة الجرد بنجاح. جاهزة الآن للاعتماد والتسوية.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _postAdjustment() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('اعتماد نتائج الجرد وتوليد التسوية'),
          content: const Text(
            'سيتم توليد سند تسوية مخزنية آلي لجميع الفروقات (عجز أو فائض) وترحيله محاسبياً وتحديث أرصدة المستودع. هل تريد المتابعة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('اعتماد وتسوية'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      final adjDoc = await _repo.postStocktakingAdjustment(
          widget.sessionId, widget.organizationId);
      await _loadSession();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم توليد وترحيل سند التسوية رقم (${adjDoc.documentNumber}) بنجاح!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StockDocumentDetailsScreen(
              organizationId: widget.organizationId,
              documentId: adjDoc.id,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_session == null) {
      return const Scaffold(body: Center(child: Text('جلسة الجرد غير موجودة')));
    }

    final s = _session!;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('جرد: ${s.sessionNumber}'),
          actions: [
            if (!s.isPosted)
              IconButton(
                icon: const Icon(Icons.save_rounded),
                tooltip: 'حفظ الكميات',
                onPressed: _isSaving ? null : _saveAllCounts,
              ),
          ],
        ),
        bottomNavigationBar: !s.isPosted
            ? Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.surface,
                child: Row(
                  children: [
                    if (s.isInProgress) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : _markCompleted,
                          child: const Text('إكمال العد الفعلي'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _postAdjustment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text('اعتماد وتسوية الفروقات'),
                      ),
                    ),
                  ],
                ),
              )
            : null,
        body: Column(
          children: [
            // Session Info Header
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.sessionNumber,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkNavy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'المستودع: ${s.warehouseName ?? "الكل"}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: s.isPosted
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          s.statusLabelAr,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: s.isPosted
                                ? AppColors.success
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHeaderStat('الأصناف في الجرد', '${s.totalItems}'),
                      _buildHeaderStat('الأصناف المجرودة', '${s.countedItems}'),
                      _buildHeaderStat(
                        'صافي الفروقات',
                        (s.totalDifferenceValue / 100.0).toStringAsFixed(2),
                        color: s.totalDifferenceValue >= 0
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Lines List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                itemCount: s.lines.length,
                itemBuilder: (context, index) {
                  final l = s.lines[index];
                  final ctrl = _countControllers[l.id];
                  final sysQty = l.systemQuantity / 1000.0;
                  final diffQty = l.differenceQuantity != null
                      ? (l.differenceQuantity! / 1000.0)
                      : null;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: l.hasVariance
                            ? const Color(0xFFFCA5A5)
                            : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l.itemNameAr ?? l.itemId,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              l.itemCode ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('رصيد النظام',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary)),
                                  Text(
                                    '${sysQty.toStringAsFixed(1)} ${l.unitSymbol ?? ""}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: TextFormField(
                                controller: ctrl,
                                enabled: !s.isPosted,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'العدد الفعلي',
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('الفرق (عجز/فائض)',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary)),
                                  Text(
                                    diffQty != null
                                        ? '${diffQty > 0 ? "+" : ""}${diffQty.toStringAsFixed(1)}'
                                        : 'لم يجرد',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: diffQty == null
                                          ? AppColors.textSecondary
                                          : diffQty == 0
                                              ? AppColors.success
                                              : (diffQty > 0
                                                  ? AppColors.primary
                                                  : AppColors.danger),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildHeaderStat(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color ?? AppColors.darkNavy,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
