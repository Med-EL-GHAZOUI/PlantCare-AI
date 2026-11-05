"""Politique d'incertitude : transforme le meilleur score en statut et classe proposée."""

from __future__ import annotations


def decide(top_class: str, top_score: float, threshold: float | None) -> tuple[str, str | None]:
    """Retourne (statut, classe prédite). Sous le seuil, le résultat est « uncertain » sans classe.

    `threshold=None` désactive l'incertitude (aucun seuil validé par défaut, voir docs/MODEL_CARD.md).
    """
    if threshold is not None and top_score < threshold:
        return "uncertain", None
    return "prediction_available", top_class
