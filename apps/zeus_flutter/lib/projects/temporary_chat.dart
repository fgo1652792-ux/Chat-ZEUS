import 'dart:async';

import 'package:flutter/material.dart';

import '../chat/chat_repository.dart';
import '../chat/chat_runtime.dart';
import '../chat/chat_workspace.dart';
import '../data/local_store.dart';
import '../design.dart';
import '../providers/provider_repository.dart';

class TemporaryChat extends StatefulWidget {
  const TemporaryChat({super.key, required this.providers});

  final ProviderRepository providers;

  @override
  State<TemporaryChat> createState() => _TemporaryChatState();
}

class _TemporaryChatState extends State<TemporaryChat> {
  late final Future<ChatRuntime> _runtime = _start();
  LocalStore? _store;
  ChatRuntime? _current;

  Future<ChatRuntime> _start() async {
    final store = await LocalStore.open(name: ':memory:');
    if (!mounted) {
      await store.close();
      throw StateError('Temporary chat closed.');
    }
    _store = store;
    return _current = ChatRuntime(ChatRepository(store), widget.providers);
  }

  @override
  void dispose() {
    _current?.dispose();
    unawaited(_store?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(localize(context, 'Temporary chat', 'محادثة مؤقتة')),
    ),
    body: FutureBuilder(
      future: _runtime,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              localize(
                context,
                'Could not start a temporary session.',
                'تعذر بدء الجلسة المؤقتة.',
              ),
            ),
          );
        }
        final runtime = snapshot.data;
        if (runtime == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                localize(
                  context,
                  'This session stays out of the local history. Messages go to the provider you choose.',
                  'هذه الجلسة خارج السجل المحلي. تُرسل الرسائل إلى المزوّد الذي تختاره.',
                ),
              ),
            ),
            Expanded(
              child: ChatWorkspace(
                runtime: runtime,
                onProviders: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      localize(
                        context,
                        'Add a connection on the Providers screen.',
                        'أضف اتصالًا في شاشة المزوّدين.',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
