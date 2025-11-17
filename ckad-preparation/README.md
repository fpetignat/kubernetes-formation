# Préparation CKAD - Kubernetes Formation

Ce répertoire contient tous les exercices et ressources pour préparer la certification **CKAD (Certified Kubernetes Application Developer)**.

## 📋 Structure du répertoire

```
ckad-preparation/
├── README.md                          # Ce fichier
├── cheatsheet.md                      # Commandes essentielles pour l'examen
├── exercises/                         # Exercices par domaine CKAD
│   ├── 01-application-design-build/
│   ├── 02-application-deployment/
│   ├── 03-observability-maintenance/
│   ├── 04-environment-config-security/
│   └── 05-services-networking/
├── practice-exam/                     # Examens blancs
└── solutions/                         # Solutions des exercices
```

## 🎯 Domaines CKAD (2024)

| Domaine | Pondération | Répertoire |
|---------|------------|------------|
| Application Design and Build | 20% | `01-application-design-build/` |
| Application Deployment | 20% | `02-application-deployment/` |
| Application Observability and Maintenance | 15% | `03-observability-maintenance/` |
| Application Environment, Configuration and Security | 25% | `04-environment-config-security/` |
| Services and Networking | 20% | `05-services-networking/` |

## 🚀 Comment utiliser ce répertoire

### 1. Parcours recommandé

#### Phase 1 : Fondamentaux (Semaines 1-2)
```bash
# Compléter d'abord les TPs de base
cd ../tp1-pods-deployments && cat quickstart.md
cd ../tp2-services && cat quickstart.md
cd ../tp3-configmaps-secrets && cat quickstart.md

# Puis pratiquer les exercices CKAD correspondants
cd ckad-preparation/exercises/02-application-deployment
cd ckad-preparation/exercises/05-services-networking
cd ckad-preparation/exercises/04-environment-config-security
```

#### Phase 2 : Observabilité et Sécurité (Semaines 3-4)
```bash
# TPs avancés
cd ../tp4-health-checks && cat quickstart.md
cd ../tp5-resources-quotas && cat quickstart.md

# Exercices CKAD
cd ckad-preparation/exercises/03-observability-maintenance
cd ckad-preparation/exercises/04-environment-config-security
```

#### Phase 3 : Production Ready (Semaines 5-6)
```bash
# TP CI/CD
cd ../tp6-production-cicd && cat quickstart.md

# Exercices CKAD
cd ckad-preparation/exercises/01-application-design-build
cd ckad-preparation/exercises/02-application-deployment
```

#### Phase 4 : Simulation d'examen (Semaine 6+)
```bash
# Examens blancs chronométrés
cd ckad-preparation/practice-exam
```

### 2. Workflow d'apprentissage

Pour chaque exercice :

1. **Lire l'énoncé** sans regarder la solution
2. **Tenter de résoudre** en utilisant kubectl et la doc officielle
3. **Chronométrer** votre temps (objectif : 6-8 min par exercice)
4. **Vérifier** que votre solution fonctionne
5. **Comparer** avec la solution proposée
6. **Répéter** si besoin jusqu'à maîtrise complète

### 3. Configuration initiale de votre environnement

Avant de commencer les exercices, configurez votre shell :

```bash
# Copier dans ~/.bashrc ou exécuter dans chaque session
alias k=kubectl
export do="--dry-run=client -o yaml"
export now="--force --grace-period=0"

# Autocompletion
source <(kubectl completion bash)
complete -F __start_kubectl k

# Vérifier la configuration
k version --short
k cluster-info
```

## 📚 Ressources essentielles

### Documentation officielle (autorisée à l'examen)
- https://kubernetes.io/docs/
- https://kubernetes.io/blog/
- https://github.com/kubernetes/

### Bookmarks recommandés pour l'examen
1. [Pod Spec Reference](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#pod-v1-core)
2. [Service Spec](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#service-v1-core)
3. [Deployment Spec](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#deployment-v1-apps)
4. [ConfigMap Examples](https://kubernetes.io/docs/concepts/configuration/configmap/)
5. [Secret Examples](https://kubernetes.io/docs/concepts/configuration/secret/)
6. [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
7. [Resource Limits](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
8. [Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)

### Simulateurs d'examen
- **Killer.sh** : 2 sessions incluses avec l'inscription CKAD
- **KodeKloud** : Plateforme d'entraînement CKAD

### Repositories d'exercices
- [CKAD Exercises](https://github.com/dgkanatsios/CKAD-exercises)
- [CKAD Practice Questions](https://github.com/bbachi/CKAD-Practice-Questions)

## ✅ Checklist de préparation

### Compétences techniques
- [ ] Maîtriser `kubectl` (create, get, describe, edit, delete, logs, exec)
- [ ] Savoir générer des manifests avec `--dry-run=client -o yaml`
- [ ] Créer et gérer des Pods, Deployments, ReplicaSets
- [ ] Configurer des Services (ClusterIP, NodePort, LoadBalancer)
- [ ] Utiliser ConfigMaps et Secrets (create, mount, env)
- [ ] Implémenter des probes (liveness, readiness, startup)
- [ ] Gérer les ressources (requests, limits, quotas)
- [ ] Créer et appliquer des NetworkPolicies
- [ ] Comprendre les patterns multi-conteneurs (sidecar, init, adapter)
- [ ] Maîtriser les stratégies de déploiement (RollingUpdate, Recreate)
- [ ] Déboguer des Pods qui ne démarrent pas
- [ ] Utiliser les labels et selectors efficacement

### Pratique
- [ ] Compléter tous les exercices de `exercises/`
- [ ] Réaliser au moins 2 examens blancs complets
- [ ] Atteindre 70%+ de réussite sur les practice exams
- [ ] Résoudre chaque exercice en moins de 8 minutes
- [ ] Pratiquer sur Killer.sh (au moins 2 sessions)

### Logistique examen
- [ ] Réserver votre créneau d'examen
- [ ] Vérifier ID officielle (passeport, CNI)
- [ ] Tester webcam et microphone
- [ ] Préparer environnement calme et isolé
- [ ] Nettoyer votre bureau (aucun papier, téléphone, etc.)
- [ ] Tester la connexion internet

## ⚡ Tips pour l'examen

### Avant l'examen
1. Dormez bien la veille
2. Arrivez 15 min en avance pour le check-in
3. Ayez une bouteille d'eau (transparente, sans étiquette)
4. Préparez vos bookmarks dans le navigateur

### Pendant l'examen
1. **Lisez attentivement** chaque question (namespace, nom, contexte)
2. **Changez de contexte** si demandé : `kubectl config use-context <name>`
3. **Utilisez --dry-run** pour générer les manifests
4. **Vérifiez toujours** après création : `k get`, `k describe`, `k logs`
5. **Ne perdez pas de temps** : marquez les questions difficiles, revenez-y plus tard
6. **Utilisez vim efficacement** : `:set paste`, `:set number`, `/search`

### Stratégie de temps
- 2h pour ~15-20 questions = **6-8 min/question**
- Questions à 1% : **3-4 min max**
- Questions à 7-8% : **10-12 min max**
- Gardez **20-30 min** pour réviser à la fin

## 🎓 Corrélation avec les TPs du repository

Les 6 TPs du repository couvrent l'essentiel du curriculum CKAD :

| TP | Domaine CKAD | Lien |
|----|--------------|------|
| TP1 | Application Deployment (20%) | [tp1-pods-deployments/](../tp1-pods-deployments/) |
| TP2 | Services & Networking (20%) | [tp2-services/](../tp2-services/) |
| TP3 | Environment & Config (25%) | [tp3-configmaps-secrets/](../tp3-configmaps-secrets/) |
| TP4 | Observability (15%) | [tp4-health-checks/](../tp4-health-checks/) |
| TP5 | Environment & Security (25%) | [tp5-resources-quotas/](../tp5-resources-quotas/) |
| TP6 | Design & Deployment (20%) | [tp6-production-cicd/](../tp6-production-cicd/) |

**Recommandation** : Compléter tous les TPs avant de commencer les exercices CKAD spécifiques.

## 📊 Suivi de progression

Créez un fichier `progress.md` pour suivre votre progression :

```markdown
# Ma progression CKAD

## Exercices complétés
- [x] 01-application-design-build (8/10)
- [ ] 02-application-deployment (5/12)
- [ ] 03-observability-maintenance (0/8)
- [ ] 04-environment-config-security (6/15)
- [ ] 05-services-networking (4/10)

## Examens blancs
- [ ] Practice Exam 1 : __/100
- [ ] Practice Exam 2 : __/100
- [ ] Killer.sh Session 1 : __/100
- [ ] Killer.sh Session 2 : __/100

## Points faibles à travailler
- NetworkPolicies (règles egress)
- Init containers
- SecurityContext (runAsUser, capabilities)
```

## 🆘 Besoin d'aide ?

- Consultez [cheatsheet.md](./cheatsheet.md) pour les commandes rapides
- Relisez les quickstart des TPs correspondants
- Posez vos questions sur le Slack du cours
- Référez-vous à la documentation officielle Kubernetes

---

**Bon courage pour votre préparation CKAD ! 🚀**

*La pratique régulière est la clé du succès. Consacrez au moins 1h par jour pendant 6 semaines.*
