import numpy as np
import pytest

from agriscan_ml.metrics import classification_report, confusion_matrix

NAMES = ["a", "b", "c"]


def test_confusion_matrix_orientation_true_rows_pred_columns() -> None:
    y_true = np.array([0, 0, 1, 2, 2, 2])
    y_pred = np.array([0, 1, 1, 2, 2, 0])
    matrix = confusion_matrix(y_true, y_pred, 3)
    assert matrix.tolist() == [[1, 1, 0], [0, 1, 0], [1, 0, 2]]


def test_report_matches_hand_computed_values() -> None:
    matrix = np.array([[1, 1, 0], [0, 1, 0], [1, 0, 2]])
    report = classification_report(matrix, NAMES)
    assert report["accuracy"] == pytest.approx(4 / 6)
    a = report["per_class"]["a"]
    assert a["precision"] == pytest.approx(1 / 2) and a["recall"] == pytest.approx(1 / 2)
    assert a["f1"] == pytest.approx(0.5) and a["support"] == 2
    b = report["per_class"]["b"]
    assert b["precision"] == pytest.approx(1 / 2) and b["recall"] == pytest.approx(1.0)
    assert b["f1"] == pytest.approx(2 / 3)
    c = report["per_class"]["c"]
    assert c["precision"] == pytest.approx(1.0) and c["recall"] == pytest.approx(2 / 3)
    assert report["macro_f1"] == pytest.approx((0.5 + 2 / 3 + 0.8) / 3)


def test_class_never_predicted_gets_zero_not_nan() -> None:
    matrix = np.array([[2, 0], [2, 0]])
    report = classification_report(matrix, ["x", "y"])
    assert report["per_class"]["y"]["precision"] == 0.0
    assert report["per_class"]["y"]["f1"] == 0.0
    assert not np.isnan(report["macro_f1"])


def test_perfect_predictions() -> None:
    y = np.array([0, 1, 2, 2])
    report = classification_report(confusion_matrix(y, y, 3), NAMES)
    assert report["accuracy"] == 1.0 and report["macro_f1"] == 1.0
