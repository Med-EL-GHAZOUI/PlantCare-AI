"""Export d'image annotée : ordre inférence → filigrane, original intact, options, validation des entrées."""

import io

import numpy as np
import pytest
from fastapi.testclient import TestClient
from PIL import Image

from app import exports
from app.config import Settings
from app.inference import ModelService
from app.main import create_app
from tests.conftest import image_bytes

URL = "/api/v1/predictions/annotated-image"


def textured_jpeg(width: int = 300, height: int = 120) -> bytes:
    rng = np.random.default_rng(3)
    buffer = io.BytesIO()
    Image.fromarray(rng.integers(0, 256, (height, width, 3), dtype=np.uint8)).save(buffer, "JPEG", quality=95)
    return buffer.getvalue()


def post(client, content: bytes, content_type: str = "image/jpeg", **params):
    return client.post(URL, params=params, files={"image": ("leaf.jpg", content, content_type)})


def decode(response) -> np.ndarray:
    return np.asarray(Image.open(io.BytesIO(response.content)).convert("RGB"))


def original_pixels(content: bytes) -> np.ndarray:
    return np.asarray(Image.open(io.BytesIO(content)).convert("RGB"))


def test_returns_a_png_with_banner_and_tracking_headers(client) -> None:
    content = textured_jpeg(300, 120)
    response = post(client, content)
    assert response.status_code == 200
    assert response.headers["content-type"] == "image/png"
    assert response.headers["cache-control"] == "no-store"
    assert response.headers["x-watermark"] == "applied"
    assert len(response.headers["x-prediction-id"]) == 36
    pixels = decode(response)
    assert pixels.shape[1] == 300 and pixels.shape[0] > 120  # même largeur, bannière en plus


def test_image_area_is_identical_to_the_uploaded_image(client) -> None:
    content = textured_jpeg(300, 120)
    pixels = decode(post(client, content))
    assert np.array_equal(pixels[:120], original_pixels(content))  # aucun pixel de la feuille modifié


def test_inference_runs_on_the_original_before_any_watermark(client, monkeypatch) -> None:
    content = textured_jpeg(300, 120)
    events = []
    real_predict = ModelService.predict
    real_compose = exports.compose_annotated_image

    def spy_predict(self, rgb):
        events.append(("predict", rgb.copy()))
        return real_predict(self, rgb)

    def spy_compose(original, caption, config, max_side):
        events.append(("compose", np.asarray(original).copy()))
        return real_compose(original, caption, config, max_side=max_side)

    monkeypatch.setattr(ModelService, "predict", spy_predict)
    monkeypatch.setattr(exports, "compose_annotated_image", spy_compose)
    assert post(client, content).status_code == 200

    assert [name for name, _ in events] == ["predict", "compose"]  # filigrane toujours APRÈS l'inférence
    expected = original_pixels(content)
    assert np.array_equal(events[0][1], expected)  # le modèle voit l'image d'origine sans filigrane
    assert np.array_equal(events[1][1], expected)  # et la copie annotée part de cette même image


def test_watermark_can_be_disabled_per_request_and_only_changes_the_banner(client) -> None:
    content = textured_jpeg(300, 120)
    with_mark = post(client, content, watermark="true")
    without = post(client, content, watermark="false")
    assert with_mark.headers["x-watermark"] == "applied" and without.headers["x-watermark"] == "none"
    a, b = decode(with_mark), decode(without)
    assert a.shape[1] == b.shape[1]  # même largeur ; la hauteur de bannière peut varier (place du filigrane)
    assert np.array_equal(a[:120], b[:120])  # zone de l'image identique
    assert a.shape != b.shape or not np.array_equal(a[120:], b[120:])  # seule la bannière diffère


def test_same_input_gives_the_same_output(client) -> None:
    content = textured_jpeg()
    assert post(client, content).content == post(client, content).content


def test_zero_opacity_keeps_the_layout_but_draws_nothing(make_client) -> None:
    content = textured_jpeg()
    visible = decode(post(make_client(watermark_opacity=1.0), content))
    invisible = decode(post(make_client(watermark_opacity=0.0), content))
    assert visible.shape == invisible.shape  # même mise en page
    assert np.array_equal(visible[:120], invisible[:120])  # feuille intacte dans les deux cas
    assert not np.array_equal(visible[120:], invisible[120:])  # seul le filigrane disparaît


@pytest.mark.parametrize("position", ["bottom-right", "bottom-left", "top-right", "top-left"])
def test_configured_position_moves_the_banner_but_never_covers_the_leaf(make_client, position) -> None:
    content = textured_jpeg(300, 120)
    pixels = decode(post(make_client(watermark_position=position), content))
    banner_height = pixels.shape[0] - 120
    leaf = pixels[banner_height:] if position.startswith("top") else pixels[:120]
    assert np.array_equal(leaf, original_pixels(content))  # feuille intacte, bannière en haut ou en bas


def test_tiny_upload_is_centered_in_a_wider_canvas(client) -> None:
    content = image_bytes(size=(40, 40), noise=True)
    pixels = decode(post(client, content))
    assert pixels.shape[1] == 240
    assert np.array_equal(pixels[:40, 100:140], original_pixels(content))


def test_custom_text_changes_the_output(make_client) -> None:
    content = textured_jpeg()
    default = post(make_client(), content).content
    custom = post(make_client(watermark_text="Coopérative X"), content).content
    assert default != custom


def test_large_uploads_are_downscaled_to_the_export_limit(make_client) -> None:
    pixels = decode(post(make_client(export_max_side=300), textured_jpeg(600, 240)))
    assert pixels.shape[1] == 300


def test_uncertain_prediction_still_exports(make_client) -> None:
    response = post(make_client(confidence_threshold=1.0), textured_jpeg())
    assert response.status_code == 200 and response.headers["content-type"] == "image/png"


def test_nothing_is_written_to_disk(client, tmp_path, monkeypatch) -> None:
    monkeypatch.chdir(tmp_path)
    assert post(client, textured_jpeg()).status_code == 200
    assert list(tmp_path.iterdir()) == []


# ---------- entrées invalides : mêmes règles que /predictions ----------

def assert_error(response, status: int, code: str) -> None:
    assert response.status_code == status
    assert response.json()["error"]["code"] == code


def test_invalid_inputs_are_rejected(client, make_client) -> None:
    assert_error(post(client, b"texte", "text/plain"), 415, "unsupported_media_type")
    assert_error(post(client, b"pas une image", "image/jpeg"), 400, "invalid_image")
    assert_error(post(client, b""), 400, "empty_file")
    assert_error(client.post(URL), 422, "invalid_request")
    assert_error(post(make_client(max_upload_bytes=500), textured_jpeg(300, 300)), 413, "file_too_large")
    assert_error(post(client, image_bytes(size=(8, 8))), 422, "image_too_small")


def test_unavailable_model_returns_503(tmp_path) -> None:
    app = create_app(Settings(_env_file=None, model_dir=tmp_path / "absent"))
    with TestClient(app) as no_model:
        assert_error(post(no_model, textured_jpeg()), 503, "model_unavailable")


def test_inconsistent_watermark_settings_fail_at_startup() -> None:
    with pytest.raises(ValueError):
        Settings(_env_file=None, watermark_text="x" * 41)
