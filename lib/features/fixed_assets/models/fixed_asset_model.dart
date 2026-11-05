/// Model representing a fixed asset (الأصل الثابت) subject to depreciation.
class FixedAssetModel {
  final String id;
  final String organizationId;
  final String assetCode;
  final String assetNameAr;
  final String assetAccountId; // Account ID under ASSETS (e.g. 1211)
  final String depreciationExpenseAccountId; // Account ID under EXPENSES (e.g. 5201)
  final String accumulatedDepreciationAccountId; // Account ID under CONTRA-ASSET (e.g. 1221)
  final String purchaseDate; // YYYY-MM-DD
  final int purchaseCost; // Minor units (scale 100)
  final int salvageValue; // Minor units (scale 100)
  final int usefulLifeMonths; // Months
  final String depreciationMethod; // 'STRAIGHT_LINE'
  final int accumulatedDepreciation; // Minor units (scale 100)
  final String? lastDepreciationDate;
  final bool isActive;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  // Joined display names
  final String? assetAccountName;
  final String? expenseAccountName;
  final String? accumulatedAccountName;

  const FixedAssetModel({
    required this.id,
    required this.organizationId,
    required this.assetCode,
    required this.assetNameAr,
    required this.assetAccountId,
    required this.depreciationExpenseAccountId,
    required this.accumulatedDepreciationAccountId,
    required this.purchaseDate,
    required this.purchaseCost,
    this.salvageValue = 0,
    required this.usefulLifeMonths,
    this.depreciationMethod = 'STRAIGHT_LINE',
    this.accumulatedDepreciation = 0,
    this.lastDepreciationDate,
    this.isActive = true,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.assetAccountName,
    this.expenseAccountName,
    this.accumulatedAccountName,
  });

  /// Net Book Value (صافي القيمة الدفترية للأصل).
  int get bookValue {
    final net = purchaseCost - accumulatedDepreciation;
    return net > 0 ? net : 0;
  }

  /// Depreciable base cost (التكلفة القابلة للإهلاك).
  int get depreciableCost {
    final base = purchaseCost - salvageValue;
    return base > 0 ? base : 0;
  }

  /// Monthly straight-line depreciation installment (قسط الإهلاك الشهري).
  int get monthlyDepreciation {
    if (usefulLifeMonths <= 0) return 0;
    return depreciableCost ~/ usefulLifeMonths;
  }

  /// Remaining depreciable amount.
  int get remainingDepreciation {
    final rem = depreciableCost - accumulatedDepreciation;
    return rem > 0 ? rem : 0;
  }

  /// Depreciated ratio between 0.0 and 1.0 for progress visualization.
  double get depreciatedRatio {
    if (depreciableCost <= 0) return 1.0;
    return (accumulatedDepreciation / depreciableCost).clamp(0.0, 1.0);
  }

  factory FixedAssetModel.fromMap(Map<String, dynamic> map) {
    return FixedAssetModel(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      assetCode: map['asset_code'] as String,
      assetNameAr: map['asset_name_ar'] as String,
      assetAccountId: map['asset_account_id'] as String,
      depreciationExpenseAccountId:
          map['depreciation_expense_account_id'] as String,
      accumulatedDepreciationAccountId:
          map['accumulated_depreciation_account_id'] as String,
      purchaseDate: map['purchase_date'] as String,
      purchaseCost: (map['purchase_cost'] as num).toInt(),
      salvageValue: (map['salvage_value'] as num?)?.toInt() ?? 0,
      usefulLifeMonths: (map['useful_life_months'] as num).toInt(),
      depreciationMethod:
          (map['depreciation_method'] as String?) ?? 'STRAIGHT_LINE',
      accumulatedDepreciation:
          (map['accumulated_depreciation'] as num?)?.toInt() ?? 0,
      lastDepreciationDate: map['last_depreciation_date'] as String?,
      isActive: (map['is_active'] as num?)?.toInt() == 1,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      assetAccountName: map['asset_account_name'] as String?,
      expenseAccountName: map['expense_account_name'] as String?,
      accumulatedAccountName: map['accumulated_account_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'asset_code': assetCode,
      'asset_name_ar': assetNameAr,
      'asset_account_id': assetAccountId,
      'depreciation_expense_account_id': depreciationExpenseAccountId,
      'accumulated_depreciation_account_id': accumulatedDepreciationAccountId,
      'purchase_date': purchaseDate,
      'purchase_cost': purchaseCost,
      'salvage_value': salvageValue,
      'useful_life_months': usefulLifeMonths,
      'depreciation_method': depreciationMethod,
      'accumulated_depreciation': accumulatedDepreciation,
      'last_depreciation_date': lastDepreciationDate,
      'is_active': isActive ? 1 : 0,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
