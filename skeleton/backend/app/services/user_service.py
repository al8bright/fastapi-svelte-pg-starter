"""사용자/인증 서비스 (architecture.md §8) — 비즈니스 로직.

라우터는 얇게 두고, 사용자 조회·인증·시드는 여기서 처리한다.
"""
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import hash_password, verify_password
from app.models.user import User, UserRole
from app.services.exceptions import ServiceError

# 기본 관리자 (처음 실행 시 자동 생성). 운영에서는 즉시 비밀번호를 변경해야 한다.
DEFAULT_ADMIN_USERNAME = "admin"
DEFAULT_ADMIN_PASSWORD = "admin123"


def get_by_username(db: Session, username: str) -> User | None:
    return db.execute(select(User).where(User.username == username)).scalar_one_or_none()


def get_by_id(db: Session, user_id: int) -> User | None:
    return db.get(User, user_id)


def create_user(
    db: Session,
    *,
    username: str,
    password: str,
    role: UserRole = UserRole.USER,
) -> User:
    if get_by_username(db, username) is not None:
        raise ServiceError("user_exists", "이미 존재하는 사용자입니다.")
    user = User(
        username=username,
        hashed_password=hash_password(password),
        role=role.value,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def authenticate(db: Session, username: str, password: str) -> User:
    """성공 시 User, 실패 시 ServiceError("invalid_credentials")."""
    user = get_by_username(db, username)
    if user is None or not verify_password(password, user.hashed_password):
        raise ServiceError("invalid_credentials", "아이디 또는 비밀번호가 올바르지 않습니다.")
    if not user.is_active:
        raise ServiceError("inactive_user", "비활성화된 계정입니다.")
    return user


def ensure_admin(db: Session) -> None:
    """관리자 계정이 하나도 없으면 기본 관리자(admin/admin123)를 생성한다 (idempotent)."""
    has_admin = db.execute(
        select(User.id).where(User.role == UserRole.ADMIN.value).limit(1)
    ).first()
    if has_admin is not None:
        return
    if get_by_username(db, DEFAULT_ADMIN_USERNAME) is not None:
        return
    create_user(
        db,
        username=DEFAULT_ADMIN_USERNAME,
        password=DEFAULT_ADMIN_PASSWORD,
        role=UserRole.ADMIN,
    )
