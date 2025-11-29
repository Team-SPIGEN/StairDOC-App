from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import select

from ..core.database import get_session
from ..core.security import create_access_token, generate_guid, hash_password, verify_password, settings
from ..models.user import User
from ..schemas.auth import AuthToken, RefreshRequest, UserCreate, UserLogin, UserRead
from .deps import get_current_user

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=AuthToken)
async def register(user_in: UserCreate, session=Depends(get_session)):
    existing = await session.exec(select(User).where(User.email == user_in.email))
    if existing.one_or_none():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already registered")

    user = User(
        id=generate_guid(),
        email=user_in.email,
        full_name=user_in.full_name,
        role=user_in.role,
        hashed_password=hash_password(user_in.password),
    )
    session.add(user)
    await session.commit()
    await session.refresh(user)

    return _issue_tokens(user)


@router.post("/login", response_model=AuthToken)
async def login(credentials: UserLogin, session=Depends(get_session)):
    result = await session.exec(select(User).where(User.email == credentials.email))
    user = result.one_or_none()
    if not user or not verify_password(credentials.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    return _issue_tokens(user)


@router.post("/refresh", response_model=AuthToken)
async def refresh_token(data: RefreshRequest, session=Depends(get_session)):
    # Stateless refresh token encoded as JWT with longer expiry
    from ..core.security import decode_token

    try:
        payload = decode_token(data.refresh_token)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")

    if payload.get("type") != "refresh":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid refresh token type")

    db_result = await session.exec(select(User).where(User.id == payload.get("sub")))
    user = db_result.one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return _issue_tokens(user)


@router.get("/me", response_model=UserRead)
async def read_profile(current_user: User = Depends(get_current_user)):
    return current_user


def _issue_tokens(user: User) -> AuthToken:
    access_expires = timedelta(minutes=settings.access_token_expire_minutes)
    refresh_expires = timedelta(minutes=settings.refresh_token_expire_minutes)

    access_token = create_access_token({"sub": user.id, "email": user.email, "role": user.role}, expires_delta=access_expires)
    refresh_token = create_access_token(
        {"sub": user.id, "email": user.email, "role": user.role, "full_name": user.full_name or ""},
        expires_delta=refresh_expires,
        token_type="refresh",
    )

    payload = UserRead(id=user.id, email=user.email, full_name=user.full_name, role=user.role, created_at=user.created_at)
    return AuthToken(access_token=access_token, refresh_token=refresh_token, user=payload)
