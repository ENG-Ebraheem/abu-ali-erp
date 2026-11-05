import 'package:sqflite/sqflite.dart';

/// Contract interface for database schema migrations.
abstract class Migration {
  /// Target version applied by this migration.
  int get version;

  /// Brief human-readable description of changes introduced.
  String get description;

  /// Executes the migration statements within the provided database executor.
  Future<void> up(DatabaseExecutor db);
}
