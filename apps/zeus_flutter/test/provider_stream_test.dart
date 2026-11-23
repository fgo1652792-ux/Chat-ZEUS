import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:zeus_chat/providers/provider_client.dart';
import 'package:zeus_chat/providers/provider_protocol.dart';

void main() {
  test(
    'SSE renders the first UTF-8 delta before the server completes',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final finish = Completer<void>();
      addTearDown(() {
        if (!finish.isCompleted) finish.complete();
      });
      var responseCompleted = false;
      server.listen((request) async {
        expect(request.uri.path, '/v1/chat/completions');
        final body = jsonDecode(
          await utf8.decoder.bind(request).join(),
        ) as Map<String, dynamic>;
        expect(body['stream'], true);
        expect(body['model'], 'test-model');
        final response = request.response
          ..bufferOutput = false
          ..headers.contentType = ContentType(
            'text',
            'event-stream',
            charset: 'utf-8',
          );
        final bytes = utf8.encode(
          'data: {"choices":[{"delta":{"content":"مرحبا"}}]}\r\n\r\n',
        );
        final split = bytes.indexWhere((b) => b > 127) + 1;
        response.add(bytes.sublist(0, split));
        await response.flush();
        response.add(bytes.sublist(split));
        await response.flush();
        await finish.future;
        response.write(
          'data: {"choices":[{"delta":{"content":" بالعالم"}}]}\n\n',
        );
        response.write('data: [DONE]\n\n');
        responseCompleted = true;
        await response.close();
      });
      final config = ProviderConnection(
        id: 'local',
        kind: ProviderKind.compatible,
        endpoint: Uri.parse('http://127.0.0.1:${server.port}/v1'),
        label: 'Local test',
      );
      final stream = const ProviderClient().streamChat(
        config,
        null,
        'test-model',
        const [ChatInput('user', 'سلام')],
        abort: Completer<void>().future,
      );
      final cursor = StreamIterator(stream);
      addTearDown(cursor.cancel);
      expect(await cursor.moveNext(), isTrue);
      expect(cursor.current.text, 'مرحبا');
      expect(responseCompleted, isFalse);
      finish.complete();
      expect(await cursor.moveNext(), isTrue);
      expect(cursor.current.text, ' بالعالم');
      expect(await cursor.moveNext(), isTrue);
      expect(cursor.current.type, ProviderEventType.completed);
      expect(await cursor.moveNext(), isFalse);
    },
  );

  test('provider-specific auth and rate limit metadata', () async {
    final config = ProviderConnection(
      id: 'claude',
      kind: ProviderKind.anthropic,
      endpoint: Uri.parse(ProviderKind.anthropic.defaultEndpoint),
      label: 'Claude',
    );
    final client = ProviderClient(
      openClient: () => MockClient((request) async {
        expect(request.headers['x-api-key'], 'fixture-secret');
        expect(request.headers['anthropic-version'], '2023-06-01');
        expect(request.url.path, '/v1/models');
        return http.Response(
          'provider error body',
          429,
          headers: {'retry-after': '7'},
        );
      }),
    );
    await expectLater(
      client.listModels(config, 'fixture-secret'),
      throwsA(
        isA<ProviderException>()
            .having(
              (error) => error.code,
              'kind',
              ProviderErrorCode.rateLimited,
            )
            .having(
              (error) => error.retryAfter,
              'retry after',
              const Duration(seconds: 7),
            ),
      ),
    );
  });

  test('finished Ollama frames and counts arrive over NDJSON', () async {
    final config = ProviderConnection(
      id: 'ollama',
      kind: ProviderKind.ollama,
      endpoint: Uri.parse(ProviderKind.ollama.defaultEndpoint),
      label: 'Ollama',
    );
    final client = ProviderClient(
      openClient: () => MockClient((request) async {
        expect(request.url.path, '/api/chat');
        return http.Response(
          '{"message":{"content":"Hello"}}\n{"done":true,"prompt_eval_count":3,"eval_count":2}\n',
          200,
        );
      }),
    );
    final events = await client.streamChat(config, null, 'model', const [
      ChatInput('user', 'hi'),
    ], abort: Completer<void>().future).toList();
    expect(events.map((event) => event.type), [
      ProviderEventType.text,
      ProviderEventType.usage,
      ProviderEventType.completed,
    ]);
    expect(events[1].outputTokens, 2);
  });
}
