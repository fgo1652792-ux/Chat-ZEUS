import 'dart:convert';

import 'package:http/http.dart' as http;

class SearchSource {
  const SearchSource({
    required this.url,
    required this.title,
    required this.summary,
    required this.query,
    this.date,
  });

  final Uri url;
  final String title;
  final String summary;
  final String query;
  final String? date;
}

class BraveSearch {
  const BraveSearch({this.openClient = http.Client.new});
  final http.Client Function() openClient;

  Future<List<SearchSource>> search(String key, String query) async {
    final client = openClient();
    try {
      final request =
          http.Request(
              'GET',
              Uri.https('api.search.brave.com', '/res/v1/web/search', {
                'q': query,
                'count': '8',
                'text_decorations': 'false',
                'safesearch': 'moderate',
              }),
            )
            ..headers.addAll({
              'Accept': 'application/json',
              'X-Subscription-Token': key,
            })
            ..followRedirects = false;
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 24));
      if (response.statusCode != 200) {
        throw SearchException(response.statusCode);
      }
      final bytes = await response.stream
          .timeout(const Duration(seconds: 15))
          .fold<List<int>>([], (data, chunk) {
            if (data.length + chunk.length > 2000000) {
              throw const FormatException('Invalid search response size.');
            }
            return data..addAll(chunk);
          });
      final result = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final web = result['web'] as Map<String, dynamic>?;
      final found = web?['results'] as List<dynamic>? ?? [];
      final sources = <SearchSource>[];
      for (final item in found.whereType<Map<String, dynamic>>()) {
        final url = Uri.tryParse(item['url'] as String? ?? '');
        if (url == null ||
            !['https', 'http'].contains(url.scheme) ||
            url.host.isEmpty ||
            url.userInfo.isNotEmpty) {
          continue;
        }
        sources.add(
          SearchSource(
            url: url,
            title: item['title'] as String? ?? url.host,
            summary: item['description'] as String? ?? '',
            query: query,
            date: (item['page_age'] ?? item['age']) as String?,
          ),
        );
      }
      return sources;
    } finally {
      client.close();
    }
  }
}

class SearchException implements Exception {
  const SearchException(this.status);
  final int status;
}
