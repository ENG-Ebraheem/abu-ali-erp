import 'package:flutter/material.dart';
import 'package:abu_ali/core/constants/app_colors.dart';
import 'package:abu_ali/core/constants/database_constants.dart';
import 'package:abu_ali/features/accounts/data/account_repository.dart';
import 'package:abu_ali/features/accounts/models/account_model.dart';
import 'package:abu_ali/features/parties/data/party_repository.dart';
import 'package:abu_ali/features/parties/models/party_model.dart';
import '../data/inventory_repository.dart';
import '../models/item_model.dart';
import '../models/stock_document_line_model.dart';
import '../models/stock_document_model.dart';
import '../models/warehouse_model.dart';

/// Screen for creating stock documents (Receipt, Issue, Transfer, Adjustment, Opening).
class CreateStockDocumentScreen extends StatefulWidget {
  final String organizationId;
  final String? initialDocType;
  final StockDocumentModel? existingDocument;

  const CreateStockDocumentScreen({
    super.key,
    required this.organizationId,
    this.initialDocType,
    this.existingDocument,
  });

  @override
  State<CreateStockDocumentScreen> createState() =>
      _CreateStockDocumentScreenState();
}

class _CreateStockDocumentScreenState extends State<CreateStockDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final InventoryRepository _repo = InventoryRepository();
  final PartyRepository _partyRepo = PartyRepository();
  final AccountRepository _accRepo = AccountRepository();

  late String _documentType;
  late final TextEditingController _docNumberCtrl;
  late final TextEditingController _dateCtrl;
  late final TextEditingController _refCtrl;
  late final TextEditingController _notesCtrl;

  String? _sourceWarehouseId;
  String? _destinationWarehouseId;
  String? _partyId;

  List<WarehouseModel> _warehouses = [];
  List<PartyModel> _parties = [];
  List<AccountModel> _expenseAccounts = [];
  List<ItemModel> _allItems = [];

  final List<_DocLineDraft> _lines = [];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.existingDocument;
    _documentType =
        d?.documentType ?? widget.initialDocType ?? StockDocumentType.receipt;
    _docNumberCtrl = TextEditingController(text: d?.documentNumber ?? '');
    _dateCtrl = TextEditingController(
      text: d?.documentDate ??
          DateTime.now().toIso8601String().split('T').first,
    );
    _refCtrl = TextEditingController(text: d?.referenceNumber ?? '');
    _notesCtrl = TextEditingController(text: d?.notes ?? '');

    _sourceWarehouseId = d?.sourceWarehouseId;
    _destinationWarehouseId = d?.destinationWarehouseId;
    _partyId = d?.partyId;

    _loadPrerequisites();
  }

  @override
  void dispose() {
    _docNumberCtrl.dispose();
    _dateCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPrerequisites() async {
    setState(() => _isLoading = true);
    try {
      final whs = await _repo.getWarehouses(widget.organizationId);
      final parties = await _partyRepo.getParties(organizationId: widget.organizationId);
      final accs = await _accRepo.getAccountsFlat(widget.organizationId, type: 'EXPENSE');
      final items = await _repo.getItems(
        organizationId: widget.organizationId,
        includeInactive: false,
      );

      String docNum = _docNumberCtrl.text;
      if (docNum.isEmpty) {
        docNum = await _repo.getNextStockDocumentNumber(
            widget.organizationId, _documentType);
      }

      if (mounted) {
        setState(() {
          _warehouses = whs;
          _parties = parties;
          _expenseAccounts = accs;
          _allItems = items.where((i) => i.trackInventory && !i.isService).toList();
          _docNumberCtrl.text = docNum;

          if (_warehouses.isNotEmpty) {
            if (_destinationWarehouseId == null &&
                (_documentType == StockDocumentType.receipt ||
                    _documentType == StockDocumentType.opening)) {
              _destinationWarehouseId = _warehouses.first.id;
            }
            if (_sourceWarehouseId == null &&
                _documentType == StockDocumentType.issue) {
              _sourceWarehouseId = _warehouses.first.id;
            }
            if (_documentType == StockDocumentType.transfer &&
                _warehouses.length >= 2) {
              _sourceWarehouseId = _warehouses[0].id;
              _destinationWarehouseId = _warehouses[1].id;
            }
          }

          if (widget.existingDocument != null &&
              widget.existingDocument!.lines.isNotEmpty) {
            for (final l in widget.existingDocument!.lines) {
              _lines.add(_DocLineDraft(
                itemId: l.itemId,
                quantityCtrl: TextEditingController(
                    text: (l.quantity / 1000.0).toString()),
                unitCostCtrl: TextEditingController(
                    text: (l.unitCost / 100.0).toStringAsFixed(2)),
                notesCtrl: TextEditingController(text: l.notes ?? ''),
                expenseAccountId: l.expenseAccountId,
              ));
            }
          } else if (_lines.isEmpty) {
            _addNewLine();
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تهيئة السند: $e')),
        );
      }
    }
  }

  void _addNewLine() {
    setState(() {
      _lines.add(_DocLineDraft(
        itemId: _allItems.isNotEmpty ? _allItems.first.id : null,
        quantityCtrl: TextEditingController(text: '1'),
        unitCostCtrl: TextEditingController(
          text: _allItems.isNotEmpty
              ? (_allItems.first.currentAverageCost / 100.0).toStringAsFixed(2)
              : '0.00',
        ),
        notesCtrl: TextEditingController(),
      ));
    });
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) return;
    setState(() {
      final removed = _lines.removeAt(index);
      removed.dispose();
    });
  }

  int _calculateTotalCost() {
    int sum = 0;
    for (final l in _lines) {
      final qty = (double.tryParse(l.quantityCtrl.text.trim()) ?? 0.0) * 1000;
      final cost = (double.tryParse(l.unitCostCtrl.text.trim()) ?? 0.0) * 100;
      sum += ((qty * cost) / 1000).round();
    }
    return sum;
  }

  Future<void> _saveAndOrPost({required bool postNow}) async {
    if (!_formKey.currentState!.validate()) return;

    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب إضافة بند واحد على الأقل في السند')),
      );
      return;
    }

    if (_documentType == StockDocumentType.transfer) {
      if (_sourceWarehouseId == null || _destinationWarehouseId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى تحديد مستودع المصدر ومستودع الوجهة')),
        );
        return;
      }
      if (_sourceWarehouseId == _destinationWarehouseId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن أن يكون مستودع المصدر مطابقاً لمستودع الوجهة')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final docId = widget.existingDocument?.id ??
          'stk_doc_${widget.organizationId}_${DateTime.now().millisecondsSinceEpoch}';

      final docLines = <StockDocumentLineModel>[];
      for (int i = 0; i < _lines.length; i++) {
        final l = _lines[i];
        if (l.itemId == null) throw Exception('يرجى اختيار الصنف للسطر ${i + 1}');

        final item = _allItems.firstWhere((it) => it.id == l.itemId);
        final qtyNum = double.tryParse(l.quantityCtrl.text.trim()) ?? 1.0;
        final costNum = double.tryParse(l.unitCostCtrl.text.trim()) ?? 0.0;

        final qtyScaled = (qtyNum * 1000).round();
        final costScaled = (costNum * 100).round();
        final lineCost = ((qtyScaled * costScaled) / 1000).round();

        docLines.add(StockDocumentLineModel(
          id: 'line_${docId}_${i + 1}',
          organizationId: widget.organizationId,
          documentId: docId,
          lineNumber: i + 1,
          itemId: l.itemId!,
          unitId: item.baseUnitId,
          quantity: qtyScaled,
          conversionFactor: 1000,
          baseQuantity: qtyScaled,
          unitCost: costScaled,
          totalCost: lineCost,
          expenseAccountId: l.expenseAccountId,
          notes: l.notesCtrl.text.trim().isEmpty ? null : l.notesCtrl.text.trim(),
        ));
      }

      final totalCost = _calculateTotalCost();

      final document = StockDocumentModel(
        id: docId,
        organizationId: widget.organizationId,
        documentNumber: _docNumberCtrl.text.trim(),
        documentType: _documentType,
        documentDate: _dateCtrl.text.trim(),
        sourceWarehouseId: _sourceWarehouseId,
        destinationWarehouseId: _destinationWarehouseId,
        partyId: _partyId,
        referenceNumber:
            _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        status: StockDocumentStatus.draft,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        totalCost: totalCost,
        createdAt: widget.existingDocument?.createdAt ?? now,
      );

      // Save draft first
      await _repo.saveStockDocument(document: document, lines: docLines);

      // Post if requested
      if (postNow) {
        await _repo.postStockDocument(docId, widget.organizationId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              postNow
                  ? 'تم حفظ وترحيل ${document.documentTypeLabelAr} بنجاح!'
                  : 'تم حفظ السند كمسودة بنجاح.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(_getTitle()),
          actions: [
            TextButton(
              onPressed: _isSaving ? null : () => _saveAndOrPost(postNow: false),
              child: const Text('حفظ كمسودة', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.surface,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الإجمالي التقديري:',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text(
                      (_calculateTotalCost() / 100.0).toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : () => _saveAndOrPost(postNow: true),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('ترحيل الآن للمخازن'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Card
                      _buildHeaderCard(),
                      const SizedBox(height: 16),

                      // Lines Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'بنود ومواد السند المخزني',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkNavy,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addNewLine,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('إضافة بند آخر'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      ..._lines.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final line = entry.value;
                        return _buildLineCard(idx, line);
                      }),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _documentType,
                  decoration: const InputDecoration(labelText: 'نوع السند *'),
                  items: const [
                    DropdownMenuItem(
                      value: StockDocumentType.receipt,
                      child: Text('سند إدخال مخزني (استلام)'),
                    ),
                    DropdownMenuItem(
                      value: StockDocumentType.issue,
                      child: Text('سند إخراج مخزني (صرف/تلف)'),
                    ),
                    DropdownMenuItem(
                      value: StockDocumentType.transfer,
                      child: Text('مناقلة بين المستودعات'),
                    ),
                    DropdownMenuItem(
                      value: StockDocumentType.adjustment,
                      child: Text('تسوية جردية'),
                    ),
                    DropdownMenuItem(
                      value: StockDocumentType.opening,
                      child: Text('رصيد افتتاحي للمخزون'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _documentType = v);
                      _loadPrerequisites();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _docNumberCtrl,
                  decoration: const InputDecoration(labelText: 'رقم السند *'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _dateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'تاريخ السند *',
                    prefixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                  onTap: () async {
                    FocusScope.of(context).requestFocus(FocusNode());
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.tryParse(_dateCtrl.text) ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) {
                      _dateCtrl.text = d.toIso8601String().split('T').first;
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _refCtrl,
                  decoration: const InputDecoration(labelText: 'رقم المرجع / الفاتورة'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Warehouse selection based on doc type
          if (_documentType == StockDocumentType.transfer) ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _sourceWarehouseId,
                    decoration: const InputDecoration(labelText: 'من مستودع (المصدر) *'),
                    items: _warehouses
                        .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _sourceWarehouseId = v),
                    validator: (v) => v == null ? 'مطلوب' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _destinationWarehouseId,
                    decoration: const InputDecoration(labelText: 'إلى مستودع (الوجهة) *'),
                    items: _warehouses
                        .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _destinationWarehouseId = v),
                    validator: (v) => v == null ? 'مطلوب' : null,
                  ),
                ),
              ],
            ),
          ] else if (_documentType == StockDocumentType.issue) ...[
            DropdownButtonFormField<String>(
              value: _sourceWarehouseId,
              decoration: const InputDecoration(labelText: 'المستودع المصروف منه *'),
              items: _warehouses
                  .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                  .toList(),
              onChanged: (v) => setState(() => _sourceWarehouseId = v),
              validator: (v) => v == null ? 'مطلوب' : null,
            ),
          ] else ...[
            DropdownButtonFormField<String>(
              value: _destinationWarehouseId,
              decoration: const InputDecoration(labelText: 'المستودع المستلم / الوارد إليه *'),
              items: _warehouses
                  .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                  .toList(),
              onChanged: (v) => setState(() => _destinationWarehouseId = v),
              validator: (v) => v == null ? 'مطلوب' : null,
            ),
          ],

          if (_documentType == StockDocumentType.receipt) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _partyId,
              decoration: const InputDecoration(labelText: 'المورد (اختياري)'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('بدون تحديد مورد')),
                ..._parties
                    .where((p) => p.partyType != 'CUSTOMER')
                    .map((p) => DropdownMenuItem<String?>(value: p.id, child: Text(p.nameAr))),
              ],
              onChanged: (v) => setState(() => _partyId = v),
            ),
          ],

          const SizedBox(height: 12),
          TextFormField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'البيان والملاحظات العامة'),
          ),
        ],
      ),
    );
  }

  Widget _buildLineCard(int index, _DocLineDraft line) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'البند #${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              if (_lines.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                  onPressed: () => _removeLine(index),
                ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: line.itemId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'الصنف *'),
            items: _allItems
                .map((it) => DropdownMenuItem(
                      value: it.id,
                      child: Text('${it.nameAr} (${it.itemCode})'),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                final it = _allItems.firstWhere((i) => i.id == val);
                setState(() {
                  line.itemId = val;
                  line.unitCostCtrl.text =
                      (it.currentAverageCost / 100.0).toStringAsFixed(2);
                });
              }
            },
            validator: (v) => v == null ? 'اختر الصنف' : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: line.quantityCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'الكمية *'),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final numVal = double.tryParse(v ?? '');
                    if (numVal == null || numVal <= 0) return 'كمية غير صالحة';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: line.unitCostCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'تكلفة الوحدة'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          if (_documentType == StockDocumentType.issue ||
              _documentType == StockDocumentType.adjustment) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              value: line.expenseAccountId,
              decoration: const InputDecoration(
                labelText: 'حساب المصروف / التلف المقابل (اختياري)',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('الحساب الافتراضي من الإعدادات'),
                ),
                ..._expenseAccounts.map((a) => DropdownMenuItem<String?>(
                      value: a.id,
                      child: Text('${a.accountNameAr} (${a.accountCode})'),
                    )),
              ],
              onChanged: (v) => setState(() => line.expenseAccountId = v),
            ),
          ],
        ],
      ),
    );
  }

  String _getTitle() {
    switch (_documentType) {
      case StockDocumentType.receipt:
        return 'سند إدخال مخزني جديد';
      case StockDocumentType.issue:
        return 'سند إخراج مخزني جديد';
      case StockDocumentType.transfer:
        return 'مناقلة مستودعات جديدة';
      case StockDocumentType.adjustment:
        return 'تسوية جردية جديدة';
      case StockDocumentType.opening:
        return 'رصيد افتتاحي للمخزون';
      default:
        return 'سند مخزني جديد';
    }
  }
}

class _DocLineDraft {
  String? itemId;
  final TextEditingController quantityCtrl;
  final TextEditingController unitCostCtrl;
  final TextEditingController notesCtrl;
  String? expenseAccountId;

  _DocLineDraft({
    this.itemId,
    required this.quantityCtrl,
    required this.unitCostCtrl,
    required this.notesCtrl,
    this.expenseAccountId,
  });

  void dispose() {
    quantityCtrl.dispose();
    unitCostCtrl.dispose();
    notesCtrl.dispose();
  }
}
