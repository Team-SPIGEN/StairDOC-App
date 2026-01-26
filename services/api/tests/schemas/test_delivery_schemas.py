"""
Unit tests for delivery schemas.

Tests:
- Delivery job validation
- Zone format validation
- Status state transitions
"""

import pytest
from datetime import datetime
from pydantic import ValidationError

from app.schemas.delivery import (
    DeliveryJobBase,
    DeliveryJobCreate,
    DeliveryJobUpdate,
    DeliveryJobRead,
)


class TestDeliveryJobBase:
    """Tests for DeliveryJobBase schema."""
    
    def test_valid_delivery_job(self):
        """Test valid delivery job data."""
        job = DeliveryJobBase(
            title="Document delivery to HR",
            pickup_zone="FLOOR1-A",
            dropoff_zone="FLOOR2-B",
            requested_by="user-123",
        )
        assert job.title == "Document delivery to HR"
        assert job.pickup_zone == "FLOOR1-A"
        assert job.dropoff_zone == "FLOOR2-B"
    
    def test_zone_uppercased(self):
        """Test zones are uppercased."""
        job = DeliveryJobBase(
            title="Test",
            pickup_zone="floor1-a",
            dropoff_zone="floor2-b",
            requested_by="user-123",
        )
        assert job.pickup_zone == "FLOOR1-A"
        assert job.dropoff_zone == "FLOOR2-B"
    
    def test_zone_with_underscore(self):
        """Test zone with underscore."""
        job = DeliveryJobBase(
            title="Test",
            pickup_zone="GROUND_LOBBY",
            dropoff_zone="FLOOR_2_OFFICE",
            requested_by="user-123",
        )
        assert job.pickup_zone == "GROUND_LOBBY"
    
    def test_title_too_long(self):
        """Test title length limit."""
        with pytest.raises(ValidationError):
            DeliveryJobBase(
                title="x" * 201,  # Exceeds 200 char limit
                pickup_zone="FLOOR1-A",
                dropoff_zone="FLOOR2-B",
                requested_by="user-123",
            )
    
    def test_empty_title_rejected(self):
        """Test empty title rejected."""
        with pytest.raises(ValidationError):
            DeliveryJobBase(
                title="",
                pickup_zone="FLOOR1-A",
                dropoff_zone="FLOOR2-B",
                requested_by="user-123",
            )
    
    def test_zone_too_long(self):
        """Test zone length limit."""
        with pytest.raises(ValidationError):
            DeliveryJobBase(
                title="Test",
                pickup_zone="A" * 21,  # Exceeds 20 char limit
                dropoff_zone="FLOOR2-B",
                requested_by="user-123",
            )
    
    def test_zone_invalid_characters(self):
        """Test zone with invalid characters rejected."""
        with pytest.raises(ValidationError):
            DeliveryJobBase(
                title="Test",
                pickup_zone="FLOOR 1 A",  # Spaces not allowed
                dropoff_zone="FLOOR2-B",
                requested_by="user-123",
            )
    
    def test_title_sanitized(self):
        """Test title has dangerous chars removed."""
        job = DeliveryJobBase(
            title="Document <script>alert(1)</script> delivery",
            pickup_zone="FLOOR1-A",
            dropoff_zone="FLOOR2-B",
            requested_by="user-123",
        )
        assert "<script>" not in job.title
        assert "</script>" not in job.title
    
    def test_requested_by_required(self):
        """Test requested_by is required."""
        with pytest.raises(ValidationError):
            DeliveryJobBase(
                title="Test",
                pickup_zone="FLOOR1-A",
                dropoff_zone="FLOOR2-B",
            )


class TestDeliveryJobCreate:
    """Tests for DeliveryJobCreate schema."""
    
    def test_create_without_robot(self):
        """Test creating job without assigned robot."""
        job = DeliveryJobCreate(
            title="Test delivery",
            pickup_zone="FLOOR1-A",
            dropoff_zone="FLOOR2-B",
            requested_by="user-123",
        )
        assert job.assigned_robot_id is None
    
    def test_create_with_robot(self):
        """Test creating job with assigned robot."""
        job = DeliveryJobCreate(
            title="Test delivery",
            pickup_zone="FLOOR1-A",
            dropoff_zone="FLOOR2-B",
            requested_by="user-123",
            assigned_robot_id="robot-001",
        )
        assert job.assigned_robot_id == "robot-001"
    
    def test_robot_id_too_long(self):
        """Test robot ID length limit."""
        with pytest.raises(ValidationError):
            DeliveryJobCreate(
                title="Test",
                pickup_zone="FLOOR1-A",
                dropoff_zone="FLOOR2-B",
                requested_by="user-123",
                assigned_robot_id="x" * 51,
            )


class TestDeliveryJobUpdate:
    """Tests for DeliveryJobUpdate schema."""
    
    def test_update_status_only(self):
        """Test updating only status."""
        update = DeliveryJobUpdate(status="in_progress")
        assert update.status == "in_progress"
        assert update.assigned_robot_id is None
    
    def test_update_robot_only(self):
        """Test updating only robot assignment."""
        update = DeliveryJobUpdate(assigned_robot_id="robot-002")
        assert update.assigned_robot_id == "robot-002"
        assert update.status is None
    
    def test_update_both(self):
        """Test updating both fields."""
        update = DeliveryJobUpdate(
            status="assigned",
            assigned_robot_id="robot-001",
        )
        assert update.status == "assigned"
        assert update.assigned_robot_id == "robot-001"
    
    def test_empty_update(self):
        """Test empty update allowed."""
        update = DeliveryJobUpdate()
        assert update.status is None
        assert update.assigned_robot_id is None
    
    def test_valid_statuses(self):
        """Test all valid status values."""
        valid_statuses = [
            "pending",
            "assigned",
            "in_progress",
            "picked_up",
            "delivered",
            "cancelled",
            "failed",
        ]
        for status in valid_statuses:
            update = DeliveryJobUpdate(status=status)
            assert update.status == status
    
    def test_invalid_status(self):
        """Test invalid status rejected."""
        with pytest.raises(ValidationError):
            DeliveryJobUpdate(status="invalid_status")


class TestDeliveryJobRead:
    """Tests for DeliveryJobRead schema."""
    
    def test_valid_read(self):
        """Test valid delivery job read."""
        now = datetime.utcnow()
        job = DeliveryJobRead(
            id="job-123",
            title="Test delivery",
            pickup_zone="FLOOR1-A",
            dropoff_zone="FLOOR2-B",
            requested_by="user-123",
            status="pending",
            assigned_robot_id=None,
            created_at=now,
            updated_at=now,
        )
        assert job.id == "job-123"
        assert job.status == "pending"
    
    def test_read_with_robot(self):
        """Test read with assigned robot."""
        now = datetime.utcnow()
        job = DeliveryJobRead(
            id="job-123",
            title="Test delivery",
            pickup_zone="FLOOR1-A",
            dropoff_zone="FLOOR2-B",
            requested_by="user-123",
            status="assigned",
            assigned_robot_id="robot-001",
            created_at=now,
            updated_at=now,
        )
        assert job.assigned_robot_id == "robot-001"
