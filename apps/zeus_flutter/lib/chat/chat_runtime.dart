import 'dart:async';

import 'package:flutter/foundation.dart';

import '../providers/provider_client.dart';
import '../providers/provider_protocol.dart';
import '../providers/provider_repository.dart';
import 'chat_repository.dart';

class ChatRuntime extends ChangeNotifier {
  ChatRuntime(
    this.repository,
    this.providers, {
    this.client = const ProviderClient(),
  });

  final ChatRepository repository;
  final ProviderRepository providers;
  final ProviderClient client;
  final _active = <String, ActiveResponse>{};
  bool _disposed = false;

  ActiveResponse? active(String id) => _active[id];

  void cancel(String id) => _active[id]?.cancel();

  Future<void> send(
    ChatThread thread,
    ProviderConnection provider,
    String model,
    String? prompt, {
    int? maxOutputTokens,
  }) async {
    if (_active.containsKey(thread.id) || prompt?.trim().isEmpty == true) {
      return;
    }
    final response = ActiveResponse();
    _active[thread.id] = response;
    _notify();

    ChatMessage? assistant;
    var status = MessageState.interrupted;
    String? error;
    var lastSave = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      final previous = await repository.messages(thread.id);
      final inputs = [
        for (final message in previous)
          if (message.state == MessageState.completed)
            ChatInput(message.role, message.text),
        if (prompt != null) ChatInput('user', prompt.trim()),
      ];
      if (inputs.isEmpty) return;
      assistant = await repository.beginTurn(
        thread.id,
        prompt?.trim(),
        provider.id,
        model,
      );
      response.messageId = assistant.id;
      response.prompt = prompt?.trim();
      _notify();

      final key = await providers.credentials.read(provider.id);
      await for (final event in client.streamChat(
        provider,
        key,
        model,
        inputs,
        abort: response.abort.future,
        maxOutputTokens: maxOutputTokens,
      )) {
        if (response.abort.isCompleted) {
          status = MessageState.cancelled;
          break;
        }
        switch (event.type) {
          case ProviderEventType.text:
            response._text.write(event.text!);
            _notify();
            final now = DateTime.now();
            if (now.difference(lastSave) >= const Duration(milliseconds: 250)) {
              await repository.saveResponse(
                assistant.id,
                response.text,
                MessageState.streaming,
              );
              lastSave = now;
            }
          case ProviderEventType.reasoning:
            response._summary.write(event.text!);
            _notify();
          case ProviderEventType.usage:
            response.inputTokens = event.inputTokens ?? response.inputTokens;
            response.outputTokens = event.outputTokens ?? response.outputTokens;
          case ProviderEventType.completed:
            status = MessageState.completed;
          case ProviderEventType.cancelled:
            status = MessageState.cancelled;
        }
      }
    } on ProviderException catch (failure) {
      status = failure.code == ProviderErrorCode.interrupted
          ? MessageState.interrupted
          : MessageState.failed;
      error = failure.code.name;
    } catch (_) {
      status = MessageState.failed;
      error = ProviderErrorCode.network.name;
      if (assistant == null) rethrow;
    } finally {
      try {
        if (assistant != null) {
          await repository.saveResponse(
            assistant.id,
            response.text,
            response.abort.isCompleted ? MessageState.cancelled : status,
            error: error,
            inputTokens: response.inputTokens,
            outputTokens: response.outputTokens,
          );
        }
      } finally {
        _active.remove(thread.id);
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final response in _active.values) {
      response.cancel();
    }
    super.dispose();
  }
}

class ActiveResponse {
  final abort = Completer<void>();
  final _text = StringBuffer();
  final _summary = StringBuffer();
  String? messageId;
  String? prompt;
  int? inputTokens;
  int? outputTokens;
  String get text => _text.toString();
  String get summary => _summary.toString();

  void cancel() {
    if (!abort.isCompleted) abort.complete();
  }
}
