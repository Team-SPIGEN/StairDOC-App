"""
Pagination utilities for high-throughput list queries.

Implements:
- Offset-based pagination (simple, good for most cases)
- Cursor-based pagination (better for large datasets)
- Optimized query building with limit/offset
"""

from datetime import datetime
from typing import Any, Generic, Optional, TypeVar, Sequence
from pydantic import BaseModel, Field
from sqlmodel import SQLModel, select
from sqlalchemy import func
from sqlalchemy.orm import Query

T = TypeVar("T", bound=SQLModel)


class PageParams(BaseModel):
    """Standard pagination parameters."""
    page: int = Field(default=1, ge=1, description="Page number (1-indexed)")
    page_size: int = Field(default=20, ge=1, le=100, description="Items per page")
    
    @property
    def offset(self) -> int:
        """Calculate offset for SQL query."""
        return (self.page - 1) * self.page_size
    
    @property
    def limit(self) -> int:
        """Alias for page_size."""
        return self.page_size


class CursorParams(BaseModel):
    """Cursor-based pagination parameters for large datasets."""
    cursor: Optional[str] = Field(default=None, description="Cursor for next page")
    limit: int = Field(default=20, ge=1, le=100, description="Items per page")
    direction: str = Field(default="next", pattern="^(next|prev)$")


class PageInfo(BaseModel):
    """Pagination metadata."""
    page: int
    page_size: int
    total_items: int
    total_pages: int
    has_next: bool
    has_prev: bool


class CursorInfo(BaseModel):
    """Cursor pagination metadata."""
    next_cursor: Optional[str] = None
    prev_cursor: Optional[str] = None
    has_next: bool
    has_prev: bool


class PaginatedResponse(BaseModel, Generic[T]):
    """Standard paginated response wrapper."""
    items: list[Any]
    page_info: PageInfo
    
    class Config:
        arbitrary_types_allowed = True


class CursorPaginatedResponse(BaseModel, Generic[T]):
    """Cursor-paginated response wrapper."""
    items: list[Any]
    cursor_info: CursorInfo
    
    class Config:
        arbitrary_types_allowed = True


def paginate_query(
    statement,
    params: PageParams,
) -> tuple:
    """
    Apply pagination to a SQLAlchemy select statement.
    
    Returns (paginated_statement, count_statement).
    """
    # Create count query (without limit/offset)
    count_stmt = select(func.count()).select_from(statement.subquery())
    
    # Apply pagination
    paginated = statement.offset(params.offset).limit(params.limit)
    
    return paginated, count_stmt


def create_page_info(
    page: int,
    page_size: int,
    total_items: int,
) -> PageInfo:
    """Create PageInfo from query results."""
    total_pages = (total_items + page_size - 1) // page_size if total_items > 0 else 0
    
    return PageInfo(
        page=page,
        page_size=page_size,
        total_items=total_items,
        total_pages=total_pages,
        has_next=page < total_pages,
        has_prev=page > 1,
    )


def encode_cursor(value: Any, field: str = "id") -> str:
    """Encode a cursor value for pagination."""
    import base64
    import json
    
    data = {"v": str(value), "f": field}
    return base64.urlsafe_b64encode(json.dumps(data).encode()).decode()


def decode_cursor(cursor: str) -> tuple[str, str]:
    """Decode a cursor to get value and field."""
    import base64
    import json
    
    try:
        data = json.loads(base64.urlsafe_b64decode(cursor.encode()).decode())
        return data["v"], data["f"]
    except Exception:
        raise ValueError("Invalid cursor")


def cursor_paginate_query(
    statement,
    params: CursorParams,
    order_field: str = "id",
    order_column = None,
):
    """
    Apply cursor-based pagination to a SQLAlchemy select statement.
    
    Better for large datasets as it doesn't need to count all rows.
    """
    if order_column is None:
        raise ValueError("order_column must be provided")
    
    if params.cursor:
        cursor_value, _ = decode_cursor(params.cursor)
        
        if params.direction == "next":
            statement = statement.where(order_column > cursor_value)
        else:
            statement = statement.where(order_column < cursor_value)
    
    # Fetch one extra to check if there are more items
    statement = statement.order_by(order_column).limit(params.limit + 1)
    
    return statement


def create_cursor_info(
    items: Sequence[T],
    limit: int,
    order_field: str = "id",
    had_cursor: bool = False,
) -> tuple[list[T], CursorInfo]:
    """
    Create CursorInfo from query results.
    
    Returns (trimmed_items, cursor_info).
    """
    has_next = len(items) > limit
    trimmed = list(items[:limit])
    
    next_cursor = None
    prev_cursor = None
    
    if trimmed:
        if has_next:
            last_item = trimmed[-1]
            next_cursor = encode_cursor(getattr(last_item, order_field), order_field)
        
        if had_cursor:
            first_item = trimmed[0]
            prev_cursor = encode_cursor(getattr(first_item, order_field), order_field)
    
    return trimmed, CursorInfo(
        next_cursor=next_cursor,
        prev_cursor=prev_cursor,
        has_next=has_next,
        has_prev=had_cursor,
    )


# =============================================================================
# Batch Operations
# =============================================================================

class BatchResult(BaseModel):
    """Result of a batch operation."""
    total: int
    successful: int
    failed: int
    errors: list[dict[str, Any]] = []


async def batch_insert(
    session,
    model_class: type[T],
    items: list[dict[str, Any]],
    batch_size: int = 100,
) -> BatchResult:
    """
    Efficiently insert multiple records.
    
    Uses batched inserts for better performance.
    """
    successful = 0
    errors = []
    
    for i in range(0, len(items), batch_size):
        batch = items[i:i + batch_size]
        try:
            objects = [model_class(**item) for item in batch]
            session.add_all(objects)
            await session.flush()
            successful += len(batch)
        except Exception as e:
            errors.append({
                "batch_start": i,
                "batch_end": i + len(batch),
                "error": str(e),
            })
    
    return BatchResult(
        total=len(items),
        successful=successful,
        failed=len(items) - successful,
        errors=errors,
    )


async def batch_update(
    session,
    model_class: type[T],
    updates: list[dict[str, Any]],
    id_field: str = "id",
) -> BatchResult:
    """
    Efficiently update multiple records.
    
    Each update dict must contain the id_field.
    """
    successful = 0
    errors = []
    
    for update in updates:
        try:
            record_id = update.pop(id_field)
            stmt = select(model_class).where(getattr(model_class, id_field) == record_id)
            result = await session.execute(stmt)
            record = result.scalar_one_or_none()
            
            if record:
                for key, value in update.items():
                    setattr(record, key, value)
                successful += 1
            else:
                errors.append({
                    "id": record_id,
                    "error": "Record not found",
                })
        except Exception as e:
            errors.append({
                "update": update,
                "error": str(e),
            })
    
    return BatchResult(
        total=len(updates),
        successful=successful,
        failed=len(updates) - successful,
        errors=errors,
    )


async def batch_delete(
    session,
    model_class: type[T],
    ids: list[Any],
    id_field: str = "id",
) -> BatchResult:
    """
    Efficiently delete multiple records.
    """
    from sqlalchemy import delete
    
    try:
        stmt = delete(model_class).where(getattr(model_class, id_field).in_(ids))
        result = await session.execute(stmt)
        deleted = result.rowcount
        
        return BatchResult(
            total=len(ids),
            successful=deleted,
            failed=len(ids) - deleted,
            errors=[],
        )
    except Exception as e:
        return BatchResult(
            total=len(ids),
            successful=0,
            failed=len(ids),
            errors=[{"error": str(e)}],
        )
