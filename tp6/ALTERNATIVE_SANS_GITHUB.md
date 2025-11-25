# Alternative CI/CD sans GitHub - Utilisation de Tekton

## Pour ceux qui ne souhaitent pas créer de compte GitHub

Cette alternative vous permet de mettre en place un pipeline CI/CD complet directement dans votre cluster Kubernetes, **sans avoir besoin de compte GitHub ou autre service externe**.

Nous utiliserons **Tekton**, un framework CI/CD Kubernetes-native, open source et gratuit.

## Pourquoi Tekton ?

- **Kubernetes-native** : S'exécute directement dans votre cluster
- **Aucun compte externe requis** : Tout est local
- **Open source et gratuit**
- **Déclaratif** : Configuration en YAML comme Kubernetes
- **Réutilisable** : Tasks et pipelines modulaires
- **Cloud-agnostic** : Fonctionne partout où Kubernetes fonctionne

## Table des matières

1. [Installation de Tekton](#installation-de-tekton)
2. [Concepts de base](#concepts-de-base)
3. [Pipeline CI (Tests et Build)](#pipeline-ci-tests-et-build)
4. [Pipeline CD (Déploiement)](#pipeline-cd-déploiement)
5. [Déclenchement des pipelines](#déclenchement-des-pipelines)
6. [Monitoring des pipelines](#monitoring-des-pipelines)
7. [Comparaison avec GitHub Actions](#comparaison-avec-github-actions)

---

## Installation de Tekton

### 1. Installer Tekton Pipelines

```bash
# Installer Tekton Pipelines (core)
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

# Vérifier l'installation
kubectl get pods -n tekton-pipelines

# Attendre que tous les pods soient prêts
kubectl wait --for=condition=ready pod --all -n tekton-pipelines --timeout=300s
```

### 2. Installer Tekton Triggers (optionnel, pour automation)

```bash
# Installer Tekton Triggers
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml

# Vérifier
kubectl get pods -n tekton-pipelines
```

### 3. Installer Tekton Dashboard (interface graphique)

```bash
# Installer le Dashboard
kubectl apply -f https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml

# Exposer le Dashboard
kubectl port-forward -n tekton-pipelines service/tekton-dashboard 9097:9097 &

# Accéder au Dashboard
echo "Dashboard disponible sur : http://localhost:9097"
```

### 4. Installer Tekton CLI (optionnel mais recommandé)

```bash
# Linux
curl -LO https://github.com/tektoncd/cli/releases/download/v0.33.0/tkn_0.33.0_Linux_x86_64.tar.gz
sudo tar xvzf tkn_0.33.0_Linux_x86_64.tar.gz -C /usr/local/bin/ tkn

# Vérifier
tkn version

# macOS avec Homebrew
# brew install tektoncd-cli
```

---

## Concepts de base

### Hiérarchie Tekton

```
Task          → Étape atomique (équivalent à un job GitHub Actions)
Pipeline      → Séquence de Tasks
PipelineRun   → Instance d'exécution d'un Pipeline
TaskRun       → Instance d'exécution d'une Task
```

### Workspaces

Les **Workspaces** permettent de partager des données entre Tasks (code source, artifacts, cache).

---

## Pipeline CI (Tests et Build)

### Étape 1 : Créer les Tasks

Créer `tekton/tasks/git-clone-task.yaml` :

```yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: git-clone
  namespace: default
spec:
  description: Clone un repository Git
  workspaces:
    - name: output
      description: Le workspace où cloner le code
  params:
    - name: url
      type: string
      description: URL du repository Git
    - name: revision
      type: string
      default: main
      description: Branch, tag ou SHA à cloner
  steps:
    - name: clone
      image: gcr.io/tekton-releases/github.com/tektoncd/pipeline/cmd/git-init:v0.40.2
      script: |
        #!/bin/sh
        set -e
        git clone $(params.url) $(workspaces.output.path)
        cd $(workspaces.output.path)
        git checkout $(params.revision)
        echo "Code cloné avec succès!"
```

Créer `tekton/tasks/npm-test-task.yaml` :

```yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: npm-test
  namespace: default
spec:
  description: Exécute les tests npm
  workspaces:
    - name: source
  params:
    - name: node-version
      type: string
      default: "18"
  steps:
    - name: install-dependencies
      image: node:$(params.node-version)-alpine
      workingDir: $(workspaces.source.path)
      script: |
        #!/bin/sh
        set -e
        echo "Installation des dépendances..."
        npm ci

    - name: run-tests
      image: node:$(params.node-version)-alpine
      workingDir: $(workspaces.source.path)
      script: |
        #!/bin/sh
        set -e
        echo "Exécution des tests..."
        npm test

    - name: lint
      image: node:$(params.node-version)-alpine
      workingDir: $(workspaces.source.path)
      script: |
        #!/bin/sh
        set -e
        echo "Linting du code..."
        npm run lint || echo "Pas de lint configuré"
```

Créer `tekton/tasks/docker-build-task.yaml` :

```yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: docker-build
  namespace: default
spec:
  description: Build et push d'une image Docker
  workspaces:
    - name: source
  params:
    - name: image
      type: string
      description: Nom complet de l'image (registry/name:tag)
    - name: dockerfile
      type: string
      default: Dockerfile
      description: Chemin vers le Dockerfile
  steps:
    - name: build-and-push
      image: gcr.io/kaniko-project/executor:latest
      workingDir: $(workspaces.source.path)
      env:
        - name: DOCKER_CONFIG
          value: /tekton/home/.docker
      command:
        - /kaniko/executor
      args:
        - --dockerfile=$(params.dockerfile)
        - --context=$(workspaces.source.path)
        - --destination=$(params.image)
        - --skip-tls-verify
        - --cache=true
      volumeMounts:
        - name: docker-config
          mountPath: /tekton/home/.docker
  volumes:
    - name: docker-config
      emptyDir: {}
```

Créer `tekton/tasks/trivy-scan-task.yaml` :

```yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: trivy-scan
  namespace: default
spec:
  description: Scan de sécurité avec Trivy
  params:
    - name: image
      type: string
      description: Image à scanner
  steps:
    - name: scan
      image: aquasec/trivy:latest
      script: |
        #!/bin/sh
        set -e
        echo "Scan de sécurité de l'image..."
        trivy image --severity HIGH,CRITICAL $(params.image) || true
        echo "Scan terminé!"
```

### Étape 2 : Créer le Pipeline CI

Créer `tekton/pipelines/ci-pipeline.yaml` :

```yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: ci-pipeline
  namespace: default
spec:
  description: Pipeline CI complet - Tests et Build
  params:
    - name: git-url
      type: string
      description: URL du repository Git
    - name: git-revision
      type: string
      default: main
    - name: image-name
      type: string
      description: Nom de l'image Docker (sans tag)
    - name: image-tag
      type: string
      default: latest

  workspaces:
    - name: shared-workspace
      description: Workspace partagé pour le code source

  tasks:
    # Task 1: Cloner le repository
    - name: fetch-repository
      taskRef:
        name: git-clone
      workspaces:
        - name: output
          workspace: shared-workspace
      params:
        - name: url
          value: $(params.git-url)
        - name: revision
          value: $(params.git-revision)

    # Task 2: Tests npm (dépend de fetch-repository)
    - name: run-tests
      taskRef:
        name: npm-test
      runAfter:
        - fetch-repository
      workspaces:
        - name: source
          workspace: shared-workspace
      params:
        - name: node-version
          value: "18"

    # Task 3: Build Docker (dépend de run-tests)
    - name: build-image
      taskRef:
        name: docker-build
      runAfter:
        - run-tests
      workspaces:
        - name: source
          workspace: shared-workspace
      params:
        - name: image
          value: "$(params.image-name):$(params.image-tag)"

    # Task 4: Scan de sécurité (dépend de build-image)
    - name: security-scan
      taskRef:
        name: trivy-scan
      runAfter:
        - build-image
      params:
        - name: image
          value: "$(params.image-name):$(params.image-tag)"
```

### Étape 3 : Appliquer les ressources

```bash
# Créer les tasks
kubectl apply -f tekton/tasks/git-clone-task.yaml
kubectl apply -f tekton/tasks/npm-test-task.yaml
kubectl apply -f tekton/tasks/docker-build-task.yaml
kubectl apply -f tekton/tasks/trivy-scan-task.yaml

# Créer le pipeline
kubectl apply -f tekton/pipelines/ci-pipeline.yaml

# Vérifier
tkn task list
tkn pipeline list
```

---

## Pipeline CD (Déploiement)

### Étape 1 : Créer les Tasks de déploiement

Créer `tekton/tasks/helm-deploy-task.yaml` :

```yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: helm-deploy
  namespace: default
spec:
  description: Déploiement avec Helm
  params:
    - name: release-name
      type: string
      description: Nom de la release Helm
    - name: chart-path
      type: string
      description: Chemin vers le chart Helm
    - name: namespace
      type: string
      default: default
    - name: image-repository
      type: string
    - name: image-tag
      type: string
  workspaces:
    - name: source
  steps:
    - name: deploy
      image: alpine/helm:latest
      script: |
        #!/bin/sh
        set -e
        echo "Déploiement avec Helm..."

        helm upgrade --install $(params.release-name) \
          $(workspaces.source.path)/$(params.chart-path) \
          --namespace $(params.namespace) \
          --create-namespace \
          --set image.repository=$(params.image-repository) \
          --set image.tag=$(params.image-tag) \
          --wait \
          --timeout 5m

        echo "Déploiement terminé!"
```

Créer `tekton/tasks/kubectl-verify-task.yaml` :

```yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: kubectl-verify
  namespace: default
spec:
  description: Vérification du déploiement
  params:
    - name: deployment-name
      type: string
    - name: namespace
      type: string
      default: default
  steps:
    - name: verify-deployment
      image: bitnami/kubectl:latest
      script: |
        #!/bin/sh
        set -e
        echo "Vérification du rollout..."
        kubectl rollout status deployment/$(params.deployment-name) -n $(params.namespace)

        echo "Liste des pods:"
        kubectl get pods -n $(params.namespace)

    - name: smoke-test
      image: curlimages/curl:latest
      script: |
        #!/bin/sh
        set -e
        echo "Exécution des smoke tests..."
        # Ajouter vos tests ici
        echo "Tests terminés!"
```

### Étape 2 : Créer le Pipeline CD

Créer `tekton/pipelines/cd-pipeline.yaml` :

```yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: cd-pipeline
  namespace: default
spec:
  description: Pipeline CD - Déploiement sur Kubernetes
  params:
    - name: git-url
      type: string
    - name: git-revision
      type: string
      default: main
    - name: release-name
      type: string
      default: my-app
    - name: chart-path
      type: string
      default: helm/my-app
    - name: namespace
      type: string
      default: production
    - name: image-repository
      type: string
    - name: image-tag
      type: string
    - name: deployment-name
      type: string
      default: my-app

  workspaces:
    - name: shared-workspace

  tasks:
    # Task 1: Cloner le repository (pour les charts Helm)
    - name: fetch-repository
      taskRef:
        name: git-clone
      workspaces:
        - name: output
          workspace: shared-workspace
      params:
        - name: url
          value: $(params.git-url)
        - name: revision
          value: $(params.git-revision)

    # Task 2: Déployer avec Helm
    - name: deploy-with-helm
      taskRef:
        name: helm-deploy
      runAfter:
        - fetch-repository
      workspaces:
        - name: source
          workspace: shared-workspace
      params:
        - name: release-name
          value: $(params.release-name)
        - name: chart-path
          value: $(params.chart-path)
        - name: namespace
          value: $(params.namespace)
        - name: image-repository
          value: $(params.image-repository)
        - name: image-tag
          value: $(params.image-tag)

    # Task 3: Vérifier le déploiement
    - name: verify-deployment
      taskRef:
        name: kubectl-verify
      runAfter:
        - deploy-with-helm
      params:
        - name: deployment-name
          value: $(params.deployment-name)
        - name: namespace
          value: $(params.namespace)
```

### Étape 3 : Appliquer les ressources

```bash
# Créer les tasks
kubectl apply -f tekton/tasks/helm-deploy-task.yaml
kubectl apply -f tekton/tasks/kubectl-verify-task.yaml

# Créer le pipeline
kubectl apply -f tekton/pipelines/cd-pipeline.yaml

# Vérifier
tkn pipeline list
```

---

## Déclenchement des pipelines

### Option 1 : Déclenchement manuel avec PipelineRun

Créer `tekton/runs/ci-pipelinerun.yaml` :

```yaml
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: ci-run-$(date +%Y%m%d-%H%M%S)
  namespace: default
spec:
  pipelineRef:
    name: ci-pipeline
  params:
    - name: git-url
      value: "https://github.com/votre-username/votre-repo.git"
    - name: git-revision
      value: "main"
    - name: image-name
      value: "localhost:5000/my-app"  # Registry local
    - name: image-tag
      value: "latest"
  workspaces:
    - name: shared-workspace
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 1Gi
```

Exécuter :

```bash
# Exécuter le pipeline CI
kubectl create -f tekton/runs/ci-pipelinerun.yaml

# Ou avec tkn CLI
tkn pipeline start ci-pipeline \
  --param git-url=https://github.com/votre-username/votre-repo.git \
  --param git-revision=main \
  --param image-name=localhost:5000/my-app \
  --param image-tag=v1.0.0 \
  --workspace name=shared-workspace,volumeClaimTemplateFile=workspace-template.yaml \
  --showlog
```

### Option 2 : Déclenchement automatique avec Git Hooks locaux

Créer `.git/hooks/pre-push` :

```bash
#!/bin/bash

echo "Déclenchement du pipeline CI Tekton..."

# Créer un PipelineRun
kubectl create -f - <<EOF
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  generateName: ci-run-
  namespace: default
spec:
  pipelineRef:
    name: ci-pipeline
  params:
    - name: git-url
      value: "file:///path/to/local/repo"
    - name: git-revision
      value: "$(git rev-parse HEAD)"
    - name: image-name
      value: "localhost:5000/my-app"
    - name: image-tag
      value: "$(git rev-parse --short HEAD)"
  workspaces:
    - name: shared-workspace
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 1Gi
EOF

echo "Pipeline déclenché!"
```

```bash
# Rendre le hook exécutable
chmod +x .git/hooks/pre-push
```

### Option 3 : Registry Docker local (pour éviter les registries externes)

```bash
# Démarrer un registry Docker local
kubectl create deployment registry --image=registry:2
kubectl expose deployment registry --port=5000 --type=NodePort

# Obtenir le port
kubectl get svc registry

# Utiliser localhost:5000 comme registry dans vos pipelines
```

---

## Monitoring des pipelines

### Via Tekton Dashboard

```bash
# Exposer le Dashboard si pas déjà fait
kubectl port-forward -n tekton-pipelines service/tekton-dashboard 9097:9097

# Ouvrir dans le navigateur
open http://localhost:9097
```

### Via CLI

```bash
# Lister tous les PipelineRuns
tkn pipelinerun list

# Voir les logs d'un PipelineRun
tkn pipelinerun logs ci-run-20240101-123456 -f

# Voir les détails
tkn pipelinerun describe ci-run-20240101-123456

# Lister les TaskRuns
tkn taskrun list

# Supprimer les anciens runs
tkn pipelinerun delete --keep 5
```

### Via kubectl

```bash
# Voir tous les PipelineRuns
kubectl get pipelinerun

# Voir les détails
kubectl describe pipelinerun ci-run-20240101-123456

# Voir les logs d'un TaskRun
kubectl logs -l tekton.dev/pipelineRun=ci-run-20240101-123456
```

---

## Comparaison avec GitHub Actions

| Fonctionnalité | GitHub Actions | Tekton |
|---------------|----------------|--------|
| **Hébergement** | Cloud GitHub | Votre cluster K8s |
| **Compte requis** | Oui (GitHub) | Non |
| **Coût** | Gratuit (limité) puis payant | Gratuit (coût infra) |
| **Déclencheurs** | Git events automatiques | Manuel ou webhooks |
| **Secrets** | GitHub Secrets | Kubernetes Secrets |
| **Registry** | ghcr.io | Local ou externe |
| **Interface Web** | Intégré GitHub | Tekton Dashboard |
| **Configuration** | .github/workflows/*.yml | Tasks + Pipelines YAML |
| **Réutilisabilité** | Actions Marketplace | Task catalog |
| **Scaling** | Automatique | Dépend du cluster |

---

## Avantages de l'approche Tekton

### 1. Aucune dépendance externe
- Pas de compte GitHub, GitLab, ou autre
- Tout tourne dans votre cluster
- Contrôle total sur l'infrastructure

### 2. GitOps-friendly
- Compatible avec ArgoCD
- Configuration déclarative
- Versionnable dans Git

### 3. Évolutif et flexible
- Peut évoluer vers des setups complexes
- Intégrable avec d'autres outils K8s
- Pas de vendor lock-in

### 4. Apprentissage Kubernetes
- Renforce la compréhension de K8s
- Utilise les concepts natifs (Pods, Volumes, etc.)
- Transférable à n'importe quel cluster

---

## Script d'installation complète

Créer `tekton/install-tekton.sh` :

```bash
#!/bin/bash

set -e

echo "=== Installation de Tekton ===="

# 1. Installer Tekton Pipelines
echo "Installation de Tekton Pipelines..."
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

echo "Attente que Tekton soit prêt..."
kubectl wait --for=condition=ready pod --all -n tekton-pipelines --timeout=300s

# 2. Installer Tekton Triggers
echo "Installation de Tekton Triggers..."
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml

# 3. Installer Tekton Dashboard
echo "Installation du Tekton Dashboard..."
kubectl apply -f https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml

echo "Attente que le Dashboard soit prêt..."
kubectl wait --for=condition=ready pod -l app=tekton-dashboard -n tekton-pipelines --timeout=300s

# 4. Installer un registry local
echo "Installation d'un registry Docker local..."
kubectl create deployment registry --image=registry:2 --dry-run=client -o yaml | kubectl apply -f -
kubectl expose deployment registry --port=5000 --type=NodePort --dry-run=client -o yaml | kubectl apply -f -

# 5. Appliquer les Tasks et Pipelines
echo "Application des Tasks et Pipelines..."
kubectl apply -f tekton/tasks/
kubectl apply -f tekton/pipelines/

echo ""
echo "=== Installation terminée! ==="
echo ""
echo "Pour accéder au Dashboard Tekton:"
echo "  kubectl port-forward -n tekton-pipelines service/tekton-dashboard 9097:9097"
echo "  Puis ouvrir: http://localhost:9097"
echo ""
echo "Pour exécuter un pipeline:"
echo "  tkn pipeline start ci-pipeline --showlog"
echo ""
```

```bash
# Rendre le script exécutable
chmod +x tekton/install-tekton.sh

# Exécuter
./tekton/install-tekton.sh
```

---

## Exercices pratiques

### Exercice 1 : Pipeline CI basique

1. Installer Tekton
2. Créer les tasks nécessaires
3. Créer un pipeline CI
4. L'exécuter manuellement
5. Observer les résultats dans le Dashboard

### Exercice 2 : Pipeline CD

1. Créer les tasks de déploiement
2. Créer un pipeline CD
3. L'exécuter pour déployer sur Kubernetes
4. Vérifier le déploiement

### Exercice 3 : Automation complète

1. Configurer un registry local
2. Créer un git hook pour déclencher le pipeline
3. Faire un commit et observer le déclenchement automatique

---

## Ressources complémentaires

### Documentation officielle
- [Tekton Documentation](https://tekton.dev/docs/)
- [Tekton Catalog](https://hub.tekton.dev/) - Tasks réutilisables
- [Tekton GitHub](https://github.com/tektoncd)

### Tutoriels
- [Getting Started with Tekton](https://tekton.dev/docs/getting-started/)
- [Tekton Tutorial](https://github.com/tektoncd/pipeline/blob/main/docs/tutorial.md)

### Alternatives CI/CD Kubernetes-native
- **Jenkins X** : CI/CD avec GitOps
- **Argo Workflows** : Workflow engine
- **Drone CI** : Peut être self-hosted

---

## Conclusion

Avec Tekton, vous disposez d'une solution CI/CD complète, Kubernetes-native, **sans avoir besoin de créer un compte sur GitHub ou tout autre service externe**.

Cette approche est idéale pour :
- L'apprentissage de Kubernetes et du CI/CD
- Les environnements on-premise
- Les projets nécessitant un contrôle total
- Les budgets limités (pas de coûts de service externe)

**Vous êtes maintenant autonome pour créer vos pipelines CI/CD directement dans Kubernetes !**
