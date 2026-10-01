"""사용자 모델 (ARCHITECTURE.md §8).

자체 계정 인증용 users 테이블. role 로 일반/관리자를 구분한다.
"""
import enum
from datetime import datetime

from sqlalchemy import Boolean, DateTime, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.security import now
from app.db.base import Base


class UserRole(enum.StrEnum):
    """사용자 권한 (StrEnum — DB 에는 값 문자열로 저장)."""

    USER = "user"
    ADMIN = "admin"


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    username: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    hashed_password: Mapped[str] = mapped_column(String(255))
    role: Mapped[str] = mapped_column(String(20), default=UserRole.USER.value)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=now, onupdate=now)

    @property
    def is_admin(self) -> bool:
        return self.role == UserRole.ADMIN.value
