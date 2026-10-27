import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from tests.conftest import CLASSES, image_bytes

PREDICT = "/api/v1/predictions"


def post_image(client, content: bytes, content_type: str = "image/jpeg", filename: str = "leaf.jpg"):
    return client.post(PREDICT, files={"image": (filename, content, content_type)})


def assert_error(response, status: int, code: str) -> None:
    assert response.status_code == status
    body = response.json()
    assert set(body) == {"error"} and body["error"]["code"] == code
    assert isinstance(body["error"]["message"], str) and body["error"]["message"]


# ---------- /health et /model/info ----------

def test_health_reports_model_loaded(client) -> None:
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "model_loaded": True}


def test_model_info_matches_trained_mapping(client) -> None:
    response = client.get("/api/v1/model/info")
    assert response.status_code == 200
    info = response.json()
    assert info["supported_classes"] == CLASSES
    assert info["model_version"].startswith("tiny-")
    assert (info["input_height"], info["input_width"]) == (32, 32)
    assert info["confidence_is_calibrated"] is False
    assert info["out_of_scope_detection"] is False
    assert info["confidence_threshold"] is None


def test_without_model_health_ok_but_not_loaded_and_inference_503(tmp_path) -> None:
    app = create_app(Settings(model_dir=tmp_path / "absent"))
    with TestClient(app) as no_model_client:
        assert no_model_client.get("/api/v1/health").json() == {"status": "ok", "model_loaded": False}
        assert_error(no_model_client.get("/api/v1/model/info"), 503, "model_unavailable")
        assert_error(post_image(no_model_client, image_bytes()), 503, "model_unavailable")


# ---------- /predictions : cas valides ----------

@pytest.mark.parametrize(("fmt", "content_type"), [("JPEG", "image/jpeg"), ("PNG", "image/png")])
def test_valid_image_returns_structured_prediction(client, fmt, content_type) -> None:
    response = post_image(client, image_bytes(fmt), content_type)
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "prediction_available"
    assert body["predicted_class"] in CLASSES
    assert set(body["scores"]) == set(CLASSES)
    assert sum(body["scores"].values()) == pytest.approx(1.0, abs=1e-4)
    assert body["confidence"] == pytest.approx(max(body["scores"].values()))
    assert body["scores"][body["predicted_class"]] == pytest.approx(body["confidence"])
    assert body["model_version"].startswith("tiny-")
    assert "pas un diagnostic" in body["disclaimer"]
    assert body["prediction_id"]


def test_prediction_is_deterministic_and_ids_are_unique(client) -> None:
    first = post_image(client, image_bytes()).json()
    second = post_image(client, image_bytes()).json()
    assert first["scores"] == second["scores"]
    assert first["prediction_id"] != second["prediction_id"]


def test_client_filename_is_ignored(client) -> None:
    response = post_image(client, image_bytes(), filename="../../etc/passwd.jpg")
    assert response.status_code == 200


def test_model_is_loaded_once_and_reused(client, model_service) -> None:
    for _ in range(3):
        assert post_image(client, image_bytes()).status_code == 200
    assert client.app.state.model_service is model_service


# ---------- politique d'incertitude ----------

def test_uncertain_status_when_below_threshold(make_client) -> None:
    uncertain_client = make_client(confidence_threshold=1.0)  # le score max est toujours < 1
    body = post_image(uncertain_client, image_bytes()).json()
    assert body["status"] == "uncertain"
    assert body["predicted_class"] is None
    assert 0.0 < body["confidence"] < 1.0


def test_threshold_exposed_in_model_info(make_client) -> None:
    info = make_client(confidence_threshold=0.5).get("/api/v1/model/info").json()
    assert info["confidence_threshold"] == 0.5


# ---------- /predictions : entrées invalides ----------

def test_missing_image_field_is_422(client) -> None:
    assert_error(client.post(PREDICT), 422, "invalid_request")
    assert_error(client.post(PREDICT, files={"other": ("a.jpg", image_bytes(), "image/jpeg")}), 422, "invalid_request")


def test_unsupported_declared_type_is_415(client) -> None:
    assert_error(post_image(client, b"hello", "text/plain", "a.txt"), 415, "unsupported_media_type")


def test_real_content_checked_not_declared_type(client) -> None:
    assert_error(post_image(client, image_bytes("GIF"), "image/png"), 415, "unsupported_media_type")
    assert_error(post_image(client, b"ceci n'est pas une image", "image/jpeg"), 400, "invalid_image")


def test_truncated_image_is_400(client) -> None:
    assert_error(post_image(client, image_bytes("JPEG", (200, 200))[:150]), 400, "invalid_image")


def test_empty_file_is_400(client) -> None:
    assert_error(post_image(client, b""), 400, "empty_file")


def test_file_too_large_is_413(make_client) -> None:
    small_limit = make_client(max_upload_bytes=1000)
    assert_error(post_image(small_limit, image_bytes("PNG", (200, 200), noise=True)), 413, "file_too_large")


def test_too_small_and_too_many_pixels_are_422(make_client) -> None:
    assert_error(post_image(make_client(min_image_side=100), image_bytes(size=(64, 48))), 422, "image_too_small")
    assert_error(post_image(make_client(max_image_pixels=1000), image_bytes(size=(64, 48))), 422,
                 "image_dimensions_too_large")


# ---------- erreurs transverses ----------

def test_unknown_route_and_wrong_method_use_error_format(client) -> None:
    assert_error(client.get("/api/v1/nothing"), 404, "not_found")
    assert_error(client.get(PREDICT), 405, "method_not_allowed")


def test_internal_error_leaks_nothing(model_service) -> None:
    class Exploding:
        model_version, class_names = "x", ["a"]
        input_height = input_width = 32

        def predict(self, _):
            raise RuntimeError("secret C:\\internal\\path.py")

    app = create_app(Settings(), model_service=Exploding())
    with TestClient(app, raise_server_exceptions=False) as failing_client:
        response = post_image(failing_client, image_bytes())
    assert_error(response, 500, "internal_error")
    assert "secret" not in response.text and "internal" not in response.json()["error"]["message"].lower()


def test_cors_disabled_by_default_and_explicit_when_configured(make_client) -> None:
    headers = {"Origin": "http://evil.example", "Access-Control-Request-Method": "POST"}
    assert "access-control-allow-origin" not in make_client().options(PREDICT, headers=headers).headers
    allowed = make_client(cors_origins=["http://app.example"])
    ok = allowed.options(PREDICT, headers={**headers, "Origin": "http://app.example"})
    assert ok.headers.get("access-control-allow-origin") == "http://app.example"
    assert "access-control-allow-origin" not in allowed.options(PREDICT, headers=headers).headers
