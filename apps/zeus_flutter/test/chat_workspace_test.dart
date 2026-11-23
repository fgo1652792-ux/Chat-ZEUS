import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:zeus_chat/chat/chat_repository.dart';
import 'package:zeus_chat/chat/chat_runtime.dart';
import 'package:zeus_chat/chat/chat_workspace.dart';
import 'package:zeus_chat/data/local_store.dart';
import 'package:zeus_chat/providers/credentials.dart';
import 'package:zeus_chat/providers/provider_client.dart';
import 'package:zeus_chat/providers/provider_protocol.dart';
import 'package:zeus_chat/providers/provider_repository.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('shows a partial answer while the provider stream is open', (
    tester,
  ) async {
    final store = await LocalStore.open(
      factory: databaseFactoryFfiNoIsolate,
      name: inMemoryDatabasePath,
    );
    addTearDown(store.close);
    final credentials = SessionCredentials();
    final providers = ProviderRepository(store, credentials);
    await providers.save(
      ProviderConnection(
        id: 'fixture',
        kind: ProviderKind.compatible,
        endpoint: Uri.parse('https://provider.example/v1'),
        label: 'Fixture provider',
        manualModel: 'text-model',
      ),
      apiKey: 'fixture-key',
    );
    expect(
      (await store.db.query('providers')).single.values,
      isNot(contains('fixture-key')),
    );
    final frames = StreamController<List<int>>();
    final runtime = ChatRuntime(
      ChatRepository(store),
      providers,
      client: ProviderClient(
        openClient: () => MockClient.streaming((request, body) async {
          expect(request.headers['authorization'], 'Bearer fixture-key');
          final input = jsonDecode(
            await utf8.decoder.bind(body).join(),
          ) as Map<String, dynamic>;
          expect(input['model'], 'text-model');
          return http.StreamedResponse(frames.stream, 200);
        }),
      ),
    );
    addTearDown(runtime.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatWorkspace(runtime: runtime, onProviders: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New conversation'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tell me something');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    frames.add(
      utf8.encode('data: {"choices":[{"delta":{"content":"First"}}]}\n\n'),
    );
    await tester.pump();
    expect(find.text('First'), findsOneWidget);
    expect(find.byTooltip('Stop'), findsOneWidget);

    frames.add(
      utf8.encode(
        'data: {"choices":[{"delta":{"content":" then second"}}]}\n\ndata: [DONE]\n\n',
      ),
    );
    unawaited(frames.close());
    await tester.pumpAndSettle();
    expect(find.text('First then second'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
