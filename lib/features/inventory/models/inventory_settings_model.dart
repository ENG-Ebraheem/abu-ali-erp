/// Organization-level inventory settings and accounting links.
class InventorySettingsModel {
  final String id;
  final String organizationId;
  final bool isInventoryEnabled;
  final String? inventoryAssetAccountId;
  final String? inventoryAdjustmentAccountId;
  final String? cogsAccountId;
  final String? openingEquityAccountId;
  final String defaultValuationMethod;
  final bool allowNegativeStock;
  final String updatedAt;

  // Joined account names
  final String? inventoryAssetAccountName;
  final String? inventoryAdjustmentAccountName;
  final String? cogsAccountName;
  final String? openingEquityAccountName;

  const InventorySettingsModel({
    required this.id,
    required this.organizationId,
    this.isInventoryEnabled = true,
    this.inventoryAssetAccountId,
    this.inventoryAdjustmentAccountId,
    this.cogsAccountId,
    this.openingEquityAccountId,
    this.defaultValuationMethod = 'WEIGHTED_AVERAGE',
    this.allowNegativeStock = false,
    required this.updatedAt,
    this.inventoryAssetAccountName,
    this.inventoryAdjustmentAccountName,
    this.cogsAccountName,
    this.openingEquityAccountName,
  });

  factory InventorySettingsModel.fromMap(Map<String, dynamic> map) {
    return InventorySettingsModel(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      isInventoryEnabled:
          (map['is_inventory_enabled'] as num?)?.toInt() == 1,
      inventoryAssetAccountId: map['inventory_asset_account_id'] as String?,
      inventoryAdjustmentAccountId:
          map['inventory_adjustment_account_id'] as String?,
      cogsAccountId: map['cogs_account_id'] as String?,
      openingEquityAccountId: map['opening_equity_account_id'] as String?,
      defaultValuationMethod:
          (map['default_valuation_method'] as String?) ?? 'WEIGHTED_AVERAGE',
      allowNegativeStock:
          (map['allow_negative_stock'] as num?)?.toInt() == 1,
      updatedAt: map['updated_at'] as String,
      inventoryAssetAccountName: map['asset_acc_name'] as String?,
      inventoryAdjustmentAccountName: map['adj_acc_name'] as String?,
      cogsAccountName: map['cogs_acc_name'] as String?,
      openingEquityAccountName: map['equity_acc_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'is_inventory_enabled': isInventoryEnabled ? 1 : 0,
      'inventory_asset_account_id': inventoryAssetAccountId,
      'inventory_adjustment_account_id': inventoryAdjustmentAccountId,
      'cogs_account_id': cogsAccountId,
      'opening_equity_account_id': openingEquityAccountId,
      'default_valuation_method': defaultValuationMethod,
      'allow_negative_stock': allowNegativeStock ? 1 : 0,
      'updated_at': updatedAt,
    };
  }

  InventorySettingsModel copyWith({
    String? id,
    String? organizationId,
    bool? isInventoryEnabled,
    String? inventoryAssetAccountId,
    String? inventoryAdjustmentAccountId,
    String? cogsAccountId,
    String? openingEquityAccountId,
    String? defaultValuationMethod,
    bool? allowNegativeStock,
    String? updatedAt,
    String? inventoryAssetAccountName,
    String? inventoryAdjustmentAccountName,
    String? cogsAccountName,
    String? openingEquityAccountName,
  }) {
    return InventorySettingsModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      isInventoryEnabled: isInventoryEnabled ?? this.isInventoryEnabled,
      inventoryAssetAccountId:
          inventoryAssetAccountId ?? this.inventoryAssetAccountId,
      inventoryAdjustmentAccountId:
          inventoryAdjustmentAccountId ?? this.inventoryAdjustmentAccountId,
      cogsAccountId: cogsAccountId ?? this.cogsAccountId,
      openingEquityAccountId:
          openingEquityAccountId ?? this.openingEquityAccountId,
      defaultValuationMethod:
          defaultValuationMethod ?? this.defaultValuationMethod,
      allowNegativeStock: allowNegativeStock ?? this.allowNegativeStock,
      updatedAt: updatedAt ?? this.updatedAt,
      inventoryAssetAccountName:
          inventoryAssetAccountName ?? this.inventoryAssetAccountName,
      inventoryAdjustmentAccountName:
          inventoryAdjustmentAccountName ?? this.inventoryAdjustmentAccountName,
      cogsAccountName: cogsAccountName ?? this.cogsAccountName,
      openingEquityAccountName:
          openingEquityAccountName ?? this.openingEquityAccountName,
    );
  }
}

