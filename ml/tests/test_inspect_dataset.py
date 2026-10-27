import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import inspect_dataset as ds


def make_image(path: Path, color: tuple[int, int, int], size: tuple[int, int] = (16, 16)) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.new("RGB", size, color).save(path, "JPEG")


def test_scan_counts_labels_and_flags_corrupt(tmp_path: Path) -> None:
    make_image(tmp_path / "a" / "1.jpg", (255, 0, 0))
    make_image(tmp_path / "b" / "2.jpg", (0, 255, 0))
    (tmp_path / "b" / "broken.jpg").write_bytes(b"not an image")

    records, corrupt = ds.scan(tmp_path)

    assert sorted(r.label for r in records) == ["a", "b"]
    assert corrupt == ["b/broken.jpg"]


def test_exact_duplicates_detected_across_labels(tmp_path: Path) -> None:
    make_image(tmp_path / "a" / "1.jpg", (10, 20, 30))
    (tmp_path / "b").mkdir()
    (tmp_path / "b" / "copy.jpg").write_bytes((tmp_path / "a" / "1.jpg").read_bytes())
    make_image(tmp_path / "b" / "other.jpg", (200, 100, 50))

    records, _ = ds.scan(tmp_path)
    groups = ds.exact_duplicate_groups(records)

    assert len(groups) == 1
    assert {r.label for r in groups[0]} == {"a", "b"}


def test_manifest_roundtrip(tmp_path: Path) -> None:
    make_image(tmp_path / "data" / "x" / "1.jpg", (1, 2, 3), size=(20, 10))
    records, _ = ds.scan(tmp_path / "data")
    out = tmp_path / "out" / "manifest.csv"

    ds.write_manifest(records, out)

    lines = out.read_text(encoding="utf-8").splitlines()
    assert lines[0].split(",") == ds.MANIFEST_FIELDS
    assert len(lines) == 2
    assert records[0].width == 20 and records[0].height == 10


def test_dhash_is_stable_and_16_hex_chars() -> None:
    image = Image.new("RGB", (32, 32), (120, 130, 140))
    assert ds.dhash_of(image) == ds.dhash_of(image)
    assert len(ds.dhash_of(image)) == 16
