"""
Unit tests for voice service.

Tests:
- Command parsing
- Voice command processing
- Intent recognition
"""

import pytest
from unittest.mock import MagicMock, patch, AsyncMock

from app.services.voice_service import VoiceCommandService, voice_service
from app.schemas.voice import VoiceCommandRequest, VoiceCommandIntent, CommandConfidence


class TestVoiceCommandService:
    """Tests for VoiceCommandService class."""
    
    def test_service_creation(self):
        """Test VoiceCommandService can be instantiated."""
        service = VoiceCommandService()
        assert service is not None
    
    def test_patterns_built(self):
        """Test that command patterns are built on initialization."""
        service = VoiceCommandService()
        assert len(service._patterns) > 0
    
    def test_normalize_text(self):
        """Test text normalization."""
        service = VoiceCommandService()
        
        # Test lowercase conversion
        assert "hello world" == service._normalize_text("Hello World")
        
        # Test whitespace normalization
        assert "hello world" == service._normalize_text("  hello   world  ")
        
        # Test punctuation removal
        result = service._normalize_text("Hello, World!")
        assert "," not in result
        assert "!" not in result
    
    def test_normalize_text_number_corrections(self):
        """Test number word to digit corrections."""
        service = VoiceCommandService()
        
        result = service._normalize_text("go to floor one")
        assert "1" in result
        
        result = service._normalize_text("floor three")
        assert "3" in result


class TestIntentRecognition:
    """Tests for intent recognition."""
    
    def test_recognize_go_to_floor(self):
        """Test recognizing go to floor command."""
        service = VoiceCommandService()
        request = VoiceCommandRequest(transcript="go to floor 3", confidence=0.9)
        
        intent, confidence, params = service.recognize_intent(request)
        
        assert intent == VoiceCommandIntent.GO_TO_FLOOR
        assert confidence > 0.5
    
    def test_recognize_stop(self):
        """Test recognizing stop command."""
        service = VoiceCommandService()
        request = VoiceCommandRequest(transcript="stop", confidence=0.95)
        
        intent, confidence, params = service.recognize_intent(request)
        
        assert intent == VoiceCommandIntent.STOP
    
    def test_recognize_emergency_stop(self):
        """Test recognizing emergency stop command."""
        service = VoiceCommandService()
        request = VoiceCommandRequest(transcript="emergency stop", confidence=0.9)
        
        intent, confidence, params = service.recognize_intent(request)
        
        assert intent == VoiceCommandIntent.EMERGENCY_STOP
    
    def test_recognize_unlock_container(self):
        """Test recognizing unlock command."""
        service = VoiceCommandService()
        request = VoiceCommandRequest(transcript="open container", confidence=0.9)
        
        intent, confidence, params = service.recognize_intent(request)
        
        assert intent == VoiceCommandIntent.UNLOCK_CONTAINER
    
    def test_recognize_unknown(self):
        """Test unknown commands."""
        service = VoiceCommandService()
        request = VoiceCommandRequest(transcript="random gibberish xyz", confidence=0.9)
        
        intent, confidence, params = service.recognize_intent(request)
        
        # Should return UNKNOWN for unrecognized commands
        assert intent == VoiceCommandIntent.UNKNOWN or confidence < 0.5


class TestCommandProcessing:
    """Tests for command processing."""
    
    @pytest.mark.asyncio
    async def test_process_valid_command(self):
        """Test processing a valid command."""
        service = VoiceCommandService()
        request = VoiceCommandRequest(transcript="go to floor 2", confidence=0.9)
        
        result = await service.process_command(request)
        
        assert result is not None
        assert result.intent == VoiceCommandIntent.GO_TO_FLOOR
        assert result.response_text is not None
    
    @pytest.mark.asyncio
    async def test_process_stop_command(self):
        """Test processing stop command."""
        service = VoiceCommandService()
        request = VoiceCommandRequest(transcript="stop", confidence=0.95)
        
        result = await service.process_command(request)
        
        assert result.intent == VoiceCommandIntent.STOP
        assert result.success is True
    
    @pytest.mark.asyncio
    async def test_process_low_confidence(self):
        """Test low confidence command processing."""
        service = VoiceCommandService()
        request = VoiceCommandRequest(transcript="mumble mumble", confidence=0.3)
        
        result = await service.process_command(request)
        
        # Low confidence should not execute
        assert result.confidence_level == CommandConfidence.UNCERTAIN or result.executed is False
    
    @pytest.mark.asyncio
    async def test_process_includes_processing_time(self):
        """Test that processing time is recorded."""
        service = VoiceCommandService()
        request = VoiceCommandRequest(transcript="stop", confidence=0.9)
        
        result = await service.process_command(request)
        
        assert result.processing_time_ms >= 0


class TestVoiceCapabilities:
    """Tests for voice capabilities."""
    
    def test_get_capabilities(self):
        """Test getting capabilities."""
        service = VoiceCommandService()
        capabilities = service.get_capabilities()
        
        assert capabilities is not None
        assert len(capabilities.supported_commands) > 0
        assert len(capabilities.supported_locales) > 0
    
    def test_supported_locales(self):
        """Test supported locales include en-US."""
        service = VoiceCommandService()
        capabilities = service.get_capabilities()
        
        assert "en-US" in capabilities.supported_locales
    
    def test_commands_have_descriptions(self):
        """Test all commands have descriptions."""
        service = VoiceCommandService()
        capabilities = service.get_capabilities()
        
        for cmd in capabilities.supported_commands:
            assert cmd.description is not None
            assert len(cmd.description) > 0
    
    def test_commands_have_examples(self):
        """Test commands have example phrases."""
        service = VoiceCommandService()
        capabilities = service.get_capabilities()
        
        # At least some commands should have examples
        has_examples = any(len(cmd.example_phrases) > 0 for cmd in capabilities.supported_commands)
        assert has_examples


class TestGlobalVoiceService:
    """Tests for global voice_service instance."""
    
    def test_global_instance_exists(self):
        """Test that global voice_service is available."""
        assert voice_service is not None
        assert isinstance(voice_service, VoiceCommandService)
    
    @pytest.mark.asyncio
    async def test_global_instance_works(self):
        """Test that global instance can process commands."""
        request = VoiceCommandRequest(transcript="help", confidence=0.9)
        result = await voice_service.process_command(request)
        
        assert result is not None
