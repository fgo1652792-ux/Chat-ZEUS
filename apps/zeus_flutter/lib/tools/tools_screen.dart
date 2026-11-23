import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../design.dart';
import 'mcp_client.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  final _endpoint = TextEditingController();
  final _token = TextEditingController();
  final _form = TextEditingController(text: '{}');
  final _events = <String>[];
  List<McpTool> _tools = [];
  McpTool? _selection;
  McpClient? _connection;
  bool _busy = false;
  String? _result;
  String? _error;

  @override
  void dispose() {
    _connection?.close();
    _endpoint.dispose();
    _token.clear();
    _token.dispose();
    _form.dispose();
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() work) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work();
    } on FormatException {
      if (mounted)
        setState(
          () => _error = localize(
            context,
            'Check the URL or tool arguments.',
            'تحقق من العنوان أو معاملات الأداة.',
          ),
        );
    } on McpException catch (failure) {
      if (mounted) {
        setState(
          () => _error = localize(
            context,
            'The MCP server rejected the request (${failure.status}).',
            'رفض خادم MCP الطلب (${failure.status}).',
          ),
        );
      }
    } catch (_) {
      if (mounted)
        setState(
          () => _error = localize(
            context,
            'Could not contact the MCP server.',
            'تعذر الاتصال بخادم MCP.',
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() async {
    final endpoint = McpClient.parseEndpoint(_endpoint.text);
    final client = McpClient(endpoint, bearer: _token.text.trim());
    if (mounted)
      setState(() {
        _selection = null;
        _tools = [];
        _result = null;
      });
    _connection?.close();
    _connection = client;
    final tools = await client.initialize();
    if (mounted) {
      setState(() {
        _tools = tools;
        _token.clear();
        _events.add(
          localize(
            context,
            'Connected to ${endpoint.host}',
            'تم الاتصال بـ ${endpoint.host}',
          ),
        );
      });
    }
  }

  Future<void> _approve() async {
    final tool = _selection!;
    final connection = _connection!;
    final input = jsonDecode(_form.text);
    if (input is! Map<String, dynamic> || _form.text.length > 30000) {
      setState(
        () => _error = localize(
          context,
          'Enter a JSON object up to 30,000 characters.',
          'أدخل كائن JSON حتى 30,000 حرف.',
        ),
      );
      return;
    }
    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localize(context, 'Run this tool?', 'تشغيل هذه الأداة؟')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${tool.name} · ${connection.endpoint.host}'),
              SelectableText(
                const JsonEncoder.withIndent('  ').convert(input),
                textDirection: TextDirection.ltr,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localize(context, 'Deny', 'رفض')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(localize(context, 'Run tool', 'تشغيل الأداة')),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (allowed != true) {
      setState(
        () => _events.add(
          localize(context, 'Denied ${tool.name}', 'رُفض تشغيل ${tool.name}'),
        ),
      );
      return;
    }
    setState(
      () => _events.add(
        localize(context, 'Running ${tool.name}', 'جارٍ تشغيل ${tool.name}'),
      ),
    );
    final response = await connection.run(tool, input);
    if (mounted) {
      setState(() {
        _result = const JsonEncoder.withIndent('  ').convert(response);
        _events.add(
          response['isError'] == true
              ? localize(context, 'Tool returned an error', 'أعادت الأداة خطأ')
              : localize(context, 'Tool completed', 'اكتمل تشغيل الأداة'),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(localize(context, 'MCP tools', 'أدوات MCP'))),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _endpoint,
              enabled: !_busy,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'MCP Streamable HTTP URL',
              ),
            ),
            TextField(
              controller: _token,
              enabled: !_busy,
              obscureText: true,
              decoration: InputDecoration(
                labelText: localize(
                  context,
                  'Optional session token',
                  'رمز جلسة اختياري',
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _busy ? null : () => _perform(_connect),
              child: Text(
                localize(
                  context,
                  'Connect and list tools',
                  'اتصل واعرض الأدوات',
                ),
              ),
            ),
            if (_tools.isNotEmpty)
              DropdownButton<McpTool>(
                value: _selection,
                isExpanded: true,
                hint: Text(localize(context, 'Choose a tool', 'اختر أداة')),
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        _selection = value;
                        _form.text = '{}';
                      }),
                items: [
                  for (final tool in _tools)
                    DropdownMenuItem(value: tool, child: Text(tool.name)),
                ],
              ),
            if (_selection case final selected?) ...[
              if (selected.description.isNotEmpty) Text(selected.description),
              ExpansionTile(
                title: Text(localize(context, 'Input schema', 'مخطط الإدخال')),
                children: [
                  SelectableText(
                    const JsonEncoder.withIndent('  ')
                        .convert(selected.inputSchema),
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ),
              TextField(
                controller: _form,
                enabled: !_busy,
                maxLines: 8,
                minLines: 3,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: localize(
                    context,
                    'Arguments (JSON)',
                    'المعاملات (JSON)',
                  ),
                ),
              ),
              FilledButton(
                onPressed: _busy ? null : () => _perform(_approve),
                child: Text(
                  localize(context, 'Review tool run', 'مراجعة تشغيل الأداة'),
                ),
              ),
            ],
            if (_busy) const LinearProgressIndicator(),
            if (_error case final error?)
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            for (final event in _events.reversed.take(10))
              ListTile(dense: true, title: Text(event)),
            if (_result case final result?)
              SelectableText(result, textDirection: TextDirection.ltr),
          ],
        ),
      ),
    ),
  );
}
