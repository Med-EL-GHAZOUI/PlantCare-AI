from itertools import pairwise

import numpy as np
import pytest

from agriscan_ml.selective import choose_threshold, per_class_coverage, selective_curve, wilson_interval

CONF = np.array([0.99, 0.95, 0.90, 0.80, 0.60, 0.50])
CORRECT = np.array([True, True, True, False, True, False])


def test_curve_values_by_hand() -> None:
    curve = selective_curve(CONF, CORRECT, np.array([0.0, 0.7, 0.92, 1.0]))
    assert curve[0]["coverage"] == 1.0 and curve[0]["accuracy_answered"] == pytest.approx(4 / 6)
    assert curve[1]["n_answered"] == 4 and curve[1]["accuracy_answered"] == pytest.approx(3 / 4)
    assert curve[2]["n_answered"] == 2 and curve[2]["accuracy_answered"] == 1.0
    assert curve[3]["n_answered"] == 0 and curve[3]["accuracy_answered"] is None
    assert curve[3]["accuracy_ci95"] is None


def test_coverage_is_non_increasing_with_threshold() -> None:
    rng = np.random.default_rng(0)
    conf, correct = rng.uniform(0, 1, 500), rng.uniform(0, 1, 500) > 0.3
    coverage = [r["coverage"] for r in selective_curve(conf, correct, np.linspace(0, 1, 21))]
    assert all(a >= b for a, b in pairwise(coverage))


def test_choose_threshold_smallest_meeting_target() -> None:
    curve = selective_curve(CONF, CORRECT, np.round(np.arange(0.0, 1.0, 0.05), 2))
    chosen = choose_threshold(curve, target_accuracy=1.0)
    assert chosen is not None and chosen["threshold"] == pytest.approx(0.85)  # exclut le 0.80 faux
    assert chosen["accuracy_answered"] == 1.0
    assert choose_threshold(curve, target_accuracy=1.0, min_coverage=0.9) is None  # cible inatteignable
    assert choose_threshold(curve, target_accuracy=0.5)["threshold"] == pytest.approx(0.0)


def test_wilson_interval_properties() -> None:
    low, high = wilson_interval(95, 100)
    assert 0.88 < low < 0.95 < high < 0.99
    assert wilson_interval(0, 0) == (0.0, 1.0)
    assert wilson_interval(10, 10)[1] == pytest.approx(1.0)


def test_per_class_coverage() -> None:
    result = per_class_coverage(CONF, np.array([0, 0, 0, 1, 1, 1]), ["a", "b"], threshold=0.85)
    assert result["a"] == {"support": 3, "answered": 3, "coverage": 1.0}
    assert result["b"]["answered"] == 0 and result["b"]["coverage"] == 0.0
