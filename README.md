# Formation Kubernetes

![Test Kubernetes Manifests](https://github.com/aboigues/kubernetes-formation/actions/workflows/test-kubernetes-manifests.yml/badge.svg)

Formation complète et pratique sur Kubernetes avec des TPs progressifs pour apprendre le déploiement, la gestion et l'orchestration de conteneurs.

## Description

Ce projet propose une formation Kubernetes structurée en travaux pratiques (TP) permettant d'acquérir progressivement les compétences essentielles pour déployer et gérer des applications conteneurisées sur Kubernetes.

**Type:** Formation pratique

**Environnement:** AlmaLinux avec minikube

## Prérequis

- Machine Linux (AlmaLinux recommandé) ou machine virtuelle
- 2 CPU minimum
- 2 Go de RAM minimum
- 20 Go d'espace disque
- Accès root ou sudo
- Connexion Internet pour télécharger les outils et images

## Table des matières

### Travaux pratiques

- **[TP1 - Premier déploiement Kubernetes avec Minikube](tp1/README.md)**

  Installation, configuration et premiers pas avec Kubernetes sur AlmaLinux

- **[TP2 - Maîtriser les Manifests Kubernetes](tp2/README.md)**

  Apprentissage approfondi de la rédaction de manifests YAML

- **[TP3 - Persistance des données dans Kubernetes](tp3/README.md)**

  Gestion des volumes et du stockage persistant

- **[TP4 - Monitoring et Gestion des Logs](tp4/README.md)**

  Observabilité, métriques, logs et alertes dans Kubernetes

- **[TP5 - Sécurité et RBAC](tp5/README.md)**

  Sécurisation des clusters, contrôle d'accès et bonnes pratiques

- **[TP6 - Mise en Production et CI/CD](tp6/README.md)**

  Déploiement automatisé, GitOps, Helm et stratégies de mise en production

### Documentation complémentaire

- [Installation rapide](#installation-rapide)
- [Structure du projet](#structure-du-projet)
- [Commandes kubectl essentielles](#commandes-kubectl-essentielles)
- [Ressources complémentaires](#ressources-complémentaires)
- [Workflow avec Claude](#workflow-avec-claude)

---

## Vue d'ensemble des TPs

### TP1 - Premier déploiement Kubernetes avec Minikube

📁 **[Accéder au TP1](tp1/README.md)**

Apprenez les bases de Kubernetes en installant et configurant un environnement local avec minikube. Ce TP couvre :
- Installation de Docker, kubectl et minikube sur AlmaLinux
- Démarrage et gestion d'un cluster Kubernetes local
- Déploiement de votre première application
- Exposition et scaling des applications
- Utilisation des fichiers YAML
- Rolling updates et rollbacks

**Durée estimée :** 3-4 heures
**Niveau :** Débutant

### TP2 - Maîtriser les Manifests Kubernetes

📁 **[Accéder au TP2](tp2/README.md)**

Maîtrisez l'écriture de manifests YAML Kubernetes et les bonnes pratiques de déploiement. Ce TP couvre :
- Structure et anatomie des manifests Kubernetes
- Création de Pods, Deployments et Services
- Gestion de la configuration avec ConfigMaps et Secrets
- Utilisation avancée des labels et selectors
- Namespaces et organisation des ressources
- Validation, tests et debugging
- Bonnes pratiques de production

**Durée estimée :** 5-6 heures
**Niveau :** Intermédiaire

### TP3 - Persistance des données dans Kubernetes

📁 **[Accéder au TP3](tp3/README.md)**

Apprenez à gérer le stockage persistant et les volumes dans Kubernetes. Ce TP couvre :
- Types de volumes (emptyDir, hostPath, PVC)
- PersistentVolumes et PersistentVolumeClaims
- StorageClasses et provisionnement dynamique
- Modes d'accès et politiques de réclamation
- Déploiement de bases de données avec persistance
- Expansion de volumes et snapshots
- Bonnes pratiques de gestion du stockage

**Durée estimée :** 4-5 heures
**Niveau :** Intermédiaire

### TP4 - Monitoring et Gestion des Logs

📁 **[Accéder au TP4](tp4/README.md)**

Maîtrisez l'observabilité et le monitoring de vos clusters Kubernetes. Ce TP couvre :
- Les trois piliers de l'observabilité (métriques, logs, traces)
- Installation et utilisation de Metrics Server
- Horizontal Pod Autoscaler (HPA)
- Dashboard Kubernetes
- Collecte et analyse des logs avec kubectl
- Déploiement de Prometheus pour le monitoring
- Création de dashboards avec Grafana
- Configuration d'alertes
- Introduction aux stacks EFK/ELK
- Bonnes pratiques de monitoring et logging

**Durée estimée :** 5-6 heures
**Niveau :** Intermédiaire/Avancé

### TP5 - Sécurité et RBAC

📁 **[Accéder au TP5](tp5/README.md)**

Maîtrisez la sécurité et le contrôle d'accès dans Kubernetes. Ce TP couvre :
- ServiceAccounts et identités
- RBAC : Roles, ClusterRoles, RoleBindings
- Security Contexts et Pod Security Standards
- Network Policies pour l'isolation réseau
- Gestion sécurisée des Secrets
- Audit et logging de sécurité
- Scanner de vulnérabilités d'images
- Admission Controllers
- Bonnes pratiques de sécurité en production

**Durée estimée :** 6-7 heures
**Niveau :** Avancé

### TP6 - Mise en Production et CI/CD

📁 **[Accéder au TP6](tp6/README.md)**

Maîtrisez le déploiement en production et l'automatisation avec Kubernetes. Ce TP couvre :
- Helm : Charts, releases et gestionnaire de packages
- Ingress Controllers : NGINX Ingress, routing HTTP/HTTPS
- CI/CD : Pipelines avec GitHub Actions
- Stratégies de déploiement : Rolling, Blue-Green, Canary
- GitOps : Déploiement continu avec ArgoCD
- Gestion d'environnements multiples (dev, staging, prod)
- HPA, PDB et haute disponibilité
- Sealed Secrets et gestion sécurisée de la configuration
- Kustomize pour la configuration multi-environnements
- Monitoring, alertes et bonnes pratiques de production

**Durée estimée :** 8-10 heures
**Niveau :** Avancé

---

## Installation rapide

```bash
# Cloner le repository
git clone https://github.com/aboigues/kubernetes-formation.git
cd kubernetes-formation

# Accéder au TP1 pour commencer
cd tp1
cat README.md
```

## Repository

```
https://github.com/aboigues/kubernetes-formation.git
```

## Structure du projet

```
kubernetes-formation/
├── README.md                  # Ce fichier
├── tp1/                       # TP1 - Premier déploiement
│   └── README.md             # Guide complet du TP1
├── tp2/                       # TP2 - Manifests Kubernetes
│   └── README.md             # Guide complet du TP2
├── tp3/                       # TP3 - Persistance des données
│   └── README.md             # Guide complet du TP3
├── tp4/                       # TP4 - Monitoring et Logs
│   └── README.md             # Guide complet du TP4
├── tp5/                       # TP5 - Sécurité et RBAC
│   └── README.md             # Guide complet du TP5
├── tp6/                       # TP6 - Mise en Production et CI/CD
│   └── README.md             # Guide complet du TP6
├── .claude/                   # Configuration et instructions
│   ├── INSTRUCTIONS.md        # Instructions pour Claude
│   ├── QUICKSTART.md          # Guide de démarrage rapide
│   └── CONTEXT.md             # Contexte et historique
├── docs/                      # Documentation complémentaire
├── examples/                  # Exemples de manifests YAML
│   ├── deployments/          # Exemples de déploiements
│   ├── services/             # Exemples de services
│   └── configs/              # Exemples de ConfigMaps et Secrets
└── exercises/                 # Solutions des exercices
```

## Démarrage

1. **Cloner le repository**
   ```bash
   git clone https://github.com/aboigues/kubernetes-formation.git
   cd kubernetes-formation
   ```

2. **Commencer par le TP1**
   ```bash
   cd tp1
   less README.md
   ```

3. **Suivre les instructions d'installation**
   - Commencer par la Partie 1 du TP1 pour installer l'environnement
   - Suivre les parties progressivement

4. **Réaliser les exercices pratiques**
   - Chaque TP contient des exercices avec solutions

## Tests automatiques

Cette formation intègre des tests automatiques via GitHub Actions pour garantir la qualité des manifests Kubernetes.

### Ce qui est testé

- **Validation YAML** : Syntaxe de tous les fichiers YAML du TP3
- **Validation Kubernetes** : Conformité des manifests avec les schémas Kubernetes
- **Tests d'intégration** : Déploiement réel sur Minikube (TP3)
- **Extraction README** : Validation de ~163 manifests contenus dans les README
- **Qualité documentation** : Vérification de la structure des README

### Statut par TP

| TP | Fichiers YAML testés | Tests d'intégration | Manifests README validés |
|----|----------------------|---------------------|--------------------------|
| TP1 | - | - | ~3 manifests |
| TP2 | - | - | ~35 manifests |
| TP3 | ✅ 9 fichiers | ✅ Tests Minikube | ~14 manifests |
| TP4 | - | - | ~23 manifests |
| TP5 | - | - | ~45 manifests |
| TP6 | - | - | ~43 manifests |

Pour plus de détails sur les tests, consultez [.github/workflows/README.md](.github/workflows/README.md).

## Concepts clés couverts

- **Conteneurisation** : Docker et containerd
- **Orchestration** : Kubernetes et minikube
- **Pods** : Unité de base de déploiement
- **Deployments** : Gestion déclarative des applications
- **Services** : Exposition et découverte de services
- **ConfigMaps & Secrets** : Gestion de la configuration
- **Scaling** : Mise à l'échelle horizontale
- **Rolling updates** : Mises à jour sans interruption
- **Rollback** : Retour arrière en cas de problème
- **YAML manifests** : Infrastructure as Code
- **kubectl** : Outil de ligne de commande

## Commandes kubectl essentielles

```bash
# Informations sur le cluster
kubectl cluster-info
kubectl get nodes

# Gestion des déploiements
kubectl create deployment <name> --image=<image>
kubectl get deployments
kubectl describe deployment <name>
kubectl delete deployment <name>

# Gestion des pods
kubectl get pods
kubectl get pods -o wide
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl exec -it <pod-name> -- /bin/bash

# Gestion des services
kubectl expose deployment <name> --type=NodePort --port=80
kubectl get services
kubectl describe service <name>

# Scaling
kubectl scale deployment <name> --replicas=3

# Mises à jour
kubectl set image deployment/<name> <container>=<image>
kubectl rollout status deployment/<name>
kubectl rollout history deployment/<name>
kubectl rollout undo deployment/<name>

# Fichiers YAML
kubectl apply -f <file.yaml>
kubectl delete -f <file.yaml>

# Informations générales
kubectl get all
kubectl get events
```

## Ressources complémentaires

### Documentation officielle
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

### Tutoriels interactifs
- [Kubernetes Tutorials](https://kubernetes.io/docs/tutorials/)
- [Katacoda Kubernetes Scenarios](https://www.katacoda.com/courses/kubernetes)

### Concepts avancés (à explorer après les TPs)
- Ingress Controllers et Ingress Resources
- StatefulSets pour applications avec état
- DaemonSets pour déploiements sur tous les nœuds
- Jobs et CronJobs pour tâches batch
- Helm (gestionnaire de packages)
- Service Mesh (Istio, Linkerd)
- GitOps (ArgoCD, FluxCD)
- Custom Resource Definitions (CRDs)
- Operators

## Progression recommandée

1. **TP1** : Bases de Kubernetes et premier déploiement ✅
2. **TP2** : Maîtrise des manifests YAML ✅
3. **TP3** : Persistance des données ✅
4. **TP4** : Monitoring et logs ✅
5. **TP5** : Sécurité et RBAC ✅
6. **TP6** : Mise en production et CI/CD ✅

## Workflow avec Claude

### Nouvelle session

1. Claude recherche le contexte avec `conversation_search`
2. Clone le repo
3. Lit `.claude/INSTRUCTIONS.md`
4. Itère sur le code existant
5. Commit et push les modifications

### Commandes Git

```bash
# Cloner
git clone https://TOKEN@github.com/aboigues/kubernetes-formation.git

# Voir l'historique
git log --oneline

# Pousser les modifications
git add .
git commit -m "Description"
git push origin main
```

## Contribution

Ce projet est en développement continu. Les contributions sont les bienvenues :

- Signaler des bugs ou problèmes
- Proposer des améliorations
- Ajouter de nouveaux TPs
- Améliorer la documentation

## Licence

Ce projet de formation est fourni à des fins éducatives.

## Auteur

**Créé par:** aboigues
**Avec l'aide de:** Claude (Anthropic)
**Date de création:** 2025-10-29

---

**Bon apprentissage Kubernetes !**
