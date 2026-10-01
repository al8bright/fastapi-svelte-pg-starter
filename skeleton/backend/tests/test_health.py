"""헬스 체크 테스트 (ARCHITECTURE.md §12, §18 TDD)."""


def test_health_ok(client):
    res = client.get("/api/v1/health")
    assert res.status_code == 200
    assert res.json() == {"status": "ok"}


def test_health_db_ok(client):
    res = client.get("/api/v1/health/db")
    assert res.status_code == 200
    body = res.json()
    assert body["db"] == "ok"
    assert body["table"] == "app_meta"
    assert body["rows"] == 0
