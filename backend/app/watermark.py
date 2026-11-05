"""Filigrane visible et image annotée, appliqués à une COPIE de sortie, après l'inférence.

Principes (docs/WATERMARK.md) :
- l'image d'origine n'est jamais modifiée (toutes les fonctions retournent de nouvelles images) ;
- le filigrane est dessiné dans une bannière ajoutée à côté de l'image, jamais sur la feuille : il ne
  masque donc pas d'indice visuel ;
- un filigrane visible n'est pas une preuve d'authenticité et n'empêche pas la manipulation de l'image.
"""

from __future__ import annotations

import unicodedata
from dataclasses import dataclass, replace

from PIL import Image, ImageDraw, ImageFont

POSITIONS = ("bottom-right", "bottom-left", "top-right", "top-left")
BANNER_COLOR = (30, 30, 30)
CAPTION_COLOR = (255, 255, 255)
DISCLAIMER_LINE = "Dépistage par IA, pas un diagnostic confirmé"
# Largeur minimale de l'image annotée : une très petite photo est centrée (jamais agrandie) pour que la
# bannière ait la place d'afficher légende et filigrane sans toucher aux pixels de l'image.
MIN_CANVAS_WIDTH = 240
MAX_CAPTION_LINES = 6

Rect = tuple[int, int, int, int]  # x0, y0, x1, y1 (x1 et y1 exclus)


def renderable_text(text: str) -> str:
    """Texte dessiné par la police intégrée de Pillow : accents retirés (é → e), caractères hors ASCII supprimés.

    La police par défaut de Pillow rend mal les lettres accentuées ; plutôt qu'un glyphe cassé, on dessine
    la lettre de base. Les écritures non latines (arabe, par exemple) ne sont pas prises en charge.
    """
    decomposed = unicodedata.normalize("NFKD", text)
    return decomposed.encode("ascii", "ignore").decode("ascii")


@dataclass(frozen=True)
class WatermarkConfig:
    text: str = "AgriScan AI"
    position: str = "bottom-right"
    opacity: float = 0.6  # 0 = invisible, 1 = opaque
    size_ratio: float = 0.04  # hauteur de police / largeur de l'image
    margin_ratio: float = 0.02  # marge / largeur de l'image
    color: tuple[int, int, int] = (255, 255, 255)
    enabled: bool = True

    def __post_init__(self) -> None:
        if not self.text.strip() or len(self.text) > 40:
            raise ValueError("Le texte du filigrane doit contenir de 1 à 40 caractères")
        if not renderable_text(self.text).strip():
            raise ValueError("Le texte du filigrane doit contenir au moins un caractère latin affichable")
        if self.position not in POSITIONS:
            raise ValueError(f"Position inconnue : {self.position} (choix : {', '.join(POSITIONS)})")
        if not 0.0 <= self.opacity <= 1.0:
            raise ValueError("L'opacité doit être comprise entre 0 et 1")
        if not 0.0 < self.size_ratio <= 0.2:
            raise ValueError("La taille relative doit être comprise entre 0 (exclu) et 0,2")
        if not 0.0 <= self.margin_ratio <= 0.1:
            raise ValueError("La marge relative doit être comprise entre 0 et 0,1")
        if len(self.color) != 3 or any(not 0 <= channel <= 255 for channel in self.color):
            raise ValueError("La couleur doit être un triplet RGB (0 à 255)")

    def with_enabled(self, enabled: bool) -> WatermarkConfig:
        return replace(self, enabled=enabled)


@dataclass(frozen=True)
class AnnotatedLayout:
    size: tuple[int, int]
    image_rect: Rect  # zone de l'image d'origine (intacte)
    banner_rect: Rect  # zone de la bannière (légende + filigrane)
    caption_rect: Rect | None
    watermark_rect: Rect | None


@dataclass(frozen=True)
class _Metrics:
    font: ImageFont.FreeTypeFont
    text: str
    stroke: int
    left: int
    top: int
    width: int
    height: int
    margin: int


def _font(size_px: int) -> ImageFont.FreeTypeFont:
    return ImageFont.load_default(size=size_px)  # police Aileron incluse dans Pillow : rendu identique partout


def _metrics(image_width: int, config: WatermarkConfig) -> _Metrics:
    size_px = max(10, round(image_width * config.size_ratio))
    margin = max(2, round(image_width * config.margin_ratio))
    stroke = 1 if size_px >= 14 else 0
    font = _font(size_px)
    text = renderable_text(config.text)
    left, top, right, bottom = ImageDraw.Draw(Image.new("RGB", (1, 1))).textbbox(
        (0, 0), text, font=font, stroke_width=stroke
    )
    return _Metrics(font, text, stroke, left, top, right - left, bottom - top, margin)


def _place(region: Rect, metrics: _Metrics, position: str) -> Rect:
    x0, y0, x1, y1 = region
    x = x1 - metrics.margin - metrics.width if position.endswith("right") else x0 + metrics.margin
    y = y1 - metrics.margin - metrics.height if position.startswith("bottom") else y0 + metrics.margin
    return (x, y, x + metrics.width, y + metrics.height)


def _paint(canvas: Image.Image, rect: Rect, metrics: _Metrics, config: WatermarkConfig) -> None:
    """Dessine le texte avec transparence sur la zone `rect` de `canvas` (modifié sur place)."""
    box = (max(rect[0], 0), max(rect[1], 0), min(rect[2], canvas.width), min(rect[3], canvas.height))
    if box[2] <= box[0] or box[3] <= box[1]:
        return
    alpha = round(255 * config.opacity)
    overlay = Image.new("RGBA", (box[2] - box[0], box[3] - box[1]), (0, 0, 0, 0))
    ImageDraw.Draw(overlay).text(
        (rect[0] - box[0] - metrics.left, rect[1] - box[1] - metrics.top),
        metrics.text,
        font=metrics.font,
        fill=(*config.color, alpha),
        stroke_width=metrics.stroke,
        stroke_fill=(0, 0, 0, alpha),
    )
    region = canvas.crop(box).convert("RGBA")
    canvas.paste(Image.alpha_composite(region, overlay).convert("RGB"), box[:2])


def apply_watermark(
    image: Image.Image, config: WatermarkConfig, region: Rect | None = None
) -> tuple[Image.Image, Rect | None]:
    """Retourne (copie filigranée, rectangle du filigrane). `image` n'est jamais modifiée.

    `region` limite le coin de placement à une zone de l'image (par défaut : l'image entière).
    Désactivé, la copie est identique et le rectangle est None.
    """
    output = image.convert("RGB").copy()
    if not config.enabled:
        return output, None
    metrics = _metrics(output.width, config)
    rect = _place(region or (0, 0, output.width, output.height), metrics, config.position)
    _paint(output, rect, metrics, config)
    return output, rect


def pretty_class(label: str) -> str:
    return label.removeprefix("Tomato___").replace("_", " ").strip()


def build_caption(status: str, predicted_class: str | None, score: float) -> list[str]:
    if status == "uncertain" or predicted_class is None:
        first = "Résultat incertain - aucune classe proposée"
    else:
        first = f"{pretty_class(predicted_class)} - score du modèle {score * 100:.0f}%"
    return [first, DISCLAIMER_LINE]


def _wrap(text: str, font: ImageFont.FreeTypeFont, max_width: int) -> list[str]:
    """Retour à la ligne par mots ; un mot plus large que la zone est coupé. Au plus MAX_CAPTION_LINES lignes."""
    lines: list[str] = []
    current = ""
    for word in text[:2000].split():  # borne la quantité de texte traitée
        candidate = word if not current else f"{current} {word}"
        if font.getlength(candidate) <= max_width:
            current = candidate
            continue
        if current:
            lines.append(current)
        current = word
        while font.getlength(current) > max_width and len(current) > 1:
            low, high = 1, len(current) - 1  # plus grand préfixe qui tient (recherche dichotomique)
            while low < high:
                middle = (low + high + 1) // 2
                if font.getlength(current[:middle]) <= max_width:
                    low = middle
                else:
                    high = middle - 1
            lines.append(current[:low])
            current = current[low:]
            if len(lines) > MAX_CAPTION_LINES:
                break  # inutile de découper davantage : la suite est tronquée plus bas
        if len(lines) > MAX_CAPTION_LINES:
            break
    if current:
        lines.append(current)
    if len(lines) > MAX_CAPTION_LINES:
        last = lines[MAX_CAPTION_LINES - 1]
        while len(last) > 1 and font.getlength(last + "...") > max_width:
            last = last[:-1]
        lines = [*lines[: MAX_CAPTION_LINES - 1], last + "..."]
    return lines


def compose_annotated_image(
    original: Image.Image,
    caption_lines: list[str],
    config: WatermarkConfig,
    max_side: int = 1024,
) -> tuple[Image.Image, AnnotatedLayout]:
    """Image annotée : l'image d'origine (réduite si besoin) + une bannière avec la légende et le filigrane.

    Le filigrane est placé dans la bannière (en haut ou en bas selon `config.position`) : la zone de
    l'image reste pixel pour pixel celle de la copie redimensionnée. Une image plus étroite que
    MIN_CANVAS_WIDTH est centrée sans être agrandie. La légende passe à la ligne dans l'espace laissé
    libre par le filigrane.
    """
    image = original.convert("RGB")
    if max(image.size) > max_side:
        scale = max_side / max(image.size)
        image = image.resize((max(1, round(image.width * scale)), max(1, round(image.height * scale))),
                             Image.Resampling.LANCZOS)
    width, height = image.size
    canvas_width = max(width, MIN_CANVAS_WIDTH)
    offset_x = (canvas_width - width) // 2

    caption_px = min(28, max(12, round(canvas_width * 0.035)))
    pad = max(6, round(canvas_width * 0.02))
    line_height = caption_px + 4
    metrics = _metrics(canvas_width, config) if config.enabled else None

    # Espace horizontal de la légende : tout le bandeau, moins la place du filigrane de son côté.
    caption_x0, caption_x1 = pad, canvas_width - pad
    if metrics is not None:
        if config.position.endswith("right"):
            caption_x1 = canvas_width - metrics.margin - metrics.width - pad
        else:
            caption_x0 = metrics.margin + metrics.width + pad
    caption_font = _font(caption_px)
    wrapped: list[str] = []
    if caption_x1 - caption_x0 >= 20:
        for line in caption_lines:
            wrapped.extend(_wrap(renderable_text(line), caption_font, caption_x1 - caption_x0))

    banner_height = 2 * pad + len(wrapped) * line_height
    if metrics is not None:
        banner_height = max(banner_height, metrics.height + 2 * metrics.margin)

    at_top = config.position.startswith("top")
    image_top = banner_height if at_top else 0
    image_rect: Rect = (offset_x, image_top, offset_x + width, image_top + height)
    banner_rect: Rect = (0, 0, canvas_width, banner_height) if at_top else (0, height, canvas_width, height + banner_height)
    canvas = Image.new("RGB", (canvas_width, height + banner_height), BANNER_COLOR)
    canvas.paste(image, (image_rect[0], image_rect[1]))

    caption_rect: Rect | None = None
    if wrapped:
        draw = ImageDraw.Draw(canvas)
        top = banner_rect[1] + pad
        for index, line in enumerate(wrapped):
            draw.text((caption_x0, top + index * line_height), line, font=caption_font, fill=CAPTION_COLOR)
        caption_rect = (caption_x0, top, caption_x1, top + len(wrapped) * line_height)

    watermark_rect: Rect | None = None
    if metrics is not None:
        watermark_rect = _place(banner_rect, metrics, config.position)
        _paint(canvas, watermark_rect, metrics, config)

    return canvas, AnnotatedLayout(canvas.size, image_rect, banner_rect, caption_rect, watermark_rect)
