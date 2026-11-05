"""Avancement de la collecte terrain par rapport aux repères du protocole (docs/FIELD_VALIDATION.md).

Lecture seule : ne valide pas les fichiers (utiliser validate_field_manifest.py pour cela).

Usage (depuis ml/) :
    .venv\\Scripts\\python.exe scripts/field_progress.py --manifest data/field/manifest.csv
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from agriscan_ml.field import (
    MIN_IMAGES_PER_CLASS,
    MIN_SUBJECTS_PER_CLASS,
    progress_summary,
    read_manifest,
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--manifest", type=Path, default=Path("data/field/manifest.csv"))
    parser.add_argument("--model-dir", type=Path, default=Path("artifacts/mobilenetv2"))
    args = parser.parse_args()
    if not args.manifest.is_file():
        print(f"Manifeste introuvable : {args.manifest}", file=sys.stderr)
        return 2
    class_names = json.loads((args.model_dir / "class_names.json").read_text(encoding="utf-8"))
    summary = progress_summary(read_manifest(args.manifest), class_names)

    print(f"Images : {summary['images']} | plantes : {summary['subjects']} | "
          f"classes au repère : {summary['classes_done']}/{len(class_names)}")
    print(f"\n{'Classe':48s} {'images':>7s} {'plantes':>8s}  reste")
    for name, v in summary["per_class"].items():
        status = "OK" if v["done"] else f"+{v['images_missing']} images, +{v['subjects_missing']} plantes"
        print(f"{name:48s} {v['images']:>3d}/{MIN_IMAGES_PER_CLASS:<3d} {v['subjects']:>4d}/{MIN_SUBJECTS_PER_CLASS:<3d}  {status}")
    ood = summary["out_of_distribution"]
    print(f"\nHors périmètre : {ood['total']}/100 (out_of_scope {ood['out_of_scope']}, other_disease {ood['other_disease']}) "
          f"— reste {ood['missing_to_100']}")
    print("\nDiversité :")
    for column, counts in summary["coverage"].items():
        print(f"  {column:16s} " + ", ".join(f"{k}: {n}" for k, n in counts.items()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
