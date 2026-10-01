"""인증 유저플로우 테스트 (ARCHITECTURE.md §12)."""
import pytest

from app.core.security import hash_password, verify_password
from app.services import user_service


def test_ensure_admin_seeds_default_admin(db_session):
    user_service.ensure_admin(db_session)
    admin = user_service.get_by_username(db_session, "admin")
    assert admin is not None
    assert admin.role == "admin"
    # 멱등성: 두 번 호출해도 중복 생성하지 않는다.
    user_service.ensure_admin(db_session)
    assert user_service.get_by_username(db_session, "admin") is not None


def test_login_success_returns_token(client, db_session):
    user_service.ensure_admin(db_session)
    res = client.post("/api/v1/auth/login", json={"username": "admin", "password": "admin123"})
    assert res.status_code == 200
    body = res.json()
    assert body["token_type"] == "bearer"
    assert body["access_token"]


def test_login_wrong_password_401(client, db_session):
    user_service.ensure_admin(db_session)
    res = client.post("/api/v1/auth/login", json={"username": "admin", "password": "nope"})
    assert res.status_code == 401


def test_me_with_token_returns_current_user(client, db_session):
    user_service.ensure_admin(db_session)
    token = client.post(
        "/api/v1/auth/login", json={"username": "admin", "password": "admin123"}
    ).json()["access_token"]
    res = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 200
    body = res.json()
    assert body["username"] == "admin"
    assert body["role"] == "admin"
    assert body["is_active"] is True


def test_me_without_token_401(client):
    assert client.get("/api/v1/auth/me").status_code == 401


def test_login_password_over_72_bytes_is_clean_422_not_500(client, db_session):
    # bcrypt 5 는 72바이트 초과 입력에 ValueError 를 던진다 → 스키마에서 422 로 막혀야 한다(500 금지).
    user_service.ensure_admin(db_session)
    res = client.post("/api/v1/auth/login", json={"username": "admin", "password": "a" * 73})
    assert res.status_code == 422
    # 한글은 UTF-8 3바이트/자 — 25자(75바이트)도 글자 수 제한(128) 안이지만 거부된다.
    res = client.post("/api/v1/auth/login", json={"username": "admin", "password": "가" * 25})
    assert res.status_code == 422


def test_hash_password_rejects_over_72_bytes():
    with pytest.raises(ValueError):
        hash_password("a" * 73)


def test_verify_password_over_72_bytes_is_false_not_truncated():
    # 앞 72바이트가 같아도 초과 입력은 인증되지 않는다(bcrypt 4 의 조용한 절단 우회 방지).
    hashed = hash_password("a" * 72)
    assert verify_password("a" * 72, hashed) is True
    assert verify_password("a" * 72 + "b", hashed) is False
