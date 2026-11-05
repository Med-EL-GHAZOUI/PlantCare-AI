"""Retire les métadonnées EXIF (dont les coordonnées GPS) d'images avant leur ajout au jeu de terrain.

Les pixels ne sont pas modifiés (recompression JPEG qualité 95 ; PNG sans perte). L'orientation EXIF est
appliquée aux pixels avant le retrait, pour que l'image ne soit pas affichée tournée.

Usage (depuis ml/) :
    .venv\\Scripts\\python.exe scripts/strip_exif.py --src data/field/raw_photos --dst data/field/images
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageOps

EXTENSIONS = {".jpg", ".jpeg", ".png"}


def strip(source: Path, destination: Path) -> None:
    with Image.open(source) as image:
        clean = ImageOps.exif_transpose(image).convert("RGB")  # applique l'orientation puis oublie les métadonnées
    destination.parent.mkdir(parents=True, exist_ok=True)
    if source.suffix.lower() == ".png":
        clean.save(destination, "PNG")
    else:
        clean.save(destination, "JPEG", quality=95)  # aucun paramètre exif= : rien n'est réécrit


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--src", type=Path, required=True)
    parser.add_argument("--dst", type=Path, required=True)
    args = parser.parse_args()
    if args.src.resolve() == args.dst.resolve():
        raise SystemExit("--dst doit différer de --src : les originaux ne sont jamais écrasés.")
    count = 0
    for file in sorted(args.src.rglob("*")):
        if file.is_file() and file.suffix.lower() in EXTENSIONS:
            strip(file, args.dst / file.relative_to(args.src))
            count += 1
    print(f"{count} image(s) nettoyée(s) dans {args.dst}")


if __name__ == "__main__":
    main()
