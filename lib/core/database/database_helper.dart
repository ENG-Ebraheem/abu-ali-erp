import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../constants/database_constants.dart';
import 'migrations/migration.dart';
import 'migrations/migration_v1_to_v2.dart';
import 'migrations/migration_v2_to_v3.dart';
import 'migrations/migration_v3_to_v4.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;

  /// Returns the singleton database instance, initializing or upgrading as needed.
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = p.join(databasePath, DatabaseConstants.databaseName);

    final db = await openDatabase(
      path,
      version: DatabaseConstants.databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _applyMigrations(db, 0, version);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _applyMigrations(db, oldVersion, newVersion);
      },
    );

    return db;
  }

  /// Applies pending database migrations sequentially.
  static Future<void> _applyMigrations(
    DatabaseExecutor db,
    int oldVersion,
    int newVersion,
  ) async {
    // 1. Ensure migrations ledger exists
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableMigrations} (
        version INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        applied_at TEXT NOT NULL
      );
    ''');

    // 2. Migration pipeline registry
    final migrations = <Migration>[
      MigrationV1ToV2(),
      MigrationV2ToV3(),
      MigrationV3ToV4(),
    ];

    for (final migration in migrations) {
      if (migration.version > oldVersion && migration.version <= newVersion) {
        final existing = await db.query(
          DatabaseConstants.tableMigrations,
          columns: ['version'],
          where: 'version = ?',
          whereArgs: [migration.version],
        );

        if (existing.isEmpty) {
          await migration.up(db);
          await db.insert(
            DatabaseConstants.tableMigrations,
            {
              'version': migration.version,
              'name': migration.description,
              'applied_at': DateTime.now().toUtc().toIso8601String(),
            },
          );
        }
      }
    }
  }

  /// Helper to cleanly close the database connection.
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
