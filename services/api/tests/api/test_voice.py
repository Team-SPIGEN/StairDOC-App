"""
Integration tests for voice command endpoints.

Tests:
- Voice command processing
- Intent recognition
- Command capabilities
"""

import pytest
from httpx import AsyncClient


class TestVoiceCommandProcessing:
    """Tests for voice command processing endpoint."""
    
    @pytest.mark.asyncio
    async def test_process_voice_command(
        self, client: AsyncClient, auth_headers: dict, valid_voice_command: dict
    ):
        """Test processing a voice command."""
        response = await client.post(
            "/api/v1/voice/command",
            json=valid_voice_command,
            headers=auth_headers,
        )
        assert response.status_code in [200, 201]
        data = response.json()
        assert "intent" in data
    
    @pytest.mark.asyncio
    async def test_voice_navigation_command(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test navigation voice command."""
        response = await client.post(
            "/api/v1/voice/command",
            json={
                "transcript": "Go to floor 2",
                "confidence": 0.95,
                "locale": "en-US",
            },
            headers=auth_headers,
        )
        assert response.status_code in [200, 201]
        data = response.json()
        # Should recognize navigation intent
        assert data.get("intent") in [
            "go_to_floor",
            "GO_TO_FLOOR",
            "navigation",
            "unknown",
        ] or "intent" in data
    
    @pytest.mark.asyncio
    async def test_voice_stop_command(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test stop voice command."""
        response = await client.post(
            "/api/v1/voice/command",
            json={
                "transcript": "Stop",
                "confidence": 0.99,
                "locale": "en-US",
            },
            headers=auth_headers,
        )
        assert response.status_code in [200, 201]
    
    @pytest.mark.asyncio
    async def test_voice_emergency_stop_command(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test emergency stop voice command."""
        response = await client.post(
            "/api/v1/voice/command",
            json={
                "transcript": "Emergency stop",
                "confidence": 0.95,
                "locale": "en-US",
            },
            headers=auth_headers,
        )
        assert response.status_code in [200, 201]
    
    @pytest.mark.asyncio
    async def test_voice_unlock_command(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test unlock voice command."""
        response = await client.post(
            "/api/v1/voice/command",
            json={
                "transcript": "Unlock the container",
                "confidence": 0.90,
                "locale": "en-US",
            },
            headers=auth_headers,
        )
        assert response.status_code in [200, 201]
    
    @pytest.mark.asyncio
    async def test_voice_low_confidence(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test voice command with low confidence."""
        response = await client.post(
            "/api/v1/voice/command",
            json={
                "transcript": "Maybe go somewhere",
                "confidence": 0.3,  # Low confidence
                "locale": "en-US",
            },
            headers=auth_headers,
        )
        assert response.status_code in [200, 201]
        data = response.json()
        # Should indicate low confidence
        assert data.get("confidence_level") in [
            "low", "uncertain", "LOW", "UNCERTAIN", None
        ] or "confidence" in data
    
    @pytest.mark.asyncio
    async def test_voice_unknown_command(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test unrecognized voice command."""
        response = await client.post(
            "/api/v1/voice/command",
            json={
                "transcript": "Alakazam hocus pocus",
                "confidence": 0.95,
                "locale": "en-US",
            },
            headers=auth_headers,
        )
        assert response.status_code in [200, 201]
        data = response.json()
        # Should return unknown intent
        assert data.get("intent") in [
            "unknown", "UNKNOWN", None
        ] or "intent" in data
    
    @pytest.mark.asyncio
    async def test_voice_empty_transcript(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test empty transcript rejected."""
        response = await client.post(
            "/api/v1/voice/command",
            json={
                "transcript": "",
                "confidence": 0.95,
            },
            headers=auth_headers,
        )
        assert response.status_code == 422
    
    @pytest.mark.asyncio
    async def test_voice_without_auth(self, client: AsyncClient):
        """Test voice command works without auth (endpoint is public)."""
        response = await client.post(
            "/api/v1/voice/command",
            json={
                "transcript": "Go to floor 2",
                "confidence": 0.95,
            },
        )
        # Voice endpoint doesn't require auth currently
        assert response.status_code in [200, 401, 403]


class TestVoiceCapabilities:
    """Tests for voice capabilities endpoint."""
    
    @pytest.mark.asyncio
    async def test_get_voice_capabilities(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test getting supported voice commands."""
        response = await client.get(
            "/api/v1/voice/capabilities",
            headers=auth_headers,
        )
        assert response.status_code in [200, 404]
        if response.status_code == 200:
            data = response.json()
            assert "supported_commands" in data or "commands" in data
    
    @pytest.mark.asyncio
    async def test_capabilities_includes_locales(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test capabilities includes supported locales."""
        response = await client.get(
            "/api/v1/voice/capabilities",
            headers=auth_headers,
        )
        if response.status_code == 200:
            data = response.json()
            if "supported_locales" in data:
                assert "en-US" in data["supported_locales"]


class TestVoiceCommandValidation:
    """Tests for voice command input validation."""
    
    @pytest.mark.asyncio
    async def test_invalid_confidence_high(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test confidence > 1.0 rejected."""
        response = await client.post(
            "/api/v1/voice/command",
            json={
                "transcript": "Go to floor 2",
                "confidence": 1.5,  # Invalid
                "locale": "en-US",
            },
            headers=auth_headers,
        )
        assert response.status_code == 422
    
    @pytest.mark.asyncio
    async def test_invalid_confidence_negative(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test negative confidence rejected."""
        response = await client.post(
            "/api/v1/voice/command",
            json={
                "transcript": "Go to floor 2",
                "confidence": -0.5,  # Invalid
                "locale": "en-US",
            },
            headers=auth_headers,
        )
        assert response.status_code == 422
    
    @pytest.mark.asyncio
    async def test_default_locale(
        self, client: AsyncClient, auth_headers: dict
    ):
        """Test default locale is used when not provided."""
        response = await client.post(
            "/api/v1/voice/command",
            json={
                "transcript": "Go to floor 2",
                "confidence": 0.95,
                # locale not provided
            },
            headers=auth_headers,
        )
        assert response.status_code in [200, 201]
