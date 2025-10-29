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

### TP1 - Premier déploiement Kubernetes avec Minikube

**Objectifs:**
- Installer et configurer minikube sur AlmaLinux
- Démarrer un cluster Kubernetes local
- Déployer votre première application
- Exposer l'application via un service
- Interagir avec les pods et services

**Contenu:**
1. Installation de l'environnement (Docker, kubectl, minikube)
2. Démarrage du cluster Kubernetes
3. Premier déploiement (Nginx)
4. Exposition de l'application
5. Manipulations avancées (scaling, rollout, rollback)
6. Utilisation de fichiers YAML
7. Nettoyage et commandes utiles

**Fichier:** [.claude/QUICKSTART.md](.claude/QUICKSTART.md#tp1---premier-déploiement-kubernetes-sur-almalinux-avec-minikube)

**Exercices pratiques:**
- Déploiement Redis
- Application multi-conteneurs
- Manipulation YAML avec MySQL

**Durée estimée:** 3-4 heures

## Installation rapide

```bash
# Cloner le repository
git clone https://github.com/aboigues/kubernetes-formation.git
cd kubernetes-formation

# Consulter le TP1
cat .claude/QUICKSTART.md
```

## Repository

```
https://github.com/aboigues/kubernetes-formation.git
```

## Structure du projet

```
kubernetes-formation/
├── README.md                  # Ce fichier
├── .claude/                   # Configuration et instructions
│   ├── INSTRUCTIONS.md        # Instructions pour Claude
│   ├── QUICKSTART.md          # TP1 - Premier déploiement Kubernetes
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

2. **Lire le TP1**
   ```bash
   less .claude/QUICKSTART.md
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
- ConfigMaps et Secrets
- Namespaces et Resource Quotas
- Ingress Controllers
- StatefulSets
- DaemonSets
- Jobs et CronJobs
- Helm (gestionnaire de packages)

## Progression recommandée

1. **TP1** : Bases de Kubernetes et premier déploiement
2. **TP2** (à venir) : Gestion de la configuration et des secrets
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

**Bon apprentissage Kubernetes !** 🚀
