import 'package:sqflite_common/sqlite_api.dart';

import 'database_factory.dart';

class LocalStore {
  LocalStore._(this.db);

  final Database db;

  static Future<LocalStore> open({
    DatabaseFactory? factory,
    String? name,
  }) async {
    final selected = factory ?? createDatabaseFactory();
    final path = name ?? '${await selected.getDatabasesPath()}/zeus.db';
    final db = await selected.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: migrate,
        onUpgrade: (db, from, to) => migrate(db, to, from: from),
      ),
    );
    return LocalStore._(db);
  }

  static Future<void> migrate(Database db, int to, {int from = 0}) async {
    if (from < 1 && to >= 1) {
      final batch = db.batch();
      batch.execute('''
        CREATE TABLE preferences (
          key TEXT PRIMARY KEY NOT NULL,
          value TEXT NOT NULL
        )
      ''');
      batch.execute('''
        CREATE TABLE conversations (
          id TEXT PRIMARY KEY NOT NULL,
          title TEXT NOT NULL,
          provider_id TEXT,
          model_id TEXT,
          draft TEXT NOT NULL DEFAULT '',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      batch.execute('''
        CREATE TABLE messages (
          id TEXT PRIMARY KEY NOT NULL,
          conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
          ordinal INTEGER NOT NULL,
          role TEXT NOT NULL CHECK(role IN ('user', 'assistant', 'tool', 'system')),
          content TEXT NOT NULL,
          status TEXT NOT NULL,
          provider_id TEXT,
          model_id TEXT,
          created_at INTEGER NOT NULL,
          UNIQUE(conversation_id, ordinal)
        )
      ''');
      await batch.commit(noResult: true);
    }
  }

  Future<Map<String, String>> preferences() async {
    return {
      for (final row in await db.query('preferences'))
        row['key'] as String: row['value'] as String,
    };
  }

  Future<void> setPreference(String key, String value) async {
    await db.insert('preferences', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> close() => db.close();
}
