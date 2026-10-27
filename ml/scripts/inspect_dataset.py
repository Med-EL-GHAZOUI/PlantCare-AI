"""Inventaire d'un dataset d'images organisé en un dossier par classe.

Produit un manifeste CSV (une ligne par image lisible) et affiche un rapport :
effectifs par classe, images corrompues, doublons exacts, dimensions et formats.

Usage (depuis ml/) :
    .venv\\Scripts\\python.exe scripts/inspect_dataset.py data/raw/plantvillage_tomato \\
        --manifest data/manifest.csv
"""

from __future__ import annotations

import argparse
import csv
import hashlib
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass
from pathlib import Path

from PIL import Image, UnidentifiedImageError

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png"}
MANIFEST_FIELDS = ["path", "label", "sha256", "dhash", "width", "height", "format", "mode", "bytes"]


@dataclass(frozen=True)
class ImageRecord:
    path: str
    label: str
    sha256: str
    dhash: str
    width: int
    height: int
    format: str
    mode: str
    bytes: int


def sha256_of(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def dhash_of(image: Image.Image, size: int = 8) -> str:
    """Hash perceptuel de différence (64 bits) en hexadécimal."""
    gray = image.convert("L").resize((size + 1, size), Image.Resampling.LANCZOS)
    pixels = gray.tobytes()
    bits = 0
    for row in range(size):
        for col in range(size):
            left = pixels[row * (size + 1) + col]
            right = pixels[row * (size + 1) + col + 1]
            bits = (bits << 1) | int(left > right)
    return f"{bits:0{size * size // 4}x}"


def read_record(path: Path, root: Path) -> ImageRecord:
    """Lit une image ; lève OSError/UnidentifiedImageError si elle est illisible."""
    with Image.open(path) as image:
        image.verify()
    with Image.open(path) as image:  # verify() invalide l'objet : on rouvre
        image.load()
        return ImageRecord(
            path=path.relative_to(root).as_posix(),
            label=path.parent.name,
            sha256=sha256_of(path),
            dhash=dhash_of(image),
            width=image.width,
            height=image.height,
            format=image.format or "",
            mode=image.mode,
            bytes=path.stat().st_size,
        )


def scan(root: Path) -> tuple[list[ImageRecord], list[str]]:
    records: list[ImageRecord] = []
    corrupt: list[str] = []
    files = sorted(p for p in root.rglob("*") if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS)
    for path in files:
        try:
            records.append(read_record(path, root))
        except (OSError, UnidentifiedImageError, SyntaxError):
            corrupt.append(path.relative_to(root).as_posix())
    return records, corrupt


def exact_duplicate_groups(records: list[ImageRecord]) -> list[list[ImageRecord]]:
    by_hash: dict[str, list[ImageRecord]] = defaultdict(list)
    for record in records:
        by_hash[record.sha256].append(record)
    return [group for group in by_hash.values() if len(group) > 1]


def write_manifest(records: list[ImageRecord], destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=MANIFEST_FIELDS)
        writer.writeheader()
        writer.writerows(asdict(record) for record in records)


def build_report(records: list[ImageRecord], corrupt: list[str]) -> str:
    lines = [f"Images lisibles : {len(records)}", f"Images corrompues : {len(corrupt)}"]
    lines.append("\nEffectif par classe :")
    for label, count in sorted(Counter(r.label for r in records).items()):
        lines.append(f"  {label}: {count}")
    lines.append("\nDimensions : " + ", ".join(
        f"{w}x{h} ({n})" for (w, h), n in Counter((r.width, r.height) for r in records).most_common(5)))
    lines.append("Formats : " + ", ".join(f"{k} ({n})" for k, n in Counter(r.format for r in records).items()))
    lines.append("Modes : " + ", ".join(f"{k} ({n})" for k, n in Counter(r.mode for r in records).items()))

    groups = exact_duplicate_groups(records)
    redundant = sum(len(g) - 1 for g in groups)
    cross_label = sum(1 for g in groups if len({r.label for r in g}) > 1)
    lines.append(f"\nGroupes de doublons exacts : {len(groups)} ({redundant} images redondantes)")
    lines.append(f"Groupes de doublons à labels différents : {cross_label}")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("root", type=Path, help="Dossier contenant un sous-dossier par classe")
    parser.add_argument("--manifest", type=Path, default=Path("data/manifest.csv"))
    args = parser.parse_args()

    if not args.root.is_dir():
        raise SystemExit(f"Dossier introuvable : {args.root}")
    records, corrupt = scan(args.root)
    write_manifest(records, args.manifest)
    print(build_report(records, corrupt))
    for name in corrupt:
        print(f"CORROMPUE : {name}")
    print(f"\nManifeste écrit : {args.manifest}")


if __name__ == "__main__":
    main()
