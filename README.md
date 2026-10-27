# AgriScan AI 🌱

**Plateforme de dépistage préliminaire des maladies des plantes par intelligence artificielle.**

AgriScan AI analyse une image de feuille et prédit une classe parmi celles prises en charge par un modèle CNN. Le MVP commence par la tomate ; d'autres cultures pourront être ajoutées après validation.

> Important : une prédiction automatique est une aide au dépistage, pas un diagnostic agricole confirmé.

## Documentation

### Contexte et pilotage
- [Instructions de développement — AGENTS.md](AGENTS.md)
- [Contexte du projet](docs/PROJECT_CONTEXT.md)
- [Exigences fonctionnelles et non fonctionnelles](docs/REQUIREMENTS.md)
- [Feuille de route](docs/ROADMAP.md)

### Conception technique
- [Architecture](docs/ARCHITECTURE.md)
- [Base de données](docs/DATABASE.md)
- [Spécification de l'API](docs/API_SPECIFICATION.md)
- [Sécurité et confidentialité](docs/SECURITY.md)

### Machine Learning
- [Documentation du dataset](docs/DATASET_CARD.md)
- [Documentation du modèle](docs/MODEL_CARD.md)

## Technologies envisagées

- Python, TensorFlow/Keras et CNN
- FastAPI et Pydantic
- PostgreSQL
- Flutter pour le mobile
- Angular pour le tableau de bord web, dans une phase ultérieure
- Git et tests automatisés

Ces technologies sont la cible de conception ; leur installation et leur compatibilité doivent être vérifiées sur l'environnement réel.

## Flux principal

1. L'utilisateur choisit ou prend une photo.
2. Le client transmet l'image à l'API.
3. L'API valide l'image et applique le prétraitement attendu.
4. Le modèle calcule les scores des classes connues.
5. La politique de décision renvoie une prédiction ou un résultat incertain.
6. L'interface affiche le résultat et ses limites.
7. Si l'utilisateur est authentifié et l'a autorisé, les métadonnées de l'analyse peuvent être enregistrées.

## Ordre recommandé

1. Inspecter l'environnement et initialiser Git.
2. Choisir et auditer un dataset.
3. Entraîner une baseline puis évaluer le modèle.
4. Exposer l'inférence via FastAPI.
5. Ajouter PostgreSQL et les contrôles d'accès.
6. Développer l'application Flutter.
7. Ajouter le tableau de bord Angular si nécessaire.
8. Tester, sécuriser et déployer.
9. Valider le produit auprès d'utilisateurs réels avant toute commercialisation.

## Règles de maintenance

- Toute modification de l'API doit mettre à jour `docs/API_SPECIFICATION.md`.
- Toute modification du schéma doit mettre à jour `docs/DATABASE.md` et les migrations.
- Toute modification des données ou du prétraitement doit mettre à jour `docs/DATASET_CARD.md` et `docs/MODEL_CARD.md`.
- Toute décision d'architecture importante doit être documentée dans `docs/ARCHITECTURE.md`.
- Les métriques publiées doivent provenir d'une exécution réelle et reproductible.

Commencer par lire [AGENTS.md](AGENTS.md), puis [le contexte du projet](docs/PROJECT_CONTEXT.md).
