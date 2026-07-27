"""Unit tests for Healthcare Flask app"""
import pytest
from app import app


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_home(client):
    response = client.get("/")
    assert response.status_code == 200


def test_health(client):
    response = client.get("/health")
    data = response.get_json()
    assert response.status_code == 200
    assert data["status"] == "healthy"
    assert data["service"] == "healthcare-website"


def test_doctors(client):
    response = client.get("/api/doctors")
    data = response.get_json()
    assert response.status_code == 200
    assert len(data) == 3
    assert data[0]["name"] == "Dr. Soni Bharti"


def test_services(client):
    response = client.get("/api/services")
    data = response.get_json()
    assert response.status_code == 200
    assert len(data) == 3
