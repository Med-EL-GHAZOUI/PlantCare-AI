import csv
import random
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import split_dataset as sp

ML_DIR = Path(__file__).resolve().parents[1]


def synthetic_rows(per_label: dict[str, int], seed: int = 0) -> list[dict[str, str]]:
    """Manifeste synthétique : dhash aléatoires, avec quelques doublons exacts et quasi-doublons."""
    rng = random.Random(seed)
    rows: list[dict[str, str]] = []
    for label, count in per_label.items():
        for i in range(count):
            value = rng.getrandbits(64)
            rows.append({"path": f"{label}/{i}.jpg", "label": label, "sha256": f"s{label}{i}", "dhash": f"{value:016x}"})
        # un doublon exact (même sha256 et dhash) et un quasi-doublon (1 bit de différence)
        base = rows[-1]
        rows.append({**base, "path": f"{label}/exact_copy.jpg"})
        flipped = int(base["dhash"], 16) ^ 1
        rows.append({**base, "path": f"{label}/near_copy.jpg", "sha256": f"n{label}", "dhash": f"{flipped:016x}"})
    return rows


@pytest.fixture
def split_result():
    rows = synthetic_rows({"a": 400, "b": 200, "c": 60})
    groups = sp.build_groups(rows, max_hamming=2)
    split = sp.split_groups(rows, groups, seed=42)
    return rows, groups, split


def test_every_image_in_exactly_one_split(split_result) -> None:
    rows, _, split = split_result
    all_indices = [i for indices in split.values() for i in indices]
    assert sorted(all_indices) == list(range(len(rows)))


def test_no_path_sha_or_group_shared_between_splits(split_result) -> None:
    rows, groups, split = split_result
    names = list(split)
    for i, first in enumerate(names):
        for second in names[i + 1:]:
            assert not {rows[k]["path"] for k in split[first]} & {rows[k]["path"] for k in split[second]}
            assert not {rows[k]["sha256"] for k in split[first]} & {rows[k]["sha256"] for k in split[second]}
            assert not {groups[k] for k in split[first]} & {groups[k] for k in split[second]}


def test_near_and_exact_duplicates_stay_together(split_result) -> None:
    rows, _, split = split_result
    where = {k: name for name, indices in split.items() for k in indices}
    by_path = {row["path"]: k for k, row in enumerate(rows)}
    assert where[by_path["a/exact_copy.jpg"]] == where[by_path["a/near_copy.jpg"]]
    assert where[by_path["a/399.jpg"]] == where[by_path["a/exact_copy.jpg"]]


def test_distant_hashes_are_not_grouped() -> None:
    rows = [
        {"path": "x/1.jpg", "label": "x", "sha256": "1", "dhash": "0" * 16},
        {"path": "x/2.jpg", "label": "x", "sha256": "2", "dhash": "f" * 16},
    ]
    groups = sp.build_groups(rows, max_hamming=2)
    assert groups[0] != groups[1]


def test_proportions_and_all_classes_in_every_split(split_result) -> None:
    rows, _, split = split_result
    total = len(rows)
    for name, ratio in zip(sp.SPLITS, sp.DEFAULT_RATIOS, strict=True):
        assert abs(len(split[name]) / total - ratio) < 0.02
        assert {rows[k]["label"] for k in split[name]} == {"a", "b", "c"}


def test_split_is_deterministic_and_seed_dependent() -> None:
    rows = synthetic_rows({"a": 100, "b": 100})
    groups = sp.build_groups(rows, max_hamming=2)
    assert sp.split_groups(rows, groups, seed=42) == sp.split_groups(rows, groups, seed=42)
    assert sp.split_groups(rows, groups, seed=42) != sp.split_groups(rows, groups, seed=7)


def test_invalid_parameters_rejected() -> None:
    rows = synthetic_rows({"a": 5})
    with pytest.raises(ValueError):
        sp.build_groups(rows, max_hamming=4)
    with pytest.raises(ValueError):
        sp.split_groups(rows, sp.build_groups(rows, 2), ratios=(0.5, 0.5, 0.5))


@pytest.mark.skipif(not (ML_DIR / "data" / "splits" / "test.csv").exists(), reason="splits réels non générés")
def test_real_splits_have_no_overlap() -> None:
    """Contrôle les fichiers réellement produits sur le dataset téléchargé."""
    folder = ML_DIR / "data" / "splits"
    loaded = {}
    for name in sp.SPLITS:
        with (folder / f"{name}.csv").open(newline="", encoding="utf-8") as handle:
            loaded[name] = list(csv.DictReader(handle))
    for i, first in enumerate(sp.SPLITS):
        for second in sp.SPLITS[i + 1:]:
            assert not {r["path"] for r in loaded[first]} & {r["path"] for r in loaded[second]}
            assert not {r["group_id"] for r in loaded[first]} & {r["group_id"] for r in loaded[second]}
