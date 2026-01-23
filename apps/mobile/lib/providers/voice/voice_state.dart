/// Voice command state for BLoC management.
library;

import 'package:equatable/equatable.dart';

import '../../models/voice_command.dart';
import '../../services/voice_service.dart';

/// State for voice command recognition.
class VoiceState extends Equatable {
  const VoiceState({
    this.serviceState = VoiceServiceState.uninitialized,
    this.isInitialized = false,
    this.isListening = false,
    this.isProcessing = false,
    this.isSpeaking = false,
    this.currentTranscript = '',
    this.lastResult,
    this.errorMessage,
    this.capabilities,
    this.speakFeedback = true,
    this.selectedLocale = 'en-US',
    this.availableLocales = const [],
  });

  /// Current state of the voice service.
  final VoiceServiceState serviceState;

  /// Whether the service has been initialized.
  final bool isInitialized;

  /// Whether currently listening for speech.
  final bool isListening;

  /// Whether processing a command.
  final bool isProcessing;

  /// Whether speaking feedback.
  final bool isSpeaking;

  /// Current partial transcript.
  final String currentTranscript;

  /// Last command result.
  final VoiceCommandResult? lastResult;

  /// Current error message.
  final String? errorMessage;

  /// Available voice commands.
  final VoiceCapabilities? capabilities;

  /// Whether to speak feedback.
  final bool speakFeedback;

  /// Selected locale for speech recognition.
  final String selectedLocale;

  /// Available locales.
  final List<String> availableLocales;

  /// Whether the service is ready to listen.
  bool get isReady =>
      isInitialized &&
      !isListening &&
      !isProcessing &&
      !isSpeaking &&
      serviceState != VoiceServiceState.error;

  /// Whether there's an active operation.
  bool get isBusy => isListening || isProcessing || isSpeaking;

  /// Whether last command was successful.
  bool get wasSuccessful => lastResult?.success ?? false;

  /// Whether there's an error.
  bool get hasError => errorMessage != null;

  VoiceState copyWith({
    VoiceServiceState? serviceState,
    bool? isInitialized,
    bool? isListening,
    bool? isProcessing,
    bool? isSpeaking,
    String? currentTranscript,
    VoiceCommandResult? lastResult,
    String? errorMessage,
    bool clearError = false,
    VoiceCapabilities? capabilities,
    bool? speakFeedback,
    String? selectedLocale,
    List<String>? availableLocales,
  }) {
    return VoiceState(
      serviceState: serviceState ?? this.serviceState,
      isInitialized: isInitialized ?? this.isInitialized,
      isListening: isListening ?? this.isListening,
      isProcessing: isProcessing ?? this.isProcessing,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      currentTranscript: currentTranscript ?? this.currentTranscript,
      lastResult: lastResult ?? this.lastResult,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      capabilities: capabilities ?? this.capabilities,
      speakFeedback: speakFeedback ?? this.speakFeedback,
      selectedLocale: selectedLocale ?? this.selectedLocale,
      availableLocales: availableLocales ?? this.availableLocales,
    );
  }

  @override
  List<Object?> get props => [
    serviceState,
    isInitialized,
    isListening,
    isProcessing,
    isSpeaking,
    currentTranscript,
    lastResult,
    errorMessage,
    capabilities,
    speakFeedback,
    selectedLocale,
    availableLocales,
  ];
}
