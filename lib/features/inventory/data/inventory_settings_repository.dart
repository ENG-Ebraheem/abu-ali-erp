import 'package:sqflite/sqflite.dart';
import 'package:abu_ali/core/constants/database_constants.dart';
import 'package:abu_ali/core/database/database_helper.dart';
import '../models/inventory_settings_model.dart';

/// Repository for managing organization-level inventory configuration and accounting links.
class InventorySettingsRepository {
  final DatabaseHelper _dbHelper;

  InventorySettingsRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db async => await _dbHelper.database;

  /// Retrieves the inventory settings for an organization, auto-seeding defaults if missing.
  Future<InventorySettingsModel> getSettings(String organizationId) async {
    final db = await _db;

    final query = '''
      SELECT 
        s.*,
        a_asset.account_name_ar AS asset_acc_name,
        a_adj.account_name_ar AS adj_acc_name,
        a_cogs.account_name_ar AS cogs_acc_name,
        a_eq.account_name_ar AS equity_acc_name
      FROM ${DatabaseConstants.tableInventorySettings} s
      LEFT JOIN ${DatabaseConstants.tableChartOfAccounts} a_asset ON s.inventory_asset_account_id = a_asset.id
      LEFT JOIN ${DatabaseConstants.tableChartOfAccounts} a_adj ON s.inventory_adjustment_account_id = a_adj.id
      LEFT JOIN ${DatabaseConstants.tableChartOfAccounts} a_cogs ON s.cogs_account_id = a_cogs.id
      LEFT JOIN ${DatabaseConstants.tableChartOfAccounts} a_eq ON s.opening_equity_account_id = a_eq.id
      WHERE s.organization_id = ?
      LIMIT 1
    ''';

    final rows = await db.rawQuery(query, [organizationId]);

    if (rows.isNotEmpty) {
      return InventorySettingsModel.fromMap(rows.first);
    }

    // Auto-create default settings if not exists
    final now = DateTime.now().toUtc().toIso8601String();
    final defaultSettings = InventorySettingsModel(
      id: 'inv_set_$organizationId',
      organizationId: organizationId,
      isInventoryEnabled: true,
      inventoryAssetAccountId: '${organizationId}_1131',
      inventoryAdjustmentAccountId: '${organizationId}_5202',
      cogsAccountId: '${organizationId}_51',
      openingEquityAccountId: '${organizationId}_3999',
      defaultValuationMethod: 'WEIGHTED_AVERAGE',
      allowNegativeStock: false,
      updatedAt: now,
    );

    await db.insert(
      DatabaseConstants.tableInventorySettings,
      defaultSettings.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return defaultSettings;
  }

  /// Updates inventory settings for an organization.
  Future<void> saveSettings(InventorySettingsModel settings) async {
    final db = await _db;
    final data = settings.toMap();
    data['updated_at'] = DateTime.now().toUtc().toIso8601String();

    await db.insert(
      DatabaseConstants.tableInventorySettings,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
