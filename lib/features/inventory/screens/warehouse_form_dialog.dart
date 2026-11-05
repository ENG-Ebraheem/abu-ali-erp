import 'package:flutter/material.dart';
import 'package:abu_ali/core/constants/app_colors.dart';
import '../models/warehouse_model.dart';

/// Dialog for creating or editing a warehouse.
class WarehouseFormDialog extends StatefulWidget {
  final String organizationId;
  final WarehouseModel? warehouse;
  final Future<void> Function(WarehouseModel warehouse) onSave;

  const WarehouseFormDialog({
    super.key,
    required this.organizationId,
    this.warehouse,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    required String organizationId,
    WarehouseModel? warehouse,
    required Future<void> Function(WarehouseModel warehouse) onSave,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WarehouseFormDialog(
        organizationId: organizationId,
        warehouse: warehouse,
        onSave: onSave,
      ),
    );
  }

  @override
  State<WarehouseFormDialog> createState() => _WarehouseFormDialogState();
}

class _WarehouseFormDialogState extends State<WarehouseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _responsibleController;
  late final TextEditingController _descController;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final w = widget.warehouse;
    _codeController = TextEditingController(text: w?.code ?? '');
    _nameController = TextEditingController(text: w?.name ?? '');
    _locationController = TextEditingController(text: w?.location ?? '');
    _responsibleController =
        TextEditingController(text: w?.responsiblePerson ?? '');
    _descController = TextEditingController(text: w?.description ?? '');
    _isActive = w?.isActive ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    _responsibleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final model = WarehouseModel(
        id: widget.warehouse?.id ??
            'wh_${widget.organizationId}_${DateTime.now().millisecondsSinceEpoch}',
        organizationId: widget.organizationId,
        code: _codeController.text.trim().toUpperCase(),
        name: _nameController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        responsiblePerson: _responsibleController.text.trim().isEmpty
            ? null
            : _responsibleController.text.trim(),
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        isActive: _isActive,
        createdAt: widget.warehouse?.createdAt ?? now,
        updatedAt: now,
      );

      await widget.onSave(model);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.warehouse != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? 'تعديل مستودع' : 'إضافة مستودع جديد',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkNavy,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  TextFormField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'رمز المستودع *',
                      hintText: 'مثال: WH-01',
                      prefixIcon: Icon(Icons.qr_code_rounded),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'يرجى إدخال رمز المستودع' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم المستودع *',
                      hintText: 'مثال: المستودع المركزي',
                      prefixIcon: Icon(Icons.warehouse_rounded),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'يرجى إدخال اسم المستودع' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'الموقع / العنوان',
                      hintText: 'مثال: شارع الزبيري - صنعاء',
                      prefixIcon: Icon(Icons.location_on_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _responsibleController,
                    decoration: const InputDecoration(
                      labelText: 'المسؤول عن المستودع',
                      hintText: 'اسم أمين المستودع',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات وتفاصيل',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    title: const Text('المستودع نشط وجاهز للعمليات'),
                    value: _isActive,
                    onChanged: (val) => setState(() => _isActive = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('إلغاء'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(isEditing ? 'حفظ التعديلات' : 'إضافة المستودع'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
