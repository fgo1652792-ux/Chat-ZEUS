import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'provider_protocol.dart';

class ProviderClient {
  const ProviderClient({this.openClient = http.Client.new});

  final http.Client Function() openClient;
  static const _connectTimeout = Duration(seconds: 20);
  static const _idleTimeout = Duration(seconds: 90);

  Future<List<ModelDescriptor>> listModels(
    ProviderConnection config,
    String? key,
  ) async {
    final client = openClient();
    try {
      final modelPath = config.kind.protocol == ProviderProtocol.ollama
          ? 'api/tags'
          : 'models';
      final result = <ModelDescriptor>[];
      final seenPages = <String>{};
      Map<String, String>? page;
      do {
        final response = await _send(
          client,
          config,
          key,
          'GET',
          modelPath,
          query: page,
        );
        final bytes = await response.stream
            .timeout(_connectTimeout)
            .fold<List<int>>([], (all, chunk) {
              if (all.length + chunk.length > 12 * 1024 * 1024) {
                throw const ProviderException(
                  ProviderErrorCode.invalidResponse,
                );
              }
              return all..addAll(chunk);
            });
        final json = _map(jsonDecode(utf8.decode(bytes)));
        final list = switch (config.kind.protocol) {
          ProviderProtocol.gemini || ProviderProtocol.ollama => json['models'],
          _ => json['data'],
        };
        if (list is! List) {
          throw const ProviderException(ProviderErrorCode.invalidResponse);
        }
        for (final entry in list) {
          final item = _map(entry);
          final id = switch (config.kind.protocol) {
            ProviderProtocol.ollama => item['model'] ?? item['name'],
            ProviderProtocol.gemini => (item['name'] as String?)?.replaceFirst(
              'models/',
              '',
            ),
            _ => item['id'],
          };
          if (id is! String || id.isEmpty) continue;
          if (config.kind.protocol == ProviderProtocol.gemini &&
              item['supportedGenerationMethods'] is List &&
              !(item['supportedGenerationMethods'] as List).contains(
                'generateContent',
              )) {
            continue;
          }
          result.add(
            ModelDescriptor(
              id,
              label:
                  (item['displayName'] ?? item['display_name'] ?? item['name'])
                      as String?,
              contextWindow:
                  (item['inputTokenLimit'] ?? item['context_length']) as int?,
              supportedInputs:
                  (_map(item['architecture'])['input_modalities'] as List?)
                      ?.whereType<String>()
                      .toList() ??
                  const [],
            ),
          );
        }
        final next = switch (config.kind.protocol) {
          ProviderProtocol.gemini => json['nextPageToken'],
          ProviderProtocol.anthropic =>
            json['has_more'] == true ? json['last_id'] : null,
          _ => null,
        };
        if (next is! String ||
            next.isEmpty ||
            seenPages.length >= 20 ||
            !seenPages.add(next)) {
          break;
        }
        page = {
          config.kind.protocol == ProviderProtocol.gemini
                  ? 'pageToken'
                  : 'after_id':
              next,
        };
      } while (true);
      return result;
    } on Object catch (error) {
      throw _normalize(error);
    } finally {
      client.close();
    }
  }

  Stream<ProviderEvent> streamChat(
    ProviderConnection config,
    String? key,
    String model,
    List<ChatInput> inputs, {
    required Future<void> abort,
    int? maxOutputTokens,
  }) async* {
    final client = openClient();
    final protocol = config.kind.protocol;
    final history = inputs.where((m) => m.role != 'system').toList();
    final instructions = inputs
        .where((m) => m.role == 'system')
        .map((m) => m.text)
        .join('\n\n');
    final output = maxOutputTokens ?? 2048;
    final (path, body) = switch (protocol) {
      ProviderProtocol.responses => (
        'responses',
        {
          'model': model,
          'stream': true,
          'input': history.map((m) => m.toJson()).toList(),
          if (instructions.isNotEmpty) 'instructions': instructions,
          if (maxOutputTokens != null) 'max_output_tokens': output,
        },
      ),
      ProviderProtocol.anthropic => (
        'messages',
        {
          'model': model,
          'stream': true,
          'max_tokens': output,
          'messages': history.map((m) => m.toJson()).toList(),
          if (instructions.isNotEmpty) 'system': instructions,
        },
      ),
      ProviderProtocol.gemini => (
        'models/${Uri.encodeComponent(model)}:streamGenerateContent',
        {
          'contents': [
            for (final m in history)
              {
                'role': m.role == 'assistant' ? 'model' : 'user',
                'parts': [
                  {'text': m.text},
                ],
              },
          ],
          if (instructions.isNotEmpty)
            'systemInstruction': {
              'parts': [
                {'text': instructions},
              ],
            },
          if (maxOutputTokens != null)
            'generationConfig': {'maxOutputTokens': output},
        },
      ),
      ProviderProtocol.chatCompletions => (
        'chat/completions',
        {
          'model': model,
          'stream': true,
          'messages': inputs.map((m) => m.toJson()).toList(),
          if (maxOutputTokens != null) 'max_tokens': output,
        },
      ),
      ProviderProtocol.ollama => (
        'api/chat',
        {
          'model': model,
          'stream': true,
          'messages': inputs.map((m) => m.toJson()).toList(),
          if (maxOutputTokens != null) 'options': {'num_predict': output},
        },
      ),
    };
    try {
      final response = await _send(
        client,
        config,
        key,
        'POST',
        path,
        query: protocol == ProviderProtocol.gemini ? {'alt': 'sse'} : null,
        body: body,
        abort: abort,
      );
      final lines = response.stream
          .timeout(_idleTimeout)
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      final frames = protocol == ProviderProtocol.ollama
          ? lines.where((line) => line.trim().isNotEmpty)
          : sseData(lines);
      var finishSeen = false;
      await for (final frame in frames) {
        if (frame == '[DONE]') {
          yield const ProviderEvent.completed();
          return;
        }
        final event = _map(jsonDecode(frame));
        for (final next in _translate(protocol, event)) {
          if (next.type == ProviderEventType.completed) {
            finishSeen = true;
            if (protocol == ProviderProtocol.gemini ||
                protocol == ProviderProtocol.chatCompletions) {
              continue;
            }
            yield next;
            return;
          }
          yield next;
        }
      }
      if (!finishSeen) {
        throw const ProviderException(ProviderErrorCode.interrupted);
      }
      yield const ProviderEvent.completed();
    } on http.RequestAbortedException {
      yield const ProviderEvent.cancelled();
    } on Object catch (error) {
      throw _normalize(error);
    } finally {
      client.close();
    }
  }

  static Stream<String> sseData(Stream<String> lines) async* {
    final data = <String>[];
    await for (final line in lines) {
      if (line.isEmpty) {
        if (data.isNotEmpty) yield data.join('\n');
        data.clear();
      } else if (line.startsWith('data:')) {
        final value = line.substring(5);
        data.add(value.startsWith(' ') ? value.substring(1) : value);
      } else if (line == 'data') {
        data.add('');
      }
    }
    if (data.isNotEmpty) yield data.join('\n');
  }

  Future<http.StreamedResponse> _send(
    http.Client client,
    ProviderConnection config,
    String? key,
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    Future<void>? abort,
  }) async {
    final base = ProviderConnection.parseEndpoint(
      config.kind,
      config.endpoint.toString(),
    );
    if (base.scheme != 'https' && key?.isNotEmpty == true) {
      throw const ProviderException(ProviderErrorCode.rejected);
    }
    final clean = base.toString().replaceFirst(RegExp(r'/+$'), '');
    final endpoint = Uri.parse('$clean/$path').replace(queryParameters: query);
    final request = http.AbortableRequest(method, endpoint, abortTrigger: abort)
      ..followRedirects = false
      ..headers['accept'] = method == 'GET'
          ? 'application/json'
          : 'text/event-stream, application/x-ndjson';
    if (key != null && key.isNotEmpty) {
      switch (config.kind.protocol) {
        case ProviderProtocol.anthropic:
          request.headers['x-api-key'] = key;
        case ProviderProtocol.gemini:
          request.headers['x-goog-api-key'] = key;
        default:
          request.headers['authorization'] = 'Bearer $key';
      }
    }
    if (config.kind.protocol == ProviderProtocol.anthropic) {
      request.headers['anthropic-version'] = '2023-06-01';
    }
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await client.send(request).timeout(_connectTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      unawaited(response.stream.listen((_) {}).cancel());
      final status = response.statusCode;
      final retry = int.tryParse(response.headers['retry-after'] ?? '');
      throw ProviderException(
        switch (status) {
          401 => ProviderErrorCode.unauthorized,
          403 => ProviderErrorCode.forbidden,
          404 => ProviderErrorCode.notFound,
          408 || 504 => ProviderErrorCode.timeout,
          429 => ProviderErrorCode.rateLimited,
          >= 500 => ProviderErrorCode.unavailable,
          _ => ProviderErrorCode.rejected,
        },
        status: status,
        retryAfter: retry != null && retry >= 0
            ? Duration(seconds: retry)
            : null,
      );
    }
    return response;
  }

  static Iterable<ProviderEvent> _translate(
    ProviderProtocol protocol,
    Map<String, dynamic> e,
  ) sync* {
    if (e['error'] != null ||
        e['type'] == 'error' ||
        e['type'] == 'response.failed') {
      throw const ProviderException(ProviderErrorCode.rejected);
    }
    switch (protocol) {
      case ProviderProtocol.responses:
        if (e['type'] == 'response.output_text.delta' && e['delta'] is String) {
          yield ProviderEvent.text(e['delta'] as String);
        } else if (e['type'] == 'response.reasoning_summary_text.delta' &&
            e['delta'] is String) {
          yield ProviderEvent.reasoning(e['delta'] as String);
        } else if (e['type'] == 'response.completed') {
          yield* _usage(_map(e['response'])['usage']);
          yield const ProviderEvent.completed();
        } else if (e['type'] == 'response.incomplete') {
          throw const ProviderException(ProviderErrorCode.interrupted);
        }
      case ProviderProtocol.anthropic:
        final delta = _map(e['delta']);
        if (e['type'] == 'content_block_delta' &&
            delta['type'] == 'text_delta' &&
            delta['text'] is String) {
          yield ProviderEvent.text(delta['text'] as String);
        }
        yield* _usage(e['usage'] ?? _map(e['message'])['usage']);
        if (e['type'] == 'message_stop') yield const ProviderEvent.completed();
      case ProviderProtocol.gemini:
        final candidates = e['candidates'];
        if (candidates is List && candidates.isNotEmpty) {
          final item = _map(candidates.first);
          final parts = _map(item['content'])['parts'];
          if (parts is List) {
            for (final value in parts) {
              final part = _map(value);
              if (part['text'] is String && part['thought'] != true) {
                yield ProviderEvent.text(part['text'] as String);
              }
            }
          }
          if (item['finishReason'] != null) {
            yield const ProviderEvent.completed();
          }
        }
        yield* _usage(e['usageMetadata']);
      case ProviderProtocol.chatCompletions:
        final choices = e['choices'];
        if (choices is List && choices.isNotEmpty) {
          final choice = _map(choices.first);
          final content = _map(choice['delta'])['content'];
          if (content is String) yield ProviderEvent.text(content);
          if (choice['finish_reason'] != null) {
            yield const ProviderEvent.completed();
          }
        }
        yield* _usage(e['usage']);
      case ProviderProtocol.ollama:
        final content = _map(e['message'])['content'];
        if (content is String) yield ProviderEvent.text(content);
        if (e['done'] == true) {
          yield* _usage({
            'input_tokens': e['prompt_eval_count'],
            'output_tokens': e['eval_count'],
          });
          yield const ProviderEvent.completed();
        }
    }
  }

  static Map<String, dynamic> _map(Object? data) =>
      data is Map<String, dynamic> ? data : const {};

  static Iterable<ProviderEvent> _usage(Object? raw) sync* {
    final usage = _map(raw);
    final input =
        usage['input_tokens'] ??
        usage['prompt_tokens'] ??
        usage['promptTokenCount'];
    final output =
        usage['output_tokens'] ??
        usage['completion_tokens'] ??
        usage['candidatesTokenCount'];
    if (input is int || output is int) {
      yield ProviderEvent.usage(
        input is int ? input : null,
        output is int ? output : null,
      );
    }
  }

  static ProviderException _normalize(Object error) => switch (error) {
    ProviderException value => value,
    TimeoutException() => const ProviderException(ProviderErrorCode.timeout),
    FormatException() ||
    TypeError() => const ProviderException(ProviderErrorCode.invalidResponse),
    _ => const ProviderException(ProviderErrorCode.network),
  };
}

enum ProviderEventType { text, reasoning, usage, completed, cancelled }

class ProviderEvent {
  const ProviderEvent._(
    this.type, {
    this.text,
    this.inputTokens,
    this.outputTokens,
  });
  const ProviderEvent.text(String text)
    : this._(ProviderEventType.text, text: text);
  const ProviderEvent.reasoning(String text)
    : this._(ProviderEventType.reasoning, text: text);
  const ProviderEvent.usage(int? inputTokens, int? outputTokens)
    : this._(
        ProviderEventType.usage,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
      );
  const ProviderEvent.completed() : this._(ProviderEventType.completed);
  const ProviderEvent.cancelled() : this._(ProviderEventType.cancelled);

  final ProviderEventType type;
  final String? text;
  final int? inputTokens;
  final int? outputTokens;
}
