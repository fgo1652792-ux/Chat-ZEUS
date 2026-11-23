import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:highlight/highlight.dart' as syntax;
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../design.dart';

class RichMessage extends StatefulWidget {
  const RichMessage(this.source, {super.key});

  final String source;

  @override
  State<RichMessage> createState() => _RichMessageState();
}

class _RichMessageState extends State<RichMessage> {
  late List<_RichBlock> _blocks = _RichBlock.parse(widget.source);

  @override
  void didUpdateWidget(covariant RichMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _blocks = _RichBlock.parse(widget.source);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final markdownStyle = MarkdownStyleSheet.fromTheme(theme)
        .copyWith(p: theme.textTheme.bodyMedium?.copyWith(height: 1.5));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final block in _blocks)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: switch (block) {
              _MarkdownBlock(:final source) => MarkdownBody(
                data: source,
                selectable: true,
                extensionSet: md.ExtensionSet.gitHubFlavored,
                styleSheet: markdownStyle,
                inlineSyntaxes: [_InlineMathSyntax()],
                builders: {'zeus-math': _InlineMathBuilder()},
                imageBuilder: (uri, title, alt) => OutlinedButton.icon(
                  onPressed: _safeLink(uri)
                      ? () => unawaited(_confirmLink(context, uri))
                      : null,
                  icon: const Icon(Icons.image_outlined, size: 17),
                  label: Text(
                    alt?.isNotEmpty == true
                        ? alt!
                        : localize(
                            context,
                            'Open image link',
                            'فتح رابط الصورة',
                          ),
                  ),
                ),
                onTapLink: (_, href, _) {
                  final uri = Uri.tryParse(href ?? '');
                  if (uri != null && _safeLink(uri)) {
                    unawaited(_confirmLink(context, uri));
                  }
                },
              ),
              _FenceBlock() => _fenced(context, block),
            },
          ),
      ],
    );
  }

  static bool _safeLink(Uri uri) =>
      ['http', 'https'].contains(uri.scheme) &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;

  static Future<void> _confirmLink(BuildContext context, Uri uri) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          localize(context, 'Open external link?', 'فتح رابط خارجي؟'),
        ),
        content: SelectableText(
          uri.toString(),
          textDirection: TextDirection.ltr,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localize(context, 'Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(localize(context, 'Open', 'فتح')),
          ),
        ],
      ),
    );
    if (approved == true && context.mounted) {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localize(context, 'Could not open the link.', 'تعذر فتح الرابط.'),
            ),
          ),
        );
      }
    }
  }

  Widget _fenced(BuildContext context, _FenceBlock block) {
    return switch (block.language) {
      'math' || 'latex' => _MathFragment(block.source),
      'mermaid' => _SimpleFlowchart.fromText(block.source) ?? _CodeCard(block),
      'chart' => _BarChart.fromText(block.source) ?? _CodeCard(block),
      _ => _CodeCard(block),
    };
  }
}

sealed class _RichBlock {
  const _RichBlock(this.source);
  final String source;
  static final _fence = RegExp(
    r'^\x60\x60\x60([\w-]*)[ \t]*\r?\n(.*?)^\x60\x60\x60[ \t]*\r?$',
    multiLine: true,
    dotAll: true,
  );

  static List<_RichBlock> parse(String source) {
    final blocks = <_RichBlock>[];
    var cursor = 0;
    for (final match in _fence.allMatches(source)) {
      if (match.start > cursor) {
        final text = source.substring(cursor, match.start).trim();
        if (text.isNotEmpty) blocks.add(_MarkdownBlock(text));
      }
      blocks.add(_FenceBlock(match[2]!.trimRight(), match[1]!.toLowerCase()));
      cursor = match.end;
    }
    final tail = source.substring(cursor).trim();
    if (tail.isNotEmpty) blocks.add(_MarkdownBlock(tail));
    return blocks;
  }
}

final class _MarkdownBlock extends _RichBlock {
  const _MarkdownBlock(super.source);
}

final class _FenceBlock extends _RichBlock {
  const _FenceBlock(super.source, this.language);
  final String language;
}

class _InlineMathSyntax extends md.InlineSyntax {
  _InlineMathSyntax() : super(r'(?<!\$)\$([^$\r\n]+?)\$(?!\$)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('zeus-math', match[1]!));
    return true;
  }
}

class _InlineMathBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? style,
    TextStyle? parentStyle,
  ) => _MathFragment(element.textContent, inline: true);
}

class _MathFragment extends StatelessWidget {
  const _MathFragment(this.source, {this.inline = false});
  final String source;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final rendered = Directionality(
      textDirection: TextDirection.ltr,
      child: Math.tex(
        source,
        mathStyle: inline ? MathStyle.text : MathStyle.display,
        textStyle: Theme.of(context).textTheme.bodyMedium,
        onErrorFallback: (_) => SelectableText(source),
      ),
    );
    return inline
        ? rendered
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: rendered,
          );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard(this.block);
  final _FenceBlock block;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontFamily: 'monospace',
      color: colors.onSurface,
      height: 1.45,
    );
    List<syntax.Node>? nodes;
    if (block.language.isNotEmpty && block.source.length <= 20000) {
      try {
        nodes = syntax.highlight
            .parse(block.source, language: block.language)
            .nodes;
      } catch (_) {
        // Preserve the code when the grammar is unavailable.
      }
    }
    return Material(
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    block.language.isEmpty
                        ? localize(context, 'Code', 'شيفرة')
                        : block.language,
                  ),
                ),
                IconButton(
                  tooltip: localize(context, 'Copy code', 'نسخ الشيفرة'),
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: block.source)),
                ),
              ],
            ),
            Directionality(
              textDirection: TextDirection.ltr,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText.rich(
                  TextSpan(
                    style: style,
                    text: nodes == null ? block.source : null,
                    children: nodes
                        ?.map((node) => _colorize(node, colors))
                        .toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextSpan _colorize(syntax.Node node, ColorScheme colors) => TextSpan(
    text: node.value,
    style: TextStyle(
      color: switch (node.className) {
        'keyword' || 'selector-tag' => colors.primary,
        'string' || 'attribute' => colors.tertiary,
        'number' || 'literal' => colors.secondary,
        'comment' => colors.onSurfaceVariant,
        _ => null,
      },
    ),
    children: node.children?.map((child) => _colorize(child, colors)).toList(),
  );
}

class _SimpleFlowchart extends StatelessWidget {
  const _SimpleFlowchart(this.edges);
  final List<(String, String)> edges;

  static final _edge = RegExp(
    r'^([A-Za-z0-9_]+)(?:\[([^\]\r\n]+)\])?\s*-->\s*([A-Za-z0-9_]+)(?:\[([^\]\r\n]+)\])?\s*;?$',
  );

  static _SimpleFlowchart? fromText(String source) {
    final lines = const LineSplitter().convert(source.trim());
    if (lines.isEmpty ||
        lines.length > 31 ||
        !RegExp(r'^(?:graph|flowchart) (?:LR|RL|TD|TB|BT)$')
            .hasMatch(lines.first)) {
      return null;
    }
    final labels = <String, String>{};
    final edges = <(String, String)>[];
    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final match = _edge.firstMatch(line.trim());
      if (match == null) return null;
      final a = match[1]!;
      final b = match[3]!;
      if (match[2] != null) labels[a] = match[2]!;
      if (match[4] != null) labels[b] = match[4]!;
      edges.add((a, b));
    }
    if (edges.isEmpty) return null;
    return _SimpleFlowchart([
      for (final (a, b) in edges) (labels[a] ?? a, labels[b] ?? b),
    ]);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (from, to) in edges)
        Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(label: Text(from)),
            const Icon(Icons.arrow_forward, size: 17),
            Chip(label: Text(to)),
          ],
        ),
    ],
  );
}

class _BarChart extends StatelessWidget {
  const _BarChart(this.rows);
  final List<(String, num)> rows;

  static _BarChart? fromText(String source) {
    if (source.length > 24000) return null;
    try {
      final json = jsonDecode(source);
      if (json is! List || json.isEmpty || json.length > 32) return null;
      final rows = <(String, num)>[];
      for (final item in json) {
        if (item is! Map || item['label'] is! String || item['value'] is! num)
          return null;
        final label = item['label'] as String;
        final val = item['value'] as num;
        if (label.isEmpty || label.length > 100 || !val.isFinite || val < 0.0) {
          return null;
        }
        rows.add((label, val));
      }
      return _BarChart(rows);
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final max = rows.map((row) => row.$2).reduce((a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$label · $value'),
                ExcludeSemantics(
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0 : value / max,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
