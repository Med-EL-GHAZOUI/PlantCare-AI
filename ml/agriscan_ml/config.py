"""Paramètres partagés entre entraînement et inférence.

Le prétraitement d'inférence doit être identique : décodage JPEG/PNG en RGB, redimensionnement
bilinéaire vers IMAGE_SIZE, valeurs conservées en float32 dans [0, 255]. La mise à l'échelle des
pixels (division par 255) est réalisée DANS le modèle (couche Rescaling), pas dans le pipeline.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass

SEED = 42


@dataclass(frozen=True)
class PreprocessConfig:
    image_height: int = 128
    image_width: int = 128
    channels: int = 3
    color_order: str = "RGB"
    resize_method: str = "bilinear"
    pixel_range_in: str = "[0, 255] float32"
    rescaling_in_model: str = "1/255 -> [0, 1]"

    @property
    def image_size(self) -> tuple[int, int]:
        return (self.image_height, self.image_width)

    def as_dict(self) -> dict:
        return asdict(self)


@dataclass(frozen=True)
class AugmentationConfig:
    """Appliquée uniquement aux données d'entraînement."""

    horizontal_flip: bool = True
    vertical_flip: bool = True
    rotation_factor: float = 0.1  # fraction de tour (0.1 = ±36°)
    zoom_factor: float = 0.1
    brightness_factor: float = 0.1
    contrast_factor: float = 0.1

    def as_dict(self) -> dict:
        return asdict(self)
