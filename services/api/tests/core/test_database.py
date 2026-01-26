"""
Unit tests for database configuration.

Tests:
- Engine creation
- Session management
- Connection pooling config
- Slow query threshold
"""

import pytest
from unittest.mock import MagicMock, AsyncMock, patch

from app.core.database import (
    SLOW_QUERY_THRESHOLD_MS,
    _before_cursor_execute,
    _after_cursor_execute,
    _query_start_times,
)


class TestDatabaseConfiguration:
    """Tests for database configuration."""
    
    def test_slow_query_threshold(self):
        """Test slow query threshold is set."""
        assert SLOW_QUERY_THRESHOLD_MS == 100
    
    def test_query_times_dict_exists(self):
        """Test query times dictionary exists."""
        assert isinstance(_query_start_times, dict)


class TestQueryTiming:
    """Tests for query timing hooks."""
    
    def test_before_cursor_execute_records_time(self):
        """Test before_cursor_execute records start time."""
        cursor = MagicMock()
        cursor_id = id(cursor)
        
        _before_cursor_execute(
            conn=None,
            cursor=cursor,
            statement="SELECT * FROM users",
            parameters=None,
            context=None,
            executemany=False,
        )
        
        # Should have recorded start time
        assert cursor_id in _query_start_times
        
        # Clean up
        _query_start_times.pop(cursor_id, None)
    
    def test_after_cursor_execute_cleans_up(self):
        """Test after_cursor_execute removes timing entry."""
        cursor = MagicMock()
        cursor_id = id(cursor)
        
        # Set up a start time
        import time
        _query_start_times[cursor_id] = time.perf_counter()
        
        _after_cursor_execute(
            conn=None,
            cursor=cursor,
            statement="SELECT 1",
            parameters=None,
            context=None,
            executemany=False,
        )
        
        # Should have removed the entry
        assert cursor_id not in _query_start_times
    
    def test_after_cursor_execute_handles_missing_entry(self):
        """Test after_cursor_execute handles missing start time."""
        cursor = MagicMock()
        
        # Should not raise even without a start time
        _after_cursor_execute(
            conn=None,
            cursor=cursor,
            statement="SELECT 1",
            parameters=None,
            context=None,
            executemany=False,
        )


class TestSlowQueryLogging:
    """Tests for slow query detection."""
    
    def test_slow_query_threshold_value(self):
        """Test threshold is reasonable."""
        assert SLOW_QUERY_THRESHOLD_MS > 0
        assert SLOW_QUERY_THRESHOLD_MS <= 1000  # Less than 1 second
    
    @patch('app.core.database.logger')
    def test_slow_query_logs_warning(self, mock_logger):
        """Test slow queries are logged."""
        cursor = MagicMock()
        cursor_id = id(cursor)
        
        # Set start time far in the past to simulate slow query
        import time
        _query_start_times[cursor_id] = time.perf_counter() - 0.5  # 500ms ago
        
        _after_cursor_execute(
            conn=None,
            cursor=cursor,
            statement="SELECT * FROM large_table WHERE complex_condition",
            parameters=None,
            context=None,
            executemany=False,
        )
        
        # Should have logged a warning
        mock_logger.warning.assert_called()
