"""Découpage train/val/test stratifié par classe et par groupes de quasi-doublons.

Entrée : le manifeste produit par inspect_dataset.py.
Sortie : train.csv, val.csv, test.csv (path, label, group_id) et split_report.json.

Les images dont le dhash diffère d'au plus --max-hamming bits (ou dont le SHA-256 est
identique) forment un groupe ; un groupe n'est jamais réparti sur deux ensembles.

Usage (depuis ml/) :
    .venv\\Scripts\\python.exe scripts/split_dataset.py --manifest data/manifest.csv \\
        --out-dir data/splits
"""

from __future__ import annotations

import argparse
import csv
import json
import random
from collections import Counter, defaultdict
from pathlib import Path

SPLITS = ("train", "val", "test")
DEFAULT_RATIOS = (0.70, 0.15, 0.15)
DEFAULT_SEED = 42
DEFAULT_MAX_HAMMING = 2  # voir docs/DATASET_CARD.md : à 4 bits, des groupes à labels mixtes apparaissent
CHUNK_BITS = 16  # 4 blocs de 16 bits : distance <= 3 => au moins un bloc identique (pigeonhole)
OUT_FIELDS = ["path", "label", "group_id"]


class UnionFind:
    def __init__(self, size: int) -> None:
        self.parent = list(range(size))

    def find(self, item: int) -> int:
        while self.parent[item] != item:
            self.parent[item] = self.parent[self.parent[item]]
            item = self.parent[item]
        return item

    def union(self, a: int, b: int) -> None:
        self.parent[self.find(a)] = self.find(b)


def read_manifest(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def build_groups(rows: list[dict[str, str]], max_hamming: int) -> list[int]:
    """Retourne, pour chaque ligne, un identifiant de groupe (quasi-doublons et doublons exacts)."""
    if max_hamming >= 4:
        raise ValueError("max_hamming doit être < 4 avec l'indexation par blocs de 16 bits")
    hashes = [int(row["dhash"], 16) for row in rows]
    union = UnionFind(len(rows))

    first_by_sha: dict[str, int] = {}
    for index, row in enumerate(rows):
        if row["sha256"] in first_by_sha:
            union.union(index, first_by_sha[row["sha256"]])
        else:
            first_by_sha[row["sha256"]] = index

    mask = (1 << CHUNK_BITS) - 1
    for chunk in range(4):
        buckets: dict[int, list[int]] = defaultdict(list)
        for index, value in enumerate(hashes):
            buckets[(value >> (CHUNK_BITS * chunk)) & mask].append(index)
        for members in buckets.values():
            for position, i in enumerate(members):
                for j in members[position + 1:]:
                    if (hashes[i] ^ hashes[j]).bit_count() <= max_hamming:
                        union.union(i, j)

    return [union.find(index) for index in range(len(rows))]


def split_groups(
    rows: list[dict[str, str]],
    group_ids: list[int],
    ratios: tuple[float, float, float] = DEFAULT_RATIOS,
    seed: int = DEFAULT_SEED,
) -> dict[str, list[int]]:
    """Répartit les groupes (donc les lignes) entre train/val/test, stratifié par classe.

    Chaque groupe prend la classe majoritaire de ses images. Au sein d'une classe, les groupes
    sont mélangés (graine fixe) puis affectés à l'ensemble qui est le plus en retard sur son
    objectif, ce qui respecte les proportions au plus près sans jamais couper un groupe.
    """
    if abs(sum(ratios) - 1.0) > 1e-9:
        raise ValueError("Les proportions doivent totaliser 1")

    members: dict[int, list[int]] = defaultdict(list)
    for index, group in enumerate(group_ids):
        members[group].append(index)

    groups_by_label: dict[str, list[int]] = defaultdict(list)
    for group, indices in members.items():
        label = Counter(rows[i]["label"] for i in indices).most_common(1)[0][0]
        groups_by_label[label].append(group)

    rng = random.Random(seed)
    result: dict[str, list[int]] = {name: [] for name in SPLITS}
    for label in sorted(groups_by_label):
        groups = sorted(groups_by_label[label])  # ordre canonique avant mélange
        rng.shuffle(groups)
        total = sum(len(members[g]) for g in groups)
        counts = dict.fromkeys(SPLITS, 0)
        for group in groups:
            deficits = {name: ratios[k] * total - counts[name] for k, name in enumerate(SPLITS)}
            chosen = max(SPLITS, key=lambda name: (deficits[name], -SPLITS.index(name)))
            counts[chosen] += len(members[group])
            result[chosen].extend(members[group])
    return {name: sorted(indices) for name, indices in result.items()}


def write_split(rows: list[dict[str, str]], group_ids: list[int], indices: list[int], dest: Path) -> None:
    with dest.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=OUT_FIELDS)
        writer.writeheader()
        for index in indices:
            writer.writerow(
                {"path": rows[index]["path"], "label": rows[index]["label"], "group_id": group_ids[index]}
            )


def build_report(rows: list[dict[str, str]], split: dict[str, list[int]], args: argparse.Namespace) -> dict:
    return {
        "seed": args.seed,
        "ratios": dict(zip(SPLITS, args.ratios, strict=True)),
        "max_hamming": args.max_hamming,
        "total_images": len(rows),
        "images": {name: len(indices) for name, indices in split.items()},
        "per_class": {
            name: dict(sorted(Counter(rows[i]["label"] for i in indices).items()))
            for name, indices in split.items()
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--manifest", type=Path, default=Path("data/manifest.csv"))
    parser.add_argument("--out-dir", type=Path, default=Path("data/splits"))
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED)
    parser.add_argument("--max-hamming", type=int, default=DEFAULT_MAX_HAMMING)
    parser.add_argument("--ratios", type=float, nargs=3, default=DEFAULT_RATIOS, metavar=("TRAIN", "VAL", "TEST"))
    args = parser.parse_args()
    args.ratios = tuple(args.ratios)

    rows = read_manifest(args.manifest)
    group_ids = build_groups(rows, args.max_hamming)
    split = split_groups(rows, group_ids, args.ratios, args.seed)

    args.out_dir.mkdir(parents=True, exist_ok=True)
    for name in SPLITS:
        write_split(rows, group_ids, split[name], args.out_dir / f"{name}.csv")
    report = build_report(rows, split, args)
    (args.out_dir / "split_report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(report, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
