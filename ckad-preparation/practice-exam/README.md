# Practice Exams CKAD

Ce répertoire contient des examens blancs pour préparer la certification CKAD.

## 📋 Liste des examens

| Examen | Difficulté | Questions | Durée | Domaines couverts |
|--------|-----------|-----------|-------|-------------------|
| [Exam 01](./exam-01.md) | Intermédiaire | 17 | 2h | Tous domaines CKAD |

## 🎯 Comment utiliser les examens blancs

### Préparation

1. **Configurez votre environnement** comme pour le vrai examen :
   ```bash
   alias k=kubectl
   export do="--dry-run=client -o yaml"
   source <(kubectl completion bash)
   complete -F __start_kubectl k
   ```

2. **Préparez votre cluster** :
   - Assurez-vous d'avoir un cluster Kubernetes fonctionnel (minikube, kind, k3s)
   - Créez les namespaces nécessaires avant de commencer
   - Vérifiez que vous avez accès à la documentation Kubernetes

3. **Conditions d'examen** :
   - Trouvez un endroit calme
   - Prévoyez 2 heures sans interruption
   - Utilisez un chronomètre
   - N'utilisez que la documentation officielle Kubernetes

### Pendant l'examen

1. **Lisez toutes les questions** rapidement pour identifier les faciles
2. **Commencez par les quick wins** (questions à faible nombre de points)
3. **Marquez les difficiles** pour y revenir
4. **Changez de contexte** si spécifié dans la question
5. **Vérifiez toujours** votre réponse avant de passer à la suivante
6. **Gardez 20-30 min** à la fin pour réviser

### Après l'examen

1. **Calculez votre score** sur 100
2. **Consultez les solutions** dans `../solutions/`
3. **Identifiez vos points faibles** pour cibler vos révisions
4. **Refaites l'examen** une semaine plus tard pour valider la progression

## 🎓 Objectifs par score

| Score | Niveau | Action recommandée |
|-------|--------|-------------------|
| < 50% | Débutant | Refaire tous les TPs et exercices avant de réessayer |
| 50-65% | Intermédiaire | Cibler les domaines faibles, refaire les exercices |
| 66-80% | Prêt | Pratiquer sur Killer.sh, réviser les points faibles |
| > 80% | Très bon niveau | Réserver votre examen CKAD ! |

## ⏱️ Gestion du temps

Pour un examen de 2h avec ~17 questions :

| Type de question | Points | Temps recommandé |
|-----------------|--------|------------------|
| Facile (2-4%)   | 2-4    | 3-5 min |
| Moyen (5-7%)    | 5-7    | 6-9 min |
| Difficile (8%+) | 8+     | 10-12 min |

**Total** : ~100 min pour les questions + 20 min de révision

## 📊 Répartition par domaine

Les examens blancs respectent la pondération officielle CKAD :

- Application Design and Build : 20%
- Application Deployment : 20%
- Application Observability and Maintenance : 15%
- Application Environment, Configuration and Security : 25%
- Services and Networking : 20%

## 💡 Tips pour maximiser votre score

1. **Ne codez pas from scratch** : Utilisez toujours `--dry-run=client -o yaml`
2. **Automatisez** : Créez des snippets vim ou des aliases pour les patterns récurrents
3. **Priorisez** : Faites d'abord les questions qui rapportent le plus de points/minute
4. **Vérifiez systématiquement** :
   ```bash
   k apply -f file.yaml
   k get <resource>
   k describe <resource>
   k logs <pod> (si applicable)
   ```
5. **Documentation** : Sachez exactement où trouver les exemples clés dans kubernetes.io

## 🔄 Plan d'entraînement recommandé

### Semaine 1-4 : Fondamentaux
- Compléter tous les exercices de `../exercises/`
- Pratiquer les commandes kubectl rapidement

### Semaine 5 : Premier exam blanc
- Faire Exam 01 en conditions réelles
- Identifier les domaines faibles
- Refaire les exercices correspondants

### Semaine 6 : Révisions ciblées
- Se concentrer sur les domaines < 70%
- Refaire Exam 01
- Pratiquer sur Killer.sh (session 1)

### Semaine 7 : Simulation finale
- Killer.sh session 2
- Réviser les erreurs
- Créer votre cheatsheet personnelle

### Semaine 8 : Examen CKAD
- Révision légère
- Repos la veille
- CKAD Exam Day! 🎉

## 📚 Ressources complémentaires

- [CKAD Curriculum officiel](https://github.com/cncf/curriculum)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Killer.sh Simulator](https://killer.sh)
- [Cheatsheet](../cheatsheet.md)

---

**Bon entraînement ! La pratique est la clé du succès. 🚀**
