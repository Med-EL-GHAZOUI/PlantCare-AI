# Requirements — AgriScan AI

## 1. Exigences fonctionnelles

- **FR-01** : l'utilisateur peut choisir ou capturer une image prise en charge.
- **FR-02** : le backend valide le format, la taille et le décodage de l'image.
- **FR-03** : le modèle renvoie des scores pour les classes apprises.
- **FR-04** : le système peut retourner un statut incertain si les critères définis sont atteints.
- **FR-05** : l'interface affiche la prédiction, les scores disponibles et un avertissement sur les limites.
- **FR-06** : un utilisateur authentifié peut consulter son propre historique.
- **FR-07** : un utilisateur peut supprimer ses propres analyses conformément à la politique de conservation.
- **FR-08** : l'API expose un endpoint de santé et des informations de version du modèle.
- **FR-09** : les erreurs sont présentées clairement sans divulguer de détails internes.
- **FR-10** : les interfaces visent le français et l'arabe, avec prise en charge du RTL.
- **FR-11** : les classes et la version du modèle sont traçables pour chaque analyse enregistrée.

## 2. Exigences non fonctionnelles

- **NFR-01 — Fiabilité** : le modèle est évalué sur des données séparées de l'entraînement.
- **NFR-02 — Reproductibilité** : les versions, graines, prétraitements et paramètres sont documentés.
- **NFR-03 — Sécurité** : les fichiers et accès aux ressources sont validés.
- **NFR-04 — Confidentialité** : les règles de conservation et de suppression sont définies.
- **NFR-05 — Maintenabilité** : code modulaire, tests et documentation à jour.
- **NFR-06 — Performance** : les objectifs de latence sont mesurés sur un matériel déclaré.
- **NFR-07 — Accessibilité** : interface lisible, erreurs explicites et navigation cohérente.
- **NFR-08 — Compatibilité** : versions et prérequis logiciels sont consignés.

## 3. Hors périmètre du MVP

- Diagnostic garanti.
- Prise en charge de toutes les cultures.
- Prescription automatique de pesticides ou de dosages.
- Fonctionnement hors ligne garanti.
- Paiements et abonnements avant validation du besoin.
- Architecture distribuée complexe sans nécessité mesurée.

## 4. Critères d'acceptation

Une fonctionnalité est terminée lorsque :
1. Son comportement attendu est documenté.
2. Les tests pertinents existent et passent dans l'environnement déclaré.
3. Les erreurs principales sont gérées.
4. La sécurité et les droits d'accès sont vérifiés lorsque nécessaire.
5. La documentation est cohérente avec l'implémentation.

## Documents liés

- [Project Context](PROJECT_CONTEXT.md)
- [Architecture](ARCHITECTURE.md)
- [Security](SECURITY.md)
- [Roadmap](ROADMAP.md)
