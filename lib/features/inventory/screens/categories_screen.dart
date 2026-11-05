import 'package:flutter/material.dart';
import 'package:abu_ali/core/constants/app_colors.dart';
import 'package:abu_ali/core/theme/app_theme.dart';
import '../data/inventory_repository.dart';
import '../models/item_category_model.dart';

/// Screen managing product and material categories.
class CategoriesScreen extends StatefulWidget {
  final String organizationId;

  const CategoriesScreen({
    super.key,
    required this.organizationId,
  });

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final InventoryRepository _repo = InventoryRepository();
  List<ItemCategoryModel> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repo.getCategories(widget.organizationId);
      if (mounted) {
        setState(() {
          _categories = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل التصنيفات: $e')),
        );
      }
    }
  }

  void _openAddEditCategory([ItemCategoryModel? category]) {
    final formKey = GlobalKey<FormState>();
    final codeCtrl = TextEditingController(text: category?.code ?? '');
    final nameArCtrl = TextEditingController(text: category?.nameAr ?? '');
    final nameEnCtrl = TextEditingController(text: category?.nameEn ?? '');
    final descCtrl = TextEditingController(text: category?.description ?? '');
    String? parentId = category?.parentId;
    bool isActive = category?.isActive ?? true;

    // Exclude current category and its children from parent dropdown
    final potentialParents = _categories
        .where((c) => category == null || c.id != category.id)
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              category == null ? 'إضافة تصنيف جديد' : 'تعديل التصنيف',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'رمز التصنيف *',
                        hintText: 'مثال: CAT-02',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'يرجى إدخال رمز التصنيف'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameArCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم التصنيف بالعربية *',
                        hintText: 'مثال: إلكترونيات، مواد غذائية',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'يرجى إدخال اسم التصنيف'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameEnCtrl,
                      decoration: const InputDecoration(
                        labelText: 'الاسم بالإنجليزية (اختياري)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: parentId,
                      decoration: const InputDecoration(
                        labelText: 'التصنيف الرئيسي (إن وجد)',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('تصنيف رئيسي (بدون أب)'),
                        ),
                        ...potentialParents.map((p) => DropdownMenuItem<String?>(
                              value: p.id,
                              child: Text('${p.nameAr} (${p.code})'),
                            )),
                      ],
                      onChanged: (val) => setDialogState(() => parentId = val),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات وتفاصيل',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('نشط'),
                      value: isActive,
                      onChanged: (v) => setDialogState(() => isActive = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
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
                  final model = ItemCategoryModel(
                    id: category?.id ??
                        'cat_${widget.organizationId}_${DateTime.now().millisecondsSinceEpoch}',
                    organizationId: widget.organizationId,
                    code: codeCtrl.text.trim().toUpperCase(),
                    nameAr: nameArCtrl.text.trim(),
                    nameEn: nameEnCtrl.text.trim().isEmpty
                        ? null
                        : nameEnCtrl.text.trim(),
                    parentId: parentId,
                    description: descCtrl.text.trim().isEmpty
                        ? null
                        : descCtrl.text.trim(),
                    isActive: isActive,
                    createdAt: category?.createdAt ?? now,
                    updatedAt: now,
                  );

                  try {
                    if (category == null) {
                      await _repo.createCategory(model);
                    } else {
                      await _repo.updateCategory(model);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadCategories();
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
                child: Text(category == null ? 'إضافة' : 'حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteCategory(ItemCategoryModel cat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد حذف التصنيف'),
          content: Text('هل أنت متأكد من حذف التصنيف "${cat.nameAr}"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        await _repo.deleteCategory(cat.id, widget.organizationId);
        _loadCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف التصنيف بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: AppColors.danger,
            ),
          );
        }
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
          title: const Text('تصنيفات الأصناف والمواد'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadCategories,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openAddEditCategory(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('تصنيف جديد'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _categories.isEmpty
                ? const Center(child: Text('لا توجد تصنيفات مسجلة'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final c = _categories[index];
                      final isSub = c.parentId != null;

                      return Container(
                        margin: EdgeInsets.only(
                          bottom: 10,
                          right: isSub ? 20 : 0,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSub
                                ? AppColors.secondary.withValues(alpha: 0.3)
                                : AppColors.border,
                          ),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isSub
                                  ? const Color(0xFFF0FDF4)
                                  : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isSub
                                  ? Icons.subdirectory_arrow_left_rounded
                                  : Icons.category_rounded,
                              color: isSub
                                  ? AppColors.success
                                  : AppColors.primary,
                              size: 20,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                c.nameAr,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  c.code,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            isSub
                                ? 'تابع لـ: ${c.parentNameAr ?? "أب"} • ${c.productCount} صنف'
                                : '${c.productCount} صنف مسجل',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 20, color: AppColors.primary),
                                onPressed: () => _openAddEditCategory(c),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 20, color: AppColors.danger),
                                onPressed: () => _deleteCategory(c),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
