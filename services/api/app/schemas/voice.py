"""Voice command schemas for speech recognition and processing."""

from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class VoiceCommandIntent(str, Enum):
    """Recognized voice command intents."""

    # Navigation commands
    GO_TO_FLOOR = "go_to_floor"
    GO_TO_ZONE = "go_to_zone"
    GO_HOME = "go_home"
    STOP = "stop"

    # Container commands
    LOCK_CONTAINER = "lock_container"
    UNLOCK_CONTAINER = "unlock_container"
    OPEN_CONTAINER = "open_container"

    # Delivery commands
    START_DELIVERY = "start_delivery"
    CANCEL_DELIVERY = "cancel_delivery"
    CHECK_DELIVERY_STATUS = "check_delivery_status"

    # Status commands
    CHECK_BATTERY = "check_battery"
    CHECK_LOCATION = "check_location"
    CHECK_STATUS = "check_status"

    # Emergency commands
    EMERGENCY_STOP = "emergency_stop"

    # Help and unknown
    HELP = "help"
    UNKNOWN = "unknown"


class CommandConfidence(str, Enum):
    """Confidence level of command recognition."""

    HIGH = "high"  # 90%+ confidence
    MEDIUM = "medium"  # 70-90% confidence
    LOW = "low"  # 50-70% confidence
    UNCERTAIN = "uncertain"  # <50% confidence


class VoiceCommandRequest(BaseModel):
    """Request to process a voice command."""

    transcript: str = Field(..., min_length=1, description="Transcribed speech text")
    confidence: float = Field(
        default=1.0, ge=0.0, le=1.0, description="Speech recognition confidence"
    )
    locale: str = Field(default="en-US", description="Locale of the speech")
    robot_id: Optional[str] = Field(
        default=None, description="Target robot ID, uses default if not specified"
    )


class ExtractedParameter(BaseModel):
    """A parameter extracted from voice command."""

    name: str
    value: str | int | float | bool
    confidence: float = Field(default=1.0, ge=0.0, le=1.0)


class VoiceCommandResult(BaseModel):
    """Result of voice command processing."""

    # Recognition results
    intent: VoiceCommandIntent
    confidence: float = Field(ge=0.0, le=1.0)
    confidence_level: CommandConfidence
    parameters: list[ExtractedParameter] = Field(default_factory=list)

    # Original input
    original_transcript: str
    normalized_transcript: str

    # Execution results
    executed: bool = False
    success: bool = False
    response_text: str = ""
    error_message: Optional[str] = None

    # Metadata
    processing_time_ms: float = 0.0
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class VoiceCommandPattern(BaseModel):
    """Pattern for matching voice commands."""

    intent: VoiceCommandIntent
    patterns: list[str]
    parameter_extractors: list[str] = Field(default_factory=list)
    description: str


class VoiceFeedback(BaseModel):
    """Feedback response for text-to-speech."""

    text: str
    ssml: Optional[str] = None  # Speech Synthesis Markup Language
    priority: int = Field(default=0, ge=0, le=10)


class SupportedCommand(BaseModel):
    """Information about a supported voice command."""

    intent: VoiceCommandIntent
    description: str
    example_phrases: list[str]
    parameters: list[str] = Field(default_factory=list)


class VoiceCapabilitiesResponse(BaseModel):
    """Response listing available voice commands."""

    supported_commands: list[SupportedCommand]
    supported_locales: list[str]
    version: str = "1.0.0"
