import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zeus_chat/data/local_store.dart';

void main() {
  sqfliteFfiInit();

  test('settings survive closing and reopening the database', () async {
    final temp = await Directory.systemTemp.createTemp('zeus_store_');
    addTearDown(() => temp.delete(recursive: true));
    final path = '${temp.path}/zeus.db';

    var store = await LocalStore.open(factory: databaseFactoryFfi, name: path);
    await store.setPreference('locale', 'en');
    await store.setPreference('theme', 'light');
    await store.setPreference('glass', 'false');
    await store.close();

    store = await LocalStore.open(factory: databaseFactoryFfi, name: path);
    addTearDown(store.close);
    expect(await store.preferences(), {
      'locale': 'en',
      'theme': 'light',
      'glass': 'false',
    });
    expect(await store.db.getVersion(), 6);
    expect(await store.db.query('conversations'), isEmpty);
    expect(await store.db.query('messages'), isEmpty);
  });
  test(
    'upgrade from schema 1 retains saved history and creates new tables',
    () async {
      final temp = await Directory.systemTemp.createTemp('zeus_migration_');
      addTearDown(() => temp.delete(recursive: true));
      final path = '${temp.path}/legacy.db';
      final legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(version: 1, onCreate: LocalStore.migrate),
      );
      await legacy.insert('conversations', {
        'id': 'original',
        'title': 'Existing chat',
        'created_at': 1,
        'updated_at': 2,
      });
      await legacy.insert('messages', {
        'id': 'original-message',
        'conversation_id': 'original',
        'ordinal': 1,
        'role': 'user',
        'content': 'Saved text',
        'status': 'completed',
        'created_at': 1,
      });
      await legacy.close();
      final upgraded = await LocalStore.open(
        factory: databaseFactoryFfi,
        name: path,
      );
      addTearDown(upgraded.close);
      expect(
        (await upgraded.db.query('messages')).single['content'],
        'Saved text',
      );
      expect(await upgraded.db.query('attachments'), isEmpty);
      expect(await upgraded.db.query('projects'), isEmpty);
    },
  );
}
