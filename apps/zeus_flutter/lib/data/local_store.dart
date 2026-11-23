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
        version: 6,
        singleInstance: path != ':memory:',
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
    if (from < 2 && to >= 2) {
      await db.execute('''
        CREATE TABLE providers (
          id TEXT PRIMARY KEY NOT NULL,
          kind TEXT NOT NULL,
          endpoint TEXT NOT NULL,
          label TEXT NOT NULL,
          manual_model TEXT NOT NULL DEFAULT ''
        )
      ''');
    }
    if (from < 3 && to >= 3) {
      final batch = db.batch();
      batch.execute("ALTER TABLE messages ADD COLUMN error_code TEXT");
      batch.execute("ALTER TABLE messages ADD COLUMN input_tokens INTEGER");
      batch.execute("ALTER TABLE messages ADD COLUMN output_tokens INTEGER");
      batch.execute(
        "ALTER TABLE conversations ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0",
      );
      batch.execute(
        "ALTER TABLE conversations ADD COLUMN archived INTEGER NOT NULL DEFAULT 0",
      );
      batch.execute(
        "ALTER TABLE conversations ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0",
      );
      batch.execute("ALTER TABLE conversations ADD COLUMN parent_thread TEXT");
      batch.execute("ALTER TABLE conversations ADD COLUMN parent_message TEXT");
      batch.execute(
        "CREATE INDEX chat_order ON conversations (deleted, archived, pinned DESC, updated_at DESC)",
      );
      await batch.commit(noResult: true);
    }
    if (from < 4 && to >= 4) {
      final batch = db.batch();
      batch.execute('''
        CREATE TABLE attachments (
          id TEXT PRIMARY KEY NOT NULL,
          conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
          name TEXT NOT NULL,
          kind TEXT NOT NULL CHECK(kind IN ('image', 'pdf', 'text')),
          size INTEGER NOT NULL CHECK(size > 0 AND size <= 8388608),
          payload BLOB NOT NULL CHECK(length(payload) = size),
          created_at INTEGER NOT NULL
        )
      ''');
      batch.execute(
        'CREATE INDEX attachments_by_conversation ON attachments(conversation_id, created_at DESC)',
      );
      await batch.commit(noResult: true);
    }
    if (from < 5 && to >= 5) {
      await db.execute('''
        CREATE TABLE generated_images (
          id TEXT PRIMARY KEY NOT NULL,
          model TEXT NOT NULL,
          prompt TEXT NOT NULL,
          payload BLOB NOT NULL CHECK(length(payload) <= 8388608),
          created_at INTEGER NOT NULL
        )
      ''');
    }
    if (from < 6 && to >= 6) {
      final batch = db.batch();
      batch.execute('''
        CREATE TABLE projects (
          id TEXT PRIMARY KEY NOT NULL,
          name TEXT NOT NULL,
          instructions TEXT NOT NULL
        )
      ''');
      batch.execute('''
        CREATE TABLE project_memories (
          id TEXT PRIMARY KEY NOT NULL,
          project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
          text TEXT NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');
      batch.execute(
        'ALTER TABLE conversations ADD COLUMN project_id TEXT REFERENCES projects(id) ON DELETE SET NULL',
      );
      batch.execute(
        'CREATE INDEX project_memories_project ON project_memories(project_id, created_at)',
      );
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
