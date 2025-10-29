# Workflows GitHub Actions - Tests de la Formation Kubernetes

Ce dossier contient les workflows GitHub Actions pour tester automatiquement les TPs de la formation Kubernetes.

## Workflow: test-kubernetes-manifests.yml

### Vue d'ensemble

Ce workflow valide et teste automatiquement les manifests Kubernetes de la formation lors de chaque push ou pull request.

### Jobs exécutés

#### 1. validate-yaml-syntax

**Objectif**: Valider la syntaxe YAML des fichiers

- Utilise `yamllint` pour vérifier la syntaxe YAML
- Teste tous les fichiers `.yaml` du TP3
- Configuration yamllint personnalisée pour Kubernetes

**Outils utilisés**:
- yamllint

#### 2. validate-kubernetes-manifests

**Objectif**: Valider la conformité des manifests Kubernetes

- Utilise `kubeconform` pour valider les schémas Kubernetes
- Utilise `kubectl --dry-run` pour simuler l'application des manifests
- Teste tous les fichiers YAML du TP3

**Outils utilisés**:
- kubectl v1.28.0
- kubeconform v0.6.4

#### 3. test-tp3-storage

**Objectif**: Tests d'intégration sur Minikube

Ce job crée un cluster Minikube réel et teste les ressources du TP3:

1. **emptyDir Pod** (01-emptydir-pod.yaml)
   - Création d'un pod avec volume emptyDir
   - Vérification que le pod passe en état Ready

2. **PersistentVolume** (02-persistent-volume.yaml)
   - Création d'un PersistentVolume
   - Vérification de sa disponibilité

3. **PersistentVolumeClaim** (03-persistent-volume-claim.yaml)
   - Création d'un PVC
   - Vérification du binding avec le PV

4. **Pod with PVC** (04-pod-with-pvc.yaml)
   - Création d'un pod utilisant le PVC
   - Vérification que le pod passe en état Ready

**Environnement**:
- Minikube avec Kubernetes v1.28.0
- Cleanup automatique des ressources

#### 4. validate-readme-manifests

**Objectif**: Extraire et valider les manifests YAML contenus dans les README

- Extrait tous les blocs de code YAML des fichiers README.md
- Valide la syntaxe YAML de chaque bloc
- Identifie les ressources Kubernetes valides
- Génère un rapport avec statistiques

**Portée**:
- TP1: ~3 manifests
- TP2: ~35 manifests
- TP3: ~14 manifests
- TP4: ~23 manifests
- TP5: ~45 manifests
- TP6: ~43 manifests

**Total**: ~163 manifests dans les README

#### 5. lint-readme

**Objectif**: Vérifier la qualité des fichiers README

- Vérifie que tous les README existent (tp1-tp6)
- Compte le nombre de lignes de chaque README
- Détecte les code blocks non fermés
- Vérifie la cohérence du markdown

## Déclenchement

Le workflow s'exécute automatiquement sur:

```yaml
on:
  push:
    branches: [ main, claude/** ]
  pull_request:
    branches: [ main ]
```

- Tous les push sur `main`
- Tous les push sur les branches `claude/**`
- Toutes les pull requests vers `main`

## Statut des tests par TP

| TP | Fichiers YAML | Tests d'intégration | Validation README |
|----|---------------|---------------------|-------------------|
| TP1 | ❌ Aucun | ❌ Non | ✅ Oui |
| TP2 | ❌ Aucun | ❌ Non | ✅ Oui |
| TP3 | ✅ 9 fichiers | ✅ Oui (Minikube) | ✅ Oui |
| TP4 | ❌ Aucun | ❌ Non | ✅ Oui |
| TP5 | ❌ Aucun | ❌ Non | ✅ Oui |
| TP6 | ❌ Aucun | ❌ Non | ✅ Oui |

## Résultats attendus

### ✅ Tests qui doivent passer

1. **Validation YAML** : Tous les fichiers YAML du TP3 doivent avoir une syntaxe valide
2. **Validation Kubernetes** : Les manifests du TP3 doivent être conformes aux schémas Kubernetes
3. **Tests d'intégration TP3** : Les ressources de base du TP3 doivent se créer sans erreur
4. **README** : Tous les README doivent exister et être bien formés

### ⚠️ Tests informatifs (non bloquants)

1. **Extraction des manifests README** : Extraction et validation des YAML des README
   - Ce test ne fait pas échouer le workflow
   - Génère un rapport informatif sur la qualité des exemples

## Améliorations futures possibles

### TP1 - Premier déploiement
- Créer des fichiers YAML d'exemple pour les exercices
- Tester les déploiements basiques

### TP2 - Manifests Kubernetes
- Extraire et créer des fichiers YAML testables
- Valider les ConfigMaps et Secrets

### TP4 - Monitoring et Logs
- Tester l'installation de Metrics Server
- Valider les configurations Prometheus/Grafana

### TP5 - Sécurité et RBAC
- Tester les configurations RBAC
- Valider les NetworkPolicies
- Vérifier les SecurityContexts

### TP6 - CI/CD et Production
- Tester les Helm charts
- Valider les configurations Ingress
- Tester les stratégies de déploiement

## Outils utilisés

| Outil | Version | Usage |
|-------|---------|-------|
| kubectl | v1.28.0 | Validation et tests Kubernetes |
| kubeconform | v0.6.4 | Validation des schémas Kubernetes |
| yamllint | latest | Validation syntaxe YAML |
| Minikube | latest | Tests d'intégration |
| Python | 3.11 | Extraction et parsing YAML |

## Débogage

### Voir les logs d'un job

1. Aller sur l'onglet "Actions" du repository GitHub
2. Cliquer sur le workflow run
3. Cliquer sur le job concerné
4. Voir les logs détaillés de chaque step

### Exécuter les tests localement

#### Test de syntaxe YAML

```bash
pip install yamllint
yamllint tp3/*.yaml
```

#### Validation Kubernetes

```bash
# Installation de kubeconform
wget https://github.com/yannh/kubeconform/releases/download/v0.6.4/kubeconform-linux-amd64.tar.gz
tar xf kubeconform-linux-amd64.tar.gz
sudo mv kubeconform /usr/local/bin/

# Validation
kubeconform tp3/*.yaml
```

#### Dry-run kubectl

```bash
for file in tp3/*.yaml; do
  kubectl apply --dry-run=client -f "$file"
done
```

#### Tests d'intégration avec Minikube

```bash
# Démarrer Minikube
minikube start

# Tester les manifests
kubectl apply -f tp3/01-emptydir-pod.yaml
kubectl wait --for=condition=Ready pod/emptydir-pod --timeout=60s
kubectl get pods

# Cleanup
kubectl delete -f tp3/01-emptydir-pod.yaml
```

## Contribution

Pour ajouter de nouveaux tests:

1. Éditer `.github/workflows/test-kubernetes-manifests.yml`
2. Ajouter un nouveau job ou step
3. Tester localement si possible
4. Créer une pull request avec vos modifications

## Badge de statut

Pour ajouter le badge de statut au README principal:

```markdown
![Test Kubernetes Manifests](https://github.com/aboigues/kubernetes-formation/actions/workflows/test-kubernetes-manifests.yml/badge.svg)
```
