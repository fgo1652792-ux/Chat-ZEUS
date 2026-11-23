import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:zeus_chat/chat/chat_repository.dart';
import 'package:zeus_chat/chat/chat_runtime.dart';
import 'package:zeus_chat/data/local_store.dart';
import 'package:zeus_chat/providers/credentials.dart';
import 'package:zeus_chat/providers/provider_protocol.dart';
import 'package:zeus_chat/providers/provider_repository.dart';

void main() {
  sqfliteFfiInit();

  test(
    'stop preserves partial response and aborts a live HTTP stream',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final serverCanFinish = Completer<void>();
      addTearDown(() {
        if (!serverCanFinish.isCompleted) serverCanFinish.complete();
      });
      server.listen((request) async {
        await request.drain<void>();
        final response = request.response
          ..bufferOutput = false
          ..headers.contentType = ContentType('text', 'event-stream');
        response.add(
          utf8.encode(
            'data: {"choices":[{"delta":{"content":"partial"}}]}\n\n',
          ),
        );
        await response.flush();
        await serverCanFinish.future;
        await response.close();
      });
      final store = await LocalStore.open(
        factory: databaseFactoryFfi,
        name: inMemoryDatabasePath,
      );
      addTearDown(store.close);
      final providers = ProviderRepository(store, SessionCredentials());
      final repository = ChatRepository(store);
      final runtime = ChatRuntime(repository, providers);
      addTearDown(runtime.dispose);
      final thread = await repository.create('My conversation');
      final received = Completer<void>();
      runtime.addListener(() {
        if (runtime.active(thread.id)?.text == 'partial' &&
            !received.isCompleted) {
          received.complete();
        }
      });

      final completion = runtime.send(
        thread,
        ProviderConnection(
          id: 'local',
          kind: ProviderKind.compatible,
          endpoint: Uri.parse('http://127.0.0.1:${server.port}/v1'),
          label: 'Test local provider',
        ),
        'fixture-model',
        'Prompt',
      );
      await received.future.timeout(const Duration(seconds: 4));
      runtime.cancel(thread.id);
      await completion.timeout(const Duration(seconds: 4));
      expect(serverCanFinish.isCompleted, isFalse);
      final messages = await repository.messages(thread.id);
      expect(messages.map((message) => message.text), ['Prompt', 'partial']);
      expect(messages.last.state, MessageState.cancelled);

      final branch = await repository.fork(
        thread,
        messages.first,
        'Edited',
        editedText: 'New prompt',
      );
      expect((await repository.messages(branch.id)).single.text, 'New prompt');
      expect((await repository.messages(thread.id)).first.text, 'Prompt');
      expect(
        (await repository.list(search: 'New prompt')).single.id,
        branch.id,
      );
      await repository.trash(branch.id, true);
      expect((await repository.list(deleted: true)).single.id, branch.id);
      await repository.trash(branch.id, false);
      expect(await repository.list(deleted: true), isEmpty);
    },
  );
}
