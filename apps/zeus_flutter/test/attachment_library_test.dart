import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:zeus_chat/attachments/attachments.dart';
import 'package:zeus_chat/chat/chat_repository.dart';
import 'package:zeus_chat/data/local_store.dart';

void main() {
  sqfliteFfiInit();

  test('stores valid text with the owning conversation only', () async {
    final store = await LocalStore.open(
      factory: databaseFactoryFfi,
      name: inMemoryDatabasePath,
    );
    addTearDown(store.close);
    final history = ChatRepository(store);
    final first = await history.create('One');
    final second = await history.create('Two');
    final library = AttachmentLibrary(store);
    final file = await library.importFile(
      first.id,
      XFile.fromData(
        utf8.encode('city,count\nبغداد,2'),
        path: 'budget.csv',
        name: 'budget.csv',
      ),
    );
    expect((await library.list(first.id)).single.name, 'budget.csv');
    expect(await library.list(second.id), isEmpty);
    expect(utf8.decode(await library.contents(file)), 'city,count\nبغداد,2');
    final wrongThread = ConversationFile(
      id: file.id,
      threadId: second.id,
      name: file.name,
      kind: file.kind,
      size: file.size,
    );
    await expectLater(
      library.contents(wrongThread),
      throwsA(isA<AttachmentException>()),
    );
    await expectLater(
      library.importFile(
        first.id,
        XFile.fromData(
          utf8.encode('wrong'),
          path: 'invalid.pdf',
          name: 'invalid.pdf',
        ),
      ),
      throwsA(isA<AttachmentException>()),
    );
    await library.remove(file);
    expect(await library.list(first.id), isEmpty);
  });
}
