import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Turns spoken English into cup commands.
///   "stop", "off", "turn off", "halt"      -> STOP
///   "fill", "fill up", "fill it"           -> FILL
///   "on", "start", "resume", "turn on"     -> ON
class VoiceService extends ChangeNotifier {
  final SpeechToText _stt = SpeechToText();
  final void Function(String command, String heard) onCommand;

  VoiceService({required this.onCommand});

  bool available = false;
  bool listening = false;
  bool handsFree = false; // keep listening again after each phrase
  String heard = '';
  String? error;

  bool _firedThisSession = false;
  Timer? _restart;

  static const _stopWords = {'stop', 'off', 'halt', 'enough', 'pause'};
  static const _fillWords = {'fill', 'refill'};
  static const _onWords = {'on', 'start', 'resume'};

  /// Returns STOP / FILL / ON, or null if no command word was heard.
  /// STOP is checked first so "don't start, stop" always stops.
  static String? parse(String text) {
    final words = text.toLowerCase().split(RegExp(r'[^a-z]+')).where((w) => w.isNotEmpty).toSet();
    if (words.any(_stopWords.contains)) return 'STOP';
    if (words.any(_fillWords.contains)) return 'FILL';
    if (words.any(_onWords.contains)) return 'ON';
    return null;
  }

  Future<bool> init() async {
    if (available) return true;
    available = await _stt.initialize(onStatus: _onStatus, onError: _onError);
    if (!available) error = 'Speech recognition is not available (check microphone permission).';
    notifyListeners();
    return available;
  }

  Future<void> start() async {
    if (!await init()) return;
    _restart?.cancel();
    _firedThisSession = false;
    heard = '';
    error = null;
    listening = true;
    notifyListeners();
    await _stt.listen(
      onResult: _onResult,
      localeId: 'en_US',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      listenOptions: SpeechListenOptions(
        partialResults: true, // react to "stop" as soon as it is heard
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      ),
    );
  }

  Future<void> stop() async {
    _restart?.cancel();
    handsFree = false;
    await _stt.stop();
    listening = false;
    notifyListeners();
  }

  void setHandsFree(bool on) {
    handsFree = on;
    notifyListeners();
    if (on && !listening) start();
    if (!on) stop();
  }

  void _onResult(SpeechRecognitionResult r) {
    heard = r.recognizedWords;
    notifyListeners();
    if (_firedThisSession) return;
    final cmd = parse(heard);
    if (cmd != null) {
      _firedThisSession = true;
      onCommand(cmd, heard);
      _stt.stop(); // end this phrase; hands-free mode restarts
    }
  }

  void _onStatus(String s) {
    if (s == 'notListening' || s == 'done') {
      listening = false;
      notifyListeners();
      if (handsFree) {
        _restart?.cancel();
        _restart = Timer(const Duration(milliseconds: 600), () {
          if (handsFree && !_stt.isListening) start();
        });
      }
    }
  }

  void _onError(SpeechRecognitionError e) {
    // "no match" / "speech timeout" are normal when nobody speaks
    if (e.errorMsg != 'error_no_match' && e.errorMsg != 'error_speech_timeout') {
      error = e.errorMsg;
    }
    listening = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _restart?.cancel();
    _stt.cancel();
    super.dispose();
  }
}
