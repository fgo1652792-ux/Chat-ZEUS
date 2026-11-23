import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zeus_chat/studio/image_api.dart';

void main() {
  test('OpenAI image generation submits a model and decodes image bytes', () async {
    const png =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aWxoAAAAASUVORK5CYII=';
    final api = ImageApi(
      openClient: () => MockClient((request) async {
        expect(
          request.url.toString(),
          'https://api.openai.com/v1/images/generations',
        );
        expect(request.headers['authorization'], 'Bearer fixture');
        expect(jsonDecode(request.body), {
          'model': 'gpt-image-1',
          'prompt': 'Fixture',
          'n': 1,
        });
        return http.Response(
          jsonEncode({
            'data': [
              {'b64_json': png},
            ],
          }),
          200,
        );
      }),
    );
    final result = await api.request(
      action: StudioAction.generate,
      key: 'fixture',
      model: 'gpt-image-1',
      prompt: 'Fixture',
    );
    expect(ImageApi.imageType(result.image!), 'image/png');
  });
}
