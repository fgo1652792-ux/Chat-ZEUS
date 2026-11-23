import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design.dart';
import '../providers/credentials.dart';
import 'brave_search.dart';

class ResearchScreen extends StatefulWidget {
  const ResearchScreen({
    super.key,
    required this.credentials,
    this.client = const BraveSearch(),
  });

  final Credentials credentials;
  final BraveSearch client;

  @override
  State<ResearchScreen> createState() => _ResearchScreenState();
}

class _ResearchScreenState extends State<ResearchScreen> {
  static const _keyId = 'research-brave';
  final _queries = TextEditingController();
  final _key = TextEditingController();
  final _sources = <Uri, SearchSource>{};
  bool _busy = false;
  bool _complete = false;
  int _session = 0;
  String? _status;
  String? _error;

  @override
  void dispose() {
    _session++;
    _key.clear();
    _key.dispose();
    _queries.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final queries = const LineSplitter()
        .convert(_queries.text)
        .map((q) => q.trim())
        .where((q) => q.isNotEmpty)
        .toSet()
        .take(5)
        .toList();
    if (queries.isEmpty || queries.any((q) => q.length > 300)) {
      setState(
        () => _error = localize(
          context,
          'Enter up to five short queries.',
          'أدخل حتى خمسة استعلامات قصيرة.',
        ),
      );
      return;
    }
    final session = ++_session;
    setState(() {
      _busy = true;
      _complete = false;
      _sources.clear();
      _error = null;
      _status = null;
    });
    try {
      final input = _key.text.trim();
      final secret = input.isEmpty
          ? await widget.credentials.read(_keyId)
          : input;
      if (!mounted || session != _session) return;
      if (secret == null || secret.isEmpty) {
        setState(
          () => _error = localize(
            context,
            'Add a Brave Search API key.',
            'أضف مفتاح Brave Search API.',
          ),
        );
        return;
      }
      if (input.isNotEmpty) {
        await widget.credentials.write(_keyId, input);
        if (mounted) _key.clear();
      }
      for (final (index, query) in queries.indexed) {
        if (!mounted || session != _session) return;
        setState(
          () => _status = localize(
            context,
            'Query ${index + 1} of ${queries.length}',
            'الاستعلام ${index + 1} من ${queries.length}',
          ),
        );
        final results = await widget.client.search(secret, query);
        if (!mounted || session != _session) return;
        setState(() {
          for (final item in results) {
            _sources.putIfAbsent(item.url.removeFragment(), () => item);
          }
        });
      }
      if (mounted && session == _session) setState(() => _complete = true);
    } on SearchException catch (e) {
      if (mounted && session == _session) {
        setState(
          () => _error = localize(
            context,
            'Brave Search returned HTTP ${e.status}.',
            'أعاد Brave Search حالة HTTP ${e.status}.',
          ),
        );
      }
    } catch (_) {
      if (mounted && session == _session) {
        setState(
          () => _error = localize(
            context,
            'Could not complete the search.',
            'تعذر إكمال البحث.',
          ),
        );
      }
    } finally {
      if (mounted && session == _session) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    final content = StringBuffer('# Zeus Chat research sources\n\n');
    for (final (index, source) in _sources.values.indexed) {
      content.writeln('${index + 1}. ${source.title}\n   ${source.url}');
      if (source.date != null) content.writeln('   ${source.date}');
      content.writeln('   ${source.summary}\n');
    }
    final region = context.findRenderObject() as RenderBox;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            utf8.encode(content.toString()),
            mimeType: 'text/markdown',
          ),
        ],
        fileNameOverrides: ['ZeusChat-research-sources.md'],
        sharePositionOrigin: region.localToGlobal(Offset.zero) & region.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(localize(context, 'Research', 'البحث'))),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 740),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _key,
              enabled: !_busy,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Brave Search API key',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _queries,
              enabled: !_busy,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: localize(
                  context,
                  'Search queries, one per line',
                  'استعلامات البحث، استعلام في كل سطر',
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              localize(
                context,
                'The queries are sent to Brave Search. Source links open in your browser.',
                'تُرسل الاستعلامات إلى Brave Search. تُفتح روابط المصادر في المتصفح.',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (_busy)
                  OutlinedButton(
                    onPressed: () => setState(() {
                      _session++;
                      _busy = false;
                    }),
                    child: Text(
                      localize(
                        context,
                        'Stop gathering results',
                        'إيقاف جمع النتائج',
                      ),
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => unawaited(_run()),
                    icon: const Icon(Icons.search),
                    label: Text(localize(context, 'Search', 'بحث')),
                  ),
                if (_sources.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => unawaited(_export()),
                    icon: const Icon(Icons.download),
                    label: Text(
                      localize(context, 'Export sources', 'تصدير المصادر'),
                    ),
                  ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          await widget.credentials.delete(_keyId);
                          if (context.mounted) {
                            _key.clear();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  localize(
                                    context,
                                    'Search key removed.',
                                    'حُذف مفتاح البحث.',
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                  child: Text(
                    localize(
                      context,
                      'Remove saved key',
                      'حذف المفتاح المحفوظ',
                    ),
                  ),
                ),
              ],
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_status case final status?) Text(status),
            if (_error case final error?)
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 12),
            if (_complete && _sources.isEmpty)
              Text(
                localize(
                  context,
                  'No sources matched these queries.',
                  'لم تطابق الاستعلامات أي مصادر.',
                ),
              ),
            for (final (index, item) in _sources.values.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: ZeusPane(
                  child: ListTile(
                    leading: Text('[${index + 1}]'),
                    title: Text(item.title),
                    subtitle: Text(
                      [
                        item.url.host,
                        ?item.date,
                        if (item.summary.isNotEmpty) item.summary,
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => unawaited(
                      launchUrl(item.url, mode: LaunchMode.externalApplication),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
