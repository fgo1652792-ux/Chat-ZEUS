enum ProviderProtocol { responses, anthropic, gemini, chatCompletions, ollama }

enum ProviderKind {
  openai('OpenAI', 'https://api.openai.com/v1', ProviderProtocol.responses),
  anthropic(
    'Anthropic',
    'https://api.anthropic.com/v1',
    ProviderProtocol.anthropic,
  ),
  gemini(
    'Google Gemini',
    'https://generativelanguage.googleapis.com/v1beta',
    ProviderProtocol.gemini,
  ),
  openrouter(
    'OpenRouter',
    'https://openrouter.ai/api/v1',
    ProviderProtocol.chatCompletions,
  ),
  xai('xAI', 'https://api.x.ai/v1', ProviderProtocol.responses),
  deepseek(
    'DeepSeek',
    'https://api.deepseek.com',
    ProviderProtocol.chatCompletions,
  ),
  mistral(
    'Mistral',
    'https://api.mistral.ai/v1',
    ProviderProtocol.chatCompletions,
  ),
  groq(
    'Groq',
    'https://api.groq.com/openai/v1',
    ProviderProtocol.chatCompletions,
  ),
  together(
    'Together AI',
    'https://api.together.xyz/v1',
    ProviderProtocol.chatCompletions,
  ),
  fireworks(
    'Fireworks',
    'https://api.fireworks.ai/inference/v1',
    ProviderProtocol.chatCompletions,
  ),
  cerebras(
    'Cerebras',
    'https://api.cerebras.ai/v1',
    ProviderProtocol.chatCompletions,
  ),
  perplexity(
    'Perplexity',
    'https://api.perplexity.ai',
    ProviderProtocol.chatCompletions,
  ),
  ollama('Ollama', 'http://127.0.0.1:11434', ProviderProtocol.ollama),
  lmStudio(
    'LM Studio',
    'http://127.0.0.1:1234/v1',
    ProviderProtocol.chatCompletions,
  ),
  vllm('vLLM', 'http://127.0.0.1:8000/v1', ProviderProtocol.chatCompletions),
  llamaCpp(
    'llama.cpp',
    'http://127.0.0.1:8080/v1',
    ProviderProtocol.chatCompletions,
  ),
  localAi(
    'LocalAI',
    'http://127.0.0.1:8080/v1',
    ProviderProtocol.chatCompletions,
  ),
  compatible('OpenAI-compatible', '', ProviderProtocol.chatCompletions);

  const ProviderKind(this.label, this.defaultEndpoint, this.protocol);

  final String label;
  final String defaultEndpoint;
  final ProviderProtocol protocol;

  bool get editableEndpoint => switch (this) {
    ollama || lmStudio || vllm || llamaCpp || localAi || compatible => true,
    _ => false,
  };
}

class ProviderConnection {
  const ProviderConnection({
    required this.id,
    required this.kind,
    required this.endpoint,
    required this.label,
    this.manualModel = '',
  });

  final String id;
  final ProviderKind kind;
  final Uri endpoint;
  final String label;
  final String manualModel;

  static Uri parseEndpoint(ProviderKind kind, String input) {
    final uri = Uri.tryParse(
      (kind.editableEndpoint ? input : kind.defaultEndpoint).trim(),
    );
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        (uri.scheme == 'http' &&
            (!kind.editableEndpoint || !_isLocal(uri.host)))) {
      throw const FormatException(
        'Enter an HTTPS endpoint or a local HTTP endpoint.',
      );
    }
    return uri;
  }

  static bool _isLocal(String host) {
    if (host == 'localhost' || host == '::1' || host.endsWith('.local')) {
      return true;
    }
    final parts = host.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((a) => a == null || a < 0 || a > 255)) {
      return false;
    }
    return parts[0] == 10 ||
        parts[0] == 127 ||
        (parts[0] == 192 && parts[1] == 168) ||
        (parts[0] == 172 && parts[1]! >= 16 && parts[1]! <= 31);
  }

  Map<String, Object?> toRow() => {
    'id': id,
    'kind': kind.name,
    'endpoint': endpoint.toString(),
    'label': label,
    'manual_model': manualModel,
  };

  factory ProviderConnection.fromRow(Map<String, Object?> row) {
    final kind = ProviderKind.values.byName(row['kind']! as String);
    return ProviderConnection(
      id: row['id']! as String,
      kind: kind,
      endpoint: parseEndpoint(kind, row['endpoint']! as String),
      label: row['label']! as String,
      manualModel: row['manual_model']! as String,
    );
  }
}

class ModelDescriptor {
  const ModelDescriptor(
    this.id, {
    this.label,
    this.contextWindow,
    this.supportedInputs = const [],
  });

  final String id;
  final String? label;
  final int? contextWindow;
  final List<String> supportedInputs;
}

class ChatInput {
  const ChatInput(this.role, this.text);

  final String role;
  final String text;

  Map<String, String> toJson() => {'role': role, 'content': text};
}

enum ProviderErrorCode {
  unauthorized,
  forbidden,
  notFound,
  rateLimited,
  timeout,
  network,
  invalidResponse,
  rejected,
  unavailable,
  interrupted,
}

class ProviderException implements Exception {
  const ProviderException(this.code, {this.status, this.retryAfter});

  final ProviderErrorCode code;
  final int? status;
  final Duration? retryAfter;

  @override
  String toString() => 'ProviderException(${code.name}, ${status ?? '-'})';
}
