import pytest

from app import create_app


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setenv("APP_VERSION", "1.0.0")
    monkeypatch.setenv("HEALTH_FAILURE", "false")

    app = create_app()
    app.config["TESTING"] = True

    return app.test_client()


@pytest.mark.parametrize(
    "endpoint, expected_status, expected_data",
    [
        ("/health", 200, {"status": "ok"}),
        ("/version", 200, {"version": "1.0.0"}),
    ],
)
def test_api_endpoints(client, endpoint, expected_status, expected_data):
    response = client.get(endpoint)

    assert response.status_code == expected_status
    assert response.get_json() == expected_data


def test_health_failure(monkeypatch):
    monkeypatch.setenv("HEALTH_FAILURE", "true")

    app = create_app()
    client = app.test_client()

    response = client.get("/health")

    assert response.status_code == 503
    assert response.get_json() == {"status": "error"}


def test_custom_version(monkeypatch):
    monkeypatch.setenv("APP_VERSION", "2.0.0")

    app = create_app()
    client = app.test_client()

    response = client.get("/version")

    assert response.status_code == 200
    assert response.get_json() == {"version": "2.0.0"}


def test_unknown_endpoint(client):
    response = client.get("/unknown")

    assert response.status_code == 404

def test_intentional_failure():
    assert 1 == 2