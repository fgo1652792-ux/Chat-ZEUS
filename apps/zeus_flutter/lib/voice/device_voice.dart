import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class DeviceVoice {
  final _speech = SpeechToText();
  final _reader = FlutterTts();
  bool _initialized = false;
  bool _isSpeaking = false;

  static bool get speechSupported =>
      kIsWeb ||
      const {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      }.contains(defaultTargetPlatform);

  static bool get readingSupported => speechSupported;

  Future<bool> startDictation({
    required String language,
    required ValueChanged<String> recognized,
    required ValueChanged<bool> onListening,
    required VoidCallback onError,
  }) async {
    if (!speechSupported) return false;
    if (!_initialized) {
      _initialized = await _speech.initialize(
        onError: (_) {
          onListening(false);
          onError();
        },
        onStatus: (status) =>
            onListening(status == SpeechToText.listeningStatus),
      );
    }
    if (!_initialized) return false;
    final locales = await _speech.locales();
    final id = locales
        .where(
          (locale) =>
              locale.localeId.toLowerCase().split(RegExp('[-_]')).first ==
              language,
        )
        .firstOrNull
        ?.localeId;
    if (id == null) return false;

    await _speech.listen(
      onResult: (result) => recognized(result.recognizedWords),
      listenOptions: SpeechListenOptions(
        localeId: id,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
    return true;
  }

  Future<void> stopDictation() async {
    if (_initialized) await _speech.stop();
  }

  Future<bool> readOrStop(String text, String language) async {
    if (!readingSupported) return false;
    if (_isSpeaking) {
      await _reader.stop();
      _isSpeaking = false;
      return true;
    }
    final voiceLanguage = language == 'ar' ? 'ar-SA' : 'en-US';
    if (await _reader.isLanguageAvailable(voiceLanguage) != true) return false;
    _reader.setCompletionHandler(() => _isSpeaking = false);
    _reader.setCancelHandler(() => _isSpeaking = false);
    _reader.setErrorHandler((_) => _isSpeaking = false);
    await _reader.setLanguage(voiceLanguage);
    await _reader.setSpeechRate(.52);
    _isSpeaking = true;
    final result = await _reader.speak(text);
    if (result != 1) _isSpeaking = false;
    return result == 1;
  }

  Future<void> stop() async {
    if (_initialized) await _speech.cancel();
    if (_isSpeaking) await _reader.stop();
    _isSpeaking = false;
  }
}
