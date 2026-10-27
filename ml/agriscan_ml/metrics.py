"""Métriques de classification calculées avec NumPy (sans dépendance supplémentaire)."""

from __future__ import annotations

import numpy as np


def confusion_matrix(y_true: np.ndarray, y_pred: np.ndarray, num_classes: int) -> np.ndarray:
    """Matrice [vrai, prédit] : lignes = classe réelle, colonnes = classe prédite."""
    matrix = np.zeros((num_classes, num_classes), dtype=np.int64)
    np.add.at(matrix, (np.asarray(y_true), np.asarray(y_pred)), 1)
    return matrix


def classification_report(matrix: np.ndarray, class_names: list[str]) -> dict:
    """Précision, rappel, F1 par classe, macro-F1 et accuracy. Une classe sans support ou sans
    prédiction obtient 0.0 pour la métrique indéfinie (convention explicite, non masquée)."""
    true_positive = np.diag(matrix).astype(float)
    predicted = matrix.sum(axis=0).astype(float)
    support = matrix.sum(axis=1).astype(float)
    precision = np.divide(true_positive, predicted, out=np.zeros_like(true_positive), where=predicted > 0)
    recall = np.divide(true_positive, support, out=np.zeros_like(true_positive), where=support > 0)
    denominator = precision + recall
    f1 = np.divide(2 * precision * recall, denominator, out=np.zeros_like(denominator), where=denominator > 0)

    per_class = {
        name: {
            "precision": float(precision[i]),
            "recall": float(recall[i]),
            "f1": float(f1[i]),
            "support": int(support[i]),
        }
        for i, name in enumerate(class_names)
    }
    total = matrix.sum()
    return {
        "accuracy": float(true_positive.sum() / total) if total else 0.0,
        "macro_precision": float(precision.mean()),
        "macro_recall": float(recall.mean()),
        "macro_f1": float(f1.mean()),
        "per_class": per_class,
        "num_samples": int(total),
    }
