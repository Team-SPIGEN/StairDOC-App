"""Voice command processing service with intent recognition."""

import re
import time
from typing import Any

from ..schemas.voice import (
    CommandConfidence,
    ExtractedParameter,
    SupportedCommand,
    VoiceCapabilitiesResponse,
    VoiceCommandIntent,
    VoiceCommandPattern,
    VoiceCommandRequest,
    VoiceCommandResult,
    VoiceFeedback,
)


class VoiceCommandService:
    """
    Service for processing voice commands.

    Handles:
    - Intent recognition from transcribed speech
    - Parameter extraction (floor numbers, zones, etc.)
    - Command execution routing
    - Response generation for text-to-speech
    """

    def __init__(self) -> None:
        """Initialize the voice command service."""
        self._patterns = self._build_patterns()
        self._command_handlers: dict[VoiceCommandIntent, Any] = {}

    def _build_patterns(self) -> list[VoiceCommandPattern]:
        """Build regex patterns for intent recognition."""
        return [
            # Navigation commands
            VoiceCommandPattern(
                intent=VoiceCommandIntent.GO_TO_FLOOR,
                patterns=[
                    r"go to floor (\d+)",
                    r"move to floor (\d+)",
                    r"take me to floor (\d+)",
                    r"floor (\d+)",
                    r"go (?:to )?level (\d+)",
                ],
                parameter_extractors=[r"(\d+)"],
                description="Navigate to a specific floor",
            ),
            VoiceCommandPattern(
                intent=VoiceCommandIntent.GO_TO_ZONE,
                patterns=[
                    r"go to zone ([a-z]+)",
                    r"move to zone ([a-z]+)",
                    r"go to (?:the )?([a-z]+) zone",
                    r"navigate to ([a-z]+)",
                ],
                parameter_extractors=[r"zone ([a-z]+)", r"to ([a-z]+)"],
                description="Navigate to a specific zone",
            ),
            VoiceCommandPattern(
                intent=VoiceCommandIntent.GO_HOME,
                patterns=[
                    r"go home",
                    r"return home",
                    r"go back home",
                    r"return to base",
                    r"go to (?:the )?(?:home|base|dock|charging)",
                ],
                parameter_extractors=[],
                description="Return to home/charging station",
            ),
            VoiceCommandPattern(
                intent=VoiceCommandIntent.STOP,
                patterns=[
                    r"^stop$",
                    r"stop (?:moving|now|there)",
                    r"halt",
                    r"pause",
                    r"wait",
                    r"hold",
                ],
                parameter_extractors=[],
                description="Stop current movement",
            ),
            # Container commands
            VoiceCommandPattern(
                intent=VoiceCommandIntent.LOCK_CONTAINER,
                patterns=[
                    r"lock (?:the )?container",
                    r"secure (?:the )?container",
                    r"close (?:and )?lock",
                ],
                parameter_extractors=[],
                description="Lock the document container",
            ),
            VoiceCommandPattern(
                intent=VoiceCommandIntent.UNLOCK_CONTAINER,
                patterns=[
                    r"unlock (?:the )?container",
                    r"open (?:the )?container",
                    r"release (?:the )?lock",
                ],
                parameter_extractors=[],
                description="Unlock the document container",
            ),
            VoiceCommandPattern(
                intent=VoiceCommandIntent.OPEN_CONTAINER,
                patterns=[
                    r"open (?:the )?(?:container|door|lid)",
                    r"open up",
                ],
                parameter_extractors=[],
                description="Open the container door",
            ),
            # Delivery commands
            VoiceCommandPattern(
                intent=VoiceCommandIntent.START_DELIVERY,
                patterns=[
                    r"start (?:a )?delivery(?: to (.+))?",
                    r"deliver (?:to|documents to) (.+)",
                    r"begin delivery",
                    r"new delivery",
                ],
                parameter_extractors=[r"to (.+)"],
                description="Start a new delivery",
            ),
            VoiceCommandPattern(
                intent=VoiceCommandIntent.CANCEL_DELIVERY,
                patterns=[
                    r"cancel (?:the )?delivery",
                    r"abort (?:the )?delivery",
                    r"stop (?:the )?delivery",
                ],
                parameter_extractors=[],
                description="Cancel current delivery",
            ),
            VoiceCommandPattern(
                intent=VoiceCommandIntent.CHECK_DELIVERY_STATUS,
                patterns=[
                    r"(?:what(?:'s| is) the )?delivery status",
                    r"where (?:is|are) (?:the )?(?:delivery|documents)",
                    r"check delivery",
                    r"delivery update",
                ],
                parameter_extractors=[],
                description="Check delivery status",
            ),
            # Status commands
            VoiceCommandPattern(
                intent=VoiceCommandIntent.CHECK_BATTERY,
                patterns=[
                    r"(?:what(?:'s| is) (?:the )?)?battery (?:level|status|percentage)",
                    r"how much battery",
                    r"check battery",
                    r"battery(?:$| left| remaining)",
                ],
                parameter_extractors=[],
                description="Check battery level",
            ),
            VoiceCommandPattern(
                intent=VoiceCommandIntent.CHECK_LOCATION,
                patterns=[
                    r"where (?:are you|am i|is (?:the )?robot)",
                    r"(?:what(?:'s| is) )?(?:your |the )?(?:current )?location",
                    r"which floor",
                    r"what floor",
                ],
                parameter_extractors=[],
                description="Check current location",
            ),
            VoiceCommandPattern(
                intent=VoiceCommandIntent.CHECK_STATUS,
                patterns=[
                    r"(?:what(?:'s| is) )?(?:your |the )?status",
                    r"how are you",
                    r"system status",
                    r"robot status",
                    r"status report",
                ],
                parameter_extractors=[],
                description="Check overall robot status",
            ),
            # Emergency commands
            VoiceCommandPattern(
                intent=VoiceCommandIntent.EMERGENCY_STOP,
                patterns=[
                    r"emergency(?: stop)?",
                    r"e(?:-)?stop",
                    r"stop (?:everything|all|immediately)",
                    r"abort",
                ],
                parameter_extractors=[],
                description="Emergency stop - halt all operations",
            ),
            # Help
            VoiceCommandPattern(
                intent=VoiceCommandIntent.HELP,
                patterns=[
                    r"help",
                    r"what can you do",
                    r"(?:what |list )?commands",
                    r"how (?:do i|to)",
                ],
                parameter_extractors=[],
                description="Get help with available commands",
            ),
        ]

    def _normalize_text(self, text: str) -> str:
        """Normalize transcript for better matching."""
        # Convert to lowercase
        normalized = text.lower().strip()
        # Remove punctuation except hyphens
        normalized = re.sub(r"[^\w\s-]", "", normalized)
        # Normalize whitespace
        normalized = re.sub(r"\s+", " ", normalized)
        # Common speech-to-text corrections
        corrections = {
            "to": "to",
            "too": "to",
            "two": "2",
            "for": "4",
            "four": "4",
            "won": "1",
            "one": "1",
            "tree": "3",
            "three": "3",
            "ate": "8",
            "eight": "8",
        }
        words = normalized.split()
        corrected_words = [corrections.get(w, w) for w in words]
        return " ".join(corrected_words)

    def _extract_parameters(
        self, text: str, extractors: list[str]
    ) -> list[ExtractedParameter]:
        """Extract parameters from text using regex extractors."""
        parameters = []
        for extractor in extractors:
            match = re.search(extractor, text, re.IGNORECASE)
            if match and match.groups():
                value = match.group(1)
                # Try to convert to int if it's a number
                try:
                    value = int(value)
                except ValueError:
                    pass
                parameters.append(
                    ExtractedParameter(
                        name=f"param_{len(parameters) + 1}",
                        value=value,
                        confidence=0.95,
                    )
                )
        return parameters

    def _get_confidence_level(self, confidence: float) -> CommandConfidence:
        """Convert numeric confidence to level."""
        if confidence >= 0.9:
            return CommandConfidence.HIGH
        if confidence >= 0.7:
            return CommandConfidence.MEDIUM
        if confidence >= 0.5:
            return CommandConfidence.LOW
        return CommandConfidence.UNCERTAIN

    def recognize_intent(
        self, request: VoiceCommandRequest
    ) -> tuple[VoiceCommandIntent, float, list[ExtractedParameter]]:
        """
        Recognize intent from transcribed text.

        Returns:
            Tuple of (intent, confidence, parameters)
        """
        normalized = self._normalize_text(request.transcript)

        best_intent = VoiceCommandIntent.UNKNOWN
        best_confidence = 0.0
        best_parameters: list[ExtractedParameter] = []

        for pattern in self._patterns:
            for regex in pattern.patterns:
                match = re.search(regex, normalized, re.IGNORECASE)
                if match:
                    # Calculate confidence based on match quality
                    match_length = match.end() - match.start()
                    text_length = len(normalized)
                    match_confidence = min(1.0, match_length / max(text_length, 1) + 0.5)

                    # Combine with speech recognition confidence
                    combined_confidence = (
                        match_confidence * 0.6 + request.confidence * 0.4
                    )

                    if combined_confidence > best_confidence:
                        best_intent = pattern.intent
                        best_confidence = combined_confidence
                        best_parameters = self._extract_parameters(
                            normalized, pattern.parameter_extractors
                        )

        return best_intent, best_confidence, best_parameters

    def _generate_response(
        self,
        intent: VoiceCommandIntent,
        success: bool,
        parameters: list[ExtractedParameter],
    ) -> str:
        """Generate spoken response for the command."""
        if not success:
            return "Sorry, I couldn't complete that command. Please try again."

        responses = {
            VoiceCommandIntent.GO_TO_FLOOR: lambda p: f"Moving to floor {p[0].value if p else 'specified'}"
            if p
            else "Please specify a floor number",
            VoiceCommandIntent.GO_TO_ZONE: lambda p: f"Navigating to zone {p[0].value if p else 'specified'}"
            if p
            else "Please specify a zone",
            VoiceCommandIntent.GO_HOME: lambda _: "Returning to home station",
            VoiceCommandIntent.STOP: lambda _: "Stopping now",
            VoiceCommandIntent.LOCK_CONTAINER: lambda _: "Container locked",
            VoiceCommandIntent.UNLOCK_CONTAINER: lambda _: "Container unlocked",
            VoiceCommandIntent.OPEN_CONTAINER: lambda _: "Opening container",
            VoiceCommandIntent.START_DELIVERY: lambda _: "Starting delivery",
            VoiceCommandIntent.CANCEL_DELIVERY: lambda _: "Delivery cancelled",
            VoiceCommandIntent.CHECK_DELIVERY_STATUS: lambda _: "Checking delivery status",
            VoiceCommandIntent.CHECK_BATTERY: lambda _: "Battery level is 78 percent",  # Placeholder
            VoiceCommandIntent.CHECK_LOCATION: lambda _: "Currently on floor 2, zone A",  # Placeholder
            VoiceCommandIntent.CHECK_STATUS: lambda _: "All systems operational",
            VoiceCommandIntent.EMERGENCY_STOP: lambda _: "Emergency stop activated!",
            VoiceCommandIntent.HELP: lambda _: "You can say commands like: go to floor 3, lock container, check battery, or emergency stop",
            VoiceCommandIntent.UNKNOWN: lambda _: "I didn't understand that command. Say help for available commands.",
        }

        generator = responses.get(
            intent, lambda _: "Command acknowledged"
        )
        return generator(parameters)

    async def process_command(
        self, request: VoiceCommandRequest
    ) -> VoiceCommandResult:
        """
        Process a voice command request.

        This is the main entry point for voice command processing.
        """
        start_time = time.time()

        # Normalize the transcript
        normalized = self._normalize_text(request.transcript)

        # Recognize intent
        intent, confidence, parameters = self.recognize_intent(request)

        # Determine confidence level
        confidence_level = self._get_confidence_level(confidence)

        # Execute command if confidence is sufficient
        executed = False
        success = False
        error_message = None

        if confidence_level in [CommandConfidence.HIGH, CommandConfidence.MEDIUM]:
            # TODO: Actually execute the command via appropriate service
            # For now, we just simulate success
            executed = True
            success = True
        else:
            error_message = "Command confidence too low. Please speak clearly and try again."

        # Generate response
        response_text = self._generate_response(intent, success, parameters)

        processing_time = (time.time() - start_time) * 1000

        return VoiceCommandResult(
            intent=intent,
            confidence=confidence,
            confidence_level=confidence_level,
            parameters=parameters,
            original_transcript=request.transcript,
            normalized_transcript=normalized,
            executed=executed,
            success=success,
            response_text=response_text,
            error_message=error_message,
            processing_time_ms=processing_time,
        )

    def get_feedback(self, result: VoiceCommandResult) -> VoiceFeedback:
        """Generate text-to-speech feedback for a command result."""
        return VoiceFeedback(
            text=result.response_text,
            priority=10 if result.intent == VoiceCommandIntent.EMERGENCY_STOP else 5,
        )

    def get_capabilities(self) -> VoiceCapabilitiesResponse:
        """Get information about supported voice commands."""
        commands = []
        for pattern in self._patterns:
            # Convert regex patterns to example phrases
            examples = []
            for regex in pattern.patterns[:3]:  # Limit to 3 examples
                # Simplify regex to readable example
                example = regex.replace(r"(\d+)", "3")
                example = example.replace(r"([a-z]+)", "alpha")
                example = example.replace(r"(.+)", "office")
                example = re.sub(r"\(\?:.+?\)", "", example)
                example = re.sub(r"[\^$\\]", "", example)
                example = example.replace("(?:", "").replace(")?", "")
                example = example.strip()
                if example:
                    examples.append(example)

            commands.append(
                SupportedCommand(
                    intent=pattern.intent,
                    description=pattern.description,
                    example_phrases=examples,
                    parameters=[
                        ext.replace(r"(\d+)", "<number>").replace(r"([a-z]+)", "<zone>")
                        for ext in pattern.parameter_extractors
                    ],
                )
            )

        return VoiceCapabilitiesResponse(
            supported_commands=commands,
            supported_locales=["en-US", "en-GB", "en-AU"],
        )


# Singleton instance
voice_service = VoiceCommandService()
