"""Validation du contenu réel des images envoyées (jamais fondée sur le nom ou l'extension seuls)."""

from __future__ import annotations

import io
import warnings

import numpy as np
from fastapi import UploadFile
from PIL import Image, UnidentifiedImageError

from app.config import Settings
from app.errors import ApiError

ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png"}
ALLOWED_FORMATS = {"JPEG", "PNG"}
READ_CHUNK = 64 * 1024


def read_limited(upload: UploadFile, max_bytes: int) -> bytes:
    """Lit le fichier par blocs et s'arrête dès que la limite est dépassée."""
    buffer = bytearray()
    while chunk := upload.file.read(READ_CHUNK):
        buffer.extend(chunk)
        if len(buffer) > max_bytes:
            raise ApiError(413, "file_too_large", f"Fichier trop volumineux (maximum {max_bytes // (1024 * 1024)} Mo).")
    if not buffer:
        raise ApiError(400, "empty_file", "Le fichier envoyé est vide.")
    return bytes(buffer)


def decode_image(upload: UploadFile, settings: Settings) -> np.ndarray:
    """Valide puis décode l'image en tableau RGB uint8 (H, W, 3). Lève ApiError sinon."""
    if upload.content_type not in ALLOWED_CONTENT_TYPES:
        raise ApiError(415, "unsupported_media_type", "Format non pris en charge : utilisez JPEG ou PNG.")

    data = read_limited(upload, settings.max_upload_bytes)
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(data)) as probe:
                image_format, (width, height) = probe.format, probe.size
                if image_format not in ALLOWED_FORMATS:
                    raise ApiError(415, "unsupported_media_type", "Format non pris en charge : utilisez JPEG ou PNG.")
                if width * height > settings.max_image_pixels:
                    raise ApiError(422, "image_dimensions_too_large", "Image trop grande (dimensions).")
                if min(width, height) < settings.min_image_side:
                    raise ApiError(422, "image_too_small", f"Image trop petite (minimum {settings.min_image_side} px).")
                probe.verify()
            with Image.open(io.BytesIO(data)) as image:  # verify() invalide l'objet : on rouvre
                return np.asarray(image.convert("RGB"), dtype=np.uint8)
    except ApiError:
        raise
    except (UnidentifiedImageError, OSError, SyntaxError, ValueError, Image.DecompressionBombError,
            Image.DecompressionBombWarning) as exc:
        raise ApiError(400, "invalid_image", "Image illisible ou corrompue.") from exc
