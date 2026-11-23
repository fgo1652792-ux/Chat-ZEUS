import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zeus_chat/research/brave_search.dart';

void main() {
  test('search returns provider URLs and skips unsupported schemes', () async {
    final search = BraveSearch(
      openClient: () => MockClient((request) async {
        expect(request.url.queryParameters['q'], 'مصادر');
        expect(request.headers['x-subscription-token'], 'fixture');
        return http.Response(
          jsonEncode({
            'web': {
              'results': [
                {
                  'url': 'https://example.test/article',
                  'title': 'Source',
                  'description': 'Excerpt',
                },
                {'url': 'javascript:alert(1)', 'title': 'Invalid'},
              ],
            },
          }),
          200,
        );
      }),
    );
    final sources = await search.search('fixture', 'مصادر');
    expect(sources.single.url.toString(), 'https://example.test/article');
    expect(sources.single.query, 'مصادر');
  });
}
