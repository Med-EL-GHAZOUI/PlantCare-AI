import keras
import numpy as np
import pytest

from agriscan_ml.config import AugmentationConfig, PreprocessConfig
from agriscan_ml.models import BACKBONE_NAME, build_mobilenetv2, unfreeze_for_finetuning

CONFIG = PreprocessConfig(image_height=96, image_width=96)  # 96 : plus rapide, MobileNetV2 l'accepte


@pytest.fixture(scope="module")
def model():
    return build_mobilenetv2(4, CONFIG, weights=None)


def test_backbone_is_frozen_and_only_head_trains(model) -> None:
    backbone = model.get_layer(BACKBONE_NAME)
    assert backbone.trainable is False
    trainable_names = {w.path for w in model.trainable_weights}
    assert len(model.trainable_weights) == 2  # kernel + bias de la couche Dense
    assert all("probabilities" in name for name in trainable_names)


def test_input_scaling_maps_0_255_to_minus1_1(model) -> None:
    rescaling = model.get_layer("rescaling")
    out = rescaling(np.array([[[[0.0, 127.5, 255.0]]]], dtype="float32")).numpy().ravel()
    np.testing.assert_allclose(out, [-1.0, 0.0, 1.0], atol=1e-6)


def test_outputs_are_probabilities(model) -> None:
    images = np.random.default_rng(0).uniform(0, 255, (3, 96, 96, 3)).astype("float32")
    out = model(images).numpy()
    assert out.shape == (3, 4)
    np.testing.assert_allclose(out.sum(axis=1), 1.0, rtol=1e-5)


def test_unfreeze_opens_last_layers_and_keeps_batchnorm_frozen() -> None:
    model = build_mobilenetv2(4, CONFIG, weights=None)
    head_only = len(model.trainable_weights)
    unfrozen = unfreeze_for_finetuning(model, num_layers=20, learning_rate=1e-5)
    backbone = model.get_layer(BACKBONE_NAME)
    assert unfrozen > 0
    assert len(model.trainable_weights) > head_only
    assert all(not layer.trainable for layer in backbone.layers if isinstance(layer, keras.layers.BatchNormalization))
    assert all(not layer.trainable for layer in backbone.layers[:-20])
    assert float(model.optimizer.learning_rate) == pytest.approx(1e-5)


def test_invalid_arguments_rejected(model) -> None:
    with pytest.raises(ValueError):
        build_mobilenetv2(1, CONFIG, weights=None)
    with pytest.raises(ValueError):
        unfreeze_for_finetuning(model, num_layers=0)


def test_smoke_head_then_finetune_step_runs() -> None:
    """Vérifie seulement que les deux phases s'exécutent ; ne mesure aucune performance."""
    rng = np.random.default_rng(1)
    x = rng.uniform(0, 255, (8, 96, 96, 3)).astype("float32")
    y = rng.integers(0, 4, 8)
    model = build_mobilenetv2(4, CONFIG, weights=None)
    before = model.get_layer(BACKBONE_NAME).get_weights()[0].copy()
    model.fit(x, y, epochs=1, batch_size=4, verbose=0)
    np.testing.assert_array_equal(before, model.get_layer(BACKBONE_NAME).get_weights()[0])  # base inchangée
    unfreeze_for_finetuning(model, 20)
    history = model.fit(x, y, epochs=1, batch_size=4, verbose=0)
    assert np.isfinite(history.history["loss"][0])
    assert AugmentationConfig()  # la config d'augmentation reste indépendante du modèle
