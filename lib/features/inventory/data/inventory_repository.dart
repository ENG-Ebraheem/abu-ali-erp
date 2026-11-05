import 'package:sqflite/sqflite.dart';
import 'package:abu_ali/core/constants/database_constants.dart';
import 'package:abu_ali/core/database/database_helper.dart';
import 'package:abu_ali/features/journal/data/journal_repository.dart';
import 'package:abu_ali/features/journal/models/journal_entry_line_model.dart';
import 'package:abu_ali/features/journal/models/journal_entry_model.dart';
import '../models/item_category_model.dart';
import '../models/item_model.dart';
import '../models/item_unit_model.dart';
import '../models/stock_document_line_model.dart';
import '../models/stock_document_model.dart';
import '../models/stock_movement_model.dart';
import '../models/stocktaking_line_model.dart';
import '../models/stocktaking_session_model.dart';
import '../models/unit_of_measure_model.dart';
import '../models/warehouse_model.dart';
import 'inventory_settings_repository.dart';

/// Core repository for inventory operations, stock documents, movements, and accounting integration.
class InventoryRepository {
  final DatabaseHelper _dbHelper;
  final JournalRepository _journalRepo;
  final InventorySettingsRepository _settingsRepo;

  InventoryRepository({
    DatabaseHelper? dbHelper,
    JournalRepository? journalRepo,
    InventorySettingsRepository? settingsRepo,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _journalRepo = journalRepo ?? JournalRepository(),
        _settingsRepo = settingsRepo ?? InventorySettingsRepository();

  Future<Database> get _db async => await _dbHelper.database;

  // ===========================================================================
  // 1. WAREHOUSES
  // ===========================================================================

  Future<List<WarehouseModel>> getWarehouses(
    String organizationId, {
    bool includeInactive = true,
  }) async {
    final db = await _db;
    String whereSql = 'w.organization_id = ?';
    final whereArgs = <dynamic>[organizationId];

    if (!includeInactive) {
      whereSql += ' AND w.is_active = 1';
    }

    final query = '''
      SELECT 
        w.*,
        COUNT(DISTINCT sm.item_id) AS item_count,
        COALESCE(SUM(sm.quantity_in - sm.quantity_out), 0) AS net_qty
      FROM ${DatabaseConstants.tableWarehouses} w
      LEFT JOIN ${DatabaseConstants.tableStockMovements} sm 
        ON w.id = sm.warehouse_id AND w.organization_id = sm.organization_id
      WHERE $whereSql
      GROUP BY w.id
      ORDER BY w.code ASC
    ''';

    final rows = await db.rawQuery(query, whereArgs);
    return rows.map((r) => WarehouseModel.fromMap(r)).toList();
  }

  Future<WarehouseModel?> getWarehouseById(
      String id, String organizationId) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseConstants.tableWarehouses,
      where: 'id = ? AND organization_id = ?',
      whereArgs: [id, organizationId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return WarehouseModel.fromMap(rows.first);
  }

  Future<void> createWarehouse(WarehouseModel warehouse) async {
    final db = await _db;

    // Check code uniqueness within organization
    final existing = await db.query(
      DatabaseConstants.tableWarehouses,
      columns: ['id'],
      where: 'organization_id = ? AND code = ?',
      whereArgs: [warehouse.organizationId, warehouse.code],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw Exception('رمز المستودع (${warehouse.code}) مستخدم مسبقاً لهذه المؤسسة.');
    }

    await db.insert(
      DatabaseConstants.tableWarehouses,
      warehouse.toMap(),
    );
  }

  Future<void> updateWarehouse(WarehouseModel warehouse) async {
    final db = await _db;

    final existing = await db.query(
      DatabaseConstants.tableWarehouses,
      columns: ['id'],
      where: 'organization_id = ? AND code = ? AND id != ?',
      whereArgs: [warehouse.organizationId, warehouse.code, warehouse.id],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw Exception('رمز المستودع (${warehouse.code}) مستخدم لدى مستودع آخر.');
    }

    final data = warehouse.toMap();
    data['updated_at'] = DateTime.now().toUtc().toIso8601String();

    await db.update(
      DatabaseConstants.tableWarehouses,
      data,
      where: 'id = ? AND organization_id = ?',
      whereArgs: [warehouse.id, warehouse.organizationId],
    );
  }

  Future<void> toggleWarehouseActive(
      String id, String organizationId, bool isActive) async {
    final db = await _db;
    await db.update(
      DatabaseConstants.tableWarehouses,
      {
        'is_active': isActive ? 1 : 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ? AND organization_id = ?',
      whereArgs: [id, organizationId],
    );
  }

  Future<void> deleteWarehouse(String id, String organizationId) async {
    final db = await _db;

    // Check movements count
    final movCount = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM ${DatabaseConstants.tableStockMovements} WHERE warehouse_id = ? AND organization_id = ?',
          [id, organizationId],
        )) ??
        0;

    if (movCount > 0) {
      throw Exception(
        'لا يمكن حذف هذا المستودع لوجود ($movCount) حركة مخزنية مسجلة به. يمكنك تعطيله بدلاً من ذلك.',
      );
    }

    // Check document references
    final docCount = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM ${DatabaseConstants.tableStockDocuments} WHERE (source_warehouse_id = ? OR destination_warehouse_id = ?) AND organization_id = ?',
          [id, id, organizationId],
        )) ??
        0;

    if (docCount > 0) {
      throw Exception(
        'لا يمكن حذف هذا المستودع لارتباطه بسندات مخزنية سابقة. يرجى تعطيله لحفظ سجلات التدقيق.',
      );
    }

    await db.delete(
      DatabaseConstants.tableWarehouses,
      where: 'id = ? AND organization_id = ?',
      whereArgs: [id, organizationId],
    );
  }

  // ===========================================================================
  // 2. ITEM CATEGORIES
  // ===========================================================================

  Future<List<ItemCategoryModel>> getCategories(
    String organizationId, {
    bool includeInactive = true,
  }) async {
    final db = await _db;
    String whereSql = 'c.organization_id = ?';
    final whereArgs = <dynamic>[organizationId];

    if (!includeInactive) {
      whereSql += ' AND c.is_active = 1';
    }

    final query = '''
      SELECT 
        c.*,
        p.name_ar AS parent_name_ar,
        COUNT(i.id) AS product_count
      FROM ${DatabaseConstants.tableItemCategories} c
      LEFT JOIN ${DatabaseConstants.tableItemCategories} p ON c.parent_id = p.id
      LEFT JOIN ${DatabaseConstants.tableItems} i ON c.id = i.category_id AND i.organization_id = c.organization_id
      WHERE $whereSql
      GROUP BY c.id
      ORDER BY c.code ASC
    ''';

    final rows = await db.rawQuery(query, whereArgs);
    return rows.map((r) => ItemCategoryModel.fromMap(r)).toList();
  }

  Future<ItemCategoryModel?> getCategoryById(
      String id, String organizationId) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseConstants.tableItemCategories,
      where: 'id = ? AND organization_id = ?',
      whereArgs: [id, organizationId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ItemCategoryModel.fromMap(rows.first);
  }

  Future<void> createCategory(ItemCategoryModel category) async {
    final db = await _db;

    final existing = await db.query(
      DatabaseConstants.tableItemCategories,
      columns: ['id'],
      where: 'organization_id = ? AND code = ?',
      whereArgs: [category.organizationId, category.code],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw Exception('رمز التصنيف (${category.code}) مستخدم مسبقاً.');
    }

    await db.insert(
      DatabaseConstants.tableItemCategories,
      category.toMap(),
    );
  }

  Future<void> updateCategory(ItemCategoryModel category) async {
    final db = await _db;

    // Prevent circular reference
    if (category.parentId != null && category.parentId == category.id) {
      throw Exception('لا يمكن جعل التصنيف أباً لنفسه.');
    }

    final existing = await db.query(
      DatabaseConstants.tableItemCategories,
      columns: ['id'],
      where: 'organization_id = ? AND code = ? AND id != ?',
      whereArgs: [category.organizationId, category.code, category.id],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw Exception('رمز التصنيف (${category.code}) مستخدم مسبقاً.');
    }

    final data = category.toMap();
    data['updated_at'] = DateTime.now().toUtc().toIso8601String();

    await db.update(
      DatabaseConstants.tableItemCategories,
      data,
      where: 'id = ? AND organization_id = ?',
      whereArgs: [category.id, category.organizationId],
    );
  }

  Future<void> toggleCategoryActive(
      String id, String organizationId, bool isActive) async {
    final db = await _db;
    await db.update(
      DatabaseConstants.tableItemCategories,
      {
        'is_active': isActive ? 1 : 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ? AND organization_id = ?',
      whereArgs: [id, organizationId],
    );
  }

  Future<void> deleteCategory(String id, String organizationId) async {
    final db = await _db;

    final childCount = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM ${DatabaseConstants.tableItemCategories} WHERE parent_id = ? AND organization_id = ?',
          [id, organizationId],
        )) ??
        0;
    if (childCount > 0) {
      throw Exception('لا يمكن حذف التصنيف لاحتوائه على تصنيفات فرعية تابعة له.');
    }

    final itemCount = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM ${DatabaseConstants.tableItems} WHERE category_id = ? AND organization_id = ?',
          [id, organizationId],
        )) ??
        0;
    if (itemCount > 0) {
      throw Exception('لا يمكن حذف التصنيف لارتباط ($itemCount) صنف مسجل به.');
    }

    await db.delete(
      DatabaseConstants.tableItemCategories,
      where: 'id = ? AND organization_id = ?',
      whereArgs: [id, organizationId],
    );
  }

  // ===========================================================================
  // 3. UNITS OF MEASURE
  // ===========================================================================

  Future<List<UnitOfMeasureModel>> getUnitsOfMeasure(
    String organizationId, {
    bool includeInactive = true,
  }) async {
    final db = await _db;
    String whereSql = 'organization_id = ?';
    final whereArgs = <dynamic>[organizationId];

    if (!includeInactive) {
      whereSql += ' AND is_active = 1';
    }

    final rows = await db.query(
      DatabaseConstants.tableUnitsOfMeasure,
      where: whereSql,
      whereArgs: whereArgs,
      orderBy: 'code ASC',
    );

    return rows.map((r) => UnitOfMeasureModel.fromMap(r)).toList();
  }

  Future<void> createUnitOfMeasure(UnitOfMeasureModel unit) async {
    final db = await _db;

    final existing = await db.query(
      DatabaseConstants.tableUnitsOfMeasure,
      columns: ['id'],
      where: 'organization_id = ? AND code = ?',
      whereArgs: [unit.organizationId, unit.code],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw Exception('رمز وحدة القياس (${unit.code}) مستخدم مسبقاً.');
    }

    await db.insert(
      DatabaseConstants.tableUnitsOfMeasure,
      unit.toMap(),
    );
  }

  Future<void> updateUnitOfMeasure(UnitOfMeasureModel unit) async {
    final db = await _db;

    final existing = await db.query(
      DatabaseConstants.tableUnitsOfMeasure,
      columns: ['id'],
      where: 'organization_id = ? AND code = ? AND id != ?',
      whereArgs: [unit.organizationId, unit.code, unit.id],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw Exception('رمز وحدة القياس (${unit.code}) مستخدم مسبقاً.');
    }

    await db.update(
      DatabaseConstants.tableUnitsOfMeasure,
      unit.toMap(),
      where: 'id = ? AND organization_id = ?',
      whereArgs: [unit.id, unit.organizationId],
    );
  }

  Future<List<ItemUnitModel>> getItemUnits(String itemId) async {
    final db = await _db;
    final query = '''
      SELECT 
        iu.*,
        u.name_ar AS unit_name_ar,
        u.symbol AS unit_symbol,
        bu.symbol AS base_unit_symbol
      FROM ${DatabaseConstants.tableItemUnits} iu
      INNER JOIN ${DatabaseConstants.tableUnitsOfMeasure} u ON iu.unit_id = u.id
      INNER JOIN ${DatabaseConstants.tableItems} i ON iu.item_id = i.id
      INNER JOIN ${DatabaseConstants.tableUnitsOfMeasure} bu ON i.base_unit_id = bu.id
      WHERE iu.item_id = ?
      ORDER BY iu.conversion_factor ASC
    ''';

    final rows = await db.rawQuery(query, [itemId]);
    return rows.map((r) => ItemUnitModel.fromMap(r)).toList();
  }

  Future<void> addItemUnit(ItemUnitModel itemUnit) async {
    final db = await _db;
    if (itemUnit.conversionFactor <= 0) {
      throw Exception('معامل التحويل للوحدة يجب أن يكون أكبر من الصفر.');
    }

    await db.insert(
      DatabaseConstants.tableItemUnits,
      itemUnit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteItemUnit(String itemUnitId) async {
    final db = await _db;
    await db.delete(
      DatabaseConstants.tableItemUnits,
      where: 'id = ?',
      whereArgs: [itemUnitId],
    );
  }

  // ===========================================================================
  // 4. ITEMS & PRODUCTS
  // ===========================================================================

  Future<List<ItemModel>> getItems({
    required String organizationId,
    String? categoryId,
    String? itemType,
    String? warehouseId,
    String? query,
    bool includeInactive = true,
    bool lowStockOnly = false,
  }) async {
    final db = await _db;
    final args = <dynamic>[organizationId];
    String whereSql = 'i.organization_id = ?';

    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'ALL') {
      whereSql += ' AND i.category_id = ?';
      args.add(categoryId);
    }

    if (itemType != null && itemType.isNotEmpty && itemType != 'ALL') {
      whereSql += ' AND i.item_type = ?';
      args.add(itemType);
    }

    if (!includeInactive) {
      whereSql += ' AND i.is_active = 1';
    }

    if (query != null && query.trim().isNotEmpty) {
      whereSql +=
          ' AND (i.item_code LIKE ? OR i.name_ar LIKE ? OR i.barcode LIKE ?)';
      final q = '%${query.trim()}%';
      args.addAll([q, q, q]);
    }

    // Warehouse stock subquery condition
    String whFilter = '';
    if (warehouseId != null && warehouseId.isNotEmpty && warehouseId != 'ALL') {
      whFilter = 'AND sm.warehouse_id = ?';
      args.add(warehouseId);
    }

    final sql = '''
      SELECT 
        i.*,
        c.name_ar AS category_name_ar,
        u.name_ar AS base_unit_name_ar,
        u.symbol AS base_unit_symbol,
        w.name AS default_warehouse_name,
        COALESCE(SUM(CASE WHEN sm.id IS NOT NULL THEN (sm.quantity_in - sm.quantity_out) ELSE 0 END), 0) AS current_stock,
        COALESCE(
          (SELECT unit_cost FROM ${DatabaseConstants.tableStockMovements} 
           WHERE item_id = i.id AND organization_id = i.organization_id AND quantity_in > 0 
           ORDER BY movement_date DESC, created_at DESC LIMIT 1),
          i.purchase_price
        ) AS current_average_cost
      FROM ${DatabaseConstants.tableItems} i
      LEFT JOIN ${DatabaseConstants.tableItemCategories} c ON i.category_id = c.id
      LEFT JOIN ${DatabaseConstants.tableUnitsOfMeasure} u ON i.base_unit_id = u.id
      LEFT JOIN ${DatabaseConstants.tableWarehouses} w ON i.default_warehouse_id = w.id
      LEFT JOIN ${DatabaseConstants.tableStockMovements} sm 
        ON i.id = sm.item_id AND i.organization_id = sm.organization_id $whFilter
      WHERE $whereSql
      GROUP BY i.id
      ORDER BY i.item_code ASC
    ''';

    final rows = await db.rawQuery(sql, args);
    var items = rows.map((r) {
      final stock = (r['current_stock'] as num?)?.toInt() ?? 0;
      final avgCost = (r['current_average_cost'] as num?)?.toInt() ?? 0;
      final totalVal = ((stock * avgCost) / DatabaseConstants.quantityScale).round();
      return ItemModel.fromMap(r).copyWith(
        currentStock: stock,
        currentAverageCost: avgCost,
        totalStockValue: totalVal,
      );
    }).toList();

    if (lowStockOnly) {
      items = items.where((i) => i.isLowStock).toList();
    }

    return items;
  }

  Future<ItemModel?> getItemById(String id, String organizationId) async {
    final items = await getItems(organizationId: organizationId);
    try {
      return items.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> createItem(ItemModel item) async {
    final db = await _db;

    // Validate SKU uniqueness
    final existingCode = await db.query(
      DatabaseConstants.tableItems,
      columns: ['id'],
      where: 'organization_id = ? AND item_code = ?',
      whereArgs: [item.organizationId, item.itemCode],
      limit: 1,
    );
    if (existingCode.isNotEmpty) {
      throw Exception('رمز الصنف (${item.itemCode}) مستخدم مسبقاً.');
    }

    // Validate barcode uniqueness if provided
    if (item.barcode != null && item.barcode!.trim().isNotEmpty) {
      final existingBarcode = await db.query(
        DatabaseConstants.tableItems,
        columns: ['id'],
        where: 'organization_id = ? AND barcode = ?',
        whereArgs: [item.organizationId, item.barcode!.trim()],
        limit: 1,
      );
      if (existingBarcode.isNotEmpty) {
        throw Exception('الباركود (${item.barcode}) مسجل لصنف آخر في هذه المؤسسة.');
      }
    }

    await db.insert(
      DatabaseConstants.tableItems,
      item.toMap(),
    );
  }

  Future<void> updateItem(ItemModel item) async {
    final db = await _db;

    final existingCode = await db.query(
      DatabaseConstants.tableItems,
      columns: ['id'],
      where: 'organization_id = ? AND item_code = ? AND id != ?',
      whereArgs: [item.organizationId, item.itemCode, item.id],
      limit: 1,
    );
    if (existingCode.isNotEmpty) {
      throw Exception('رمز الصنف (${item.itemCode}) مستخدم مسبقاً لدى صنف آخر.');
    }

    if (item.barcode != null && item.barcode!.trim().isNotEmpty) {
      final existingBarcode = await db.query(
        DatabaseConstants.tableItems,
        columns: ['id'],
        where: 'organization_id = ? AND barcode = ? AND id != ?',
        whereArgs: [item.organizationId, item.barcode!.trim(), item.id],
        limit: 1,
      );
      if (existingBarcode.isNotEmpty) {
        throw Exception('الباركود (${item.barcode}) مسجل لصنف آخر في هذه المؤسسة.');
      }
    }

    final data = item.toMap();
    data['updated_at'] = DateTime.now().toUtc().toIso8601String();

    await db.update(
      DatabaseConstants.tableItems,
      data,
      where: 'id = ? AND organization_id = ?',
      whereArgs: [item.id, item.organizationId],
    );
  }

  Future<void> toggleItemActive(
      String id, String organizationId, bool isActive) async {
    final db = await _db;
    await db.update(
      DatabaseConstants.tableItems,
      {
        'is_active': isActive ? 1 : 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ? AND organization_id = ?',
      whereArgs: [id, organizationId],
    );
  }

  Future<void> deleteItem(String id, String organizationId) async {
    final db = await _db;

    final movCount = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM ${DatabaseConstants.tableStockMovements} WHERE item_id = ? AND organization_id = ?',
          [id, organizationId],
        )) ??
        0;

    if (movCount > 0) {
      throw Exception('لا يمكن حذف الصنف لوجود ($movCount) حركة مخزنية سابقة مرتبطة به.');
    }

    await db.delete(
      DatabaseConstants.tableItems,
      where: 'id = ? AND organization_id = ?',
      whereArgs: [id, organizationId],
    );
  }

  // ===========================================================================
  // 5. STOCK VALUATION & QUANTITY INQUIRIES
  // ===========================================================================

  /// Returns current physical stock for an item (scaled 10^3) in base units.
  Future<int> getItemStock(String itemId, String organizationId,
      {String? warehouseId}) async {
    final db = await _db;
    String sql = '''
      SELECT COALESCE(SUM(quantity_in - quantity_out), 0) AS balance
      FROM ${DatabaseConstants.tableStockMovements}
      WHERE item_id = ? AND organization_id = ?
    ''';
    final args = <dynamic>[itemId, organizationId];

    if (warehouseId != null && warehouseId.isNotEmpty && warehouseId != 'ALL') {
      sql += ' AND warehouse_id = ?';
      args.add(warehouseId);
    }

    final res = await db.rawQuery(sql, args);
    return (res.first['balance'] as num?)?.toInt() ?? 0;
  }

  /// Calculates the Weighted Average Cost (WAC) per base unit for an item (scaled 10^2).
  Future<int> getItemWeightedAverageCost(
      String itemId, String organizationId) async {
    final db = await _db;

    // Fetch movements in chronological order
    final rows = await db.rawQuery('''
      SELECT quantity_in, quantity_out, unit_cost
      FROM ${DatabaseConstants.tableStockMovements}
      WHERE item_id = ? AND organization_id = ?
      ORDER BY movement_date ASC, created_at ASC
    ''', [itemId, organizationId]);

    if (rows.isEmpty) {
      // Fallback to item master purchase price
      final itemRes = await db.query(
        DatabaseConstants.tableItems,
        columns: ['purchase_price'],
        where: 'id = ? AND organization_id = ?',
        whereArgs: [itemId, organizationId],
        limit: 1,
      );
      if (itemRes.isNotEmpty) {
        return (itemRes.first['purchase_price'] as num?)?.toInt() ?? 0;
      }
      return 0;
    }

    int currentQty = 0; // Scaled 10^3
    int currentTotalVal = 0; // Minor units (scaled 10^2)

    for (final r in rows) {
      final qIn = (r['quantity_in'] as num).toInt();
      final qOut = (r['quantity_out'] as num).toInt();
      final uCost = (r['unit_cost'] as num).toInt();

      if (qIn > 0) {
        final inVal = ((qIn * uCost) / DatabaseConstants.quantityScale).round();
        currentTotalVal += inVal;
        currentQty += qIn;
      }

      if (qOut > 0) {
        if (currentQty > 0) {
          final avg = ((currentTotalVal * DatabaseConstants.quantityScale) / currentQty).round();
          final outVal = ((qOut * avg) / DatabaseConstants.quantityScale).round();
          currentTotalVal -= outVal;
          currentQty -= qOut;
          if (currentTotalVal < 0) currentTotalVal = 0;
        } else {
          currentQty -= qOut;
        }
      }
    }

    if (currentQty > 0) {
      return ((currentTotalVal * DatabaseConstants.quantityScale) / currentQty).round();
    }

    // If stock zero, return last recorded positive cost
    final lastRow = rows.lastWhere(
      (r) => (r['quantity_in'] as num).toInt() > 0 && (r['unit_cost'] as num).toInt() > 0,
      orElse: () => rows.last,
    );
    return (lastRow['unit_cost'] as num).toInt();
  }

  // ===========================================================================
  // 6. STOCK DOCUMENTS (RECEIPT, ISSUE, TRANSFER, ADJUSTMENT, OPENING)
  // ===========================================================================

  Future<String> getNextStockDocumentNumber(
      String organizationId, String docType) async {
    final db = await _db;
    final year = DateTime.now().year;

    String prefix = 'DOC';
    if (docType == StockDocumentType.opening) prefix = 'STK-OP';
    if (docType == StockDocumentType.receipt) prefix = 'STK-RC';
    if (docType == StockDocumentType.issue) prefix = 'STK-IS';
    if (docType == StockDocumentType.transfer) prefix = 'STK-TR';
    if (docType == StockDocumentType.adjustment) prefix = 'STK-ADJ';

    final results = await db.rawQuery('''
      SELECT document_number FROM ${DatabaseConstants.tableStockDocuments}
      WHERE organization_id = ? AND document_number LIKE '$prefix-$year-%'
      ORDER BY document_number DESC
      LIMIT 1
    ''', [organizationId]);

    if (results.isEmpty) {
      return '$prefix-$year-0001';
    }

    final last = results.first['document_number'] as String;
    final parts = last.split('-');
    if (parts.length >= 3) {
      final numVal = int.tryParse(parts.last);
      if (numVal != null) {
        return '$prefix-$year-${(numVal + 1).toString().padLeft(4, '0')}';
      }
    }

    return '$prefix-$year-${DateTime.now().millisecondsSinceEpoch % 10000}';
  }

  Future<List<StockDocumentModel>> getStockDocuments({
    required String organizationId,
    String? docType,
    String? status,
    String? warehouseId,
    String? query,
    int limit = 50,
  }) async {
    final db = await _db;
    final args = <dynamic>[organizationId];
    String whereSql = 'd.organization_id = ?';

    if (docType != null && docType.isNotEmpty && docType != 'ALL') {
      whereSql += ' AND d.document_type = ?';
      args.add(docType);
    }

    if (status != null && status.isNotEmpty && status != 'ALL') {
      whereSql += ' AND d.status = ?';
      args.add(status);
    }

    if (warehouseId != null && warehouseId.isNotEmpty && warehouseId != 'ALL') {
      whereSql +=
          ' AND (d.source_warehouse_id = ? OR d.destination_warehouse_id = ?)';
      args.addAll([warehouseId, warehouseId]);
    }

    if (query != null && query.trim().isNotEmpty) {
      whereSql +=
          ' AND (d.document_number LIKE ? OR d.reference_number LIKE ? OR d.notes LIKE ?)';
      final q = '%${query.trim()}%';
      args.addAll([q, q, q]);
    }

    final queryStr = '''
      SELECT 
        d.*,
        sw.name AS source_warehouse_name,
        dw.name AS destination_warehouse_name,
        p.name_ar AS party_name_ar
      FROM ${DatabaseConstants.tableStockDocuments} d
      LEFT JOIN ${DatabaseConstants.tableWarehouses} sw ON d.source_warehouse_id = sw.id
      LEFT JOIN ${DatabaseConstants.tableWarehouses} dw ON d.destination_warehouse_id = dw.id
      LEFT JOIN ${DatabaseConstants.tableParties} p ON d.party_id = p.id
      WHERE $whereSql
      ORDER BY d.document_date DESC, d.created_at DESC
      LIMIT $limit
    ''';

    final rows = await db.rawQuery(queryStr, args);
    return rows.map((r) => StockDocumentModel.fromMap(r)).toList();
  }

  Future<StockDocumentModel?> getStockDocumentById(
      String id, String organizationId) async {
    final db = await _db;

    final headerRows = await db.rawQuery('''
      SELECT 
        d.*,
        sw.name AS source_warehouse_name,
        dw.name AS destination_warehouse_name,
        p.name_ar AS party_name_ar
      FROM ${DatabaseConstants.tableStockDocuments} d
      LEFT JOIN ${DatabaseConstants.tableWarehouses} sw ON d.source_warehouse_id = sw.id
      LEFT JOIN ${DatabaseConstants.tableWarehouses} dw ON d.destination_warehouse_id = dw.id
      LEFT JOIN ${DatabaseConstants.tableParties} p ON d.party_id = p.id
      WHERE d.id = ? AND d.organization_id = ?
      LIMIT 1
    ''', [id, organizationId]);

    if (headerRows.isEmpty) return null;

    final linesRows = await db.rawQuery('''
      SELECT 
        l.*,
        i.item_code,
        i.name_ar AS item_name_ar,
        u.name_ar AS unit_name_ar,
        u.symbol AS unit_symbol,
        coa.account_name_ar AS expense_account_name_ar
      FROM ${DatabaseConstants.tableStockDocumentLines} l
      INNER JOIN ${DatabaseConstants.tableItems} i ON l.item_id = i.id
      INNER JOIN ${DatabaseConstants.tableUnitsOfMeasure} u ON l.unit_id = u.id
      LEFT JOIN ${DatabaseConstants.tableChartOfAccounts} coa ON l.expense_account_id = coa.id
      WHERE l.document_id = ? AND l.organization_id = ?
      ORDER BY l.line_number ASC
    ''', [id, organizationId]);

    final lines =
        linesRows.map((r) => StockDocumentLineModel.fromMap(r)).toList();
    return StockDocumentModel.fromMap(headerRows.first, lines: lines);
  }

  Future<void> saveStockDocument({
    required StockDocumentModel document,
    required List<StockDocumentLineModel> lines,
  }) async {
    final db = await _db;

    // Check if modifying a POSTED document
    final existing = await db.query(
      DatabaseConstants.tableStockDocuments,
      columns: ['status'],
      where: 'id = ? AND organization_id = ?',
      whereArgs: [document.id, document.organizationId],
      limit: 1,
    );
    if (existing.isNotEmpty && existing.first['status'] == StockDocumentStatus.posted) {
      throw Exception('لا يمكن تعديل سند مخزني مرحل مسبقاً.');
    }

    if (lines.isEmpty) {
      throw Exception('السند المخزني يجب أن يحتوي على بند واحد على الأقل.');
    }

    // Calculate totals
    int totalCost = 0;
    for (final l in lines) {
      totalCost += l.totalCost;
    }

    await db.transaction((txn) async {
      final docMap = document.copyWith(totalCost: totalCost).toMap();

      await txn.insert(
        DatabaseConstants.tableStockDocuments,
        docMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Clean old lines if updating
      await txn.delete(
        DatabaseConstants.tableStockDocumentLines,
        where: 'document_id = ?',
        whereArgs: [document.id],
      );

      // Insert new lines
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].copyWith(
          documentId: document.id,
          organizationId: document.organizationId,
          lineNumber: i + 1,
        );
        await txn.insert(
          DatabaseConstants.tableStockDocumentLines,
          line.toMap(),
        );
      }
    });
  }

  /// Posts a stock document: Creates physical stock movements and double-entry accounting records atomically.
  Future<void> postStockDocument(
      String documentId, String organizationId) async {
    final db = await _db;
    final doc = await getStockDocumentById(documentId, organizationId);

    if (doc == null) throw Exception('السند المخزني غير موجود.');
    if (doc.isPosted) throw Exception('السند المخزني مرحل مسبقاً.');
    if (doc.lines.isEmpty) throw Exception('السند لا يحتوي على أي بنود للترحيل.');

    // 1. Ensure Fiscal Period is open
    final periodId = await _journalRepo.ensureFiscalPeriod(
        organizationId, doc.documentDate);
    await _journalRepo.validateFiscalPeriodOpen(periodId, organizationId);

    // 2. Fetch inventory configuration
    final settings = await _settingsRepo.getSettings(organizationId);
    if (!settings.isInventoryEnabled) {
      throw Exception('نظام المخزون معطل في إعدادات هذه المؤسسة.');
    }

    final assetAccId = settings.inventoryAssetAccountId;
    if (assetAccId == null || assetAccId.isEmpty) {
      throw Exception('لم يتم تحديد حساب المخزون السلعي (الأصول) في إعدادات المخزون.');
    }

    // 3. Validate stock availability for deduction types
    final bool isDeduction = doc.documentType == StockDocumentType.issue ||
        doc.documentType == StockDocumentType.transfer;

    final targetWhId = doc.documentType == StockDocumentType.transfer
        ? doc.sourceWarehouseId
        : (doc.sourceWarehouseId ?? doc.destinationWarehouseId);

    if (targetWhId == null && isDeduction) {
      throw Exception('يرجى تحديد المستودع المسحوب منه.');
    }

    // 4. Recalculate line costs using WAC for issues/transfers if needed
    final preparedLines = <StockDocumentLineModel>[];
    int calculatedTotalCost = 0;

    for (final line in doc.lines) {
      final item = await getItemById(line.itemId, organizationId);
      if (item == null) throw Exception('الصنف (${line.itemId}) غير موجود.');

      if (!item.trackInventory || item.isService) {
        // Skip stock calculation for services
        continue;
      }

      int effectiveUnitCost = line.unitCost;
      if (isDeduction || doc.documentType == StockDocumentType.adjustment) {
        // If unit cost not manually fixed, use item current WAC
        if (effectiveUnitCost <= 0) {
          effectiveUnitCost =
              await getItemWeightedAverageCost(line.itemId, organizationId);
        }
      }

      final baseQty = (line.quantity * line.conversionFactor) ~/ 1000;
      final lineCost = (baseQty * effectiveUnitCost) ~/ 1000;

      // Check stock availability
      if (isDeduction && !settings.allowNegativeStock) {
        final currentStock = await getItemStock(line.itemId, organizationId,
            warehouseId: targetWhId);
        if (currentStock < baseQty) {
          final diff = (baseQty - currentStock) / 1000.0;
          throw Exception(
            'رصيد الصنف "${item.nameAr}" (${item.itemCode}) في المستودع غير كافٍ. المطلوب: ${(baseQty / 1000.0)}, المتوفر: ${(currentStock / 1000.0)} (عجز: $diff).',
          );
        }
      }

      calculatedTotalCost += lineCost;
      preparedLines.add(line.copyWith(
        unitCost: effectiveUnitCost,
        baseQuantity: baseQty,
        totalCost: lineCost,
      ));
    }

    final finalTotalCost = calculatedTotalCost > 0 ? calculatedTotalCost : doc.totalCost;
    final now = DateTime.now().toUtc().toIso8601String();

    // 5. Generate Accounting Journal Entry
    JournalEntryModel? journalEntry;
    final glLines = <JournalEntryLineModel>[];

    if (finalTotalCost > 0 && doc.documentType != StockDocumentType.transfer) {
      final orgRes = await db.query(
        DatabaseConstants.tableOrganizations,
        columns: ['base_currency_code'],
        where: 'id = ?',
        whereArgs: [organizationId],
        limit: 1,
      );
      final baseCurrency = (orgRes.isNotEmpty && orgRes.first['base_currency_code'] != null)
          ? orgRes.first['base_currency_code'] as String
          : 'YER';
      const fxScaled = DatabaseConstants.exchangeRateScale;

      final entryNumber = await _journalRepo.getNextEntryNumber(
          organizationId, JournalEntryType.general);
      final entryId = 'je_stock_${doc.id}';

      if (doc.documentType == StockDocumentType.opening) {
        // Debit Inventory Asset, Credit Opening Balances Equity
        final equityAccId = settings.openingEquityAccountId ?? '${organizationId}_3999';
        glLines.add(JournalEntryLineModel(
          id: 'jel_${entryId}_1',
          journalEntryId: entryId,
          organizationId: organizationId,
          lineNumber: 1,
          accountId: assetAccId,
          currencyCode: baseCurrency,
          exchangeRateScaled: fxScaled,
          foreignDebit: finalTotalCost,
          foreignCredit: 0,
          baseDebit: finalTotalCost,
          baseCredit: 0,
          description: 'إثبات رصيد افتتاحي للمخزون - سند رقم ${doc.documentNumber}',
          createdAt: now,
        ));
        glLines.add(JournalEntryLineModel(
          id: 'jel_${entryId}_2',
          journalEntryId: entryId,
          organizationId: organizationId,
          lineNumber: 2,
          accountId: equityAccId,
          currencyCode: baseCurrency,
          exchangeRateScaled: fxScaled,
          foreignDebit: 0,
          foreignCredit: finalTotalCost,
          baseDebit: 0,
          baseCredit: finalTotalCost,
          description: 'حساب الأرصدة الافتتاحية المقابل - سند رقم ${doc.documentNumber}',
          createdAt: now,
        ));
      } else if (doc.documentType == StockDocumentType.receipt) {
        // Debit Inventory Asset, Credit Supplier/Clearing Account
        String creditAccountId = '${organizationId}_2111'; // Accounts Payable Default
        if (doc.partyId != null) {
          // Check party control account
          final partyRes = await db.query(
            DatabaseConstants.tableParties,
            columns: ['control_account_id'],
            where: 'id = ? AND organization_id = ?',
            whereArgs: [doc.partyId, organizationId],
            limit: 1,
          );
          if (partyRes.isNotEmpty && partyRes.first['control_account_id'] != null) {
            creditAccountId = partyRes.first['control_account_id'] as String;
          }
        }

        glLines.add(JournalEntryLineModel(
          id: 'jel_${entryId}_1',
          journalEntryId: entryId,
          organizationId: organizationId,
          lineNumber: 1,
          accountId: assetAccId,
          currencyCode: baseCurrency,
          exchangeRateScaled: fxScaled,
          foreignDebit: finalTotalCost,
          foreignCredit: 0,
          baseDebit: finalTotalCost,
          baseCredit: 0,
          description: 'إدخال واستلام بضاعة للمستودع - سند رقم ${doc.documentNumber}',
          createdAt: now,
        ));
        glLines.add(JournalEntryLineModel(
          id: 'jel_${entryId}_2',
          journalEntryId: entryId,
          organizationId: organizationId,
          lineNumber: 2,
          accountId: creditAccountId,
          partyId: doc.partyId,
          currencyCode: baseCurrency,
          exchangeRateScaled: fxScaled,
          foreignDebit: 0,
          foreignCredit: finalTotalCost,
          baseDebit: 0,
          baseCredit: finalTotalCost,
          description: 'استحقاق مورد / مشتريات بضاعة - سند رقم ${doc.documentNumber}',
          createdAt: now,
        ));
      } else if (doc.documentType == StockDocumentType.issue) {
        // Debit Expense Account, Credit Inventory Asset
        int lineIdx = 1;
        for (final l in preparedLines) {
          final expAcc = l.expenseAccountId ??
              settings.cogsAccountId ??
              settings.inventoryAdjustmentAccountId ??
              '${organizationId}_51';

          glLines.add(JournalEntryLineModel(
            id: 'jel_${entryId}_$lineIdx',
            journalEntryId: entryId,
            organizationId: organizationId,
            lineNumber: lineIdx++,
            accountId: expAcc,
            currencyCode: baseCurrency,
            exchangeRateScaled: fxScaled,
            foreignDebit: l.totalCost,
            foreignCredit: 0,
            baseDebit: l.totalCost,
            baseCredit: 0,
            description: 'صرف بضاعة/مواد - ${l.notes ?? doc.notes ?? doc.documentNumber}',
            createdAt: now,
          ));
        }

        glLines.add(JournalEntryLineModel(
          id: 'jel_${entryId}_$lineIdx',
          journalEntryId: entryId,
          organizationId: organizationId,
          lineNumber: lineIdx,
          accountId: assetAccId,
          currencyCode: baseCurrency,
          exchangeRateScaled: fxScaled,
          foreignDebit: 0,
          foreignCredit: finalTotalCost,
          baseDebit: 0,
          baseCredit: finalTotalCost,
          description: 'تخفيض المخزون السلعي - سند صرف رقم ${doc.documentNumber}',
          createdAt: now,
        ));
      } else if (doc.documentType == StockDocumentType.adjustment) {
        // Inventory adjustment: Surplus or Deficit
        final adjAcc = settings.inventoryAdjustmentAccountId ?? '${organizationId}_5202';
        final isSurplus = doc.destinationWarehouseId != null;

        if (isSurplus) {
          // Surplus: Debit Asset, Credit Adjustment
          glLines.add(JournalEntryLineModel(
            id: 'jel_${entryId}_1',
            journalEntryId: entryId,
            organizationId: organizationId,
            lineNumber: 1,
            accountId: assetAccId,
            currencyCode: baseCurrency,
            exchangeRateScaled: fxScaled,
            foreignDebit: finalTotalCost,
            foreignCredit: 0,
            baseDebit: finalTotalCost,
            baseCredit: 0,
            description: 'تسوية جردية (فائض مخزني) - سند رقم ${doc.documentNumber}',
            createdAt: now,
          ));
          glLines.add(JournalEntryLineModel(
            id: 'jel_${entryId}_2',
            journalEntryId: entryId,
            organizationId: organizationId,
            lineNumber: 2,
            accountId: adjAcc,
            currencyCode: baseCurrency,
            exchangeRateScaled: fxScaled,
            foreignDebit: 0,
            foreignCredit: finalTotalCost,
            baseDebit: 0,
            baseCredit: finalTotalCost,
            description: 'أرباح وفروقات تسوية الجرد - سند رقم ${doc.documentNumber}',
            createdAt: now,
          ));
        } else {
          // Deficit: Debit Adjustment, Credit Asset
          glLines.add(JournalEntryLineModel(
            id: 'jel_${entryId}_1',
            journalEntryId: entryId,
            organizationId: organizationId,
            lineNumber: 1,
            accountId: adjAcc,
            currencyCode: baseCurrency,
            exchangeRateScaled: fxScaled,
            foreignDebit: finalTotalCost,
            foreignCredit: 0,
            baseDebit: finalTotalCost,
            baseCredit: 0,
            description: 'فروقات وتلفيات تسوية الجرد - سند رقم ${doc.documentNumber}',
            createdAt: now,
          ));
          glLines.add(JournalEntryLineModel(
            id: 'jel_${entryId}_2',
            journalEntryId: entryId,
            organizationId: organizationId,
            lineNumber: 2,
            accountId: assetAccId,
            currencyCode: baseCurrency,
            exchangeRateScaled: fxScaled,
            foreignDebit: 0,
            foreignCredit: finalTotalCost,
            baseDebit: 0,
            baseCredit: finalTotalCost,
            description: 'تخفيض المخزون لعجز الجرد - سند رقم ${doc.documentNumber}',
            createdAt: now,
          ));
        }
      }

      journalEntry = JournalEntryModel(
        id: entryId,
        organizationId: organizationId,
        fiscalPeriodId: periodId,
        entryNumber: entryNumber,
        entryDate: doc.documentDate,
        entryType: JournalEntryType.general,
        reference: doc.documentNumber,
        narration: '${doc.documentTypeLabelAr} - سند رقم ${doc.documentNumber}',
        status: JournalEntryStatus.posted,
        totalBaseDebit: finalTotalCost,
        totalBaseCredit: finalTotalCost,
        postedAt: now,
        createdAt: now,
        updatedAt: now,
      );
    }

    // 6. Execute atomic transaction
    await db.transaction((txn) async {
      // A. Post journal entry if generated
      if (journalEntry != null && glLines.isNotEmpty) {
        await txn.insert(
          DatabaseConstants.tableJournalEntries,
          journalEntry.toMap(),
        );
        for (final l in glLines) {
          await txn.insert(
            DatabaseConstants.tableJournalEntryLines,
            l.toMap(),
          );
        }
      }

      // B. Insert stock movements
      for (final line in preparedLines) {
        if (doc.documentType == StockDocumentType.opening ||
            doc.documentType == StockDocumentType.receipt) {
          final whId = doc.destinationWarehouseId ?? doc.sourceWarehouseId!;
          await txn.insert(
            DatabaseConstants.tableStockMovements,
            StockMovementModel(
              id: 'sm_${doc.id}_${line.id}_in',
              organizationId: organizationId,
              itemId: line.itemId,
              warehouseId: whId,
              documentId: doc.id,
              documentLineId: line.id,
              documentNumber: doc.documentNumber,
              movementType: doc.documentType == StockDocumentType.opening
                  ? StockMovementType.opening
                  : StockMovementType.receipt,
              movementDate: doc.documentDate,
              quantityIn: line.baseQuantity,
              quantityOut: 0,
              unitCost: line.unitCost,
              totalCost: line.totalCost,
              notes: line.notes ?? doc.notes,
              createdAt: now,
            ).toMap(),
          );
        } else if (doc.documentType == StockDocumentType.issue) {
          final whId = doc.sourceWarehouseId ?? doc.destinationWarehouseId!;
          await txn.insert(
            DatabaseConstants.tableStockMovements,
            StockMovementModel(
              id: 'sm_${doc.id}_${line.id}_out',
              organizationId: organizationId,
              itemId: line.itemId,
              warehouseId: whId,
              documentId: doc.id,
              documentLineId: line.id,
              documentNumber: doc.documentNumber,
              movementType: StockMovementType.issue,
              movementDate: doc.documentDate,
              quantityIn: 0,
              quantityOut: line.baseQuantity,
              unitCost: line.unitCost,
              totalCost: line.totalCost,
              notes: line.notes ?? doc.notes,
              createdAt: now,
            ).toMap(),
          );
        } else if (doc.documentType == StockDocumentType.transfer) {
          // Movement 1: Transfer Out from source
          await txn.insert(
            DatabaseConstants.tableStockMovements,
            StockMovementModel(
              id: 'sm_${doc.id}_${line.id}_tout',
              organizationId: organizationId,
              itemId: line.itemId,
              warehouseId: doc.sourceWarehouseId!,
              documentId: doc.id,
              documentLineId: line.id,
              documentNumber: doc.documentNumber,
              movementType: StockMovementType.transferOut,
              movementDate: doc.documentDate,
              quantityIn: 0,
              quantityOut: line.baseQuantity,
              unitCost: line.unitCost,
              totalCost: line.totalCost,
              notes: 'صادر مناقلة إلى ${doc.destinationWarehouseName ?? ""}',
              createdAt: now,
            ).toMap(),
          );

          // Movement 2: Transfer In to destination
          await txn.insert(
            DatabaseConstants.tableStockMovements,
            StockMovementModel(
              id: 'sm_${doc.id}_${line.id}_tin',
              organizationId: organizationId,
              itemId: line.itemId,
              warehouseId: doc.destinationWarehouseId!,
              documentId: doc.id,
              documentLineId: line.id,
              documentNumber: doc.documentNumber,
              movementType: StockMovementType.transferIn,
              movementDate: doc.documentDate,
              quantityIn: line.baseQuantity,
              quantityOut: 0,
              unitCost: line.unitCost,
              totalCost: line.totalCost,
              notes: 'وارد مناقلة من ${doc.sourceWarehouseName ?? ""}',
              createdAt: now,
            ).toMap(),
          );
        } else if (doc.documentType == StockDocumentType.adjustment) {
          final isSurplus = doc.destinationWarehouseId != null;
          final whId = (isSurplus ? doc.destinationWarehouseId : doc.sourceWarehouseId)!;
          await txn.insert(
            DatabaseConstants.tableStockMovements,
            StockMovementModel(
              id: 'sm_${doc.id}_${line.id}_adj',
              organizationId: organizationId,
              itemId: line.itemId,
              warehouseId: whId,
              documentId: doc.id,
              documentLineId: line.id,
              documentNumber: doc.documentNumber,
              movementType: isSurplus
                  ? StockMovementType.adjustmentIn
                  : StockMovementType.adjustmentOut,
              movementDate: doc.documentDate,
              quantityIn: isSurplus ? line.baseQuantity : 0,
              quantityOut: isSurplus ? 0 : line.baseQuantity,
              unitCost: line.unitCost,
              totalCost: line.totalCost,
              notes: line.notes ?? doc.notes,
              createdAt: now,
            ).toMap(),
          );
        }
      }

      // C. Update stock document status
      await txn.update(
        DatabaseConstants.tableStockDocuments,
        {
          'status': StockDocumentStatus.posted,
          'total_cost': finalTotalCost,
          'journal_entry_id': journalEntry?.id,
          'posted_at': now,
          'posted_by': 'abu-ali',
        },
        where: 'id = ? AND organization_id = ?',
        whereArgs: [doc.id, organizationId],
      );

      // D. Audit log
      await txn.insert(
        DatabaseConstants.tableAuditLogs,
        {
          'id': 'audit_stk_${doc.id}_$now',
          'organization_id': organizationId,
          'entity_name': DatabaseConstants.tableStockDocuments,
          'entity_id': doc.id,
          'action': 'POST',
          'performed_by': 'abu-ali',
          'performed_at': now,
          'details': 'ترحيل ${doc.documentTypeLabelAr} رقم ${doc.documentNumber}',
        },
      );
    });
  }

  // ===========================================================================
  // 7. STOCKTAKING (PHYSICAL INVENTORY COUNT)
  // ===========================================================================

  Future<String> getNextStocktakingSessionNumber(String organizationId) async {
    final db = await _db;
    final year = DateTime.now().year;

    final results = await db.rawQuery('''
      SELECT session_number FROM ${DatabaseConstants.tableStocktakingSessions}
      WHERE organization_id = ? AND session_number LIKE 'STK-CNT-$year-%'
      ORDER BY session_number DESC
      LIMIT 1
    ''', [organizationId]);

    if (results.isEmpty) {
      return 'STK-CNT-$year-0001';
    }

    final last = results.first['session_number'] as String;
    final parts = last.split('-');
    if (parts.length >= 4) {
      final numVal = int.tryParse(parts.last);
      if (numVal != null) {
        return 'STK-CNT-$year-${(numVal + 1).toString().padLeft(4, '0')}';
      }
    }

    return 'STK-CNT-$year-${DateTime.now().millisecondsSinceEpoch % 10000}';
  }

  Future<List<StocktakingSessionModel>> getStocktakingSessions({
    required String organizationId,
    String? status,
    String? warehouseId,
  }) async {
    final db = await _db;
    final args = <dynamic>[organizationId];
    String whereSql = 's.organization_id = ?';

    if (status != null && status.isNotEmpty && status != 'ALL') {
      whereSql += ' AND s.status = ?';
      args.add(status);
    }

    if (warehouseId != null && warehouseId.isNotEmpty && warehouseId != 'ALL') {
      whereSql += ' AND s.warehouse_id = ?';
      args.add(warehouseId);
    }

    final sql = '''
      SELECT 
        s.*,
        w.name AS warehouse_name,
        c.name_ar AS category_name_ar,
        COUNT(l.id) AS total_items,
        COUNT(CASE WHEN l.counted_quantity IS NOT NULL THEN 1 END) AS counted_items,
        COALESCE(SUM(l.difference_value), 0) AS total_difference_value
      FROM ${DatabaseConstants.tableStocktakingSessions} s
      LEFT JOIN ${DatabaseConstants.tableWarehouses} w ON s.warehouse_id = w.id
      LEFT JOIN ${DatabaseConstants.tableItemCategories} c ON s.category_id = c.id
      LEFT JOIN ${DatabaseConstants.tableStocktakingLines} l ON s.id = l.session_id
      WHERE $whereSql
      GROUP BY s.id
      ORDER BY s.started_at DESC, s.created_at DESC
    ''';

    final rows = await db.rawQuery(sql, args);
    return rows.map((r) => StocktakingSessionModel.fromMap(r)).toList();
  }

  Future<StocktakingSessionModel?> getStocktakingSessionById(
      String sessionId, String organizationId) async {
    final db = await _db;

    final headerRows = await db.rawQuery('''
      SELECT 
        s.*,
        w.name AS warehouse_name,
        c.name_ar AS category_name_ar,
        COUNT(l.id) AS total_items,
        COUNT(CASE WHEN l.counted_quantity IS NOT NULL THEN 1 END) AS counted_items,
        COALESCE(SUM(l.difference_value), 0) AS total_difference_value
      FROM ${DatabaseConstants.tableStocktakingSessions} s
      LEFT JOIN ${DatabaseConstants.tableWarehouses} w ON s.warehouse_id = w.id
      LEFT JOIN ${DatabaseConstants.tableItemCategories} c ON s.category_id = c.id
      LEFT JOIN ${DatabaseConstants.tableStocktakingLines} l ON s.id = l.session_id
      WHERE s.id = ? AND s.organization_id = ?
      GROUP BY s.id
      LIMIT 1
    ''', [sessionId, organizationId]);

    if (headerRows.isEmpty) return null;

    final linesRows = await db.rawQuery('''
      SELECT 
        l.*,
        i.item_code,
        i.name_ar AS item_name_ar,
        u.name_ar AS unit_name_ar,
        u.symbol AS unit_symbol
      FROM ${DatabaseConstants.tableStocktakingLines} l
      INNER JOIN ${DatabaseConstants.tableItems} i ON l.item_id = i.id
      INNER JOIN ${DatabaseConstants.tableUnitsOfMeasure} u ON i.base_unit_id = u.id
      WHERE l.session_id = ? AND l.organization_id = ?
      ORDER BY i.item_code ASC
    ''', [sessionId, organizationId]);

    final lines =
        linesRows.map((r) => StocktakingLineModel.fromMap(r)).toList();
    return StocktakingSessionModel.fromMap(headerRows.first, lines: lines);
  }

  /// Initializes a new stocktaking session and captures the current system quantities.
  Future<StocktakingSessionModel> startStocktakingSession({
    required String organizationId,
    required String warehouseId,
    String? categoryId,
    String? notes,
  }) async {
    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();
    final sessionNum = await getNextStocktakingSessionNumber(organizationId);
    final sessionId = 'stk_ses_${DateTime.now().millisecondsSinceEpoch}';

    // Fetch items to count in this warehouse
    final items = await getItems(
      organizationId: organizationId,
      categoryId: categoryId,
      warehouseId: warehouseId,
      includeInactive: false,
    );

    final trackableItems = items.where((i) => i.trackInventory && !i.isService).toList();

    await db.transaction((txn) async {
      await txn.insert(
        DatabaseConstants.tableStocktakingSessions,
        {
          'id': sessionId,
          'organization_id': organizationId,
          'session_number': sessionNum,
          'warehouse_id': warehouseId,
          'category_id': categoryId,
          'status': StocktakingStatus.inProgress,
          'started_at': now,
          'notes': notes,
          'created_at': now,
        },
      );

      for (final it in trackableItems) {
        final sysQty = await getItemStock(it.id, organizationId,
            warehouseId: warehouseId);
        final avgCost = await getItemWeightedAverageCost(it.id, organizationId);

        await txn.insert(
          DatabaseConstants.tableStocktakingLines,
          {
            'id': 'stk_line_${sessionId}_${it.id}',
            'organization_id': organizationId,
            'session_id': sessionId,
            'item_id': it.id,
            'system_quantity': sysQty,
            'counted_quantity': null,
            'difference_quantity': null,
            'unit_cost': avgCost,
            'difference_value': null,
            'notes': null,
          },
        );
      }
    });

    return (await getStocktakingSessionById(sessionId, organizationId))!;
  }

  /// Updates actual counted quantities for stocktaking lines.
  Future<void> updateStocktakingCount({
    required String lineId,
    required String organizationId,
    required int countedQuantity, // Scaled 10^3
    String? notes,
  }) async {
    final db = await _db;

    final lineRes = await db.query(
      DatabaseConstants.tableStocktakingLines,
      where: 'id = ? AND organization_id = ?',
      whereArgs: [lineId, organizationId],
      limit: 1,
    );
    if (lineRes.isEmpty) throw Exception('سطر الجرد غير موجود.');

    final sysQty = (lineRes.first['system_quantity'] as num).toInt();
    final uCost = (lineRes.first['unit_cost'] as num).toInt();

    final diffQty = countedQuantity - sysQty;
    final diffVal = ((diffQty * uCost) / DatabaseConstants.quantityScale).round();

    await db.update(
      DatabaseConstants.tableStocktakingLines,
      {
        'counted_quantity': countedQuantity,
        'difference_quantity': diffQty,
        'difference_value': diffVal,
        'notes': notes,
      },
      where: 'id = ? AND organization_id = ?',
      whereArgs: [lineId, organizationId],
    );
  }

  /// Completes stocktaking session and marks it ready for approval.
  Future<void> completeStocktakingSession(
      String sessionId, String organizationId) async {
    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.update(
      DatabaseConstants.tableStocktakingSessions,
      {
        'status': StocktakingStatus.completed,
        'completed_at': now,
      },
      where: 'id = ? AND organization_id = ?',
      whereArgs: [sessionId, organizationId],
    );
  }

  /// Approves stocktaking session, generates and posts an inventory adjustment document.
  Future<StockDocumentModel> postStocktakingAdjustment(
      String sessionId, String organizationId) async {
    final session = await getStocktakingSessionById(sessionId, organizationId);
    if (session == null) throw Exception('جلسة الجرد غير موجودة.');
    if (session.isPosted) throw Exception('تم اعتماد وتسوية جلسة الجرد هذه مسبقاً.');

    final linesWithVariance =
        session.lines.where((l) => l.isCounted && l.differenceQuantity != 0).toList();

    if (linesWithVariance.isEmpty) {
      // Mark as posted without creating adjustment document
      final db = await _db;
      await db.update(
        DatabaseConstants.tableStocktakingSessions,
        {'status': StocktakingStatus.posted},
        where: 'id = ? AND organization_id = ?',
        whereArgs: [sessionId, organizationId],
      );
      throw Exception('لا توجد أي فروقات بين الجرد الفعلي ورصيد النظام. تم اعتماد الجرد بنجاح دون الحاجة لسند تسوية.');
    }

    final today = DateTime.now().toIso8601String().split('T').first;
    final docNum = await getNextStockDocumentNumber(
        organizationId, StockDocumentType.adjustment);
    final docId = 'doc_adj_stk_$sessionId';

    // Separate surplus and deficit or create balanced adjustment document
    int totalAdjVal = 0;
    final docLines = <StockDocumentLineModel>[];

    for (int i = 0; i < linesWithVariance.length; i++) {
      final l = linesWithVariance[i];
      final absQty = (l.differenceQuantity ?? 0).abs();
      final lineCost = (l.differenceValue ?? 0).abs();
      totalAdjVal += lineCost;

      docLines.add(StockDocumentLineModel(
        id: 'line_${docId}_${i + 1}',
        organizationId: organizationId,
        documentId: docId,
        lineNumber: i + 1,
        itemId: l.itemId,
        unitId: 'base', // Base unit
        quantity: absQty,
        conversionFactor: 1000,
        baseQuantity: absQty,
        unitCost: l.unitCost,
        totalCost: lineCost,
        notes: (l.differenceQuantity ?? 0) > 0 ? 'فائض جرد فعلي' : 'عجز وتلف جرد فعلي',
      ));
    }

    final bool isNetSurplus = (session.totalDifferenceValue >= 0);

    final adjDoc = StockDocumentModel(
      id: docId,
      organizationId: organizationId,
      documentNumber: docNum,
      documentType: StockDocumentType.adjustment,
      documentDate: today,
      sourceWarehouseId: isNetSurplus ? null : session.warehouseId,
      destinationWarehouseId: isNetSurplus ? session.warehouseId : null,
      status: StockDocumentStatus.draft,
      notes: 'تسوية آلية ناتجة عن جلسة الجرد رقم ${session.sessionNumber}',
      totalCost: totalAdjVal,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );

    // Save and post document
    await saveStockDocument(document: adjDoc, lines: docLines);
    await postStockDocument(docId, organizationId);

    // Link adjustment document to session
    final db = await _db;
    await db.update(
      DatabaseConstants.tableStocktakingSessions,
      {
        'status': StocktakingStatus.posted,
        'adjustment_document_id': docId,
      },
      where: 'id = ? AND organization_id = ?',
      whereArgs: [sessionId, organizationId],
    );

    return (await getStockDocumentById(docId, organizationId))!;
  }
}
