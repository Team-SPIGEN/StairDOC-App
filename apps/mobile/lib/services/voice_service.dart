/// Voice service for speech recognition and text-to-speech.
///
/// Handles:
/// - Microphone permission management
/// - Speech-to-text recognition
/// - Text-to-speech feedback
/// - Command processing via API
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/voice_command.dart';
import '../utils/api_endpoints.dart';

/// State of the voice service.
enum VoiceServiceState {
  /// Not initialized.
  uninitialized,

  /// Ready to listen.
  ready,

  /// Currently listening for speech.
  listening,

  /// Processing recognized speech.
  processing,

  /// Speaking feedback.
  speaking,

  /// Error state.
  error,
}

/// Service for voice command recognition and text-to-speech.
class VoiceService {
  VoiceService({Dio? dio})
    : _dio = dio ?? Dio(BaseOptions(baseUrl: ApiEndpoints.baseUrl));

  final Dio _dio;
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  // State
  VoiceServiceState _state = VoiceServiceState.uninitialized;
  bool _isInitialized = false;
  String? _lastError;
  String _currentLocale = 'en-US';
  List<LocaleName> _availableLocales = [];

  // Callbacks
  final _stateController = StreamController<VoiceServiceState>.broadcast();
  final _transcriptController = StreamController<String>.broadcast();
  final _resultController = StreamController<VoiceCommandResult>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  // Settings
  double _confidenceThreshold = 0.5;
  bool _speakFeedback = true;

  // Getters
  VoiceServiceState get state => _state;
  bool get isInitialized => _isInitialized;
  bool get isListening => _state == VoiceServiceState.listening;
  bool get isProcessing => _state == VoiceServiceState.processing;
  bool get isSpeaking => _state == VoiceServiceState.speaking;
  String? get lastError => _lastError;
  String get currentLocale => _currentLocale;
  List<LocaleName> get availableLocales => _availableLocales;
  bool get speakFeedback => _speakFeedback;

  // Streams
  Stream<VoiceServiceState> get stateStream => _stateController.stream;
  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<VoiceCommandResult> get resultStream => _resultController.stream;
  Stream<String> get errorStream => _errorController.stream;

  /// Initialize the voice service.
  ///
  /// Must be called before using speech recognition.
  /// Returns true if initialization succeeded.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Initialize speech recognition
      final hasSpeech = await _speech.initialize(
        onError: _onSpeechError,
        onStatus: _onSpeechStatus,
        debugLogging: kDebugMode,
      );

      if (!hasSpeech) {
        _lastError = 'Speech recognition not available on this device';
        _setState(VoiceServiceState.error);
        return false;
      }

      // Get available locales
      _availableLocales = await _speech.locales();

      // Set default locale to en-US if available
      final hasEnUs = _availableLocales.any((l) => l.localeId == 'en-US');
      if (hasEnUs) {
        _currentLocale = 'en-US';
      } else if (_availableLocales.isNotEmpty) {
        _currentLocale = _availableLocales.first.localeId;
      }

      // Initialize TTS
      await _tts.setLanguage(_currentLocale);
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      // Set TTS completion handler
      _tts.setCompletionHandler(() {
        if (_state == VoiceServiceState.speaking) {
          _setState(VoiceServiceState.ready);
        }
      });

      _isInitialized = true;
      _setState(VoiceServiceState.ready);
      return true;
    } catch (e) {
      _lastError = 'Failed to initialize voice service: $e';
      _errorController.add(_lastError!);
      _setState(VoiceServiceState.error);
      return false;
    }
  }

  /// Start listening for voice commands.
  ///
  /// Returns true if listening started successfully.
  Future<bool> startListening() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    if (_state == VoiceServiceState.listening) {
      return true;
    }

    if (_state == VoiceServiceState.speaking) {
      await _tts.stop();
    }

    try {
      _setState(VoiceServiceState.listening);

      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: _currentLocale,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
        ),
      );

      return true;
    } catch (e) {
      _lastError = 'Failed to start listening: $e';
      _errorController.add(_lastError!);
      _setState(VoiceServiceState.error);
      return false;
    }
  }

  /// Stop listening for voice commands.
  Future<void> stopListening() async {
    if (_state != VoiceServiceState.listening) return;

    await _speech.stop();
    _setState(VoiceServiceState.ready);
  }

  /// Cancel current listening session.
  Future<void> cancelListening() async {
    await _speech.cancel();
    _setState(VoiceServiceState.ready);
  }

  /// Speak text using text-to-speech.
  Future<void> speak(String text) async {
    if (!_speakFeedback) return;

    if (_state == VoiceServiceState.listening) {
      await _speech.stop();
    }

    _setState(VoiceServiceState.speaking);
    await _tts.speak(text);
  }

  /// Stop speaking.
  Future<void> stopSpeaking() async {
    await _tts.stop();
    if (_state == VoiceServiceState.speaking) {
      _setState(VoiceServiceState.ready);
    }
  }

  /// Process a transcript through the backend API.
  Future<VoiceCommandResult?> processTranscript(
    String transcript, {
    double confidence = 1.0,
  }) async {
    if (transcript.isEmpty) return null;

    _setState(VoiceServiceState.processing);

    try {
      final request = VoiceCommandRequest(
        transcript: transcript,
        confidence: confidence,
        locale: _currentLocale,
      );

      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.voiceCommand,
        data: request.toJson(),
      );

      final result = VoiceCommandResult.fromJson(response.data!);
      _resultController.add(result);

      // Speak feedback if enabled
      if (_speakFeedback && result.responseText.isNotEmpty) {
        await speak(result.responseText);
      } else {
        _setState(VoiceServiceState.ready);
      }

      return result;
    } catch (e) {
      _lastError = 'Failed to process command: $e';
      _errorController.add(_lastError!);
      _setState(VoiceServiceState.error);

      // Try to speak error
      if (_speakFeedback) {
        await speak("Sorry, I couldn't process that command.");
      }

      return null;
    }
  }

  /// Get available voice commands from the backend.
  Future<VoiceCapabilities?> getCapabilities() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.voiceCapabilities,
      );
      return VoiceCapabilities.fromJson(response.data!);
    } catch (e) {
      _lastError = 'Failed to get voice capabilities: $e';
      return null;
    }
  }

  /// Set the speech locale.
  Future<void> setLocale(String localeId) async {
    _currentLocale = localeId;
    await _tts.setLanguage(localeId);
  }

  /// Set the confidence threshold for command execution.
  void setConfidenceThreshold(double threshold) {
    _confidenceThreshold = threshold.clamp(0.0, 1.0);
  }

  /// Enable or disable spoken feedback.
  void setSpeakFeedback(bool enabled) {
    _speakFeedback = enabled;
  }

  /// Set TTS speech rate (0.0 to 1.0).
  Future<void> setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate.clamp(0.0, 1.0));
  }

  void _setState(VoiceServiceState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    _transcriptController.add(result.recognizedWords);

    if (result.finalResult && result.recognizedWords.isNotEmpty) {
      final confidence = result.confidence > 0
          ? result.confidence
          : _confidenceThreshold;

      if (confidence >= _confidenceThreshold) {
        processTranscript(result.recognizedWords, confidence: confidence);
      } else {
        _setState(VoiceServiceState.ready);
        if (_speakFeedback) {
          speak("I didn't catch that. Please try again.");
        }
      }
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    _lastError = 'Speech error: ${error.errorMsg}';
    _errorController.add(_lastError!);

    // Don't set error state for "no match" - just return to ready
    if (error.errorMsg != 'error_no_match') {
      _setState(VoiceServiceState.error);
    } else {
      _setState(VoiceServiceState.ready);
    }
  }

  void _onSpeechStatus(String status) {
    if (kDebugMode) {
      print('Voice status: $status');
    }

    // Update state based on speech recognition status
    if (status == 'done' && _state == VoiceServiceState.listening) {
      _setState(VoiceServiceState.ready);
    }
  }

  /// Dispose of resources.
  void dispose() {
    _speech.stop();
    _speech.cancel();
    _tts.stop();
    _stateController.close();
    _transcriptController.close();
    _resultController.close();
    _errorController.close();
  }
}
