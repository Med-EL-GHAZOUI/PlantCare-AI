"""Tests unitaires du filigrane : placement, dimensions, transparence, original intact, preuve non masquée."""

import numpy as np
import pytest
from PIL import Image
from pydantic import ValidationError

from app.config import Settings
from app.watermark import (
    BANNER_COLOR,
    MIN_CANVAS_WIDTH,
    POSITIONS,
    WatermarkConfig,
    apply_watermark,
    build_caption,
    compose_annotated_image,
    pretty_class,
    renderable_text,
)

BACKGROUND = (90, 90, 90)


def blank(width: int = 400, height: int = 300, color=BACKGROUND) -> Image.Image:
    return Image.new("RGB", (width, height), color)


def textured(width: int, height: int) -> Image.Image:
    rng = np.random.default_rng(0)
    return Image.fromarray(rng.integers(0, 256, (height, width, 3), dtype=np.uint8))


def changed_bbox(before: Image.Image, after: Image.Image) -> tuple[int, int, int, int] | None:
    mask = np.any(np.asarray(before) != np.asarray(after), axis=2)
    ys, xs = np.nonzero(mask)
    return None if xs.size == 0 else (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)


def intersects(a, b) -> bool:
    return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


# ---------- configuration ----------

@pytest.mark.parametrize("kwargs", [
    {"text": ""}, {"text": "   "}, {"text": "x" * 41}, {"position": "center"}, {"opacity": -0.1}, {"opacity": 1.1},
    {"size_ratio": 0}, {"size_ratio": 0.5}, {"margin_ratio": -1}, {"margin_ratio": 0.5}, {"color": (256, 0, 0)},
])
def test_invalid_config_is_rejected(kwargs) -> None:
    with pytest.raises(ValueError):
        WatermarkConfig(**kwargs)


def test_defaults_match_the_documented_suggestion() -> None:
    config = WatermarkConfig()
    assert config.text == "AgriScan AI" and config.position == "bottom-right" and config.enabled


def test_settings_validate_watermark_options() -> None:
    assert Settings(_env_file=None).watermark_position == "bottom-right"
    with pytest.raises(ValidationError):
        Settings(_env_file=None, watermark_position="center")
    with pytest.raises(ValidationError):
        Settings(_env_file=None, watermark_opacity=2)


# ---------- original intact ----------

def test_apply_watermark_never_modifies_the_input_image() -> None:
    original = textured(300, 200)
    snapshot = original.tobytes()
    output, rect = apply_watermark(original, WatermarkConfig())
    assert original.tobytes() == snapshot
    assert output is not original and output.size == original.size
    assert rect is not None and output.tobytes() != snapshot


def test_compose_never_modifies_the_input_image() -> None:
    original = textured(300, 200)
    snapshot = original.tobytes()
    compose_annotated_image(original, ["a", "b"], WatermarkConfig())
    assert original.tobytes() == snapshot


def test_disabled_watermark_returns_an_identical_copy() -> None:
    original = textured(200, 100)
    output, rect = apply_watermark(original, WatermarkConfig(enabled=False))
    assert rect is None and output is not original and output.tobytes() == original.tobytes()


# ---------- placement ----------

@pytest.mark.parametrize("position", POSITIONS)
def test_watermark_is_placed_in_the_requested_corner_with_margins(position) -> None:
    base = blank(400, 300)
    output, rect = apply_watermark(base, WatermarkConfig(position=position))
    margin = max(2, round(400 * 0.02))
    x0, y0, x1, y1 = rect
    assert (x1 == 400 - margin) if position.endswith("right") else (x0 == margin)
    assert (y1 == 300 - margin) if position.startswith("bottom") else (y0 == margin)

    box = changed_bbox(base, output)
    assert box is not None
    assert x0 <= box[0] and box[2] <= x1 and y0 <= box[1] and box[3] <= y1  # rien ne déborde du rectangle
    assert box[0] >= margin and box[1] >= margin and box[2] <= 400 - margin and box[3] <= 300 - margin
    half_x, half_y = 200, 150
    assert (box[0] >= half_x) if position.endswith("right") else (box[2] <= half_x)
    assert (box[1] >= half_y) if position.startswith("bottom") else (box[3] <= half_y)


def test_size_scales_with_image_width_and_with_size_ratio() -> None:
    small = apply_watermark(blank(400, 300), WatermarkConfig())[1]
    large = apply_watermark(blank(800, 600), WatermarkConfig())[1]
    assert (large[2] - large[0]) == pytest.approx(2 * (small[2] - small[0]), abs=4)
    bigger = apply_watermark(blank(400, 300), WatermarkConfig(size_ratio=0.08))[1]
    assert (bigger[2] - bigger[0]) > 1.7 * (small[2] - small[0])


def test_margin_ratio_moves_the_watermark_inward() -> None:
    tight = apply_watermark(blank(), WatermarkConfig(margin_ratio=0.0))[1]
    loose = apply_watermark(blank(), WatermarkConfig(margin_ratio=0.1))[1]
    assert tight[2] > loose[2] and tight[3] > loose[3]


# ---------- transparence ----------

def test_opacity_zero_is_invisible_and_one_is_fully_opaque() -> None:
    base = blank()
    invisible, _ = apply_watermark(base, WatermarkConfig(opacity=0.0))
    assert invisible.tobytes() == base.tobytes()

    opaque, _ = apply_watermark(base, WatermarkConfig(opacity=1.0, color=(255, 255, 255)))
    pixels = np.asarray(opaque).reshape(-1, 3)
    assert (pixels == (255, 255, 255)).all(axis=1).any()  # le texte atteint exactement sa couleur
    assert (pixels == (0, 0, 0)).all(axis=1).any()  # contour sombre opaque


def test_intermediate_opacity_blends_with_the_background() -> None:
    base = blank()
    half, _ = apply_watermark(base, WatermarkConfig(opacity=0.5, color=(255, 255, 255)))
    array = np.asarray(half).astype(int)
    assert array.max() < 255  # jamais opaque
    assert array.max() > BACKGROUND[0]  # mais visible (éclaircit le fond)
    assert array.min() < BACKGROUND[0]  # le contour assombrit légèrement


def test_visibility_increases_monotonically_with_opacity() -> None:
    base = np.asarray(blank()).astype(int)
    strengths = []
    for opacity in (0.0, 0.25, 0.5, 0.75, 1.0):
        output, _ = apply_watermark(blank(), WatermarkConfig(opacity=opacity))
        strengths.append(int(np.abs(np.asarray(output).astype(int) - base).sum()))
    assert strengths == sorted(strengths) and strengths[0] == 0 and strengths[-1] > strengths[1] > 0


# ---------- image annotée : dimensions et preuve visuelle intacte ----------

def test_output_dimensions_without_resizing() -> None:
    original = textured(640, 480)
    canvas, layout = compose_annotated_image(original, ["ligne 1", "ligne 2"], WatermarkConfig(), max_side=1024)
    assert canvas.size == layout.size and canvas.width == 640
    assert layout.image_rect == (0, 0, 640, 480)
    assert canvas.height == 480 + (layout.banner_rect[3] - layout.banner_rect[1]) and layout.banner_rect[1] == 480
    assert layout.banner_rect[3] == canvas.height


def test_large_images_are_downscaled_to_the_maximum_side() -> None:
    canvas, layout = compose_annotated_image(textured(640, 480), ["a"], WatermarkConfig(), max_side=320)
    assert canvas.width == 320
    assert layout.image_rect[2] - layout.image_rect[0] == 320 and layout.image_rect[3] - layout.image_rect[1] == 240


@pytest.mark.parametrize("position", POSITIONS)
@pytest.mark.parametrize("size", [(32, 32), (64, 64), (200, 120), (640, 480), (300, 900)])
def test_watermark_never_covers_the_image_or_the_caption(position, size) -> None:
    original = textured(*size)
    canvas, layout = compose_annotated_image(
        original, build_caption("prediction_available", "Tomato___Late_blight", 0.91), WatermarkConfig(position=position)
    )
    bx0, by0, bx1, by1 = layout.banner_rect
    wx0, wy0, wx1, wy1 = layout.watermark_rect
    assert layout.size[0] >= MIN_CANVAS_WIDTH
    assert bx0 <= wx0 and by0 <= wy0 and wx1 <= bx1 and wy1 <= by1  # dans la bannière
    assert not intersects(layout.watermark_rect, layout.image_rect)
    if layout.caption_rect is not None:
        assert not intersects(layout.watermark_rect, layout.caption_rect)
    # La zone de l'image est strictement celle de l'original (aucun pixel masqué ni modifié)
    assert np.array_equal(np.asarray(canvas.crop(layout.image_rect)), np.asarray(original))
    # Bannière en haut pour les positions « top », en bas sinon
    assert (layout.banner_rect[1] == 0) == position.startswith("top")


def test_without_watermark_the_banner_is_plain_outside_the_caption() -> None:
    canvas, layout = compose_annotated_image(textured(300, 200), ["a", "b"], WatermarkConfig(enabled=False))
    assert layout.watermark_rect is None
    _x0, _y0, x1, y1 = layout.banner_rect
    assert canvas.getpixel((x1 - 3, y1 - 3)) == BANNER_COLOR


def test_watermark_and_caption_rectangles_for_left_positions_do_not_collide() -> None:
    _, layout = compose_annotated_image(textured(500, 300), ["texte"], WatermarkConfig(position="bottom-left"))
    assert layout.caption_rect[0] >= layout.watermark_rect[2]


def test_long_caption_wraps_inside_the_banner_without_overlapping() -> None:
    canvas, layout = compose_annotated_image(textured(300, 100), ["mot " * 80], WatermarkConfig())
    assert canvas.width == 300
    assert layout.caption_rect is not None and layout.caption_rect[2] <= layout.watermark_rect[0]
    assert layout.caption_rect[3] <= layout.banner_rect[3]  # la légende reste dans la bannière
    assert not intersects(layout.caption_rect, layout.image_rect)


def test_unbreakable_text_is_hard_wrapped_and_line_count_is_capped() -> None:
    small_canvas, small = compose_annotated_image(textured(300, 100), ["x"], WatermarkConfig())
    huge_canvas, huge = compose_annotated_image(textured(300, 100), ["x" * 5000], WatermarkConfig())
    assert huge.caption_rect is not None
    line_height = min(28, max(12, round(300 * 0.035))) + 4
    assert (huge.caption_rect[3] - huge.caption_rect[1]) <= 6 * line_height  # au plus 6 lignes
    assert huge_canvas.width == small_canvas.width == 300 and small.caption_rect is not None


def test_small_plantvillage_sized_image_shows_the_whole_caption_on_several_lines() -> None:
    _, layout = compose_annotated_image(
        textured(256, 256), build_caption("prediction_available", "Tomato___Target_Spot", 0.74), WatermarkConfig()
    )
    lines = (layout.caption_rect[3] - layout.caption_rect[1]) // (max(12, round(256 * 0.035)) + 4)
    assert lines >= 3  # retour à la ligne plutôt que texte coupé


# ---------- légende ----------

def test_caption_texts() -> None:
    available = build_caption("prediction_available", "Tomato___Late_blight", 0.914)
    assert available[0] == "Late blight - score du modèle 91%"
    assert "pas un diagnostic" in available[1]
    uncertain = build_caption("uncertain", None, 0.55)
    assert "incertain" in uncertain[0] and "Late blight" not in uncertain[0]
    assert pretty_class("Tomato___Spider_mites Two-spotted_spider_mite") == "Spider mites Two-spotted spider mite"


def test_tiny_images_are_centered_not_enlarged() -> None:
    original = textured(32, 32)
    canvas, layout = compose_annotated_image(original, ["a", "b"], WatermarkConfig())
    assert canvas.width == MIN_CANVAS_WIDTH
    assert layout.image_rect[2] - layout.image_rect[0] == 32  # pixels de l'image jamais agrandis
    assert layout.image_rect[0] == (MIN_CANVAS_WIDTH - 32) // 2
    assert np.array_equal(np.asarray(canvas.crop(layout.image_rect)), np.asarray(original))


def test_accents_are_flattened_for_rendering_and_config_needs_latin_text() -> None:
    assert renderable_text("Dépistage - Résultat incertain à ç") == "Depistage - Resultat incertain a c"
    assert WatermarkConfig(text="Coopérative X").text == "Coopérative X"  # la valeur saisie est conservée
    with pytest.raises(ValueError):
        WatermarkConfig(text="العربية")  # aucun caractère latin affichable
