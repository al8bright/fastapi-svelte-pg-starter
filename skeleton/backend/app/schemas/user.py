"""사용자/인증 스키마 (architecture.md §8) — Pydantic v2."""
from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core.security import MAX_PASSWORD_BYTES


class LoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=50)
    password: str = Field(min_length=1, max_length=128)

    @field_validator("password")
    @classmethod
    def _within_bcrypt_limit(cls, v: str) -> str:
        # 글자 수가 아니라 바이트 수가 기준이다 (한글 1자 = UTF-8 3바이트).
        if len(v.encode("utf-8")) > MAX_PASSWORD_BYTES:
            raise ValueError(f"비밀번호는 UTF-8 {MAX_PASSWORD_BYTES}바이트를 넘을 수 없습니다.")
        return v


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    username: str
    role: str
    is_active: bool
