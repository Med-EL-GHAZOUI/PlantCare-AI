from pathlib import Path

import numpy as np
import pytest
import tensorflow as tf
from PIL import Image

from agriscan_ml import data
from agriscan_ml.config import AugmentationConfig, PreprocessConfig
from agriscan_ml.models import build_baseline

CONFIG = PreprocessConfig(image_height=32, image_width=32)
CLASSES = ["a", "b", "c"]


@pytest.fixture
def tiny_split(tmp_path: Path):
    """12 images aléatoires de tailles variées, 4 par classe, avec un CSV de découpage."""
    rng = np.random.default_rng(0)
    rows = ["path,label,group_id"]
    for label in CLASSES:
        for i in range(4):
            size = (40 + 7 * i, 50 + 3 * i)
            pixels = rng.integers(0, 256, size=(*size, 3), dtype=np.uint8)
            rel = f"{label}/{i}.jpg"
            (tmp_path / label).mkdir(exist_ok=True)
            Image.fromarray(pixels).save(tmp_path / rel, quality=95)
            rows.append(f"{rel},{label},{len(rows)}")
    csv_path = tmp_path / "train.csv"
    csv_path.write_text("\n".join(rows), encoding="utf-8")
    return tmp_path, csv_path


def load(tiny_split):
    root, csv_path = tiny_split
    paths, labels = data.read_split(csv_path, root)
    names = data.class_names_from(labels)
    return paths, data.encode_labels(labels, names), names


def test_label_mapping_is_sorted_and_strict(tiny_split) -> None:
    _, encoded, names = load(tiny_split)
    assert names == CLASSES
    assert set(encoded.tolist()) == {0, 1, 2}
    with pytest.raises(ValueError):
        data.encode_labels(["zzz"], names)


def test_eval_dataset_shapes_dtype_range_and_order(tiny_split) -> None:
    paths, encoded, _ = load(tiny_split)
    ds = data.make_dataset(paths, encoded, CONFIG, batch_size=5, training=False)
    images = np.concatenate([x.numpy() for x, _ in ds])
    labels = np.concatenate([y.numpy() for _, y in ds])
    assert images.shape == (12, 32, 32, 3) and images.dtype == np.float32
    assert 0.0 <= images.min() and images.max() <= 255.0
    assert labels.tolist() == encoded.tolist()  # ordre conservé


def test_eval_dataset_has_no_randomness(tiny_split) -> None:
    paths, encoded, _ = load(tiny_split)
    ds = data.make_dataset(paths, encoded, CONFIG, batch_size=12, training=False,
                           augmentation=AugmentationConfig())
    first = next(iter(ds))[0].numpy()
    second = next(iter(ds))[0].numpy()
    np.testing.assert_array_equal(first, second)


def test_augmentation_changes_training_images_only(tiny_split) -> None:
    paths, encoded, _ = load(tiny_split)
    plain = data.make_dataset(paths, encoded, CONFIG, 12, True, augmentation=None, seed=3)
    augmented = data.make_dataset(paths, encoded, CONFIG, 12, True, AugmentationConfig(), seed=3)
    plain_x, plain_y = next(iter(plain))
    aug_x, aug_y = next(iter(augmented))
    assert plain_y.numpy().tolist() == aug_y.numpy().tolist()  # même mélange (même graine)
    assert not np.array_equal(plain_x.numpy(), aug_x.numpy())  # pixels modifiés
    assert float(tf.reduce_min(aug_x)) >= 0.0 and float(tf.reduce_max(aug_x)) <= 255.0


def test_training_without_augmentation_only_shuffles(tiny_split) -> None:
    paths, encoded, _ = load(tiny_split)
    reference = np.concatenate([x.numpy() for x, _ in data.make_dataset(paths, encoded, CONFIG, 12, False)])
    batch_x, batch_y = next(iter(data.make_dataset(paths, encoded, CONFIG, 12, True, augmentation=None)))
    # Chaque image mélangée correspond exactement à une image de référence de même label
    for image, label in zip(batch_x.numpy(), batch_y.numpy(), strict=True):
        matches = [k for k in range(12) if encoded[k] == label and np.array_equal(reference[k], image)]
        assert matches


def test_shuffle_is_reproducible_with_same_seed(tiny_split) -> None:
    paths, encoded, _ = load(tiny_split)
    one = [y.numpy().tolist() for _, y in data.make_dataset(paths, encoded, CONFIG, 4, True, seed=1)]
    two = [y.numpy().tolist() for _, y in data.make_dataset(paths, encoded, CONFIG, 4, True, seed=1)]
    assert one == two


def test_balanced_class_weights() -> None:
    encoded = np.array([0] * 6 + [1] * 3 + [2] * 1)
    weights = data.balanced_class_weights(encoded, 3)
    assert weights[2] > weights[1] > weights[0]
    assert sum(weights[c] * (encoded == c).sum() for c in weights) == pytest.approx(len(encoded))


def test_model_outputs_probabilities_and_rejects_bad_classes() -> None:
    model = build_baseline(3, CONFIG)
    out = model(np.random.default_rng(0).uniform(0, 255, (4, 32, 32, 3)).astype("float32")).numpy()
    assert out.shape == (4, 3)
    np.testing.assert_allclose(out.sum(axis=1), 1.0, rtol=1e-5)
    assert model.count_params() < 100_000
    with pytest.raises(ValueError):
        build_baseline(1, CONFIG)


def test_smoke_one_step_fit_runs(tiny_split) -> None:
    """Vérifie seulement que le code d'entraînement s'exécute ; n'évalue aucune performance."""
    paths, encoded, _ = load(tiny_split)
    ds = data.make_dataset(paths, encoded, CONFIG, 6, True, AugmentationConfig())
    history = build_baseline(3, CONFIG).fit(ds, epochs=1, verbose=0)
    assert np.isfinite(history.history["loss"][0])
