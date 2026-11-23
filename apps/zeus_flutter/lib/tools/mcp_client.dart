import 'dart:convert';

import 'package:http/http.dart' as http;

import '../providers/provider_client.dart';

class McpTool {
  const McpTool(this.name, this.description, this.inputSchema);
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
}

class McpClient {
  McpClient(this.endpoint, {this.bearer, http.Client? transport})
    : _transport = transport ?? http.Client();

  final Uri endpoint;
  final String? bearer;
  final http.Client _transport;
  String? _session;
  String? _version;
  int _id = 0;

  static Uri parseEndpoint(String text) {
    final uri = Uri.parse(text.trim());
    final local = const {'127.0.0.1', 'localhost', '::1'}.contains(uri.host);
    if (uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.scheme != 'https' && !(uri.scheme == 'http' && local))) {
      throw const FormatException(
        'MCP requires an HTTPS endpoint or a local loopback address.',
      );
    }
    return uri;
  }

  Future<List<McpTool>> initialize() async {
    final result = await _send('initialize', {
      'protocolVersion': '2025-11-25',
      'capabilities': {},
      'clientInfo': {'name': 'Zeus Chat', 'version': '0.1.0'},
    });
    _version = result['protocolVersion'] as String;
    if (!const {'2025-11-25', '2025-06-18', '2025-03-26'}.contains(_version)) {
      throw const FormatException('Unsupported MCP version.');
    }
    await _send('notifications/initialized', const {}, notify: true);
    final tools = <McpTool>[];
    final visited = <String>{};
    String? cursor;
    do {
      final results = await _send('tools/list', {'cursor': ?cursor});
      for (final item
          in (results['tools'] as List).whereType<Map<String, dynamic>>()) {
        tools.add(
          McpTool(
            item['name'] as String,
            item['description'] as String? ?? '',
            item['inputSchema'] as Map<String, dynamic>,
          ),
        );
      }
      cursor = results['nextCursor'] as String?;
    } while (cursor != null && visited.length < 10 && visited.add(cursor));
    return tools;
  }

  Future<Map<String, dynamic>> run(
    McpTool tool,
    Map<String, dynamic> arguments,
  ) {
    final schema = tool.inputSchema;
    final requiredKeys =
        (schema['required'] as List?)?.whereType<String>() ?? [];
    final properties = schema['properties'];
    if (requiredKeys.any((name) => !arguments.containsKey(name)) ||
        (schema['additionalProperties'] == false &&
            properties is Map &&
            arguments.keys.any((name) => !properties.containsKey(name)))) {
      throw const FormatException('Arguments do not match the tool schema.');
    }
    return _send('tools/call', {'name': tool.name, 'arguments': arguments});
  }

  Future<Map<String, dynamic>> _send(
    String method,
    Map<String, Object?> params, {
    bool notify = false,
  }) async {
    if (endpoint.scheme != 'https' && bearer?.isNotEmpty == true) {
      throw const FormatException('Use HTTPS to send an authorization token.');
    }
    final id = ++_id;
    final request = http.Request('POST', endpoint)
      ..followRedirects = false
      ..headers.addAll({
        'content-type': 'application/json',
        'accept': 'application/json, text/event-stream',
        if (bearer?.isNotEmpty == true) 'authorization': 'Bearer $bearer',
        'mcp-session-id': ?_session,
        'mcp-protocol-version': ?_version,
      })
      ..body = jsonEncode({
        'jsonrpc': '2.0',
        if (!notify) 'id': id,
        'method': method,
        'params': params,
      });
    final response = await _transport
        .send(request)
        .timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw McpException(response.statusCode);
    }
    _session = response.headers['mcp-session-id'] ?? _session;
    if (notify) {
      await response.stream.drain<void>().timeout(const Duration(seconds: 12));
      return {};
    }
    final input = _bounded(
      response.stream.timeout(const Duration(seconds: 25)),
    );
    final isStream =
        response.headers['content-type']?.startsWith('text/event-stream') ??
        false;
    final values = isStream
        ? ProviderClient.sseData(
            input.transform(utf8.decoder).transform(const LineSplitter()),
          )
        : Stream.fromFuture(input.transform(utf8.decoder).join());
    await for (final value in values) {
      final message = jsonDecode(value);
      if (message is! Map<String, dynamic> || message['id'] != id) continue;
      if (message['error'] != null) throw const McpException(200);
      return message['result'] as Map<String, dynamic>;
    }
    throw const FormatException('The MCP response did not contain a result.');
  }

  Stream<List<int>> _bounded(Stream<List<int>> input) async* {
    var length = 0;
    await for (final segment in input) {
      length += segment.length;
      if (length > 1024 * 1024) {
        throw const FormatException('MCP result exceeded the response limit.');
      }
      yield segment;
    }
  }

  void close() => _transport.close();
}

class McpException implements Exception {
  const McpException(this.status);
  final int status;
}
