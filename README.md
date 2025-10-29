# Formation Kubernetes

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
- Persistent Volumes et Storage
- Ingress Controllers
- StatefulSets
- DaemonSets
- Jobs et CronJobs
- Helm (gestionnaire de packages)
- Network Policies
- RBAC (contrôle d'accès)

## Progression recommandée

1. **TP1** : Bases de Kubernetes et premier déploiement ✅
2. **TP2** : Maîtrise des manifests YAML ✅
3. **TP3** (à venir) : Persistance des données
4. **TP4** (à venir) : Monitoring et logs
5. **TP5** (à venir) : Mise en production

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
