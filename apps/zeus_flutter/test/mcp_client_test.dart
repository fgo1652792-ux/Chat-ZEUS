import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zeus_chat/tools/mcp_client.dart';

void main() {
  test('MCP negotiates a session and invokes only the selected tool', () async {
    final methods = <String>[];
    final client = McpClient(
      Uri.parse('https://tool.example/mcp'),
      transport: MockClient((request) async {
        final input = jsonDecode(request.body) as Map<String, dynamic>;
        final method = input['method'] as String;
        methods.add(method);
        if (method != 'initialize') {
          expect(request.headers['mcp-session-id'], 'fixture-session');
        }
        if (method == 'notifications/initialized') {
          return http.Response('', 202);
        }
        final result = switch (method) {
          'initialize' => {'protocolVersion': '2025-06-18'},
          'tools/list' => {
            'tools': [
              {
                'name': 'calculate',
                'inputSchema': {
                  'type': 'object',
                  'required': ['number'],
                },
              },
            ],
          },
          'tools/call' => {
            'content': [
              {'type': 'text', 'text': '42'},
            ],
          },
          _ => throw StateError('Unexpected method'),
        };
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': input['id'], 'result': result}),
          200,
          headers: {
            'mcp-session-id': 'fixture-session',
            'content-type': 'application/json',
          },
        );
      }),
    );
    addTearDown(client.close);
    final tool = (await client.initialize()).single;
    expect(() => client.run(tool, {}), throwsFormatException);
    expect(methods, ['initialize', 'notifications/initialized', 'tools/list']);
    expect((await client.run(tool, {'number': 21}))['content'], [
      {'type': 'text', 'text': '42'},
    ]);
    expect(methods.last, 'tools/call');
  });
}
