/// Voice command models matching backend schemas.
///
/// Defines the data structures for:
/// - Voice command intents
/// - Command requests and results
/// - Text-to-speech feedback
library;

import 'package:equatable/equatable.dart';

/// Recognized voice command intents.
enum VoiceCommandIntent {
  // Navigation
  goToFloor('go_to_floor'),
  goToZone('go_to_zone'),
  goHome('go_home'),
  stop('stop'),

  // Container
  lockContainer('lock_container'),
  unlockContainer('unlock_container'),
  openContainer('open_container'),

  // Delivery
  startDelivery('start_delivery'),
  cancelDelivery('cancel_delivery'),
  checkDeliveryStatus('check_delivery_status'),

  // Status
  checkBattery('check_battery'),
  checkLocation('check_location'),
  checkStatus('check_status'),

  // Emergency
  emergencyStop('emergency_stop'),

  // Help
  help('help'),
  unknown('unknown');

  const VoiceCommandIntent(this.value);
  final String value;

  static VoiceCommandIntent fromString(String value) {
    return VoiceCommandIntent.values.firstWhere(
      (e) => e.value == value,
      orElse: () => VoiceCommandIntent.unknown,
    );
  }

  /// Whether this is a critical/emergency command.
  bool get isCritical =>
      this == emergencyStop || this == stop || this == cancelDelivery;

  /// Whether this is a navigation command.
  bool get isNavigation =>
      this == goToFloor || this == goToZone || this == goHome || this == stop;

  /// Whether this is a container command.
  bool get isContainer =>
      this == lockContainer || this == unlockContainer || this == openContainer;

  /// Whether this is a status query.
  bool get isStatusQuery =>
      this == checkBattery ||
      this == checkLocation ||
      this == checkStatus ||
      this == checkDeliveryStatus;
}

/// Confidence level of command recognition.
enum CommandConfidence {
  high('high'),
  medium('medium'),
  low('low'),
  uncertain('uncertain');

  const CommandConfidence(this.value);
  final String value;

  static CommandConfidence fromString(String value) {
    return CommandConfidence.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CommandConfidence.uncertain,
    );
  }

  /// Whether confidence is sufficient for execution.
  bool get isSufficientForExecution => this == high || this == medium;
}

/// Request to process a voice command.
class VoiceCommandRequest extends Equatable {
  const VoiceCommandRequest({
    required this.transcript,
    this.confidence = 1.0,
    this.locale = 'en-US',
    this.robotId,
  });

  /// Transcribed speech text.
  final String transcript;

  /// Speech recognition confidence (0.0 - 1.0).
  final double confidence;

  /// Locale of the speech.
  final String locale;

  /// Target robot ID.
  final String? robotId;

  Map<String, dynamic> toJson() => {
    'transcript': transcript,
    'confidence': confidence,
    'locale': locale,
    if (robotId != null) 'robot_id': robotId,
  };

  @override
  List<Object?> get props => [transcript, confidence, locale, robotId];
}

/// A parameter extracted from voice command.
class ExtractedParameter extends Equatable {
  const ExtractedParameter({
    required this.name,
    required this.value,
    this.confidence = 1.0,
  });

  final String name;
  final dynamic value;
  final double confidence;

  factory ExtractedParameter.fromJson(Map<String, dynamic> json) {
    return ExtractedParameter(
      name: json['name'] as String,
      value: json['value'],
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }

  /// Get value as integer if possible.
  int? get asInt {
    if (value is int) return value as int;
    if (value is String) return int.tryParse(value as String);
    return null;
  }

  /// Get value as string.
  String get asString => value.toString();

  @override
  List<Object?> get props => [name, value, confidence];
}

/// Result of voice command processing.
class VoiceCommandResult extends Equatable {
  const VoiceCommandResult({
    required this.intent,
    required this.confidence,
    required this.confidenceLevel,
    required this.originalTranscript,
    required this.normalizedTranscript,
    required this.responseText,
    this.parameters = const [],
    this.executed = false,
    this.success = false,
    this.errorMessage,
    this.processingTimeMs = 0,
  });

  final VoiceCommandIntent intent;
  final double confidence;
  final CommandConfidence confidenceLevel;
  final List<ExtractedParameter> parameters;
  final String originalTranscript;
  final String normalizedTranscript;
  final bool executed;
  final bool success;
  final String responseText;
  final String? errorMessage;
  final double processingTimeMs;

  factory VoiceCommandResult.fromJson(Map<String, dynamic> json) {
    return VoiceCommandResult(
      intent: VoiceCommandIntent.fromString(json['intent'] as String),
      confidence: (json['confidence'] as num).toDouble(),
      confidenceLevel: CommandConfidence.fromString(
        json['confidence_level'] as String,
      ),
      parameters:
          (json['parameters'] as List<dynamic>?)
              ?.map(
                (e) => ExtractedParameter.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      originalTranscript: json['original_transcript'] as String,
      normalizedTranscript: json['normalized_transcript'] as String,
      executed: json['executed'] as bool? ?? false,
      success: json['success'] as bool? ?? false,
      responseText: json['response_text'] as String,
      errorMessage: json['error_message'] as String?,
      processingTimeMs: (json['processing_time_ms'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Get first parameter value.
  ExtractedParameter? get firstParameter =>
      parameters.isNotEmpty ? parameters.first : null;

  /// Get floor number if this is a go_to_floor command.
  int? get floorNumber => firstParameter?.asInt;

  /// Get zone name if this is a go_to_zone command.
  String? get zoneName => firstParameter?.asString;

  @override
  List<Object?> get props => [
    intent,
    confidence,
    confidenceLevel,
    parameters,
    originalTranscript,
    normalizedTranscript,
    executed,
    success,
    responseText,
    errorMessage,
    processingTimeMs,
  ];
}

/// Text-to-speech feedback response.
class VoiceFeedback extends Equatable {
  const VoiceFeedback({required this.text, this.ssml, this.priority = 5});

  final String text;
  final String? ssml;
  final int priority;

  factory VoiceFeedback.fromJson(Map<String, dynamic> json) {
    return VoiceFeedback(
      text: json['text'] as String,
      ssml: json['ssml'] as String?,
      priority: json['priority'] as int? ?? 5,
    );
  }

  @override
  List<Object?> get props => [text, ssml, priority];
}

/// Information about a supported voice command.
class SupportedCommand extends Equatable {
  const SupportedCommand({
    required this.intent,
    required this.description,
    required this.examplePhrases,
    this.parameters = const [],
  });

  final VoiceCommandIntent intent;
  final String description;
  final List<String> examplePhrases;
  final List<String> parameters;

  factory SupportedCommand.fromJson(Map<String, dynamic> json) {
    return SupportedCommand(
      intent: VoiceCommandIntent.fromString(json['intent'] as String),
      description: json['description'] as String,
      examplePhrases: (json['example_phrases'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      parameters:
          (json['parameters'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  @override
  List<Object?> get props => [intent, description, examplePhrases, parameters];
}

/// Response listing available voice commands.
class VoiceCapabilities extends Equatable {
  const VoiceCapabilities({
    required this.supportedCommands,
    required this.supportedLocales,
    this.version = '1.0.0',
  });

  final List<SupportedCommand> supportedCommands;
  final List<String> supportedLocales;
  final String version;

  factory VoiceCapabilities.fromJson(Map<String, dynamic> json) {
    return VoiceCapabilities(
      supportedCommands: (json['supported_commands'] as List<dynamic>)
          .map((e) => SupportedCommand.fromJson(e as Map<String, dynamic>))
          .toList(),
      supportedLocales: (json['supported_locales'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      version: json['version'] as String? ?? '1.0.0',
    );
  }

  @override
  List<Object?> get props => [supportedCommands, supportedLocales, version];
}
