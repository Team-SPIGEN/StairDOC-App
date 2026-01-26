"""
Unit tests for pagination utilities.

Tests:
- Page parameters
- Cursor parameters  
- Page info calculation
- Paginated response
- Helper functions
"""

import pytest
from unittest.mock import MagicMock, AsyncMock

from app.utils.pagination import (
    PageParams,
    CursorParams,
    PageInfo,
    CursorInfo,
    PaginatedResponse,
    CursorPaginatedResponse,
    paginate_query,
    create_page_info,
    encode_cursor,
    decode_cursor,
    cursor_paginate_query,
    create_cursor_info,
)


class TestPageParams:
    """Tests for PageParams."""
    
    def test_default_values(self):
        """Test default pagination values."""
        params = PageParams()
        assert params.page == 1
        assert params.page_size == 20
    
    def test_custom_values(self):
        """Test custom pagination values."""
        params = PageParams(page=5, page_size=50)
        assert params.page == 5
        assert params.page_size == 50
    
    def test_offset_calculation(self):
        """Test offset calculation."""
        # First page
        params = PageParams(page=1, page_size=20)
        assert params.offset == 0
        
        # Second page
        params = PageParams(page=2, page_size=20)
        assert params.offset == 20
        
        # Third page with different size
        params = PageParams(page=3, page_size=10)
        assert params.offset == 20
    
    def test_limit_alias(self):
        """Test limit property is alias for page_size."""
        params = PageParams(page_size=30)
        assert params.limit == 30
    
    def test_page_validation(self):
        """Test page number validation."""
        # Valid: page >= 1
        params = PageParams(page=1)
        assert params.page == 1
        
        # Invalid: page < 1 should raise
        with pytest.raises(ValueError):
            PageParams(page=0)
    
    def test_page_size_validation(self):
        """Test page size validation."""
        # Valid range
        params = PageParams(page_size=1)
        assert params.page_size == 1
        
        params = PageParams(page_size=100)
        assert params.page_size == 100
        
        # Invalid: > 100
        with pytest.raises(ValueError):
            PageParams(page_size=101)


class TestCursorParams:
    """Tests for CursorParams."""
    
    def test_default_values(self):
        """Test default cursor params."""
        params = CursorParams()
        assert params.cursor is None
        assert params.limit == 20
        assert params.direction == "next"
    
    def test_with_cursor(self):
        """Test cursor params with cursor."""
        params = CursorParams(cursor="abc123", limit=50, direction="next")
        assert params.cursor == "abc123"
        assert params.limit == 50
    
    def test_prev_direction(self):
        """Test previous direction."""
        params = CursorParams(direction="prev")
        assert params.direction == "prev"
    
    def test_limit_validation(self):
        """Test cursor limit validation."""
        # Valid range
        params = CursorParams(limit=1)
        assert params.limit == 1
        
        params = CursorParams(limit=100)
        assert params.limit == 100
        
        # Invalid: > 100
        with pytest.raises(ValueError):
            CursorParams(limit=101)


class TestPageInfo:
    """Tests for PageInfo."""
    
    def test_first_page(self):
        """Test first page info."""
        info = PageInfo(
            page=1,
            page_size=20,
            total_items=100,
            total_pages=5,
            has_next=True,
            has_prev=False,
        )
        assert info.page == 1
        assert info.has_next is True
        assert info.has_prev is False
    
    def test_middle_page(self):
        """Test middle page info."""
        info = PageInfo(
            page=3,
            page_size=20,
            total_items=100,
            total_pages=5,
            has_next=True,
            has_prev=True,
        )
        assert info.has_next is True
        assert info.has_prev is True
    
    def test_last_page(self):
        """Test last page info."""
        info = PageInfo(
            page=5,
            page_size=20,
            total_items=100,
            total_pages=5,
            has_next=False,
            has_prev=True,
        )
        assert info.has_next is False
        assert info.has_prev is True
    
    def test_single_page(self):
        """Test single page (all items fit)."""
        info = PageInfo(
            page=1,
            page_size=100,
            total_items=50,
            total_pages=1,
            has_next=False,
            has_prev=False,
        )
        assert info.has_next is False
        assert info.has_prev is False
    
    def test_empty_result(self):
        """Test empty result set."""
        info = PageInfo(
            page=1,
            page_size=20,
            total_items=0,
            total_pages=0,
            has_next=False,
            has_prev=False,
        )
        assert info.total_items == 0
        assert info.total_pages == 0


class TestCursorInfo:
    """Tests for CursorInfo."""
    
    def test_with_next_cursor(self):
        """Test cursor info with next cursor."""
        info = CursorInfo(
            next_cursor="cursor_abc",
            prev_cursor=None,
            has_next=True,
            has_prev=False,
        )
        assert info.next_cursor == "cursor_abc"
        assert info.has_next is True
    
    def test_with_both_cursors(self):
        """Test cursor info with both cursors."""
        info = CursorInfo(
            next_cursor="next_xyz",
            prev_cursor="prev_abc",
            has_next=True,
            has_prev=True,
        )
        assert info.next_cursor == "next_xyz"
        assert info.prev_cursor == "prev_abc"
    
    def test_no_more_pages(self):
        """Test cursor at end of data."""
        info = CursorInfo(
            next_cursor=None,
            prev_cursor="prev_123",
            has_next=False,
            has_prev=True,
        )
        assert info.next_cursor is None
        assert info.has_next is False


class TestPaginatedResponse:
    """Tests for PaginatedResponse."""
    
    def test_create_response(self):
        """Test creating paginated response."""
        items = [{"id": 1}, {"id": 2}, {"id": 3}]
        page_info = PageInfo(
            page=1,
            page_size=20,
            total_items=3,
            total_pages=1,
            has_next=False,
            has_prev=False,
        )
        
        response = PaginatedResponse(items=items, page_info=page_info)
        
        assert len(response.items) == 3
        assert response.page_info.total_items == 3
    
    def test_empty_response(self):
        """Test empty paginated response."""
        page_info = PageInfo(
            page=1,
            page_size=20,
            total_items=0,
            total_pages=0,
            has_next=False,
            has_prev=False,
        )
        
        response = PaginatedResponse(items=[], page_info=page_info)
        
        assert len(response.items) == 0
        assert response.page_info.total_items == 0


class TestCursorPaginatedResponse:
    """Tests for CursorPaginatedResponse."""
    
    def test_create_response(self):
        """Test creating cursor paginated response."""
        items = [{"id": 1}, {"id": 2}]
        cursor_info = CursorInfo(
            next_cursor="cursor_123",
            prev_cursor=None,
            has_next=True,
            has_prev=False,
        )
        
        response = CursorPaginatedResponse(items=items, cursor_info=cursor_info)
        
        assert len(response.items) == 2
        assert response.cursor_info.has_next is True
    
    def test_response_with_no_more_pages(self):
        """Test cursor response at end of data."""
        items = [{"id": 5}]
        cursor_info = CursorInfo(
            next_cursor=None,
            prev_cursor="cursor_xyz",
            has_next=False,
            has_prev=True,
        )
        
        response = CursorPaginatedResponse(items=items, cursor_info=cursor_info)
        
        assert response.cursor_info.has_next is False
        assert response.cursor_info.has_prev is True


class TestPaginationCalculations:
    """Tests for pagination math."""
    
    def test_total_pages_calculation(self):
        """Test calculating total pages."""
        # Exact division
        assert (100 + 20 - 1) // 20 == 5  # 100 items, 20 per page = 5 pages
        
        # Partial last page
        assert (101 + 20 - 1) // 20 == 6  # 101 items, 20 per page = 6 pages
        
        # Single page
        assert (5 + 20 - 1) // 20 == 1  # 5 items, 20 per page = 1 page
    
    def test_offset_calculation(self):
        """Test offset calculations for different pages."""
        page_size = 20
        
        # Page 1 = offset 0
        assert (1 - 1) * page_size == 0
        
        # Page 2 = offset 20
        assert (2 - 1) * page_size == 20
        
        # Page 10 = offset 180
        assert (10 - 1) * page_size == 180


class TestPaginationEdgeCases:
    """Tests for pagination edge cases."""
    
    def test_large_page_number(self):
        """Test large page numbers."""
        params = PageParams(page=9999, page_size=10)
        assert params.offset == 99980
    
    def test_minimum_values(self):
        """Test minimum valid values."""
        params = PageParams(page=1, page_size=1)
        assert params.page == 1
        assert params.page_size == 1
        assert params.offset == 0
    
    def test_maximum_page_size(self):
        """Test maximum page size."""
        params = PageParams(page=1, page_size=100)
        assert params.page_size == 100


class TestCreatePageInfo:
    """Tests for create_page_info helper function."""
    
    def test_create_first_page_info(self):
        """Test creating page info for first page."""
        info = create_page_info(page=1, page_size=20, total_items=100)
        
        assert info.page == 1
        assert info.page_size == 20
        assert info.total_items == 100
        assert info.total_pages == 5
        assert info.has_next is True
        assert info.has_prev is False
    
    def test_create_middle_page_info(self):
        """Test creating page info for middle page."""
        info = create_page_info(page=3, page_size=20, total_items=100)
        
        assert info.page == 3
        assert info.total_pages == 5
        assert info.has_next is True
        assert info.has_prev is True
    
    def test_create_last_page_info(self):
        """Test creating page info for last page."""
        info = create_page_info(page=5, page_size=20, total_items=100)
        
        assert info.page == 5
        assert info.has_next is False
        assert info.has_prev is True
    
    def test_create_page_info_single_page(self):
        """Test page info when all items fit on one page."""
        info = create_page_info(page=1, page_size=50, total_items=30)
        
        assert info.total_pages == 1
        assert info.has_next is False
        assert info.has_prev is False
    
    def test_create_page_info_empty_result(self):
        """Test page info for empty result."""
        info = create_page_info(page=1, page_size=20, total_items=0)
        
        assert info.total_items == 0
        assert info.total_pages == 0
        assert info.has_next is False
        assert info.has_prev is False
    
    def test_create_page_info_partial_last_page(self):
        """Test page info when last page is partial."""
        info = create_page_info(page=1, page_size=20, total_items=55)
        
        assert info.total_pages == 3  # 20 + 20 + 15


class TestEncodeDecode:
    """Tests for cursor encoding and decoding."""
    
    def test_encode_cursor(self):
        """Test cursor encoding."""
        cursor = encode_cursor("123", "id")
        
        assert isinstance(cursor, str)
        assert len(cursor) > 0
    
    def test_decode_cursor(self):
        """Test cursor decoding."""
        cursor = encode_cursor("456", "id")
        value, field = decode_cursor(cursor)
        
        assert value == "456"
        assert field == "id"
    
    def test_encode_decode_roundtrip(self):
        """Test encoding and decoding roundtrip."""
        original_value = "test_value_123"
        original_field = "created_at"
        
        cursor = encode_cursor(original_value, original_field)
        decoded_value, decoded_field = decode_cursor(cursor)
        
        assert decoded_value == original_value
        assert decoded_field == original_field
    
    def test_encode_integer_value(self):
        """Test encoding integer values."""
        cursor = encode_cursor(42, "id")
        value, field = decode_cursor(cursor)
        
        # Value is stringified
        assert value == "42"
        assert field == "id"
    
    def test_decode_invalid_cursor(self):
        """Test decoding invalid cursor raises error."""
        with pytest.raises(ValueError, match="Invalid cursor"):
            decode_cursor("not_a_valid_cursor")
    
    def test_decode_malformed_base64(self):
        """Test decoding malformed base64."""
        with pytest.raises(ValueError, match="Invalid cursor"):
            decode_cursor("!!!invalid!!!")
    
    def test_encode_with_special_characters(self):
        """Test encoding values with special characters."""
        cursor = encode_cursor("user@example.com", "email")
        value, field = decode_cursor(cursor)
        
        assert value == "user@example.com"
        assert field == "email"


class TestCreateCursorInfo:
    """Tests for create_cursor_info helper function."""
    
    def test_create_cursor_info_with_more_items(self):
        """Test cursor info when there are more items."""
        # Mock items with id attribute
        class MockItem:
            def __init__(self, id):
                self.id = id
        
        items = [MockItem(i) for i in range(21)]  # One more than limit
        trimmed, info = create_cursor_info(items, limit=20, order_field="id")
        
        assert len(trimmed) == 20
        assert info.has_next is True
        assert info.next_cursor is not None
    
    def test_create_cursor_info_no_more_items(self):
        """Test cursor info when at end of data."""
        class MockItem:
            def __init__(self, id):
                self.id = id
        
        items = [MockItem(i) for i in range(10)]  # Less than limit
        trimmed, info = create_cursor_info(items, limit=20, order_field="id")
        
        assert len(trimmed) == 10
        assert info.has_next is False
        assert info.next_cursor is None
    
    def test_create_cursor_info_exact_limit(self):
        """Test cursor info when items exactly match limit."""
        class MockItem:
            def __init__(self, id):
                self.id = id
        
        items = [MockItem(i) for i in range(20)]  # Exactly limit
        trimmed, info = create_cursor_info(items, limit=20, order_field="id")
        
        assert len(trimmed) == 20
        assert info.has_next is False  # No extra item to indicate more
    
    def test_create_cursor_info_with_prev_cursor(self):
        """Test cursor info with previous page cursor."""
        class MockItem:
            def __init__(self, id):
                self.id = id
        
        items = [MockItem(i) for i in range(15)]
        trimmed, info = create_cursor_info(items, limit=20, order_field="id", had_cursor=True)
        
        assert info.has_prev is True
        assert info.prev_cursor is not None
    
    def test_create_cursor_info_empty_result(self):
        """Test cursor info with empty result."""
        trimmed, info = create_cursor_info([], limit=20, order_field="id")
        
        assert len(trimmed) == 0
        assert info.has_next is False
        assert info.has_prev is False
        assert info.next_cursor is None
        assert info.prev_cursor is None


class TestPaginateQuery:
    """Tests for paginate_query function."""
    
    def test_paginate_query_returns_tuple(self):
        """Test paginate_query returns paginated and count statements."""
        from sqlmodel import select, SQLModel, Field
        from typing import Optional
        
        # Create a mock statement using select
        class MockPaginateModel(SQLModel, table=True):
            __tablename__ = "mock_paginate_model"
            id: Optional[int] = Field(default=None, primary_key=True)
            name: str = ""
        
        # The paginate_query function modifies the statement
        params = PageParams(page=2, page_size=10)
        
        stmt = select(MockPaginateModel)
        
        # Verify the function can be called
        paginated, count = paginate_query(stmt, params)
        assert paginated is not None
        assert count is not None


class TestCursorPaginateQuery:
    """Tests for cursor_paginate_query function."""
    
    def test_cursor_paginate_requires_order_column(self):
        """Test cursor_paginate_query requires order_column."""
        from sqlmodel import select, SQLModel, Field
        from typing import Optional
        
        class MockCursorModel(SQLModel, table=True):
            __tablename__ = "mock_cursor_model"
            id: Optional[int] = Field(default=None, primary_key=True)
            name: str = ""
        
        params = CursorParams(limit=10)
        stmt = select(MockCursorModel)
        
        with pytest.raises(ValueError, match="order_column must be provided"):
            cursor_paginate_query(stmt, params, order_column=None)
    
    def test_cursor_paginate_with_column(self):
        """Test cursor_paginate_query with order column."""
        from sqlmodel import select, SQLModel, Field
        from typing import Optional
        
        class MockCursorModel2(SQLModel, table=True):
            __tablename__ = "mock_cursor_model_2"
            id: Optional[int] = Field(default=None, primary_key=True)
            name: str = ""
        
        params = CursorParams(limit=10)
        stmt = select(MockCursorModel2)
        
        result = cursor_paginate_query(
            stmt,
            params,
            order_field="id",
            order_column=MockCursorModel2.id
        )
        
        # Should return a modified statement
        assert result is not None