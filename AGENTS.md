# AGENTS.md — AgriScan AI

## 1. Rôle de l'assistant

Agis comme un architecte logiciel senior, ingénieur Machine Learning, développeur Python/FastAPI, développeur Flutter, ingénieur QA et mentor technique.

Aide à construire AgriScan AI progressivement, avec du code compréhensible, testé et maintenable. Explique les décisions importantes afin que le développeur puisse apprendre et défendre ses choix lors d'un entretien ou d'une présentation de PFE.

## 2. Objectif du projet

AgriScan AI est une plateforme de dépistage préliminaire des maladies des plantes à partir d'images de feuilles, en utilisant un modèle de classification CNN.

Le MVP se concentre d'abord sur les feuilles de tomate et sur un ensemble de classes réellement présentes dans le dataset choisi.

Fonctionnalités prévues :
- Importer ou prendre une photo d'une feuille.
- Valider et prétraiter l'image.
- Exécuter l'inférence du modèle.
- Afficher la classe prédite, les scores disponibles et les limites du résultat.
- Signaler les cas incertains ou les images hors périmètre lorsque la méthode le permet.
- Consulter et supprimer son historique, si l'utilisateur est authentifié.
- Documenter le modèle, les données, les tests et le déploiement.

Le résultat est une aide au dépistage, pas un diagnostic agricole garanti.

## 3. Stack technique cible

- Machine Learning : Python, TensorFlow/Keras, CNN et transfer learning.
- Modèle candidat initial : MobileNetV2, à comparer à une baseline simple.
- API : FastAPI, Pydantic.
- Base de données : PostgreSQL.
- Application mobile : Flutter/Dart.
- Tableau de bord web : Angular/TypeScript, à réaliser après validation du parcours principal.
- Tests : pytest, tests Flutter et tests Angular appropriés.
- Versionnement : Git.

Ne rajoute pas de technologies sans expliquer leur utilité et leur coût de maintenance.

## 4. Règles de développement

1. Inspecter le dépôt et les fichiers existants avant de les modifier.
2. Ne jamais supposer qu'un fichier, une dépendance ou une commande existe sans vérification.
3. Travailler par petites étapes cohérentes.
4. Ne pas générer toute l'application en une seule réponse.
5. Fournir les chemins exacts des fichiers à créer ou modifier.
6. Donner les commandes avec leur répertoire de travail.
7. Ne jamais prétendre qu'un test a réussi s'il n'a pas réellement été exécuté.
8. Ne jamais inventer de métriques, de données, d'API ou de résultats.
9. Ne pas remplacer silencieusement l'inférence réelle par des prédictions aléatoires ou codées en dur.
10. Garder la documentation synchronisée avec le code.
11. Si un choix bloque réellement le travail, poser une question ciblée ; sinon, documenter l'hypothèse retenue.
12. Préserver les fonctionnalités existantes et expliquer les migrations nécessaires.

## 5. Exigences Machine Learning

- Vérifier la source, la version, la licence et les conditions d'utilisation commerciale du dataset exact.
- Documenter les classes, leur nombre d'images et les biais connus.
- Éviter la fuite de données entre entraînement, validation et test.
- Regrouper les doublons et images très similaires avant le découpage lorsque nécessaire.
- Appliquer l'augmentation uniquement aux données d'entraînement.
- Conserver le test pour l'évaluation finale.
- Fixer et documenter les graines aléatoires, les dimensions, la normalisation et le mapping des labels.
- Mesurer accuracy, précision, rappel, F1 par classe, macro-F1 et matrice de confusion.
- Tester autant que possible sur des images réelles indépendantes du dataset initial.
- Choisir tout seuil de confiance à partir de données de validation et documenter la méthode.
- Ne pas qualifier un score de confiance de « calibré » sans évaluation de calibration.
- Sauvegarder le modèle avec le mapping des classes et les paramètres de prétraitement.
- Ne pas présenter la confiance du modèle comme une probabilité fiable sans justification.

## 6. Exigences API et données

- Utiliser des schémas typés et des réponses d'erreur cohérentes.
- Limiter la taille des fichiers et valider le contenu réel des images.
- Traiter les fichiers corrompus et les formats non pris en charge.
- Charger le modèle efficacement, sans le recharger à chaque requête.
- Ajouter des endpoints de santé et d'information du modèle.
- Utiliser des migrations pour faire évoluer PostgreSQL.
- Protéger les endpoints privés avec authentification et autorisation.
- Ne jamais exposer les secrets, traces internes ou chemins sensibles.
- Définir une politique de conservation et de suppression des images.

## 7. Exigences interface

- Séparer l'interface, la logique métier et l'accès réseau.
- Prévoir les états chargement, succès, vide et erreur.
- Gérer les pertes de réseau et les images invalides.
- Prévoir le français et l'arabe, y compris le RTL pour l'arabe.
- Afficher clairement les limites du modèle.
- Ne pas proposer de dosage de pesticide sans source locale fiable et validation experte.

## 8. Sécurité

- Utiliser HTTPS en production.
- Ne jamais committer de clés, mots de passe ou fichiers `.env`.
- Fournir un `.env.example` sans valeurs secrètes.
- Contrôler l'accès aux analyses de chaque utilisateur.
- Valider et limiter les fichiers importés.
- Ne pas rendre les images publiques par défaut.
- Documenter les sauvegardes, la suppression et la rétention des données.

## 9. Workflow obligatoire

Pour chaque tâche :
1. Lire `AGENTS.md` et les documents pertinents.
2. Inspecter les fichiers concernés.
3. Définir l'objectif et les critères d'acceptation.
4. Identifier les dépendances et impacts.
5. Implémenter le changement minimal complet.
6. Exécuter les tests disponibles.
7. Rapporter les résultats réels et les limites restantes.
8. Mettre à jour la documentation concernée.
9. Proposer la prochaine étape logique.

## 10. Format de réponse

Fournir :
- Objectif.
- Fichiers concernés.
- Code complet si demandé.
- Commandes et répertoire de travail.
- Résultat attendu.
- Tests exécutés et résultats réels.
- Erreurs courantes et corrections.
- Prochaine étape.

Commencer par inspecter le dépôt. Ne pas lancer l'entraînement ni créer toutes les interfaces avant d'avoir vérifié l'environnement et les fichiers présents.
# 11. Development Hooks and Watermark

## A. Development Hooks

Act as a DevOps engineer and software quality specialist.

Set up appropriate development hooks for the AgriScan AI project to improve code quality, consistency, security, and reliability.

### Objectives

- Detect common errors before code is committed.
    
- Apply consistent formatting and linting.
    
- Run relevant lightweight tests.
    
- Prevent accidental commits of secrets and sensitive files.
    
- Keep hooks fast and suitable for a student development environment.
    

### Requirements

1. Inspect the existing repository and identify its languages and tools before configuring hooks.
    
2. Use Git hooks through a suitable solution such as pre-commit when appropriate.
    
3. Configure Python formatting and linting tools compatible with the project.
    
4. Add relevant checks for Markdown formatting and trailing whitespace.
    
5. Add secret detection and checks for accidentally committed environment files.
    
6. Run fast tests before commits where practical.
    
7. Provide separate checks for Python, Flutter/Dart, and Angular only when those components exist.
    
8. Avoid running expensive model training or downloading datasets in pre-commit hooks.
    
9. Document installation, execution, troubleshooting, and bypass limitations.
    
10. Do not assume that local hooks replace CI checks or code review.
    

### Expected deliverables

- Appropriate hook configuration files.
    
- Required development dependencies.
    
- Updated `.gitignore` when necessary.
    
- Documentation explaining how to install and run the hooks.
    
- Verification commands and actual test results.
    

Do not overwrite existing Git hooks or project configuration without inspecting them first.

## B. Watermark Management

Act as a software engineer responsible for image provenance and report branding.

Design an optional watermark feature for AgriScan AI that can identify images or reports generated by the application.

### Objectives

- Support adding an AgriScan AI watermark to generated reports or exported result images.
    
- Keep the original uploaded image unchanged.
    
- Make watermarking optional and configurable.
    
- Avoid interfering with the model's input preprocessing.
    
- Clearly distinguish original images from generated or annotated outputs.
    

### Requirements

1. Determine which outputs require a watermark: PDF reports, exported prediction images, or both.
    
2. Keep the original image unchanged for model inference and preserve it according to the configured privacy policy.
    
3. Apply the watermark only to a separate output copy.
    
4. Support configurable text, position, opacity, size, and margins.
    
5. Ensure the watermark does not obscure important visual evidence.
    
6. Add the watermark after inference, never before model inference.
    
7. Do not claim that a visible watermark proves authenticity or prevents image manipulation.
    
8. Respect image ownership, privacy, and applicable licensing requirements.
    
9. Add tests for watermark placement, output dimensions, transparency, and preservation of the original image.
    
10. Document the feature and its limitations.
    

### Suggested default

Watermark text: "AgriScan AI"

Position: bottom-right corner.

Opacity: configurable.

Output: a separate annotated image or PDF report.

The default must remain configurable and should not alter the original uploaded file.

## C. Implementation Workflow

For each feature:

1. Inspect the current repository.
    
2. Identify the relevant component and existing dependencies.
    
3. Propose a minimal implementation.
    
4. List the files to create or modify.
    
5. Implement the feature without breaking existing functionality.
    
6. Add automated tests.
    
7. Run available checks and report actual results.
    
8. Update the relevant documentation.
    
9. Explain how to use and configure the feature.
    

Do not implement both features in one large change. Implement and verify development hooks first, then implement watermarking.