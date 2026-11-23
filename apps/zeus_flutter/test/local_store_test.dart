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
    expect(await store.db.getVersion(), 4);
    expect(await store.db.query('conversations'), isEmpty);
    expect(await store.db.query('messages'), isEmpty);
  });
}
