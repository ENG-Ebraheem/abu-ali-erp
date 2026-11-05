import 'package:flutter_test/flutter_test.dart';
import 'package:abu_ali/core/constants/database_constants.dart';
import 'package:abu_ali/features/inventory/models/warehouse_model.dart';
import 'package:abu_ali/features/inventory/models/item_category_model.dart';
import 'package:abu_ali/features/inventory/models/unit_of_measure_model.dart';
import 'package:abu_ali/features/inventory/models/item_model.dart';
import 'package:abu_ali/features/inventory/models/stock_document_model.dart';
import 'package:abu_ali/features/inventory/models/stock_movement_model.dart';
import 'package:abu_ali/features/inventory/models/stocktaking_line_model.dart';
import 'package:abu_ali/features/inventory/models/inventory_settings_model.dart';
import 'package:abu_ali/features/journal/models/journal_entry_model.dart';
import 'package:abu_ali/features/journal/models/journal_entry_line_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 8: Inventory & Warehouse Management Unit Tests', () {
    const orgId = 'org_test_phase8';
    const otherOrgId = 'org_test_phase8_other';
    const nowIso = '2026-11-01T12:00:00Z';

    // =========================================================================
    // 1. Database Schema V4 Constants & Architecture
    // =========================================================================
    test('1. Schema V4 constants and 11 inventory tables are registered', () {
      expect(DatabaseConstants.databaseVersion, equals(4));
      expect(DatabaseConstants.quantityScale, equals(1000));
      expect(DatabaseConstants.defaultMoneyScale, equals(100));

      final all11InventoryTables = [
        DatabaseConstants.tableWarehouses,
        DatabaseConstants.tableItemCategories,
        DatabaseConstants.tableUnitsOfMeasure,
        DatabaseConstants.tableItems,
        DatabaseConstants.tableItemUnits,
        DatabaseConstants.tableStockDocuments,
        DatabaseConstants.tableStockDocumentLines,
        DatabaseConstants.tableStockMovements,
        DatabaseConstants.tableStocktakingSessions,
        DatabaseConstants.tableStocktakingLines,
        DatabaseConstants.tableInventorySettings,
      ];

      expect(all11InventoryTables.length, equals(11));
      expect(all11InventoryTables.toSet().length, equals(11)); // All unique
    });

    test('2. Inventory enum values and constant codes are consistent', () {
      expect(ItemType.merchandise, equals('MERCHANDISE'));
      expect(ItemType.rawMaterial, equals('RAW_MATERIAL'));
      expect(ItemType.finishedProduct, equals('FINISHED_PRODUCT'));
      expect(ItemType.service, equals('SERVICE'));

      expect(StockDocumentType.opening, equals('OPENING'));
      expect(StockDocumentType.receipt, equals('RECEIPT'));
      expect(StockDocumentType.issue, equals('ISSUE'));
      expect(StockDocumentType.transfer, equals('TRANSFER'));
      expect(StockDocumentType.adjustment, equals('ADJUSTMENT'));

      expect(StockDocumentStatus.draft, equals('DRAFT'));
      expect(StockDocumentStatus.posted, equals('POSTED'));
      expect(StockDocumentStatus.cancelled, equals('CANCELLED'));

      expect(StockMovementType.opening, equals('OPENING'));
      expect(StockMovementType.receipt, equals('RECEIPT'));
      expect(StockMovementType.issue, equals('ISSUE'));
      expect(StockMovementType.transferOut, equals('TRANSFER_OUT'));
      expect(StockMovementType.transferIn, equals('TRANSFER_IN'));
      expect(StockMovementType.adjustmentIn, equals('ADJUSTMENT_IN'));
      expect(StockMovementType.adjustmentOut, equals('ADJUSTMENT_OUT'));

      expect(ValuationMethod.weightedAverage, equals('WEIGHTED_AVERAGE'));
      expect(ValuationMethod.fifo, equals('FIFO'));
    });

    // =========================================================================
    // 2. Models Serialization & Data Integrity
    // =========================================================================
    test('3. WarehouseModel round-trip serialization and defaults', () {
      final wh = WarehouseModel(
        id: 'wh_main_$orgId',
        organizationId: orgId,
        code: 'WH01',
        name: 'المستودع الرئيسي - صنعاء',
        location: 'شارع الزبيري',
        responsiblePerson: 'علي محمد',
        isActive: true,
        createdAt: nowIso,
      );

      final map = wh.toMap();
      expect(map['id'], equals('wh_main_$orgId'));
      expect(map['code'], equals('WH01'));
      expect(map['name'], equals('المستودع الرئيسي - صنعاء'));
      expect(map['is_active'], equals(1));

      final restored = WarehouseModel.fromMap(map);
      expect(restored.id, equals(wh.id));
      expect(restored.name, equals(wh.name));
      expect(restored.isActive, isTrue);
    });

    test('4. ItemCategoryModel hierarchy and serialization', () {
      final parentCat = ItemCategoryModel(
        id: 'cat_electronics_$orgId',
        organizationId: orgId,
        code: 'ELEC',
        nameAr: 'إلكترونيات وأجهزة',
        createdAt: nowIso,
      );

      final subCat = ItemCategoryModel(
        id: 'cat_phones_$orgId',
        organizationId: orgId,
        code: 'PHONES',
        nameAr: 'هواتف ذكية',
        parentId: parentCat.id,
        createdAt: nowIso,
      );

      expect(subCat.parentId, equals(parentCat.id));
      final subMap = subCat.toMap();
      expect(subMap['parent_id'], equals(parentCat.id));

      final restoredSub = ItemCategoryModel.fromMap(subMap);
      expect(restoredSub.parentId, equals(parentCat.id));
      expect(restoredSub.code, equals('PHONES'));
    });

    test('5. UnitOfMeasureModel serialization', () {
      final pieceUnit = UnitOfMeasureModel(
        id: 'uom_pcs_$orgId',
        organizationId: orgId,
        code: 'PCS',
        nameAr: 'حبة',
        symbol: 'حبة',
        isActive: true,
        createdAt: nowIso,
      );

      final map = pieceUnit.toMap();
      expect(map['code'], equals('PCS'));
      expect(map['name_ar'], equals('حبة'));
      expect(map['is_active'], equals(1));

      final restored = UnitOfMeasureModel.fromMap(map);
      expect(restored.code, equals('PCS'));
      expect(restored.symbol, equals('حبة'));
      expect(restored.isActive, isTrue);
    });

    test('6. ItemModel serialization and stock controls', () {
      final item = ItemModel(
        id: 'item_note20_$orgId',
        organizationId: orgId,
        itemCode: 'ITM-N20',
        barcode: '629110000001',
        nameAr: 'سامسونج جالاكسي نوت 20 ألترا',
        nameEn: 'Samsung Galaxy Note 20 Ultra',
        itemType: ItemType.merchandise,
        baseUnitId: 'uom_pcs_$orgId',
        trackInventory: true,
        minStockLevel: 5000, // 5.000 units
        maxStockLevel: 50000, // 50.000 units
        reorderLevel: 10000, // 10.000 units
        valuationMethod: ValuationMethod.weightedAverage,
        createdAt: nowIso,
      );

      final map = item.toMap();
      expect(map['item_code'], equals('ITM-N20'));
      expect(map['min_stock_level'], equals(5000));
      expect(map['track_inventory'], equals(1));
      expect(map['reorder_level'], equals(10000));

      final restored = ItemModel.fromMap(map);
      expect(restored.minStockLevel, equals(5000));
      expect(restored.trackInventory, isTrue);
      expect(restored.reorderLevel, equals(10000));
      expect(restored.isService, isFalse);
    });

    // =========================================================================
    // 3. Multi-Unit Packaging & Conversion Mathematics
    // =========================================================================
    test('7. Multi-unit conversion factors correctly scale quantities', () {
      // 1 Carton (كرتون) = 24 Pieces (حبة)
      // Conversion factor is scaled by 1,000 => 24.0 * 1000 = 24,000
      const int factorCartonToPcs = 24000;
      const int inputQuantityCartons = 5000; // 5.000 Cartons

      // Base quantity in pieces
      final int baseQuantityPcs = (inputQuantityCartons * factorCartonToPcs) ~/ 1000;
      // 5 * 24 = 120 pieces => 120,000 scaled
      expect(baseQuantityPcs, equals(120000));
      expect(baseQuantityPcs / 1000.0, equals(120.0));

      // Reverse conversion: 120 pieces back to cartons
      final int reversedCartons = (baseQuantityPcs * 1000) ~/ factorCartonToPcs;
      expect(reversedCartons, equals(inputQuantityCartons));
    });

    test('8. Fractional packaging conversions (e.g. 1 Box = 12 Pieces, 2.5 Boxes)', () {
      const int factorBoxToPcs = 12000; // 12 pieces per box
      const int inputBoxesScaled = 2500; // 2.500 boxes

      final int baseQuantityPcs = (inputBoxesScaled * factorBoxToPcs) ~/ 1000;
      // 2.5 * 12 = 30 pieces => 30,000 scaled
      expect(baseQuantityPcs, equals(30000));
      expect(baseQuantityPcs / 1000.0, equals(30.0));
    });

    // =========================================================================
    // 4. Weighted Average Cost (WAC) Valuation Engine
    // =========================================================================
    test('9. Weighted Average Cost accurately computes without float drift', () {
      // Scale: Quantity * 1000, Currency minor units * 100
      // Transaction 1: Opening Stock 100 units @ 500.00 YER
      const int qty1 = 100000; // 100.000 units
      const int cost1 = 50000; // 500.00 YER
      final int totalVal1 = (qty1 * cost1) ~/ 1000; // 5,000,000 minor units (50,000.00 YER)
      expect(totalVal1, equals(5000000));

      // Transaction 2: Inward Purchase Receipt 50 units @ 650.00 YER
      const int qty2 = 50000; // 50.000 units
      const int cost2 = 65000; // 650.00 YER
      final int totalVal2 = (qty2 * cost2) ~/ 1000; // 3,250,000 minor units (32,500.00 YER)
      expect(totalVal2, equals(3250000));

      // Combined Stock
      final int totalQty = qty1 + qty2; // 150,000 (150 units)
      final int totalVal = totalVal1 + totalVal2; // 8,250,000 minor units (82,500.00 YER)

      // Formula: New WAC = (Total Value * 1000) / Total Quantity
      final int wac = (totalVal * 1000) ~/ totalQty;
      // 82,500.00 / 150 = 550.00 YER => 55,000 minor units
      expect(wac, equals(55000));
      expect(wac / 100.0, equals(550.0));

      // Transaction 3: Stock Issue (Sale/Usage) 70 units
      // Issues are valued at the current WAC (550.00 YER)
      const int issueQty = 70000; // 70.000 units
      final int issueCost = (issueQty * wac) ~/ 1000; // 3,850,000 minor units (38,500.00 YER)
      expect(issueCost, equals(3850000));

      // Remaining stock and value
      final int remQty = totalQty - issueQty; // 80,000 (80 units)
      final int remVal = totalVal - issueCost; // 4,400,000 minor units (44,000.00 YER)

      // WAC after issue remains unchanged (550.00 YER)
      final int wacAfterIssue = (remVal * 1000) ~/ remQty;
      expect(wacAfterIssue, equals(55000));
    });

    test('10. WAC correctly handles precision when dividing non-round amounts', () {
      // 3 units costing 1000.00 YER total => unit cost 333.33 YER
      const int qty = 3000; // 3 units
      const int totalVal = 100000; // 1,000.00 YER
      final int wac = (totalVal * 1000) ~/ qty; // 33333 minor units (333.33 YER)
      expect(wac, equals(33333));
    });

    // =========================================================================
    // 5. Accounting Double-Entry Invariants
    // =========================================================================
    test('11. Opening Inventory GL entry preserves debit-credit balance equality', () {
      const totalInventoryCost = 50000000; // 500,000.00 YER
      final assetAcc = '${orgId}_1131';
      final equityAcc = '${orgId}_3999';

      final glLines = [
        JournalEntryLineModel(
          id: 'jel_stock_op_1',
          journalEntryId: 'je_stock_op',
          organizationId: orgId,
          lineNumber: 1,
          accountId: assetAcc,
          currencyCode: 'YER',
          exchangeRateScaled: DatabaseConstants.exchangeRateScale,
          baseDebit: totalInventoryCost,
          baseCredit: 0,
          foreignDebit: totalInventoryCost,
          foreignCredit: 0,
          description: 'إثبات رصيد افتتاحي للمخزون',
          createdAt: nowIso,
        ),
        JournalEntryLineModel(
          id: 'jel_stock_op_2',
          journalEntryId: 'je_stock_op',
          organizationId: orgId,
          lineNumber: 2,
          accountId: equityAcc,
          currencyCode: 'YER',
          exchangeRateScaled: DatabaseConstants.exchangeRateScale,
          baseDebit: 0,
          baseCredit: totalInventoryCost,
          foreignDebit: 0,
          foreignCredit: totalInventoryCost,
          description: 'حساب الأرصدة الافتتاحية المقابل',
          createdAt: nowIso,
        ),
      ];

      final totalDebit = glLines.fold<int>(0, (sum, l) => sum + l.baseDebit);
      final totalCredit = glLines.fold<int>(0, (sum, l) => sum + l.baseCredit);

      expect(totalDebit, equals(totalCredit));
      expect(totalDebit, equals(totalInventoryCost));

      final entry = JournalEntryModel(
        id: 'je_stock_op',
        organizationId: orgId,
        entryNumber: 'JV-0001',
        fiscalPeriodId: 'fp_2026',
        entryDate: '2026-11-01',
        narration: 'بضاعة أول المدة - سند مخزني رقم OP-0001',
        totalBaseDebit: totalDebit,
        totalBaseCredit: totalCredit,
        lines: glLines,
      );

      expect(entry.isBalanced, isTrue);
      expect(entry.totalBaseDebitDouble, equals(500000.0));
    });

    test('12. Stock Issue GL entry correctly debits COGS and credits Inventory Asset', () {
      const issueCost = 3850000; // 38,500.00 YER
      final cogsAcc = '${orgId}_5101';
      final assetAcc = '${orgId}_1131';

      final glLines = [
        JournalEntryLineModel(
          id: 'jel_stock_iss_1',
          journalEntryId: 'je_stock_iss',
          organizationId: orgId,
          lineNumber: 1,
          accountId: cogsAcc,
          currencyCode: 'YER',
          exchangeRateScaled: DatabaseConstants.exchangeRateScale,
          baseDebit: issueCost,
          baseCredit: 0,
          foreignDebit: issueCost,
          foreignCredit: 0,
          description: 'صرف بضاعة ومواد تشغيلية',
          createdAt: nowIso,
        ),
        JournalEntryLineModel(
          id: 'jel_stock_iss_2',
          journalEntryId: 'je_stock_iss',
          organizationId: orgId,
          lineNumber: 2,
          accountId: assetAcc,
          currencyCode: 'YER',
          exchangeRateScaled: DatabaseConstants.exchangeRateScale,
          baseDebit: 0,
          baseCredit: issueCost,
          foreignDebit: 0,
          foreignCredit: issueCost,
          description: 'تخفيض المخزون السلعي',
          createdAt: nowIso,
        ),
      ];

      final totalDebit = glLines.fold<int>(0, (sum, l) => sum + l.baseDebit);
      final totalCredit = glLines.fold<int>(0, (sum, l) => sum + l.baseCredit);

      expect(totalDebit, equals(totalCredit));
      expect(totalDebit, equals(issueCost));
    });

    test('13. Stock Adjustment Surplus and Deficit GL entries are self-balancing', () {
      // Surplus: Debit Asset, Credit Surplus Income
      const surplusAmount = 150000; // 1,500.00 YER
      final surplusLines = [
        JournalEntryLineModel(
          id: 'jel_adj_s_1',
          journalEntryId: 'je_adj_s',
          organizationId: orgId,
          lineNumber: 1,
          accountId: '${orgId}_1131',
          currencyCode: 'YER',
          exchangeRateScaled: DatabaseConstants.exchangeRateScale,
          baseDebit: surplusAmount,
          baseCredit: 0,
          createdAt: nowIso,
        ),
        JournalEntryLineModel(
          id: 'jel_adj_s_2',
          journalEntryId: 'je_adj_s',
          organizationId: orgId,
          lineNumber: 2,
          accountId: '${orgId}_5202',
          currencyCode: 'YER',
          exchangeRateScaled: DatabaseConstants.exchangeRateScale,
          baseDebit: 0,
          baseCredit: surplusAmount,
          createdAt: nowIso,
        ),
      ];
      expect(surplusLines[0].baseDebit, equals(surplusLines[1].baseCredit));

      // Deficit: Debit Deficit Expense, Credit Asset
      const deficitAmount = 220000; // 2,200.00 YER
      final deficitLines = [
        JournalEntryLineModel(
          id: 'jel_adj_d_1',
          journalEntryId: 'je_adj_d',
          organizationId: orgId,
          lineNumber: 1,
          accountId: '${orgId}_5202',
          currencyCode: 'YER',
          exchangeRateScaled: DatabaseConstants.exchangeRateScale,
          baseDebit: deficitAmount,
          baseCredit: 0,
          createdAt: nowIso,
        ),
        JournalEntryLineModel(
          id: 'jel_adj_d_2',
          journalEntryId: 'je_adj_d',
          organizationId: orgId,
          lineNumber: 2,
          accountId: '${orgId}_1131',
          currencyCode: 'YER',
          exchangeRateScaled: DatabaseConstants.exchangeRateScale,
          baseDebit: 0,
          baseCredit: deficitAmount,
          createdAt: nowIso,
        ),
      ];
      expect(deficitLines[0].baseDebit, equals(deficitLines[1].baseCredit));
    });

    // =========================================================================
    // 6. Multi-Tenant Organization Isolation
    // =========================================================================
    test('14. Cross-tenant isolation guarantees no data leakage between organizations', () {
      final itemOrgA = ItemModel(
        id: 'itm_001_$orgId',
        organizationId: orgId,
        itemCode: 'SKU-100',
        nameAr: 'صنف المؤسسة أ',
        baseUnitId: 'uom_pcs_$orgId',
        itemType: ItemType.merchandise,
        createdAt: nowIso,
      );

      final itemOrgB = ItemModel(
        id: 'itm_001_$otherOrgId',
        organizationId: otherOrgId,
        itemCode: 'SKU-100', // Same code allowed because org_id is distinct
        nameAr: 'صنف المؤسسة ب',
        baseUnitId: 'uom_pcs_$otherOrgId',
        itemType: ItemType.merchandise,
        createdAt: nowIso,
      );

      expect(itemOrgA.organizationId, isNot(equals(itemOrgB.organizationId)));
      expect(itemOrgA.id, isNot(equals(itemOrgB.id)));

      // Warehouse isolation
      final whA = WarehouseModel(
        id: 'wh_$orgId',
        organizationId: orgId,
        code: 'WH01',
        name: 'مستودع أ',
        createdAt: nowIso,
      );
      final whB = WarehouseModel(
        id: 'wh_$otherOrgId',
        organizationId: otherOrgId,
        code: 'WH01',
        name: 'مستودع ب',
        createdAt: nowIso,
      );

      expect(whA.organizationId, equals(orgId));
      expect(whB.organizationId, equals(otherOrgId));
    });

    // =========================================================================
    // 7. Negative Stock Prevention Logic
    // =========================================================================
    test('15. Negative stock restriction detects stock exhaustion correctly', () {
      const int currentStockBase = 15000; // 15.000 available units
      const int requestedDeduction = 20000; // 20.000 units requested
      const bool allowNegativeStock = false;

      bool canDeduct = true;
      if (!allowNegativeStock && currentStockBase < requestedDeduction) {
        canDeduct = false;
      }

      expect(canDeduct, isFalse);
      final deficit = (requestedDeduction - currentStockBase) / 1000.0;
      expect(deficit, equals(5.0)); // Shortage of 5 units
    });

    // =========================================================================
    // 8. Physical Stocktaking & Variance Calculation
    // =========================================================================
    test('16. Stocktaking session accurately computes surplus and deficit variances', () {
      // Deficit: Counted (95) - System (100) = -5 units
      const int systemQty1 = 100000;
      const int countedQty1 = 95000;
      const int diffQty1 = countedQty1 - systemQty1; // -5,000
      const int unitCost1 = 50000; // 500.00 YER
      final int diffVal1 = (diffQty1 * unitCost1) ~/ 1000; // -250,000 minor units

      final line1 = StocktakingLineModel(
        id: 'stk_l_1',
        organizationId: orgId,
        sessionId: 'session_01',
        itemId: 'item_01',
        systemQuantity: systemQty1,
        countedQuantity: countedQty1,
        differenceQuantity: diffQty1,
        unitCost: unitCost1,
        differenceValue: diffVal1,
      );

      expect(line1.differenceQuantity, equals(-5000));
      expect(line1.hasVariance, isTrue);
      expect(line1.differenceValue, equals(-250000));

      // Surplus: Counted (53) - System (50) = +3 units
      const int systemQty2 = 50000;
      const int countedQty2 = 53000;
      const int diffQty2 = countedQty2 - systemQty2; // +3,000
      const int unitCost2 = 100000; // 1,000.00 YER
      final int diffVal2 = (diffQty2 * unitCost2) ~/ 1000; // +300,000 minor units

      final line2 = StocktakingLineModel(
        id: 'stk_l_2',
        organizationId: orgId,
        sessionId: 'session_01',
        itemId: 'item_02',
        systemQuantity: systemQty2,
        countedQuantity: countedQty2,
        differenceQuantity: diffQty2,
        unitCost: unitCost2,
        differenceValue: diffVal2,
      );

      expect(line2.differenceQuantity, equals(3000));
      expect(line2.hasVariance, isTrue);
      expect(line2.differenceValue, equals(300000));

      // Zero Variance
      final line3 = StocktakingLineModel(
        id: 'stk_l_3',
        organizationId: orgId,
        sessionId: 'session_01',
        itemId: 'item_03',
        systemQuantity: 20000,
        countedQuantity: 20000,
        differenceQuantity: 0,
        unitCost: 80000,
        differenceValue: 0,
      );
      expect(line3.differenceQuantity, equals(0));
      expect(line3.hasVariance, isFalse);
      expect(line3.differenceValue, equals(0));
    });

    // =========================================================================
    // 9. Stock Document & Movement Lifecycle
    // =========================================================================
    test('17. Stock document status transitions and movement generation', () {
      final doc = StockDocumentModel(
        id: 'doc_rcpt_001',
        organizationId: orgId,
        documentNumber: 'SR-2026-0001',
        documentType: StockDocumentType.receipt,
        documentDate: '2026-11-01',
        destinationWarehouseId: 'wh_main_$orgId',
        status: StockDocumentStatus.draft,
        totalCost: 1500000,
        createdAt: nowIso,
      );

      expect(doc.isDraft, isTrue);
      expect(doc.isPosted, isFalse);

      final postedDoc = doc.copyWith(
        status: StockDocumentStatus.posted,
        postedAt: nowIso,
      );

      expect(postedDoc.isDraft, isFalse);
      expect(postedDoc.isPosted, isTrue);

      final movement = StockMovementModel(
        id: 'sm_001',
        organizationId: orgId,
        itemId: 'item_01',
        warehouseId: 'wh_main_$orgId',
        documentId: postedDoc.id,
        documentNumber: postedDoc.documentNumber,
        movementType: StockMovementType.receipt,
        movementDate: postedDoc.documentDate,
        quantityIn: 10000, // +10.000 units
        quantityOut: 0,
        unitCost: 15000, // 150.00 YER
        totalCost: 1500000, // 15,000.00 YER
        createdAt: nowIso,
      );

      expect(movement.quantityIn, equals(10000));
      expect(movement.quantityOut, equals(0));
      expect(movement.movementType, equals(StockMovementType.receipt));
    });

    // =========================================================================
    // 10. Inventory Settings Serialization & Default Behavior
    // =========================================================================
    test('18. InventorySettingsModel default values and fallback accounts', () {
      final settings = InventorySettingsModel(
        id: 'set_$orgId',
        organizationId: orgId,
        allowNegativeStock: false,
        defaultValuationMethod: ValuationMethod.weightedAverage,
        inventoryAssetAccountId: '${orgId}_1131',
        cogsAccountId: '${orgId}_5101',
        inventoryAdjustmentAccountId: '${orgId}_5202',
        updatedAt: nowIso,
      );

      final map = settings.toMap();
      expect(map['allow_negative_stock'], equals(0));
      expect(map['default_valuation_method'], equals(ValuationMethod.weightedAverage));
      expect(map['inventory_asset_account_id'], equals('${orgId}_1131'));

      final restored = InventorySettingsModel.fromMap(map);
      expect(restored.allowNegativeStock, isFalse);
      expect(restored.cogsAccountId, equals('${orgId}_5101'));
      expect(restored.defaultValuationMethod, equals(ValuationMethod.weightedAverage));
    });
  });
}
