import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

enum StudioAction { generate, edit, describe }

class ImageApi {
  const ImageApi({this.openClient = http.Client.new});

  final http.Client Function() openClient;

  Future<StudioResult> request({
    required StudioAction action,
    required String key,
    required String model,
    required String prompt,
    Uint8List? image,
  }) async {
    final mime = image == null ? null : imageType(image);
    if (action != StudioAction.generate && mime == null) {
      throw const FormatException('A PNG or JPEG image is required.');
    }
    final client = openClient();
    try {
      final route = switch (action) {
        StudioAction.generate => 'images/generations',
        StudioAction.edit => 'images/edits',
        StudioAction.describe => 'responses',
      };
      final uri = Uri.https('api.openai.com', '/v1/$route');
      final http.BaseRequest call;
      if (action == StudioAction.edit) {
        call = http.MultipartRequest('POST', uri)
          ..fields.addAll({'model': model, 'prompt': prompt})
          ..files.add(
            http.MultipartFile.fromBytes(
              'image',
              image!,
              filename: mime == 'image/png' ? 'image.png' : 'image.jpg',
            ),
          );
      } else {
        call = http.Request('POST', uri)
          ..headers['content-type'] = 'application/json'
          ..body = jsonEncode(
            action == StudioAction.generate
                ? {'model': model, 'prompt': prompt, 'n': 1}
                : {
                    'model': model,
                    'input': [
                      {
                        'role': 'user',
                        'content': [
                          {'type': 'input_text', 'text': prompt},
                          {
                            'type': 'input_image',
                            'image_url':
                                'data:$mime;base64,${base64Encode(image!)}',
                          },
                        ],
                      },
                    ],
                  },
          );
      }
      call.headers['authorization'] = 'Bearer $key';
      call.followRedirects = false;
      final response = await client
          .send(call)
          .timeout(const Duration(minutes: 3));
      if (response.statusCode != 200) {
        throw StudioException(response.statusCode);
      }
      final bytes = BytesBuilder();
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 25),
      )) {
        if (bytes.length + chunk.length > 13000000) {
          throw const FormatException(
            'Image result exceeds the local size limit.',
          );
        }
        bytes.add(chunk);
      }
      final decoded =
          jsonDecode(utf8.decode(bytes.takeBytes())) as Map<String, dynamic>;
      if (action == StudioAction.describe) {
        final output = decoded['output'] as List<dynamic>;
        final text = [
          for (final item in output.whereType<Map<String, dynamic>>())
            for (final part
                in (item['content'] as List<dynamic>? ?? [])
                    .whereType<Map<String, dynamic>>())
              if (part['type'] == 'output_text' && part['text'] is String)
                part['text'] as String,
        ].join('\n').trim();
        if (text.isEmpty) {
          throw const FormatException('The model returned no description.');
        }
        return StudioResult(description: text);
      }
      final data = decoded['data'] as List<dynamic>;
      final imageBytes = base64Decode(
        (data.single as Map<String, dynamic>)['b64_json'] as String,
      );
      if (imageType(imageBytes) == null ||
          imageBytes.length > 8 * 1024 * 1024) {
        throw const FormatException(
          'The returned image format or size is unsupported.',
        );
      }
      return StudioResult(image: imageBytes);
    } finally {
      client.close();
    }
  }

  static String? imageType(Uint8List image) {
    if (image.length < 8) return null;
    if (image[0] == 137 && image[1] == 80 && image[2] == 78 && image[3] == 71) {
      return 'image/png';
    }
    if (image[0] == 255 && image[1] == 216 && image[2] == 255) {
      return 'image/jpeg';
    }
    return null;
  }
}

class StudioResult {
  const StudioResult({this.image, this.description});
  final Uint8List? image;
  final String? description;
}

class StudioException implements Exception {
  const StudioException(this.status);
  final int status;
}
