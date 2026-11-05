"""Valide le manifeste d'images de terrain avant toute évaluation (consentement, GPS, fuite, doublons).

Usage (depuis ml/) :
    .venv\\Scripts\\python.exe scripts/validate_field_manifest.py --manifest data/field/manifest.csv

Code de sortie 1 s'il y a des erreurs ; les avertissements (effectifs insuffisants) n'échouent pas.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

from inspect_dataset import dhash_of
from PIL import Image

from agriscan_ml.field import read_manifest, validate_manifest


def load_reference(manifest: Path) -> tuple[dict[str, str], list[tuple[str, int]]]:
    """Empreintes des images PlantVillage (entraînement, validation, test) pour détecter les non-indépendantes."""
    hashes: dict[str, str] = {}
    dhashes: list[tuple[str, int]] = []
    with manifest.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            hashes[row["sha256"]] = row["path"]
            dhashes.append((row["path"], int(row["dhash"], 16)))
    return hashes, dhashes


def dhash_int(image: Image.Image) -> int:
    return int(dhash_of(image), 16)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--manifest", type=Path, default=Path("data/field/manifest.csv"))
    parser.add_argument("--root", type=Path, default=Path("data/field/images"), help="Dossier des images (chemins du manifeste relatifs)")
    parser.add_argument("--model-dir", type=Path, default=Path("artifacts/mobilenetv2"))
    parser.add_argument("--reference", type=Path, default=Path("data/manifest.csv"), help="Manifeste PlantVillage (détection de fuite)")
    parser.add_argument("--json", type=Path, help="Écrit le rapport en JSON")
    args = parser.parse_args()

    if not args.manifest.is_file():
        print(f"Manifeste introuvable : {args.manifest} (modèle : docs/field/manifest_template.csv)", file=sys.stderr)
        return 2
    class_names = json.loads((args.model_dir / "class_names.json").read_text(encoding="utf-8"))
    known_hashes, known_dhashes = load_reference(args.reference) if args.reference.is_file() else (None, None)
    if known_hashes is None:
        print(f"AVERTISSEMENT : {args.reference} absent, la fuite vers PlantVillage n'est pas vérifiée.")

    report = validate_manifest(read_manifest(args.manifest), class_names, args.root, known_hashes, known_dhashes, dhash_int)
    print(f"Images : {report.counts.get('images', 0)} | plantes : {report.counts.get('subjects', 0)} | "
          f"dev : {report.counts.get('dev', 0)} | test : {report.counts.get('test', 0)} | "
          f"hors périmètre : {report.counts.get('out_of_distribution', 0)}")
    for message in report.errors:
        print(f"ERREUR      {message}")
    for message in report.warnings:
        print(f"AVERTISSEMENT {message}")
    print("VALIDE" if report.ok else f"INVALIDE : {len(report.errors)} erreur(s)")
    if args.json:
        args.json.write_text(json.dumps({"ok": report.ok, "errors": report.errors, "warnings": report.warnings,
                                         "counts": report.counts}, indent=2, ensure_ascii=False), encoding="utf-8")
    return 0 if report.ok else 1


if __name__ == "__main__":
    sys.exit(main())
