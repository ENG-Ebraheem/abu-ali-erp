import 'package:sqflite/sqflite.dart';
import '../../../core/constants/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../models/exchange_rate_model.dart';

/// Repository for handling foreign exchange rates and currency lists in SQLite.
class ExchangeRateRepository {
  final DatabaseHelper _dbHelper;

  ExchangeRateRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db async => await _dbHelper.database;

  /// Fetches all active currencies in the system.
  Future<List<Map<String, dynamic>>> getCurrencies() async {
    final db = await _db;
    return await db.query(
      DatabaseConstants.tableCurrencies,
      where: 'is_active = 1',
      orderBy: 'code ASC',
    );
  }

  /// Fetches exchange rates for an organization, ordered by date descending.
  Future<List<ExchangeRateModel>> getExchangeRates(
      String organizationId) async {
    final db = await _db;
    final results = await db.query(
      DatabaseConstants.tableExchangeRates,
      where: 'organization_id = ?',
      whereArgs: [organizationId],
      orderBy: 'rate_date DESC, created_at DESC',
    );

    return results.map((map) => ExchangeRateModel.fromMap(map)).toList();
  }

  /// Fetches the latest exchange rate between two currencies as of a given date.
  Future<ExchangeRateModel?> getLatestRate({
    required String organizationId,
    required String fromCurrency,
    required String toCurrency,
    String? asOfDate,
  }) async {
    if (fromCurrency == toCurrency) {
      // 1:1 rate scaled by 1,000,000
      return ExchangeRateModel(
        id: 'identity',
        organizationId: organizationId,
        fromCurrencyCode: fromCurrency,
        toCurrencyCode: toCurrency,
        rateScaled: DatabaseConstants.exchangeRateScale,
        rateDate: asOfDate ?? DateTime.now().toIso8601String().split('T').first,
        createdAt: '',
      );
    }

    final db = await _db;
    final date = asOfDate ?? DateTime.now().toIso8601String().split('T').first;

    final results = await db.query(
      DatabaseConstants.tableExchangeRates,
      where:
          'organization_id = ? AND from_currency_code = ? AND to_currency_code = ? AND rate_date <= ?',
      whereArgs: [organizationId, fromCurrency, toCurrency, date],
      orderBy: 'rate_date DESC',
      limit: 1,
    );

    if (results.isNotEmpty) {
      return ExchangeRateModel.fromMap(results.first);
    }

    // Check inverse rate
    final inverse = await db.query(
      DatabaseConstants.tableExchangeRates,
      where:
          'organization_id = ? AND from_currency_code = ? AND to_currency_code = ? AND rate_date <= ?',
      whereArgs: [organizationId, toCurrency, fromCurrency, date],
      orderBy: 'rate_date DESC',
      limit: 1,
    );

    if (inverse.isNotEmpty) {
      final invRate = ExchangeRateModel.fromMap(inverse.first);
      // Invert: scaled^2 / inv.rateScaled
      final double invDouble = invRate.rateAsDouble;
      if (invDouble > 0) {
        final double directDouble = 1.0 / invDouble;
        final int directScaled =
            (directDouble * DatabaseConstants.exchangeRateScale).round();
        return ExchangeRateModel(
          id: '${invRate.id}_inv',
          organizationId: organizationId,
          fromCurrencyCode: fromCurrency,
          toCurrencyCode: toCurrency,
          rateScaled: directScaled,
          rateDate: invRate.rateDate,
          createdAt: invRate.createdAt,
        );
      }
    }

    return null;
  }

  /// Upserts an exchange rate for a given date.
  Future<void> saveRate(ExchangeRateModel rate) async {
    final db = await _db;
    final map = rate.toMap();
    if (map['created_at'] == null || (map['created_at'] as String).isEmpty) {
      map['created_at'] = DateTime.now().toIso8601String();
    }

    // Use INSERT OR REPLACE to update existing rate on same date
    await db.insert(
      DatabaseConstants.tableExchangeRates,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Deletes an exchange rate.
  Future<void> deleteRate(String id, String organizationId) async {
    final db = await _db;
    await db.delete(
      DatabaseConstants.tableExchangeRates,
      where: 'id = ? AND organization_id = ?',
      whereArgs: [id, organizationId],
    );
  }
}
