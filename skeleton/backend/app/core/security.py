"""보안 및 시각(now) 유틸 (architecture.md §9, §10).

날짜·시간 규칙(§10):
- 업무 시각은 KST 기준이며, UTC<->KST 변환 레이어를 두지 않는다.
- 애플리케이션에서는 naive datetime 만 다룬다.
- KST 는 OS 로컬 시각이나 TZ 환경변수가 아니라 이 모듈의 고정 오프셋으로 보장한다.
  (Windows 는 time.tzset() 이 없고 TZ="Asia/Seoul" 을 POSIX 처럼 해석하지 않으므로
   TZ 에 의존하면 macOS 와 Windows 가 서로 다른 시각을 기록한다. 한국은 DST 가 없어
   고정 +09:00 으로 항상 정확하며, zoneinfo/tzdata 의존도 생기지 않는다.)
"""
import time
from datetime import datetime, timedelta, timezone
from typing import Literal

import bcrypt
import jwt

KST = timezone(timedelta(hours=9))

# bcrypt 는 입력의 앞 72바이트만 사용한다. 초과분을 조용히 버리면 서로 다른 비밀번호가
# 같은 해시로 검증되므로(UTF-8 한글은 3바이트/자 → 24자에서 도달) 명시적으로 거부한다.
MAX_PASSWORD_BYTES = 72


def now() -> datetime:
    """KST 기준 naive 현재 시각 (OS 로컬 TZ 에 의존하지 않는다)."""
    return datetime.now(KST).replace(tzinfo=None)


def hash_password(plain: str) -> str:
    """bcrypt 해시 생성 (자체 계정 비밀번호 저장용). 72바이트 초과 시 ValueError."""
    pw = plain.encode("utf-8")
    if len(pw) > MAX_PASSWORD_BYTES:
        raise ValueError(f"비밀번호는 UTF-8 {MAX_PASSWORD_BYTES}바이트를 넘을 수 없습니다.")
    return bcrypt.hashpw(pw, bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    """평문과 bcrypt 해시 비교. 형식 오류·길이 초과 시 False."""
    pw = plain.encode("utf-8")
    if len(pw) > MAX_PASSWORD_BYTES:
        # hash_password 가 거부하는 길이이므로 대응하는 해시가 존재할 수 없다.
        # 여기서 막지 않으면 bcrypt 가 앞 72바이트만 비교해 인증이 우회된다.
        return False
    try:
        return bcrypt.checkpw(pw, hashed.encode("utf-8"))
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
