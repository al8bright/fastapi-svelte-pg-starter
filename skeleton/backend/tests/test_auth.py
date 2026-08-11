"""인증 유저플로우 테스트 (architecture.md §12)."""
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
