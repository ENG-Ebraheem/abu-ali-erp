import 'package:sqflite/sqflite.dart';
import '../../../core/constants/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../models/party_model.dart';

/// Repository handling party (customer/supplier) SQLite operations.
class PartyRepository {
  final DatabaseHelper _dbHelper;

  PartyRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db async => await _dbHelper.database;

  /// Fetches parties with dynamically calculated balances from posted journal entries.
  Future<List<PartyModel>> getParties({
    required String organizationId,
    String? partyType, // 'CUSTOMER', 'SUPPLIER', 'BOTH', or null for all
    String? query,
    bool includeInactive = false,
  }) async {
    final db = await _db;

    // Join with journal_entry_lines to calculate net balance for each party
    // For customers: Debit increases balance (receivable), Credit reduces balance
    // For suppliers: Credit increases balance (payable), Debit reduces balance
    final String sql = '''
      SELECT 
        p.*,
        COALESCE(SUM(
          CASE 
            WHEN je.id IS NOT NULL THEN
              CASE 
                WHEN p.party_type = 'SUPPLIER' THEN (jel.base_credit - jel.base_debit)
                ELSE (jel.base_debit - jel.base_credit)
              END
            ELSE 0
          END
        ), 0) AS calculated_balance,
        COUNT(je.id) AS tx_count
      FROM ${DatabaseConstants.tableParties} p
      LEFT JOIN ${DatabaseConstants.tableJournalEntryLines} jel 
        ON jel.party_id = p.id AND jel.organization_id = p.organization_id
      LEFT JOIN ${DatabaseConstants.tableJournalEntries} je 
        ON je.id = jel.journal_entry_id AND je.organization_id = jel.organization_id AND je.status = 'POSTED'
      WHERE p.organization_id = ?
        ${!includeInactive ? 'AND p.is_active = 1' : ''}
        ${partyType != null && partyType != 'ALL' ? "AND (p.party_type = '$partyType' OR p.party_type = 'BOTH')" : ''}
        ${query != null && query.trim().isNotEmpty ? "AND (p.name_ar LIKE ? OR p.code LIKE ? OR p.phone LIKE ?)" : ''}
      GROUP BY p.id
      ORDER BY p.code ASC
    ''';

    final List<dynamic> args = [organizationId];
    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim()}%';
      args.addAll([q, q, q]);
    }

    final List<Map<String, dynamic>> results = await db.rawQuery(sql, args);
    return results.map((map) => PartyModel.fromMap(map)).toList();
  }

  /// Fetches a single party by ID with its live balance.
  Future<PartyModel?> getPartyById(String id, String organizationId) async {
    final db = await _db;
    final String sql = '''
      SELECT 
        p.*,
        COALESCE(SUM(
          CASE 
            WHEN je.id IS NOT NULL THEN
              CASE 
                WHEN p.party_type = 'SUPPLIER' THEN (jel.base_credit - jel.base_debit)
                ELSE (jel.base_debit - jel.base_credit)
              END
            ELSE 0
          END
        ), 0) AS calculated_balance,
        COUNT(je.id) AS tx_count
      FROM ${DatabaseConstants.tableParties} p
      LEFT JOIN ${DatabaseConstants.tableJournalEntryLines} jel 
        ON jel.party_id = p.id AND jel.organization_id = p.organization_id
      LEFT JOIN ${DatabaseConstants.tableJournalEntries} je 
        ON je.id = jel.journal_entry_id AND je.organization_id = jel.organization_id AND je.status = 'POSTED'
      WHERE p.id = ? AND p.organization_id = ?
      GROUP BY p.id
      LIMIT 1
    ''';

    final results = await db.rawQuery(sql, [id, organizationId]);
    if (results.isEmpty) return null;
    return PartyModel.fromMap(results.first);
  }

  /// Generates the next sequential code for a customer or supplier.
  Future<String> getNextPartyCode(
      String organizationId, String partyType) async {
    final db = await _db;
    final prefix = partyType == 'SUPPLIER' ? 'SUPP' : 'CUST';
    final results = await db.rawQuery('''
      SELECT code FROM ${DatabaseConstants.tableParties}
      WHERE organization_id = ? AND code LIKE '$prefix-%'
      ORDER BY length(code) DESC, code DESC
      LIMIT 1
    ''', [organizationId]);

    if (results.isEmpty) {
      return '$prefix-001';
    }

    final lastCode = results.first['code'] as String;
    final parts = lastCode.split('-');
    if (parts.length == 2) {
      final numVal = int.tryParse(parts[1]);
      if (numVal != null) {
        return '$prefix-${(numVal + 1).toString().padLeft(3, '0')}';
      }
    }

    return '$prefix-${DateTime.now().millisecondsSinceEpoch % 1000}';
  }

  /// Inserts a new party into SQLite.
  Future<void> createParty(PartyModel party) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final map = party.toMap();
    map['created_at'] = now;
    map['updated_at'] = now;

    await db.insert(
      DatabaseConstants.tableParties,
      map,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Updates an existing party.
  Future<void> updateParty(PartyModel party) async {
    final db = await _db;
    final map = party.toMap();
    map['updated_at'] = DateTime.now().toIso8601String();

    await db.update(
      DatabaseConstants.tableParties,
      map,
      where: 'id = ? AND organization_id = ?',
      whereArgs: [party.id, party.organizationId],
    );
  }

  /// Toggles active status.
  Future<void> togglePartyActive(
      String id, String organizationId, bool isActive) async {
    final db = await _db;
    await db.update(
      DatabaseConstants.tableParties,
      {
        'is_active': isActive ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND organization_id = ?',
      whereArgs: [id, organizationId],
    );
  }

  /// Checks if a party has any financial activity before deletion.
  Future<bool> hasTransactions(String id, String organizationId) async {
    final db = await _db;

    final jelCount = Sqflite.firstIntValue(await db.rawQuery('''
      SELECT COUNT(*) FROM ${DatabaseConstants.tableJournalEntryLines}
      WHERE party_id = ? AND organization_id = ?
    ''', [id, organizationId])) ?? 0;
    if (jelCount > 0) return true;

    final invCount = Sqflite.firstIntValue(await db.rawQuery('''
      SELECT COUNT(*) FROM ${DatabaseConstants.tableInvoices}
      WHERE party_id = ? AND organization_id = ?
    ''', [id, organizationId])) ?? 0;
    if (invCount > 0) return true;

    final payCount = Sqflite.firstIntValue(await db.rawQuery('''
      SELECT COUNT(*) FROM ${DatabaseConstants.tablePayments}
      WHERE party_id = ? AND organization_id = ?
    ''', [id, organizationId])) ?? 0;
    if (payCount > 0) return true;

    return false;
  }

  /// Safely deletes a party if it has no financial records.
  Future<void> deleteParty(String id, String organizationId) async {
    if (await hasTransactions(id, organizationId)) {
      throw Exception(
        'لا يمكن حذف هذا الطرف المحاسبي لوجود فواتير أو دفعات أو قيود يومية مرتبطة به. يمكنك إلغاء تفعيله أو أرشفته بدلاً من الحذف.',
      );
    }

    final db = await _db;
    await db.delete(
      DatabaseConstants.tableParties,
      where: 'id = ? AND organization_id = ?',
      whereArgs: [id, organizationId],
    );
  }

  /// Fetches statement / ledger lines for this party.
  Future<List<Map<String, dynamic>>> getPartyTransactions(
    String partyId,
    String organizationId,
  ) async {
    final db = await _db;
    return await db.rawQuery('''
      SELECT 
        jel.id,
        je.entry_number,
        je.entry_date,
        je.entry_type,
        jel.description,
        jel.currency_code,
        jel.foreign_debit,
        jel.foreign_credit,
        jel.base_debit,
        jel.base_credit
      FROM ${DatabaseConstants.tableJournalEntryLines} jel
      INNER JOIN ${DatabaseConstants.tableJournalEntries} je 
        ON je.id = jel.journal_entry_id AND je.organization_id = jel.organization_id
      WHERE jel.party_id = ? AND jel.organization_id = ? AND je.status = 'POSTED'
      ORDER BY je.entry_date DESC, je.entry_number DESC
    ''', [partyId, organizationId]);
  }
}
