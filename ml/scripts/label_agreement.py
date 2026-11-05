r"""Accord entre deux étiqueteurs : compare les étiquettes du manifeste à celles d'un second expert.

Le second expert étiquette les mêmes photos SANS voir la première étiquette ni la prédiction du modèle et
remplit un CSV `path,label`. Usage (depuis ml/) :
    .venv\Scripts\python.exe scripts/label_agreement.py --manifest data/field/manifest.csv --review data/field/review.csv
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

from agriscan_ml.field import cohens_kappa, read_manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--manifest", type=Path, default=Path("data/field/manifest.csv"))
    parser.add_argument("--review", type=Path, required=True, help="CSV path,label du second expert")
    args = parser.parse_args()

    first = {row["path"]: row["label"] for row in read_manifest(args.manifest)}
    with args.review.open(newline="", encoding="utf-8") as handle:
        second = {row["path"].strip(): row["label"].strip() for row in csv.DictReader(handle)}
    common = sorted(set(first) & set(second))
    unknown = sorted(set(second) - set(first))
    if unknown:
        print(f"ERREUR : {len(unknown)} chemin(s) du second expert absents du manifeste, par exemple {unknown[0]}", file=sys.stderr)
        return 1
    if not common:
        print("Aucune photo en commun.", file=sys.stderr)
        return 1

    labels_a = [first[p] for p in common]
    labels_b = [second[p] for p in common]
    disagreements = [(p, a, b) for p, a, b in zip(common, labels_a, labels_b, strict=True) if a != b]
    print(f"Photos comparées : {len(common)} | accord brut : {1 - len(disagreements) / len(common):.3f} | "
          f"kappa de Cohen : {cohens_kappa(labels_a, labels_b):.3f}")
    print(f"Désaccords à arbitrer : {len(disagreements)} (marquer label_certainty=uncertain tant qu'ils ne sont pas tranchés)")
    for path, a, b in disagreements:
        print(f"  {path} : expert 1 = {a} ; expert 2 = {b}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
