"""Voice command API endpoints."""

from fastapi import APIRouter, HTTPException

from ..schemas.voice import (
    VoiceCapabilitiesResponse,
    VoiceCommandRequest,
    VoiceCommandResult,
    VoiceFeedback,
)
from ..services.voice_service import voice_service

router = APIRouter(prefix="/voice", tags=["voice"])


@router.post("/command", response_model=VoiceCommandResult)
async def process_voice_command(request: VoiceCommandRequest) -> VoiceCommandResult:
    """
    Process a voice command.

    Accepts transcribed speech text and returns the recognized intent,
    extracted parameters, and execution result.
    """
    try:
        result = await voice_service.process_command(request)
        return result
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to process voice command: {str(e)}",
        )


@router.post("/command/feedback", response_model=VoiceFeedback)
async def get_command_feedback(request: VoiceCommandRequest) -> VoiceFeedback:
    """
    Get text-to-speech feedback for a voice command.

    Processes the command and returns feedback suitable for speech synthesis.
    """
    result = await voice_service.process_command(request)
    return voice_service.get_feedback(result)


@router.get("/capabilities", response_model=VoiceCapabilitiesResponse)
async def get_voice_capabilities() -> VoiceCapabilitiesResponse:
    """
    Get information about supported voice commands.

    Returns a list of all available commands with example phrases.
    """
    return voice_service.get_capabilities()
