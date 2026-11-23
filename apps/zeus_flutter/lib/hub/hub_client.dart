import 'dart:convert';

import 'package:http/http.dart' as http;

class HubClient {
  HubClient(this.base, {http.Client? transport})
    : _transport = transport ?? http.Client();

  final Uri base;
  final http.Client _transport;
  String? accessToken;
  String? refreshToken;

  static Uri endpoint(String value) {
    final uri = Uri.parse(value.trim());
    final local = const {'127.0.0.1', 'localhost', '::1'}.contains(uri.host);
    if (uri.host.isEmpty ||
        (uri.scheme != 'https' && !(uri.scheme == 'http' && local)) ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Provide an HTTPS Hub URL.');
    }
    return uri;
  }

  Future<void> login(String email, String password, String invite) async {
    final tokens = await request(
      'POST',
      invite.isEmpty ? 'auth/login' : 'auth/register',
      data: {
        'email': email,
        'password': password,
        if (invite.isNotEmpty) 'inviteCode': invite,
      },
      useAuth: false,
    );
    _setTokens(tokens);
  }

  Future<void> restore(String token) async {
    final tokens = await request(
      'POST',
      'auth/refresh',
      data: {'refreshToken': token},
      useAuth: false,
    );
    _setTokens(tokens);
  }

  void _setTokens(Map<String, dynamic> tokens) {
    accessToken = tokens['accessToken'] as String;
    refreshToken = tokens['refreshToken'] as String;
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, Object?>? data,
    bool useAuth = true,
    bool retry = true,
  }) async {
    final endpoint = Uri.parse(
      '${base.toString().replaceFirst(RegExp(r'/+$'), '')}/v1/$path',
    );
    final call = http.Request(method, endpoint)
      ..followRedirects = false
      ..headers['accept'] = 'application/json';
    final token = accessToken;
    if (useAuth && token != null) {
      call.headers['authorization'] = 'Bearer $token';
    }
    if (data != null) {
      call.headers['content-type'] = 'application/json';
      call.body = jsonEncode(data);
    }
    final result = await _transport
        .send(call)
        .timeout(const Duration(seconds: 30));
    if (result.statusCode == 401 && useAuth && retry && refreshToken != null) {
      await result.stream.drain<void>();
      await restore(refreshToken!);
      return request(method, path, data: data, retry: false);
    }
    if (result.statusCode < 200 || result.statusCode >= 300)
      throw HubException(result.statusCode);
    if (result.statusCode == 204) return const {};
    final body = await result.stream
        .timeout(const Duration(seconds: 20))
        .fold<List<int>>([], (all, chunk) {
          if (all.length + chunk.length > 4 * 1024 * 1024)
            throw const FormatException('Hub response is too large.');
          return all..addAll(chunk);
        });
    return jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
  }

  void close() => _transport.close();
}

class HubException implements Exception {
  const HubException(this.status);
  final int status;
}
