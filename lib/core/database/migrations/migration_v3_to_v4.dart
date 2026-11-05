import 'package:sqflite/sqflite.dart';
import '../../constants/database_constants.dart';
import 'migration.dart';

/// Migration from schema Version 3 to Version 4.
///
/// Implements Phase 8: Complete Inventory & Warehouse Management System:
/// 1. Warehouses (Multi-warehouse support with organization isolation).
/// 2. Hierarchical Item & Material Categories.
/// 3. Units of Measurement & Multi-Unit Conversions.
/// 4. Products and Materials Catalog (Merchandise, Raw, Finished, Consumable, Services).
/// 5. Stock Documents & Lines (Opening, Receipts, Issues, Transfers, Adjustments).
/// 6. Physical Stock Movements Ledger (Item Stock Card & Running Balances).
/// 7. Stocktaking Sessions & Physical Count Variance Lines.
/// 8. Organization-Scoped Inventory Settings & Account Mapping.
/// 9. Comprehensive Indexes and Non-Destructive Integrity Triggers.
class MigrationV3ToV4 implements Migration {
  @override
  int get version => 4;

  @override
  String get description =>
      'Phase 8: Complete Inventory & Warehouse Management System with Multi-Warehouse, Multi-Unit, Stock Movements, Stocktaking, and Accounting Integration.';

  @override
  Future<void> up(DatabaseExecutor db) async {
    // -----------------------------------------------------------------
    // 1. Warehouses Table
    // -----------------------------------------------------------------
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableWarehouses} (
        id TEXT PRIMARY KEY,
        organization_id TEXT NOT NULL,
        code TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        location TEXT,
        responsible_person TEXT,
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations}(id) ON DELETE RESTRICT,
        CONSTRAINT uq_warehouses_org_code UNIQUE (organization_id, code)
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_warehouses_org 
      ON ${DatabaseConstants.tableWarehouses}(organization_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_warehouses_active 
      ON ${DatabaseConstants.tableWarehouses}(organization_id, is_active);
    ''');

    // -----------------------------------------------------------------
    // 2. Item Categories Table
    // -----------------------------------------------------------------
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableItemCategories} (
        id TEXT PRIMARY KEY,
        organization_id TEXT NOT NULL,
        code TEXT NOT NULL,
        name_ar TEXT NOT NULL,
        name_en TEXT,
        parent_id TEXT,
        description TEXT,
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations}(id) ON DELETE RESTRICT,
        FOREIGN KEY (parent_id) REFERENCES ${DatabaseConstants.tableItemCategories}(id) ON DELETE RESTRICT,
        CONSTRAINT uq_item_categories_org_code UNIQUE (organization_id, code)
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_item_categories_org 
      ON ${DatabaseConstants.tableItemCategories}(organization_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_item_categories_parent 
      ON ${DatabaseConstants.tableItemCategories}(parent_id);
    ''');

    // -----------------------------------------------------------------
    // 3. Units of Measure Table
    // -----------------------------------------------------------------
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableUnitsOfMeasure} (
        id TEXT PRIMARY KEY,
        organization_id TEXT NOT NULL,
        code TEXT NOT NULL,
        name_ar TEXT NOT NULL,
        symbol TEXT,
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at TEXT NOT NULL,
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations}(id) ON DELETE RESTRICT,
        CONSTRAINT uq_units_of_measure_org_code UNIQUE (organization_id, code)
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_units_of_measure_org 
      ON ${DatabaseConstants.tableUnitsOfMeasure}(organization_id);
    ''');

    // -----------------------------------------------------------------
    // 4. Items (Products & Materials) Table
    // -----------------------------------------------------------------
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableItems} (
        id TEXT PRIMARY KEY,
        organization_id TEXT NOT NULL,
        item_code TEXT NOT NULL,
        barcode TEXT,
        name_ar TEXT NOT NULL,
        name_en TEXT,
        description TEXT,
        category_id TEXT,
        item_type TEXT NOT NULL CHECK (item_type IN ('MERCHANDISE', 'RAW_MATERIAL', 'FINISHED_PRODUCT', 'SEMI_FINISHED', 'CONSUMABLE', 'SERVICE')),
        base_unit_id TEXT NOT NULL,
        purchase_price INTEGER NOT NULL DEFAULT 0 CHECK (purchase_price >= 0),
        selling_price INTEGER NOT NULL DEFAULT 0 CHECK (selling_price >= 0),
        min_stock_level INTEGER NOT NULL DEFAULT 0 CHECK (min_stock_level >= 0),
        max_stock_level INTEGER CHECK (max_stock_level IS NULL OR max_stock_level >= 0),
        reorder_level INTEGER NOT NULL DEFAULT 0 CHECK (reorder_level >= 0),
        track_inventory INTEGER NOT NULL DEFAULT 1 CHECK (track_inventory IN (0, 1)),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        image_path TEXT,
        default_warehouse_id TEXT,
        valuation_method TEXT NOT NULL DEFAULT 'WEIGHTED_AVERAGE' CHECK (valuation_method IN ('WEIGHTED_AVERAGE', 'FIFO')),
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations}(id) ON DELETE RESTRICT,
        FOREIGN KEY (category_id) REFERENCES ${DatabaseConstants.tableItemCategories}(id) ON DELETE RESTRICT,
        FOREIGN KEY (base_unit_id) REFERENCES ${DatabaseConstants.tableUnitsOfMeasure}(id) ON DELETE RESTRICT,
        FOREIGN KEY (default_warehouse_id) REFERENCES ${DatabaseConstants.tableWarehouses}(id) ON DELETE SET NULL,
        CONSTRAINT uq_items_org_item_code UNIQUE (organization_id, item_code)
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_items_org 
      ON ${DatabaseConstants.tableItems}(organization_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_items_category 
      ON ${DatabaseConstants.tableItems}(organization_id, category_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_items_barcode 
      ON ${DatabaseConstants.tableItems}(organization_id, barcode);
    ''');

    // -----------------------------------------------------------------
    // 5. Item Units (Multi-unit conversions) Table
    // -----------------------------------------------------------------
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableItemUnits} (
        id TEXT PRIMARY KEY,
        organization_id TEXT NOT NULL,
        item_id TEXT NOT NULL,
        unit_id TEXT NOT NULL,
        conversion_factor INTEGER NOT NULL CHECK (conversion_factor > 0),
        purchase_price INTEGER CHECK (purchase_price IS NULL OR purchase_price >= 0),
        selling_price INTEGER CHECK (selling_price IS NULL OR selling_price >= 0),
        barcode TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations}(id) ON DELETE RESTRICT,
        FOREIGN KEY (item_id) REFERENCES ${DatabaseConstants.tableItems}(id) ON DELETE CASCADE,
        FOREIGN KEY (unit_id) REFERENCES ${DatabaseConstants.tableUnitsOfMeasure}(id) ON DELETE RESTRICT,
        CONSTRAINT uq_item_units_item_unit UNIQUE (item_id, unit_id)
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_item_units_item 
      ON ${DatabaseConstants.tableItemUnits}(item_id);
    ''');

    // -----------------------------------------------------------------
    // 6. Stock Documents Table
    // -----------------------------------------------------------------
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableStockDocuments} (
        id TEXT PRIMARY KEY,
        organization_id TEXT NOT NULL,
        document_number TEXT NOT NULL,
        document_type TEXT NOT NULL CHECK (document_type IN ('OPENING', 'RECEIPT', 'ISSUE', 'TRANSFER', 'ADJUSTMENT')),
        document_date TEXT NOT NULL,
        source_warehouse_id TEXT,
        destination_warehouse_id TEXT,
        party_id TEXT,
        reference_number TEXT,
        status TEXT NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'POSTED', 'CANCELLED')),
        notes TEXT,
        total_cost INTEGER NOT NULL DEFAULT 0 CHECK (total_cost >= 0),
        journal_entry_id TEXT,
        created_at TEXT NOT NULL,
        posted_at TEXT,
        posted_by TEXT,
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations}(id) ON DELETE RESTRICT,
        FOREIGN KEY (source_warehouse_id) REFERENCES ${DatabaseConstants.tableWarehouses}(id) ON DELETE RESTRICT,
        FOREIGN KEY (destination_warehouse_id) REFERENCES ${DatabaseConstants.tableWarehouses}(id) ON DELETE RESTRICT,
        FOREIGN KEY (party_id) REFERENCES ${DatabaseConstants.tableParties}(id) ON DELETE RESTRICT,
        FOREIGN KEY (journal_entry_id) REFERENCES ${DatabaseConstants.tableJournalEntries}(id) ON DELETE RESTRICT,
        CONSTRAINT uq_stock_documents_org_number UNIQUE (organization_id, document_number)
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_stock_documents_org 
      ON ${DatabaseConstants.tableStockDocuments}(organization_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_stock_documents_type 
      ON ${DatabaseConstants.tableStockDocuments}(organization_id, document_type);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_stock_documents_date 
      ON ${DatabaseConstants.tableStockDocuments}(organization_id, document_date);
    ''');

    // -----------------------------------------------------------------
    // 7. Stock Document Lines Table
    // -----------------------------------------------------------------
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableStockDocumentLines} (
        id TEXT PRIMARY KEY,
        organization_id TEXT NOT NULL,
        document_id TEXT NOT NULL,
        line_number INTEGER NOT NULL,
        item_id TEXT NOT NULL,
        unit_id TEXT NOT NULL,
        quantity INTEGER NOT NULL CHECK (quantity > 0),
        conversion_factor INTEGER NOT NULL DEFAULT 1000 CHECK (conversion_factor > 0),
        base_quantity INTEGER NOT NULL CHECK (base_quantity > 0),
        unit_cost INTEGER NOT NULL DEFAULT 0 CHECK (unit_cost >= 0),
        total_cost INTEGER NOT NULL DEFAULT 0 CHECK (total_cost >= 0),
        expense_account_id TEXT,
        notes TEXT,
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations}(id) ON DELETE RESTRICT,
        FOREIGN KEY (document_id) REFERENCES ${DatabaseConstants.tableStockDocuments}(id) ON DELETE CASCADE,
        FOREIGN KEY (item_id) REFERENCES ${DatabaseConstants.tableItems}(id) ON DELETE RESTRICT,
        FOREIGN KEY (unit_id) REFERENCES ${DatabaseConstants.tableUnitsOfMeasure}(id) ON DELETE RESTRICT,
        FOREIGN KEY (expense_account_id) REFERENCES ${DatabaseConstants.tableChartOfAccounts}(id) ON DELETE RESTRICT,
        CONSTRAINT uq_stock_doc_lines_num UNIQUE (document_id, line_number)
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_stock_doc_lines_doc 
      ON ${DatabaseConstants.tableStockDocumentLines}(document_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_stock_doc_lines_item 
      ON ${DatabaseConstants.tableStockDocumentLines}(organization_id, item_id);
    ''');

    // -----------------------------------------------------------------
    // 8. Stock Movements Ledger Table
    // -----------------------------------------------------------------
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableStockMovements} (
        id TEXT PRIMARY KEY,
        organization_id TEXT NOT NULL,
        item_id TEXT NOT NULL,
        warehouse_id TEXT NOT NULL,
        document_id TEXT NOT NULL,
        document_line_id TEXT,
        document_number TEXT NOT NULL,
        movement_type TEXT NOT NULL CHECK (movement_type IN ('OPENING', 'RECEIPT', 'ISSUE', 'TRANSFER_OUT', 'TRANSFER_IN', 'ADJUSTMENT_IN', 'ADJUSTMENT_OUT')),
        movement_date TEXT NOT NULL,
        quantity_in INTEGER NOT NULL DEFAULT 0 CHECK (quantity_in >= 0),
        quantity_out INTEGER NOT NULL DEFAULT 0 CHECK (quantity_out >= 0),
        unit_cost INTEGER NOT NULL DEFAULT 0 CHECK (unit_cost >= 0),
        total_cost INTEGER NOT NULL DEFAULT 0 CHECK (total_cost >= 0),
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations}(id) ON DELETE RESTRICT,
        FOREIGN KEY (item_id) REFERENCES ${DatabaseConstants.tableItems}(id) ON DELETE RESTRICT,
        FOREIGN KEY (warehouse_id) REFERENCES ${DatabaseConstants.tableWarehouses}(id) ON DELETE RESTRICT,
        FOREIGN KEY (document_id) REFERENCES ${DatabaseConstants.tableStockDocuments}(id) ON DELETE RESTRICT,
        FOREIGN KEY (document_line_id) REFERENCES ${DatabaseConstants.tableStockDocumentLines}(id) ON DELETE RESTRICT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_stock_mov_item_wh 
      ON ${DatabaseConstants.tableStockMovements}(organization_id, item_id, warehouse_id, movement_date);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_stock_mov_doc 
      ON ${DatabaseConstants.tableStockMovements}(document_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_stock_mov_date 
      ON ${DatabaseConstants.tableStockMovements}(organization_id, movement_date);
    ''');

    // -----------------------------------------------------------------
    // 9. Stocktaking Sessions Table
    // -----------------------------------------------------------------
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableStocktakingSessions} (
        id TEXT PRIMARY KEY,
        organization_id TEXT NOT NULL,
        session_number TEXT NOT NULL,
        warehouse_id TEXT NOT NULL,
        category_id TEXT,
        status TEXT NOT NULL DEFAULT 'IN_PROGRESS' CHECK (status IN ('IN_PROGRESS', 'COMPLETED', 'POSTED', 'CANCELLED')),
        started_at TEXT NOT NULL,
        completed_at TEXT,
        notes TEXT,
        adjustment_document_id TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations}(id) ON DELETE RESTRICT,
        FOREIGN KEY (warehouse_id) REFERENCES ${DatabaseConstants.tableWarehouses}(id) ON DELETE RESTRICT,
        FOREIGN KEY (category_id) REFERENCES ${DatabaseConstants.tableItemCategories}(id) ON DELETE RESTRICT,
        FOREIGN KEY (adjustment_document_id) REFERENCES ${DatabaseConstants.tableStockDocuments}(id) ON DELETE RESTRICT,
        CONSTRAINT uq_stocktaking_org_number UNIQUE (organization_id, session_number)
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_stocktaking_org 
      ON ${DatabaseConstants.tableStocktakingSessions}(organization_id);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_stocktaking_status 
      ON ${DatabaseConstants.tableStocktakingSessions}(organization_id, status);
    ''');

    // -----------------------------------------------------------------
    // 10. Stocktaking Lines Table
    // -----------------------------------------------------------------
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableStocktakingLines} (
        id TEXT PRIMARY KEY,
        organization_id TEXT NOT NULL,
        session_id TEXT NOT NULL,
        item_id TEXT NOT NULL,
        system_quantity INTEGER NOT NULL DEFAULT 0 CHECK (system_quantity >= 0),
        counted_quantity INTEGER CHECK (counted_quantity IS NULL OR counted_quantity >= 0),
        difference_quantity INTEGER,
        unit_cost INTEGER NOT NULL DEFAULT 0 CHECK (unit_cost >= 0),
        difference_value INTEGER,
        notes TEXT,
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations}(id) ON DELETE RESTRICT,
        FOREIGN KEY (session_id) REFERENCES ${DatabaseConstants.tableStocktakingSessions}(id) ON DELETE CASCADE,
        FOREIGN KEY (item_id) REFERENCES ${DatabaseConstants.tableItems}(id) ON DELETE RESTRICT,
        CONSTRAINT uq_stocktaking_lines UNIQUE (session_id, item_id)
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_stocktaking_lines_session 
      ON ${DatabaseConstants.tableStocktakingLines}(session_id);
    ''');

    // -----------------------------------------------------------------
    // 11. Inventory Settings Table
    // -----------------------------------------------------------------
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableInventorySettings} (
        id TEXT PRIMARY KEY,
        organization_id TEXT NOT NULL UNIQUE,
        is_inventory_enabled INTEGER NOT NULL DEFAULT 1 CHECK (is_inventory_enabled IN (0, 1)),
        inventory_asset_account_id TEXT,
        inventory_adjustment_account_id TEXT,
        cogs_account_id TEXT,
        opening_equity_account_id TEXT,
        default_valuation_method TEXT NOT NULL DEFAULT 'WEIGHTED_AVERAGE' CHECK (default_valuation_method IN ('WEIGHTED_AVERAGE', 'FIFO')),
        allow_negative_stock INTEGER NOT NULL DEFAULT 0 CHECK (allow_negative_stock IN (0, 1)),
        updated_at TEXT NOT NULL,
        FOREIGN KEY (organization_id) REFERENCES ${DatabaseConstants.tableOrganizations}(id) ON DELETE RESTRICT,
        FOREIGN KEY (inventory_asset_account_id) REFERENCES ${DatabaseConstants.tableChartOfAccounts}(id) ON DELETE RESTRICT,
        FOREIGN KEY (inventory_adjustment_account_id) REFERENCES ${DatabaseConstants.tableChartOfAccounts}(id) ON DELETE RESTRICT,
        FOREIGN KEY (cogs_account_id) REFERENCES ${DatabaseConstants.tableChartOfAccounts}(id) ON DELETE RESTRICT,
        FOREIGN KEY (opening_equity_account_id) REFERENCES ${DatabaseConstants.tableChartOfAccounts}(id) ON DELETE RESTRICT
      );
    ''');

    // -----------------------------------------------------------------
    // 12. Integrity Triggers
    // -----------------------------------------------------------------
    // A. Prevent deleting warehouses with existing movements or documents
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_warehouses_prevent_del_with_movements
      BEFORE DELETE ON ${DatabaseConstants.tableWarehouses}
      FOR EACH ROW
      WHEN (
        (SELECT COUNT(*) FROM ${DatabaseConstants.tableStockMovements} WHERE warehouse_id = OLD.id) > 0 OR
        (SELECT COUNT(*) FROM ${DatabaseConstants.tableStockDocuments} WHERE source_warehouse_id = OLD.id OR destination_warehouse_id = OLD.id) > 0
      )
      BEGIN
        SELECT RAISE(ABORT, 'لا يمكن حذف المستودع لوجود حركات مخزنية أو سندات مسجلة عليه.');
      END;
    ''');

    // B. Prevent deleting items with movements or document lines
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_items_prevent_del_with_movements
      BEFORE DELETE ON ${DatabaseConstants.tableItems}
      FOR EACH ROW
      WHEN (
        (SELECT COUNT(*) FROM ${DatabaseConstants.tableStockMovements} WHERE item_id = OLD.id) > 0 OR
        (SELECT COUNT(*) FROM ${DatabaseConstants.tableStockDocumentLines} WHERE item_id = OLD.id) > 0
      )
      BEGIN
        SELECT RAISE(ABORT, 'لا يمكن حذف الصنف لوجود حركات مخزنية أو سندات مرتبطة به.');
      END;
    ''');

    // C. Prevent editing or deleting POSTED stock documents
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_stock_docs_prevent_mod_when_posted
      BEFORE UPDATE ON ${DatabaseConstants.tableStockDocuments}
      FOR EACH ROW
      WHEN OLD.status = 'POSTED' AND NEW.status != 'CANCELLED'
      BEGIN
        SELECT RAISE(ABORT, 'لا يمكن تعديل سند مخزني مرحل. يجب إلغاء السند أو إجراء تسوية مخزنية رسمية.');
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_stock_docs_prevent_del_when_posted
      BEFORE DELETE ON ${DatabaseConstants.tableStockDocuments}
      FOR EACH ROW
      WHEN OLD.status = 'POSTED'
      BEGIN
        SELECT RAISE(ABORT, 'لا يمكن حذف سند مخزني مرحل نهائياً لحفظ مسار الرقابة والتدقيق.');
      END;
    ''');

    // D. Enforce Transfer constraints: Source and Destination must differ
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_stock_docs_transfer_wh_integrity_ins
      BEFORE INSERT ON ${DatabaseConstants.tableStockDocuments}
      FOR EACH ROW
      WHEN NEW.document_type = 'TRANSFER' AND (
        NEW.source_warehouse_id IS NULL OR 
        NEW.destination_warehouse_id IS NULL OR 
        NEW.source_warehouse_id = NEW.destination_warehouse_id
      )
      BEGIN
        SELECT RAISE(ABORT, 'سند المناقلة يتطلب تحديد مستودعين مختلفين (المصدر والوجهة).');
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_stock_docs_transfer_wh_integrity_upd
      BEFORE UPDATE ON ${DatabaseConstants.tableStockDocuments}
      FOR EACH ROW
      WHEN NEW.document_type = 'TRANSFER' AND (
        NEW.source_warehouse_id IS NULL OR 
        NEW.destination_warehouse_id IS NULL OR 
        NEW.source_warehouse_id = NEW.destination_warehouse_id
      )
      BEGIN
        SELECT RAISE(ABORT, 'سند المناقلة يتطلب تحديد مستودعين مختلفين (المصدر والوجهة).');
      END;
    ''');

    // -----------------------------------------------------------------
    // 13. Data Seeding for Existing Organizations
    // -----------------------------------------------------------------
    // Fetch all existing organizations and ensure default warehouse, units,
    // inventory accounts, and inventory settings exist.
    final orgRows = await db.query(DatabaseConstants.tableOrganizations);
    final now = DateTime.now().toUtc().toIso8601String();

    for (final org in orgRows) {
      final orgId = org['id'] as String;

      // A. Seed standard units of measure if not present
      final standardUnits = [
        {'code': 'PCS', 'name': 'قطعة / حبة', 'symbol': 'حبة'},
        {'code': 'BOX', 'name': 'صندوق', 'symbol': 'صندوق'},
        {'code': 'CTN', 'name': 'كرتون', 'symbol': 'كرتون'},
        {'code': 'KG', 'name': 'كيلوجرام', 'symbol': 'كجم'},
        {'code': 'G', 'name': 'جرام', 'symbol': 'جم'},
        {'code': 'L', 'name': 'لتر', 'symbol': 'لتر'},
        {'code': 'M', 'name': 'متر', 'symbol': 'م'},
        {'code': 'PKG', 'name': 'طرد / باكت', 'symbol': 'طرد'},
      ];

      for (final u in standardUnits) {
        await db.insert(
          DatabaseConstants.tableUnitsOfMeasure,
          {
            'id': 'uom_${orgId}_${u['code']}',
            'organization_id': orgId,
            'code': u['code'],
            'name_ar': u['name'],
            'symbol': u['symbol'],
            'is_active': 1,
            'created_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // B. Seed Default Primary Warehouse if none exists
      await db.insert(
        DatabaseConstants.tableWarehouses,
        {
          'id': 'wh_${orgId}_main',
          'organization_id': orgId,
          'code': 'WH-01',
          'name': 'المستودع الرئيسي',
          'description': 'المستودع المركزي للبضائع والمواد',
          'location': 'المركز الرئيسي',
          'responsible_person': 'أمين المستودع',
          'is_active': 1,
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      // C. Seed Default General Category if none exists
      await db.insert(
        DatabaseConstants.tableItemCategories,
        {
          'id': 'cat_${orgId}_general',
          'organization_id': orgId,
          'code': 'CAT-01',
          'name_ar': 'بضائع عامة',
          'name_en': 'General Merchandise',
          'parent_id': null,
          'description': 'التصنيف الافتراضي للأصناف التجارية',
          'is_active': 1,
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      // D. Seed Standard Inventory Accounts in Chart of Accounts if missing
      // 113: المخزون السلعي (Parent 11: الأصول المتداولة)
      await db.insert(
        DatabaseConstants.tableChartOfAccounts,
        {
          'id': '${orgId}_113',
          'organization_id': orgId,
          'account_code': '113',
          'account_name_ar': 'المخزون السلعي',
          'account_name_en': 'Inventory',
          'account_type': 'ASSET',
          'account_nature': 'DEBIT',
          'parent_id': '${orgId}_11',
          'currency_code': org['base_currency_code'] ?? 'YER',
          'is_cash_bank': 0,
          'is_reconcilable': 0,
          'is_active': 1,
          'is_system': 1,
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      // 1131: بضاعة بالمستودعات (Leaf Account under 113)
      await db.insert(
        DatabaseConstants.tableChartOfAccounts,
        {
          'id': '${orgId}_1131',
          'organization_id': orgId,
          'account_code': '1131',
          'account_name_ar': 'بضاعة بالمستودعات',
          'account_name_en': 'Merchandise Inventory',
          'account_type': 'ASSET',
          'account_nature': 'DEBIT',
          'parent_id': '${orgId}_113',
          'currency_code': org['base_currency_code'] ?? 'YER',
          'is_cash_bank': 0,
          'is_reconcilable': 0,
          'is_active': 1,
          'is_system': 1,
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      // 5202: فروقات وتلفيات الجرد (Parent 52: المصروفات التشغيلية والإدارية)
      await db.insert(
        DatabaseConstants.tableChartOfAccounts,
        {
          'id': '${orgId}_5202',
          'organization_id': orgId,
          'account_code': '5202',
          'account_name_ar': 'فروقات وتلفيات الجرد المخزني',
          'account_name_en': 'Inventory Adjustment & Spoilage',
          'account_type': 'EXPENSE',
          'account_nature': 'DEBIT',
          'parent_id': '${orgId}_52',
          'currency_code': org['base_currency_code'] ?? 'YER',
          'is_cash_bank': 0,
          'is_reconcilable': 0,
          'is_active': 1,
          'is_system': 0,
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      // E. Seed Default Inventory Settings for each org
      await db.insert(
        DatabaseConstants.tableInventorySettings,
        {
          'id': 'inv_set_$orgId',
          'organization_id': orgId,
          'is_inventory_enabled': 1,
          'inventory_asset_account_id': '${orgId}_1131',
          'inventory_adjustment_account_id': '${orgId}_5202',
          'cogs_account_id': '${orgId}_51',
          'opening_equity_account_id': '${orgId}_3999',
          'default_valuation_method': 'WEIGHTED_AVERAGE',
          'allow_negative_stock': 0,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }
}

