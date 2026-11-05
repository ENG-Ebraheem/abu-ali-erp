import 'package:sqflite/sqflite.dart';
import 'package:abu_ali/core/constants/database_constants.dart';
import 'package:abu_ali/core/database/database_helper.dart';

/// Repository extracting and aggregating data for the 12 Inventory Reports.
class InventoryReportsRepository {
  final DatabaseHelper _dbHelper;

  InventoryReportsRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db async => await _dbHelper.database;

  // ---------------------------------------------------------------------------
  // 1. Current Stock Report (تقرير المخزون الحالي)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getCurrentStockReport({
    required String organizationId,
    String? warehouseId,
    String? categoryId,
    String? query,
  }) async {
    final db = await _db;
    final args = <dynamic>[organizationId];
    String whereSql = 'i.organization_id = ? AND i.track_inventory = 1';

    if (warehouseId != null && warehouseId.isNotEmpty && warehouseId != 'ALL') {
      whereSql += ' AND sm.warehouse_id = ?';
      args.add(warehouseId);
    }
    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'ALL') {
      whereSql += ' AND i.category_id = ?';
      args.add(categoryId);
    }
    if (query != null && query.trim().isNotEmpty) {
      whereSql += ' AND (i.item_code LIKE ? OR i.name_ar LIKE ?)';
      final q = '%${query.trim()}%';
      args.addAll([q, q]);
    }

    final sql = '''
      SELECT 
        i.id,
        i.item_code,
        i.name_ar,
        c.name_ar AS category_name,
        u.name_ar AS unit_name,
        u.symbol AS unit_symbol,
        COALESCE(SUM(sm.quantity_in - sm.quantity_out), 0) AS current_stock,
        COALESCE(
          (SELECT unit_cost FROM ${DatabaseConstants.tableStockMovements} 
           WHERE item_id = i.id AND organization_id = i.organization_id AND quantity_in > 0 
           ORDER BY movement_date DESC, created_at DESC LIMIT 1),
          i.purchase_price
        ) AS unit_cost,
        i.selling_price
      FROM ${DatabaseConstants.tableItems} i
      LEFT JOIN ${DatabaseConstants.tableItemCategories} c ON i.category_id = c.id
      LEFT JOIN ${DatabaseConstants.tableUnitsOfMeasure} u ON i.base_unit_id = u.id
      LEFT JOIN ${DatabaseConstants.tableStockMovements} sm 
        ON i.id = sm.item_id AND i.organization_id = sm.organization_id
      WHERE $whereSql
      GROUP BY i.id
      ORDER BY i.item_code ASC
    ''';

    final rows = await db.rawQuery(sql, args);
    return rows.map((r) {
      final stock = (r['current_stock'] as num).toInt();
      final cost = (r['unit_cost'] as num).toInt();
      final totalVal = ((stock * cost) / DatabaseConstants.quantityScale).round();
      return {
        ...r,
        'current_stock': stock,
        'unit_cost': cost,
        'total_value': totalVal,
      };
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // 2. Stock by Warehouse Report (تقرير المخزون حسب المستودع)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getStockByWarehouseReport(
      String organizationId) async {
    final db = await _db;
    final sql = '''
      SELECT 
        w.id AS warehouse_id,
        w.code AS warehouse_code,
        w.name AS warehouse_name,
        COUNT(DISTINCT sm.item_id) AS distinct_items,
        COALESCE(SUM(sm.quantity_in - sm.quantity_out), 0) AS total_quantity,
        COALESCE(SUM(
          CASE 
            WHEN sm.quantity_in > 0 THEN ((sm.quantity_in * sm.unit_cost) / 1000)
            ELSE -((sm.quantity_out * sm.unit_cost) / 1000)
          END
        ), 0) AS total_valuation
      FROM ${DatabaseConstants.tableWarehouses} w
      LEFT JOIN ${DatabaseConstants.tableStockMovements} sm 
        ON w.id = sm.warehouse_id AND w.organization_id = sm.organization_id
      WHERE w.organization_id = ?
      GROUP BY w.id
      ORDER BY w.code ASC
    ''';

    return await db.rawQuery(sql, [organizationId]);
  }

  // ---------------------------------------------------------------------------
  // 3. Stock by Category Report (تقرير المخزون حسب التصنيف)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getStockByCategoryReport(
      String organizationId) async {
    final db = await _db;
    final sql = '''
      SELECT 
        COALESCE(c.id, 'uncategorized') AS category_id,
        COALESCE(c.code, 'N/A') AS category_code,
        COALESCE(c.name_ar, 'غير مصنف') AS category_name,
        COUNT(DISTINCT i.id) AS item_count,
        COALESCE(SUM(sm.quantity_in - sm.quantity_out), 0) AS total_quantity,
        COALESCE(SUM(
          CASE 
            WHEN sm.quantity_in > 0 THEN ((sm.quantity_in * sm.unit_cost) / 1000)
            ELSE -((sm.quantity_out * sm.unit_cost) / 1000)
          END
        ), 0) AS total_valuation
      FROM ${DatabaseConstants.tableItems} i
      LEFT JOIN ${DatabaseConstants.tableItemCategories} c ON i.category_id = c.id
      LEFT JOIN ${DatabaseConstants.tableStockMovements} sm 
        ON i.id = sm.item_id AND i.organization_id = sm.organization_id
      WHERE i.organization_id = ? AND i.track_inventory = 1
      GROUP BY c.id
      ORDER BY c.code ASC
    ''';

    return await db.rawQuery(sql, [organizationId]);
  }

  // ---------------------------------------------------------------------------
  // 4. Stock Movement Report (تقرير حركة المخزون)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getStockMovementsReport({
    required String organizationId,
    String? warehouseId,
    String? itemId,
    String? movementType,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _db;
    final args = <dynamic>[organizationId];
    String whereSql = 'sm.organization_id = ?';

    if (warehouseId != null && warehouseId.isNotEmpty && warehouseId != 'ALL') {
      whereSql += ' AND sm.warehouse_id = ?';
      args.add(warehouseId);
    }
    if (itemId != null && itemId.isNotEmpty && itemId != 'ALL') {
      whereSql += ' AND sm.item_id = ?';
      args.add(itemId);
    }
    if (movementType != null && movementType.isNotEmpty && movementType != 'ALL') {
      whereSql += ' AND sm.movement_type = ?';
      args.add(movementType);
    }
    if (fromDate != null && fromDate.isNotEmpty) {
      whereSql += ' AND sm.movement_date >= ?';
      args.add(fromDate);
    }
    if (toDate != null && toDate.isNotEmpty) {
      whereSql += ' AND sm.movement_date <= ?';
      args.add(toDate);
    }

    final sql = '''
      SELECT 
        sm.*,
        i.item_code,
        i.name_ar AS item_name_ar,
        w.name AS warehouse_name,
        u.symbol AS unit_symbol
      FROM ${DatabaseConstants.tableStockMovements} sm
      INNER JOIN ${DatabaseConstants.tableItems} i ON sm.item_id = i.id
      INNER JOIN ${DatabaseConstants.tableWarehouses} w ON sm.warehouse_id = w.id
      INNER JOIN ${DatabaseConstants.tableUnitsOfMeasure} u ON i.base_unit_id = u.id
      WHERE $whereSql
      ORDER BY sm.movement_date DESC, sm.created_at DESC
      LIMIT 200
    ''';

    return await db.rawQuery(sql, args);
  }

  // ---------------------------------------------------------------------------
  // 5. Item Stock Card (كارت الصنف / أستاذ الصنف)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getItemStockCard({
    required String organizationId,
    required String itemId,
    String? warehouseId,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _db;
    final args = <dynamic>[organizationId, itemId];
    String whereSql = 'sm.organization_id = ? AND sm.item_id = ?';

    if (warehouseId != null && warehouseId.isNotEmpty && warehouseId != 'ALL') {
      whereSql += ' AND sm.warehouse_id = ?';
      args.add(warehouseId);
    }

    final sql = '''
      SELECT 
        sm.*,
        w.name AS warehouse_name,
        u.symbol AS unit_symbol
      FROM ${DatabaseConstants.tableStockMovements} sm
      INNER JOIN ${DatabaseConstants.tableWarehouses} w ON sm.warehouse_id = w.id
      INNER JOIN ${DatabaseConstants.tableItems} i ON sm.item_id = i.id
      INNER JOIN ${DatabaseConstants.tableUnitsOfMeasure} u ON i.base_unit_id = u.id
      WHERE $whereSql
      ORDER BY sm.movement_date ASC, sm.created_at ASC
    ''';

    final rows = await db.rawQuery(sql, args);

    // Compute running balance
    int runningQty = 0;
    int runningVal = 0;
    final result = <Map<String, dynamic>>[];

    for (final r in rows) {
      final qIn = (r['quantity_in'] as num).toInt();
      final qOut = (r['quantity_out'] as num).toInt();
      final cost = (r['unit_cost'] as num).toInt();

      runningQty += (qIn - qOut);
      if (qIn > 0) {
        runningVal += ((qIn * cost) / DatabaseConstants.quantityScale).round();
      } else {
        runningVal -= ((qOut * cost) / DatabaseConstants.quantityScale).round();
      }
      if (runningVal < 0) runningVal = 0;

      final date = r['movement_date'] as String;
      if (fromDate != null && fromDate.isNotEmpty && date.compareTo(fromDate) < 0) {
        continue;
      }
      if (toDate != null && toDate.isNotEmpty && date.compareTo(toDate) > 0) {
        continue;
      }

      result.add({
        ...r,
        'running_quantity': runningQty,
        'running_value': runningVal,
      });
    }

    return result.reversed.toList();
  }

  // ---------------------------------------------------------------------------
  // 6. Inventory Valuation Report (تقرير تقييم المخزون)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getInventoryValuationReport({
    required String organizationId,
    String? warehouseId,
  }) async {
    final items = await getCurrentStockReport(
      organizationId: organizationId,
      warehouseId: warehouseId,
    );

    return items.map((i) {
      final stock = (i['current_stock'] as num).toInt();
      final cost = (i['unit_cost'] as num).toInt();
      final sell = (i['selling_price'] as num).toInt();

      final costVal = ((stock * cost) / DatabaseConstants.quantityScale).round();
      final retailVal = ((stock * sell) / DatabaseConstants.quantityScale).round();
      final potentialProfit = retailVal - costVal;

      return {
        ...i,
        'cost_valuation': costVal,
        'retail_valuation': retailVal,
        'potential_profit': potentialProfit,
      };
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // 7. Low Stock Report (تقرير النواقص / حد الطلب)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getLowStockReport(
      String organizationId) async {
    final items = await getCurrentStockReport(organizationId: organizationId);
    final db = await _db;

    final rows = await db.query(
      DatabaseConstants.tableItems,
      columns: ['id', 'reorder_level', 'min_stock_level'],
      where: 'organization_id = ? AND reorder_level > 0',
      whereArgs: [organizationId],
    );

    final reorderMap = {for (var r in rows) r['id'] as String: r};

    final lowStock = <Map<String, dynamic>>[];
    for (final it in items) {
      final id = it['id'] as String;
      if (reorderMap.containsKey(id)) {
        final reorder = (reorderMap[id]!['reorder_level'] as num).toInt();
        final current = (it['current_stock'] as num).toInt();
        if (current <= reorder) {
          lowStock.add({
            ...it,
            'reorder_level': reorder,
            'shortage_quantity': reorder - current,
          });
        }
      }
    }

    return lowStock;
  }

  // ---------------------------------------------------------------------------
  // 8. Out of Stock Report (تقرير الأصناف المنتهية)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getOutOfStockReport(
      String organizationId) async {
    final items = await getCurrentStockReport(organizationId: organizationId);
    return items.where((i) => (i['current_stock'] as num).toInt() <= 0).toList();
  }

  // ---------------------------------------------------------------------------
  // 9. Stocktaking Differences Report (تقرير فروقات الجرد)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getStocktakingDifferencesReport(
      String sessionId, String organizationId) async {
    final db = await _db;
    final sql = '''
      SELECT 
        l.*,
        i.item_code,
        i.name_ar AS item_name_ar,
        u.name_ar AS unit_name_ar,
        u.symbol AS unit_symbol,
        s.session_number,
        w.name AS warehouse_name
      FROM ${DatabaseConstants.tableStocktakingLines} l
      INNER JOIN ${DatabaseConstants.tableStocktakingSessions} s ON l.session_id = s.id
      INNER JOIN ${DatabaseConstants.tableItems} i ON l.item_id = i.id
      INNER JOIN ${DatabaseConstants.tableWarehouses} w ON s.warehouse_id = w.id
      INNER JOIN ${DatabaseConstants.tableUnitsOfMeasure} u ON i.base_unit_id = u.id
      WHERE l.session_id = ? AND l.organization_id = ? AND (l.difference_quantity != 0 OR l.difference_quantity IS NULL)
      ORDER BY i.item_code ASC
    ''';

    return await db.rawQuery(sql, [sessionId, organizationId]);
  }

  // ---------------------------------------------------------------------------
  // 10. Stock Receipts Report (تقرير سندات الإدخال)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getStockReceiptsReport({
    required String organizationId,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _db;
    final args = <dynamic>[organizationId, StockDocumentType.receipt];
    String whereSql = 'd.organization_id = ? AND d.document_type = ?';

    if (fromDate != null && fromDate.isNotEmpty) {
      whereSql += ' AND d.document_date >= ?';
      args.add(fromDate);
    }
    if (toDate != null && toDate.isNotEmpty) {
      whereSql += ' AND d.document_date <= ?';
      args.add(toDate);
    }

    final sql = '''
      SELECT 
        d.*,
        w.name AS warehouse_name,
        p.name_ar AS supplier_name,
        COUNT(l.id) AS item_count
      FROM ${DatabaseConstants.tableStockDocuments} d
      LEFT JOIN ${DatabaseConstants.tableWarehouses} w ON d.destination_warehouse_id = w.id
      LEFT JOIN ${DatabaseConstants.tableParties} p ON d.party_id = p.id
      LEFT JOIN ${DatabaseConstants.tableStockDocumentLines} l ON d.id = l.document_id
      WHERE $whereSql
      GROUP BY d.id
      ORDER BY d.document_date DESC, d.created_at DESC
    ''';

    return await db.rawQuery(sql, args);
  }

  // ---------------------------------------------------------------------------
  // 11. Stock Issues Report (تقرير سندات الإخراج)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getStockIssuesReport({
    required String organizationId,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _db;
    final args = <dynamic>[organizationId, StockDocumentType.issue];
    String whereSql = 'd.organization_id = ? AND d.document_type = ?';

    if (fromDate != null && fromDate.isNotEmpty) {
      whereSql += ' AND d.document_date >= ?';
      args.add(fromDate);
    }
    if (toDate != null && toDate.isNotEmpty) {
      whereSql += ' AND d.document_date <= ?';
      args.add(toDate);
    }

    final sql = '''
      SELECT 
        d.*,
        w.name AS warehouse_name,
        COUNT(l.id) AS item_count
      FROM ${DatabaseConstants.tableStockDocuments} d
      LEFT JOIN ${DatabaseConstants.tableWarehouses} w ON d.source_warehouse_id = w.id
      LEFT JOIN ${DatabaseConstants.tableStockDocumentLines} l ON d.id = l.document_id
      WHERE $whereSql
      GROUP BY d.id
      ORDER BY d.document_date DESC, d.created_at DESC
    ''';

    return await db.rawQuery(sql, args);
  }

  // ---------------------------------------------------------------------------
  // 12. Warehouse Transfers Report (تقرير مناقلات المستودعات)
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getWarehouseTransfersReport({
    required String organizationId,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _db;
    final args = <dynamic>[organizationId, StockDocumentType.transfer];
    String whereSql = 'd.organization_id = ? AND d.document_type = ?';

    if (fromDate != null && fromDate.isNotEmpty) {
      whereSql += ' AND d.document_date >= ?';
      args.add(fromDate);
    }
    if (toDate != null && toDate.isNotEmpty) {
      whereSql += ' AND d.document_date <= ?';
      args.add(toDate);
    }

    final sql = '''
      SELECT 
        d.*,
        sw.name AS source_warehouse_name,
        dw.name AS destination_warehouse_name,
        COUNT(l.id) AS item_count
      FROM ${DatabaseConstants.tableStockDocuments} d
      INNER JOIN ${DatabaseConstants.tableWarehouses} sw ON d.source_warehouse_id = sw.id
      INNER JOIN ${DatabaseConstants.tableWarehouses} dw ON d.destination_warehouse_id = dw.id
      LEFT JOIN ${DatabaseConstants.tableStockDocumentLines} l ON d.id = l.document_id
      WHERE $whereSql
      GROUP BY d.id
      ORDER BY d.document_date DESC, d.created_at DESC
    ''';

    return await db.rawQuery(sql, args);
  }
}
