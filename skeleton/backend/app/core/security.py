"""보안 및 시각(now) 유틸 (architecture.md §9, §10).

날짜·시간 규칙(§10):
- 업무 시각은 KST 기준이며, UTC<->KST 변환 레이어를 두지 않는다.
- 애플리케이션에서는 naive datetime.now() 만 사용한다.
- 실행 환경에 TZ=Asia/Seoul 을 설정한다.
"""
import time
from datetime import datetime
from typing import Literal

import bcrypt
import jwt


def now() -> datetime:
    """KST 기준 naive 현재 시각."""
    return datetime.now()


def hash_password(plain: str) -> str:
    """bcrypt 해시 생성 (자체 계정 비밀번호 저장용)."""
    return bcrypt.hashpw(plain.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    """평문과 bcrypt 해시 비교. 형식 오류 시 False."""
    try:
        return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))
    except (ValueError, TypeError):
        return False


def create_token(
    *,
    subject: str,
    secret: str,
    expires_minutes: int,
    token_type: Literal["access", "refresh"] = "access",
) -> str:
    exp = int(time.time()) + expires_minutes * 60
    payload = {"sub": subject, "exp": exp, "typ": token_type}
    return jwt.encode(payload, secret, algorithm="HS256")


def decode_access_token(token: str, secret: str) -> dict | None:
    """JWT 디코드. 유효하지 않으면 None."""
    try:
        payload = jwt.decode(token, secret, algorithms=["HS256"])
    except jwt.PyJWTError:
        return None
    if payload.get("typ") != "access":
        return None
    return payload
