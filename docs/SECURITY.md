# Security and Privacy — AgriScan AI

## 1. Principes

- Minimiser les données collectées.
- Refuser les fichiers invalides et limiter la taille des uploads.
- Protéger les comptes et les ressources privées.
- Ne pas rendre les images publiques par défaut.
- Ne jamais committer de secrets.
- Définir une politique claire de conservation et de suppression.

## 2. Gestion des secrets

- Utiliser des variables d'environnement ou un gestionnaire de secrets adapté.
- Fournir uniquement des exemples fictifs dans `.env.example`.
- Ajouter `.env`, les clés privées et les fichiers de credentials à `.gitignore`.
- Si un secret est committé, le révoquer ou le faire tourner ; supprimer seulement le texte du dépôt ne suffit pas.

## 3. Upload d'images

- Définir une taille maximale.
- Vérifier l'extension, le type déclaré et le contenu réel.
- Décoder l'image avec une bibliothèque maintenue.
- Rejeter les fichiers corrompus et formats non pris en charge.
- Éviter d'utiliser directement le nom fourni par le client comme chemin de fichier.
- Utiliser des noms générés côté serveur si un stockage est nécessaire.
- Ne jamais exécuter un fichier uploadé.

## 4. Authentification et autorisation

- Utiliser une solution d'authentification maintenue.
- Hacher les mots de passe avec un algorithme adapté si l'authentification locale est implémentée.
- Vérifier les permissions côté serveur pour chaque analyse.
- Ne pas considérer qu'un UUID difficile à deviner remplace l'autorisation.
- Protéger les routes d'administration et limiter les tentatives abusives.

## 5. Images et données personnelles

- Définir si les images sont conservées, pendant combien de temps et pourquoi.
- Demander le consentement requis lorsque cela s'applique.
- Fournir un mécanisme de suppression.
- Ne pas journaliser inutilement les images, tokens, mots de passe ou données personnelles.
- Restreindre l'accès aux fichiers stockés.

## 6. Production

- HTTPS obligatoire.
- Configurer les CORS selon les origines autorisées.
- Utiliser des dépendances maintenues et mettre à jour les correctifs de sécurité.
- Protéger les sauvegardes et tester la restauration.
- Surveiller les erreurs sans collecter de données sensibles inutiles.
- Définir des limites de débit et d'usage adaptées au déploiement.

## 7. Checklist avant publication

- [ ] Aucun secret dans Git.
- [ ] Upload limité et validé.
- [ ] Autorisation testée pour les analyses privées.
- [ ] HTTPS activé.
- [ ] CORS configuré explicitement.
- [ ] Politique de conservation et suppression documentée.
- [ ] Dépendances vérifiées.
- [ ] Sauvegarde et restauration testées.
- [ ] Messages d'erreur sans détails internes.

## Documents liés

- [Architecture](ARCHITECTURE.md)
- [Database](DATABASE.md)
- [API Specification](API_SPECIFICATION.md)
- [Requirements](REQUIREMENTS.md)
