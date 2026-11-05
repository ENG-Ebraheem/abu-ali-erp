import 'package:flutter/material.dart';
import 'package:abu_ali/core/constants/app_colors.dart';
import 'package:abu_ali/core/theme/app_theme.dart';
import '../data/inventory_repository.dart';
import '../models/unit_of_measure_model.dart';

/// Screen managing units of measure (UoM).
class UnitsScreen extends StatefulWidget {
  final String organizationId;

  const UnitsScreen({
    super.key,
    required this.organizationId,
  });

  @override
  State<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends State<UnitsScreen> {
  final InventoryRepository _repo = InventoryRepository();
  List<UnitOfMeasureModel> _units = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repo.getUnitsOfMeasure(widget.organizationId);
      if (mounted) {
        setState(() {
          _units = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل وحدات القياس: $e')),
        );
      }
    }
  }

  void _openAddEditUnit([UnitOfMeasureModel? unit]) {
    final formKey = GlobalKey<FormState>();
    final codeCtrl = TextEditingController(text: unit?.code ?? '');
    final nameArCtrl = TextEditingController(text: unit?.nameAr ?? '');
    final symbolCtrl = TextEditingController(text: unit?.symbol ?? '');

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            unit == null ? 'إضافة وحدة قياس' : 'تعديل وحدة القياس',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'رمز الوحدة *',
                    hintText: 'مثال: PCS, BOX, KG, L',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'يرجى إدخال الرمز' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameArCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم الوحدة بالعربية *',
                    hintText: 'مثال: حبة، كرتون، كيلوجرام',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'يرجى إدخال الاسم' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: symbolCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الرمز المختصر',
                    hintText: 'مثال: حبة، كجم، لتر',
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
                if (!formKey.currentState!.validate()) return;
                final now = DateTime.now().toUtc().toIso8601String();
                final model = UnitOfMeasureModel(
                  id: unit?.id ??
                      'uom_${widget.organizationId}_${codeCtrl.text.trim().toUpperCase()}',
                  organizationId: widget.organizationId,
                  code: codeCtrl.text.trim().toUpperCase(),
                  nameAr: nameArCtrl.text.trim(),
                  symbol: symbolCtrl.text.trim().isEmpty
                      ? null
                      : symbolCtrl.text.trim(),
                  isActive: true,
                  createdAt: unit?.createdAt ?? now,
                );

                try {
                  if (unit == null) {
                    await _repo.createUnitOfMeasure(model);
                  } else {
                    await _repo.updateUnitOfMeasure(model);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadUnits();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content:
                            Text(e.toString().replaceAll('Exception: ', '')),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                  }
                }
              },
              child: Text(unit == null ? 'إضافة' : 'حفظ'),
            ),
          ],
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
          title: const Text('وحدات القياس والتحويل'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadUnits,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openAddEditUnit(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('وحدة جديدة'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _units.isEmpty
                ? const Center(child: Text('لا توجد وحدات قياس'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: _units.length,
                    itemBuilder: (context, index) {
                      final u = _units[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFEFF6FF),
                            child: Text(
                              u.symbol ?? u.code,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          title: Text(
                            u.nameAr,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('الرمز القياسي: ${u.code}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                size: 20, color: AppColors.primary),
                            onPressed: () => _openAddEditUnit(u),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
