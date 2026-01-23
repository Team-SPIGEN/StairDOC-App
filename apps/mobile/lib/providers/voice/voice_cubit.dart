/// Voice command BLoC for managing speech recognition state.
library;

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/voice_service.dart';
import 'voice_state.dart';

/// Cubit for managing voice command state.
class VoiceCubit extends Cubit<VoiceState> {
  VoiceCubit({VoiceService? voiceService})
    : _voiceService = voiceService ?? VoiceService(),
      super(const VoiceState());

  final VoiceService _voiceService;
  StreamSubscription<VoiceServiceState>? _stateSubscription;
  StreamSubscription<String>? _transcriptSubscription;
  StreamSubscription<dynamic>? _resultSubscription;
  StreamSubscription<String>? _errorSubscription;

  /// Initialize the voice service.
  Future<bool> initialize() async {
    if (state.isInitialized) return true;

    final success = await _voiceService.initialize();

    if (success) {
      _setupSubscriptions();

      // Get available locales
      final locales = _voiceService.availableLocales
          .map((l) => l.localeId)
          .toList();

      emit(
        state.copyWith(
          isInitialized: true,
          serviceState: _voiceService.state,
          selectedLocale: _voiceService.currentLocale,
          availableLocales: locales,
          clearError: true,
        ),
      );

      // Load capabilities
      await loadCapabilities();
    } else {
      emit(
        state.copyWith(
          errorMessage: _voiceService.lastError ?? 'Failed to initialize',
          serviceState: VoiceServiceState.error,
        ),
      );
    }

    return success;
  }

  void _setupSubscriptions() {
    _stateSubscription = _voiceService.stateStream.listen((serviceState) {
      emit(
        state.copyWith(
          serviceState: serviceState,
          isListening: serviceState == VoiceServiceState.listening,
          isProcessing: serviceState == VoiceServiceState.processing,
          isSpeaking: serviceState == VoiceServiceState.speaking,
        ),
      );
    });

    _transcriptSubscription = _voiceService.transcriptStream.listen((
      transcript,
    ) {
      emit(state.copyWith(currentTranscript: transcript));
    });

    _resultSubscription = _voiceService.resultStream.listen((result) {
      emit(state.copyWith(lastResult: result, currentTranscript: ''));
    });

    _errorSubscription = _voiceService.errorStream.listen((error) {
      emit(state.copyWith(errorMessage: error));
    });
  }

  /// Start listening for voice commands.
  Future<void> startListening() async {
    if (state.isBusy) return;

    emit(state.copyWith(currentTranscript: '', clearError: true));

    final success = await _voiceService.startListening();
    if (!success) {
      emit(
        state.copyWith(
          errorMessage: _voiceService.lastError ?? 'Failed to start listening',
        ),
      );
    }
  }

  /// Stop listening for voice commands.
  Future<void> stopListening() async {
    await _voiceService.stopListening();
    emit(state.copyWith(isListening: false));
  }

  /// Cancel current listening session.
  Future<void> cancelListening() async {
    await _voiceService.cancelListening();
    emit(state.copyWith(isListening: false, currentTranscript: ''));
  }

  /// Toggle listening state.
  Future<void> toggleListening() async {
    if (state.isListening) {
      await stopListening();
    } else {
      await startListening();
    }
  }

  /// Process a manual text command.
  Future<void> processText(String text) async {
    if (text.isEmpty || state.isProcessing) return;

    emit(
      state.copyWith(
        isProcessing: true,
        currentTranscript: text,
        clearError: true,
      ),
    );

    await _voiceService.processTranscript(text);
  }

  /// Speak text using TTS.
  Future<void> speak(String text) async {
    await _voiceService.speak(text);
  }

  /// Stop speaking.
  Future<void> stopSpeaking() async {
    await _voiceService.stopSpeaking();
  }

  /// Load voice capabilities from backend.
  Future<void> loadCapabilities() async {
    final capabilities = await _voiceService.getCapabilities();
    if (capabilities != null) {
      emit(state.copyWith(capabilities: capabilities));
    }
  }

  /// Set the speech locale.
  Future<void> setLocale(String localeId) async {
    await _voiceService.setLocale(localeId);
    emit(state.copyWith(selectedLocale: localeId));
  }

  /// Enable or disable spoken feedback.
  void setSpeakFeedback(bool enabled) {
    _voiceService.setSpeakFeedback(enabled);
    emit(state.copyWith(speakFeedback: enabled));
  }

  /// Clear the last error.
  void clearError() {
    emit(state.copyWith(clearError: true));
  }

  /// Clear the last result.
  void clearResult() {
    emit(
      VoiceState(
        serviceState: state.serviceState,
        isInitialized: state.isInitialized,
        speakFeedback: state.speakFeedback,
        selectedLocale: state.selectedLocale,
        availableLocales: state.availableLocales,
        capabilities: state.capabilities,
      ),
    );
  }

  @override
  Future<void> close() {
    _stateSubscription?.cancel();
    _transcriptSubscription?.cancel();
    _resultSubscription?.cancel();
    _errorSubscription?.cancel();
    _voiceService.dispose();
    return super.close();
  }
}
