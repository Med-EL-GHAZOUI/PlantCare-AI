# Roadmap — AgriScan AI

## Phase 0 — Inspection et cadrage

**Travail**
- Inspecter l'environnement et le dépôt.
- Confirmer le système d'exploitation et les versions de Python, Git et outils nécessaires.
- Définir le périmètre exact du MVP.
- Initialiser Git et vérifier les fichiers de contexte.

**Critères de sortie**
- Dépôt compris.
- Prérequis documentés.
- Décisions et questions bloquantes recensées.

## Phase 1 — Dataset

**Travail**
- Choisir une source et vérifier sa licence.
- Télécharger les données.
- Analyser les classes, doublons, images corrompues et déséquilibres.
- Créer un découpage sans fuite de données.
- Compléter `DATASET_CARD.md`.

**Critères de sortie**
- Provenance et licence enregistrées.
- Répartition des classes connue.
- Splits reproductibles et séparés.

## Phase 2 — Baseline CNN

**Travail**
- Créer un pipeline de chargement et prétraitement.
- Entraîner une baseline simple.
- Évaluer une candidate MobileNetV2.
- Générer métriques et matrice de confusion.
- Sauvegarder le modèle, les labels et la configuration.
- Compléter `MODEL_CARD.md`.

**Critères de sortie**
- Entraînement reproductible.
- Métriques calculées sur un test indépendant.
- Limites et erreurs fréquentes identifiées.

## Phase 3 — API FastAPI

**Travail**
- Créer `/health`, `/model/info` et `/predictions`.
- Charger le modèle une fois par processus.
- Valider les images et gérer les erreurs.
- Documenter et tester les contrats API.

**Critères de sortie**
- Une image valide peut être traitée de bout en bout.
- Les fichiers invalides sont rejetés proprement.
- Les tests de contrat passent.

## Phase 4 — PostgreSQL et comptes

**Travail**
- Définir les migrations et tables nécessaires.
- Implémenter l'authentification choisie.
- Protéger l'historique et la suppression.
- Définir la conservation des données.

**Critères de sortie**
- Les utilisateurs n'accèdent qu'à leurs données.
- Les migrations sont reproductibles.
- Les tests d'autorisation passent.

## Phase 5 — Flutter

**Travail**
- Créer l'interface de sélection/capture d'image.
- Connecter l'API.
- Afficher résultats, incertitude, erreurs et historique.
- Préparer français et arabe/RTL.

**Critères de sortie**
- Parcours principal fonctionnel sur un appareil ou émulateur déclaré.
- Gestion des erreurs réseau testée.

## Phase 6 — Angular (optionnel pour le MVP)

**Travail**
- Construire le tableau de bord après validation du parcours principal.
- Ajouter les pages autorisées et les statistiques utiles.
- Tester les rôles et les écrans responsives.

**Critères de sortie**
- Les fonctions web respectent l'API et les permissions.
- Les tests essentiels passent.

## Phase 7 — Validation terrain

**Travail**
- Collecter ou obtenir des images représentatives avec autorisation.
- Tester les conditions réelles.
- Analyser les erreurs par classe et les cas hors périmètre.
- Recueillir les retours des utilisateurs.

**Critères de sortie**
- Rapport de validation terrain.
- Limites clairement décrites.
- Décision documentée sur les corrections nécessaires.

## Phase 8 — Déploiement

**Travail**
- Configurer environnement, secrets, HTTPS et base de données.
- Ajouter logs, surveillance, sauvegardes et restauration.
- Documenter le déploiement et le retour arrière.

**Critères de sortie**
- Déploiement vérifié.
- Procédure de restauration testée.
- Aucun secret inclus dans le dépôt.

## Phase 9 — Validation commerciale

**Travail**
- Interroger des utilisateurs potentiels.
- Estimer coûts d'hébergement et de support.
- Vérifier licences et obligations applicables.
- Tester une proposition de valeur avant d'ajouter les paiements.

**Critères de sortie**
- Besoin documenté.
- Coûts et limites connus.
- Décision de poursuivre fondée sur des retours, pas sur une supposition.

## Documents liés

- [Requirements](REQUIREMENTS.md)
- [Architecture](ARCHITECTURE.md)
- [Dataset Card](DATASET_CARD.md)
- [Model Card](MODEL_CARD.md)
- [Security](SECURITY.md)
