"""Classification sélective : compromis entre couverture et précision selon un seuil de confiance.

Un échantillon est « répondu » si son score softmax maximal est >= seuil, sinon « incertain ».
La précision sélective est l'accuracy mesurée sur les seuls échantillons répondus. Ce score
n'est PAS une probabilité calibrée : le seuil est un point de fonctionnement empirique.
"""

from __future__ import annotations

import math

import numpy as np


def wilson_interval(successes: int, total: int, z: float = 1.96) -> tuple[float, float]:
    """Intervalle de Wilson à ~95 % pour une proportion."""
    if total == 0:
        return (0.0, 1.0)
    p = successes / total
    denominator = 1 + z**2 / total
    centre = (p + z**2 / (2 * total)) / denominator
    half = z * math.sqrt(p * (1 - p) / total + z**2 / (4 * total**2)) / denominator
    return (max(0.0, centre - half), min(1.0, centre + half))


def selective_curve(confidences: np.ndarray, correct: np.ndarray, thresholds: np.ndarray) -> list[dict]:
    confidences = np.asarray(confidences, dtype=float)
    correct = np.asarray(correct, dtype=bool)
    total = len(confidences)
    rows = []
    for threshold in thresholds:
        answered = confidences >= threshold
        n_answered = int(answered.sum())
        n_correct = int(correct[answered].sum())
        low, high = wilson_interval(n_correct, n_answered)
        rows.append({
            "threshold": float(threshold),
            "n_answered": n_answered,
            "coverage": n_answered / total if total else 0.0,
            "accuracy_answered": n_correct / n_answered if n_answered else None,
            "accuracy_ci95": [low, high] if n_answered else None,
            "errors_answered": n_answered - n_correct,
        })
    return rows


def choose_threshold(curve: list[dict], target_accuracy: float, min_coverage: float = 0.0) -> dict | None:
    """Plus petit seuil dont la précision sélective atteint la cible, avec une couverture minimale.

    Le plus petit seuil conserve la plus grande couverture. Retourne None si aucun seuil ne convient.
    """
    for row in sorted(curve, key=lambda r: r["threshold"]):
        accuracy = row["accuracy_answered"]
        if accuracy is not None and accuracy >= target_accuracy and row["coverage"] >= min_coverage:
            return row
    return None


def per_class_coverage(
    confidences: np.ndarray, y_true: np.ndarray, class_names: list[str], threshold: float
) -> dict[str, dict]:
    """Part des images de chaque classe réelle qui reste répondue au seuil donné."""
    confidences, y_true = np.asarray(confidences), np.asarray(y_true)
    result = {}
    for index, name in enumerate(class_names):
        mask = y_true == index
        total = int(mask.sum())
        answered = int((confidences[mask] >= threshold).sum())
        result[name] = {"support": total, "answered": answered, "coverage": answered / total if total else 0.0}
    return result
