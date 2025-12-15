# Gestion des Registres d'Images en Environnement DMZ

## Introduction

La gestion des images de conteneurs est un défi majeur en environnement sécurisé. Ce document détaille les stratégies, solutions et bonnes pratiques pour gérer efficacement un registre d'images privé en DMZ ou environnement isolé.

## 🎯 Pourquoi un Registre Privé ?

### Enjeux de Sécurité

En environnement sécurisé, l'utilisation d'un registre privé est **obligatoire** pour :

1. **Contrôle des images** : Seules les images validées peuvent être déployées
2. **Scan de vulnérabilités** : Détection automatique des CVE
3. **Conformité** : Traçabilité complète des images utilisées
4. **Isolation** : Pas de dépendance à Internet/registres publics
5. **Performance** : Cache local des images
6. **Gouvernance** : Politique de rétention et nettoyage

### Flux Typique en DMZ

```
┌──────────────────────────────────────────────────────────────┐
│                    Internet (Externe)                         │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  Docker Hub  │  │     GCR      │  │     Quay     │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────┬────────────────────────────────────┘
                          │
                    [Firewall/Proxy]
                          │
┌─────────────────────────┼────────────────────────────────────┐
│                         │                                     │
│              ┌──────────▼──────────┐                         │
│              │  Registre Miroir    │                         │
│              │  (Zone Proxy)       │                         │
│              └──────────┬──────────┘                         │
│                         │                                     │
│                   [Scan/Validation]                           │
│                         │                                     │
│              ┌──────────▼──────────┐                         │
│              │  Registre Production│                         │
│              │  (Harbor/Nexus)     │                         │
│              └──────────┬──────────┘                         │
│                         │                                     │
│  ┌──────────────────────┼──────────────────────────┐         │
│  │      Cluster Kubernetes (DMZ)                    │         │
│  │                      │                            │         │
│  │  ┌───────┐   ┌───────┐   ┌───────┐   ┌───────┐ │         │
│  │  │ Node1 │   │ Node2 │   │ Node3 │   │ Node4 │ │         │
│  │  │       │◄──┤       │◄──┤       │◄──┤       │ │         │
│  │  └───────┘   └───────┘   └───────┘   └───────┘ │         │
│  │        Pull images depuis registre privé        │         │
│  └──────────────────────────────────────────────────┘        │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

## 🏗️ Solutions de Registre Privé

### Comparatif des Solutions

| Critère | Harbor | Nexus Repository | Artifactory | Docker Registry | GitLab CR |
|---------|--------|------------------|-------------|-----------------|-----------|
| **Complexité** | Moyenne | Moyenne | Élevée | Faible | Moyenne |
| **Scan vulnérabilités** | ✅ Trivy intégré | ✅ Via plugins | ✅ Xray | ❌ Non | ✅ Via CI/CD |
| **Réplication** | ✅ Avancée | ✅ Oui | ✅ Oui | ❌ Non | ✅ Limitée |
| **RBAC** | ✅ Granulaire | ✅ Granulaire | ✅ Granulaire | ❌ Basique | ✅ Oui |
| **Helm charts** | ✅ Oui | ✅ Oui | ✅ Oui | ❌ Non | ✅ Oui |
| **Proxy cache** | ✅ Oui | ✅ Oui | ✅ Oui | ❌ Non | ❌ Non |
| **Webhook** | ✅ Oui | ✅ Oui | ✅ Oui | ❌ Non | ✅ Oui |
| **API REST** | ✅ Complète | ✅ Complète | ✅ Complète | ⚠️ Limitée | ✅ Oui |
| **Coût** | Gratuit (OSS) | Gratuit (OSS) | $$$ (Pro) | Gratuit | Gratuit (avec GitLab) |
| **Support** | Communauté + Pro | Communauté + Pro | Commercial | Communauté | Communauté + Enterprise |

### Recommandation par Contexte

- **Environnement Enterprise complexe** : Harbor ou Artifactory
- **Multi-format (Docker + Maven + npm)** : Nexus Repository
- **Environnement simple** : Docker Registry v2 + externe scan
- **Déjà GitLab** : GitLab Container Registry
- **Budget limité + besoins avancés** : Harbor (open source)

## 📦 Déploiement de Harbor (Recommandé)

### Architecture Harbor

```
┌─────────────────────────────────────────────────────────────┐
│                         Harbor                               │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Portal     │  │     Core     │  │   JobService │      │
│  │  (Web UI)    │  │   (API)      │  │  (Scanning)  │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │              │
│  ┌──────▼──────────────────▼──────────────────▼───────┐     │
│  │              Nginx (Reverse Proxy)                  │     │
│  └──────┬──────────────────────────────────────────────┘     │
│         │                                                     │
│  ┌──────▼───────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Registry    │  │  PostgreSQL  │  │    Redis     │      │
│  │  (Storage)   │  │  (Metadata)  │  │   (Cache)    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         │                                                     │
│  ┌──────▼───────┐  ┌──────────────┐  ┌──────────────┐      │
│  │     S3/      │  │    Trivy     │  │   ChartMuseum│      │
│  │   NFS/PVC    │  │  (Scanner)   │  │  (Helm repo) │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Installation avec Helm

#### 1. Prérequis

```bash
# Créer le namespace
kubectl create namespace harbor

# Créer un secret TLS
kubectl create secret tls harbor-tls \
  --cert=/path/to/cert.crt \
  --key=/path/to/cert.key \
  -n harbor

# (Optionnel) Créer un StorageClass pour persistance
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: harbor-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF
```

#### 2. Configuration Values

```yaml
# harbor-values.yaml

# Exposition du service
expose:
  type: loadBalancer
  tls:
    enabled: true
    certSource: secret
    secret:
      secretName: harbor-tls
  loadBalancer:
    name: harbor
    IP: ""  # Laissez vide pour auto-assign
    ports:
      httpPort: 80
      httpsPort: 443

# URL externe
externalURL: https://harbor.internal.company.com

# Persistance
persistence:
  enabled: true

  # Volume pour le registre
  imageChartStorage:
    type: filesystem  # ou s3, gcs, azure, etc.
    filesystem:
      rootdirectory: /storage

  persistentVolumeClaim:
    registry:
      storageClass: "harbor-storage"
      size: 500Gi
      accessMode: ReadWriteOnce

    database:
      storageClass: "harbor-storage"
      size: 10Gi
      accessMode: ReadWriteOnce

    redis:
      storageClass: "harbor-storage"
      size: 1Gi
      accessMode: ReadWriteOnce

    trivy:
      storageClass: "harbor-storage"
      size: 5Gi
      accessMode: ReadWriteOnce

# Haute disponibilité
portal:
  replicas: 2
core:
  replicas: 2
jobservice:
  replicas: 2
registry:
  replicas: 2

# Scanner de vulnérabilités
trivy:
  enabled: true
  replicas: 1
  gitHubToken: ""  # Token pour rate limit plus élevé
  skipUpdate: false  # En air-gapped, mettre true

# Base de données
database:
  type: internal  # ou external pour DB externe
  internal:
    password: "changeme-database-password"

# Cache Redis
redis:
  type: internal
  internal:
    password: "changeme-redis-password"

# Helm Chart Repository
chartmuseum:
  enabled: true

# Notary pour signature d'images
notary:
  enabled: true

# Métriques
metrics:
  enabled: true
  core:
    path: /metrics
    port: 8001
  registry:
    path: /metrics
    port: 8001
  exporter:
    path: /metrics
    port: 8001
```

#### 3. Installation

```bash
# Ajouter le repo Helm
helm repo add harbor https://helm.goharbor.io
helm repo update

# Installer Harbor
helm install harbor harbor/harbor \
  --namespace harbor \
  --create-namespace \
  -f harbor-values.yaml \
  --version 1.13.0

# Vérifier le déploiement
kubectl get pods -n harbor
kubectl get svc -n harbor

# Obtenir l'IP du LoadBalancer
kubectl get svc harbor -n harbor
```

#### 4. Configuration Post-Installation

```bash
# Se connecter à Harbor
# URL: https://harbor.internal.company.com
# User: admin
# Password: Harbor12345 (par défaut, à changer immédiatement)

# Via CLI (installer harbor-cli)
harbor login harbor.internal.company.com \
  --username admin \
  --password Harbor12345

# Créer un projet
harbor project create \
  --name production \
  --public false

# Créer un utilisateur robot pour Kubernetes
harbor robot-account create \
  --name k8s-puller \
  --project production \
  --action pull
```

### Configuration Kubernetes pour Harbor

#### 1. Créer un Secret pour Pull Images

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: harbor-registry-secret
  namespace: production
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-docker-config>
```

Ou via CLI :
```bash
kubectl create secret docker-registry harbor-registry-secret \
  --docker-server=harbor.internal.company.com \
  --docker-username=robot$k8s-puller \
  --docker-password=<robot-token> \
  --docker-email=admin@company.com \
  -n production
```

#### 2. Utiliser le Secret dans les Pods

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      imagePullSecrets:
      - name: harbor-registry-secret
      containers:
      - name: webapp
        image: harbor.internal.company.com/production/webapp:v1.2.0
        ports:
        - containerPort: 8080
```

#### 3. Configurer un ServiceAccount par défaut

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
  namespace: production
imagePullSecrets:
- name: harbor-registry-secret
```

## 🔍 Scan de Vulnérabilités

### Configuration Trivy dans Harbor

#### 1. Politique de Scan Automatique

Via l'interface Harbor :
- **Configuration** > **Interrogation**
- Créer une nouvelle politique :
  - Scan automatique à chaque push
  - Bloquer le déploiement si vulnérabilités CRITICAL/HIGH

#### 2. Intégration CI/CD

```yaml
# .gitlab-ci.yml
stages:
  - build
  - scan
  - deploy

variables:
  HARBOR_URL: "harbor.internal.company.com"
  HARBOR_PROJECT: "production"
  IMAGE_NAME: "${HARBOR_URL}/${HARBOR_PROJECT}/webapp"
  IMAGE_TAG: "${CI_COMMIT_SHORT_SHA}"

build-image:
  stage: build
  script:
    - docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
    - docker login -u $HARBOR_USER -p $HARBOR_PASSWORD ${HARBOR_URL}
    - docker push ${IMAGE_NAME}:${IMAGE_TAG}

scan-image:
  stage: scan
  script:
    # Attendre que Harbor scanne l'image
    - sleep 30

    # Vérifier le résultat du scan via API Harbor
    - |
      SCAN_RESULT=$(curl -s -u "${HARBOR_USER}:${HARBOR_PASSWORD}" \
        "https://${HARBOR_URL}/api/v2.0/projects/${HARBOR_PROJECT}/repositories/webapp/artifacts/${IMAGE_TAG}/additions/vulnerabilities")

      CRITICAL=$(echo $SCAN_RESULT | jq '.scan_overview.severity.Critical // 0')
      HIGH=$(echo $SCAN_RESULT | jq '.scan_overview.severity.High // 0')

      if [ "$CRITICAL" -gt 0 ] || [ "$HIGH" -gt 0 ]; then
        echo "❌ Image has $CRITICAL critical and $HIGH high vulnerabilities"
        exit 1
      fi

      echo "✅ Image passed security scan"

deploy:
  stage: deploy
  script:
    - kubectl set image deployment/webapp webapp=${IMAGE_NAME}:${IMAGE_TAG} -n production
  only:
    - main
```

### Scan Manuel avec Trivy

```bash
# Scanner une image locale
trivy image harbor.internal.company.com/production/webapp:v1.2.0

# Scanner et générer un rapport JSON
trivy image -f json -o report.json \
  harbor.internal.company.com/production/webapp:v1.2.0

# Scanner uniquement les vulnérabilités critiques et hautes
trivy image --severity CRITICAL,HIGH \
  harbor.internal.company.com/production/webapp:v1.2.0

# Ignorer les vulnérabilités non fixées
trivy image --ignore-unfixed \
  harbor.internal.company.com/production/webapp:v1.2.0
```

## 🔄 Gestion du Cycle de Vie des Images

### Politique de Rétention

```yaml
# Configuration dans Harbor UI
# Project > Tag Retention

# Exemple de règle :
# - Garder les 10 dernières images taggées
# - Garder les images des 30 derniers jours
# - Supprimer automatiquement les images non taggées
# - Garder indéfiniment les images en production

# Via API
curl -X POST "https://harbor.internal.company.com/api/v2.0/retentions" \
  -H "Content-Type: application/json" \
  -u "admin:Harbor12345" \
  -d '{
    "scope": {
      "level": "project",
      "ref": 1
    },
    "trigger": {
      "kind": "Schedule",
      "settings": {
        "cron": "0 0 * * 0"
      }
    },
    "rules": [
      {
        "disabled": false,
        "action": "retain",
        "params": {
          "latestPushedK": 10
        },
        "tag_selectors": [
          {
            "kind": "doublestar",
            "decoration": "matches",
            "pattern": "**"
          }
        ],
        "scope_selectors": {
          "repository": [
            {
              "kind": "doublestar",
              "decoration": "matches",
              "pattern": "**"
            }
          ]
        }
      }
    ]
  }'
```

### Stratégie de Tagging

#### Convention de Nommage

```bash
# Format recommandé :
# <registre>/<projet>/<image>:<tag>

# Exemples :
harbor.internal.company.com/production/webapp:v1.2.0
harbor.internal.company.com/production/webapp:v1.2.0-sha-a1b2c3d
harbor.internal.company.com/production/webapp:latest
harbor.internal.company.com/production/webapp:main-20250115-1430

# Tags à éviter en production :
# - latest (ambigu, non versionné)
# - dev, test (environnement, pas version)
```

#### Multi-Tagging

```bash
# Builder et pousser avec plusieurs tags
docker build -t webapp:${VERSION} .

# Tag sémantique
docker tag webapp:${VERSION} \
  harbor.internal.company.com/production/webapp:${VERSION}

# Tag avec commit SHA
docker tag webapp:${VERSION} \
  harbor.internal.company.com/production/webapp:${VERSION}-${GIT_SHA}

# Tag latest (pour env dev seulement)
docker tag webapp:${VERSION} \
  harbor.internal.company.com/dev/webapp:latest

# Pousser tous les tags
docker push harbor.internal.company.com/production/webapp --all-tags
```

### Réplication Multi-Site

#### Configuration de la Réplication Harbor

```yaml
# Harbor permet la réplication entre instances

# Source: Harbor Paris
# Target: Harbor Lyon (DR)

# Via Harbor UI:
# Administration > Replications > New Replication Rule

# - Name: paris-to-lyon-production
# - Source registry: Local
# - Source resources filter:
#   - Name: production/**
#   - Tag: v*
# - Destination:
#   - Provider: Harbor
#   - Endpoint: https://harbor-lyon.internal.company.com
#   - Access ID: replication-user
#   - Access secret: ***
# - Trigger Mode: Event Based (on push)
# - Override: true
# - Enable rule: true
```

Via API :
```bash
curl -X POST "https://harbor-paris.internal.company.com/api/v2.0/replication/policies" \
  -H "Content-Type: application/json" \
  -u "admin:password" \
  -d '{
    "name": "paris-to-lyon-production",
    "src_registry": {
      "id": 0
    },
    "dest_registry": {
      "id": 1
    },
    "dest_namespace": "production",
    "trigger": {
      "type": "event_based"
    },
    "filters": [
      {
        "type": "name",
        "value": "production/**"
      },
      {
        "type": "tag",
        "value": "v*"
      }
    ],
    "deletion": false,
    "override": true,
    "enabled": true
  }'
```

## 🔐 Sécurité Avancée

### Signature d'Images avec Notary

#### 1. Activer Content Trust

```bash
# Côté client
export DOCKER_CONTENT_TRUST=1
export DOCKER_CONTENT_TRUST_SERVER=https://harbor.internal.company.com:4443

# Pousser une image signée
docker push harbor.internal.company.com/production/webapp:v1.2.0
# La signature est automatiquement créée
```

#### 2. Vérification des Signatures

```yaml
# Utiliser un admission controller pour vérifier les signatures

# Option 1: Portieris (IBM)
apiVersion: portieris.cloud.ibm.com/v1
kind: ImagePolicy
metadata:
  name: production-policy
  namespace: production
spec:
  repositories:
  - name: "harbor.internal.company.com/production/*"
    policy:
      trust:
        enabled: true
        trustServer: "https://harbor.internal.company.com:4443"
      va:
        enabled: true

# Option 2: Connaisseur
apiVersion: v1
kind: ConfigMap
metadata:
  name: connaisseur-config
  namespace: connaisseur
data:
  config.yaml: |
    policy:
      - pattern: "harbor.internal.company.com/production/*:*"
        validator: notary
        with:
          trust_roots:
          - name: default
            key: |
              -----BEGIN PUBLIC KEY-----
              ...
              -----END PUBLIC KEY-----
```

### RBAC Granulaire dans Harbor

```bash
# Créer un projet avec permissions fines
# Via Harbor UI: Projects > New Project

# Rôles disponibles:
# - Project Admin: Gestion complète
# - Master: Push/Pull + scan
# - Developer: Push/Pull
# - Guest: Pull seulement
# - Limited Guest: Pull artifacts listés seulement

# Ajouter un membre
curl -X POST "https://harbor.internal.company.com/api/v2.0/projects/production/members" \
  -H "Content-Type: application/json" \
  -u "admin:password" \
  -d '{
    "role_id": 2,
    "member_user": {
      "username": "developer-team"
    }
  }'

# Créer un robot account avec permissions limitées
curl -X POST "https://harbor.internal.company.com/api/v2.0/robots" \
  -H "Content-Type: application/json" \
  -u "admin:password" \
  -d '{
    "name": "ci-builder",
    "description": "Robot account for CI/CD",
    "duration": -1,
    "level": "project",
    "permissions": [
      {
        "kind": "project",
        "namespace": "production",
        "access": [
          {
            "resource": "repository",
            "action": "push"
          },
          {
            "resource": "repository",
            "action": "pull"
          }
        ]
      }
    ]
  }'
```

## 📊 Monitoring et Métriques

### Prometheus Metrics

```yaml
# ServiceMonitor pour Harbor
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: harbor-metrics
  namespace: harbor
  labels:
    app: harbor
spec:
  selector:
    matchLabels:
      app: harbor
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

### Métriques Importantes à Surveiller

```promql
# Nombre de pulls d'images
rate(harbor_project_artifact_pull_count[5m])

# Espace disque utilisé
harbor_project_quota_usage_byte / harbor_project_quota_hard_byte * 100

# Durée des scans
harbor_scan_duration_seconds

# Nombre de vulnérabilités par projet
sum by (project_name, severity) (harbor_artifact_vulnerabilities)

# Taux d'erreur API
rate(harbor_api_request_total{code=~"5.."}[5m])
```

### Alerting

```yaml
# PrometheusRule pour alertes Harbor
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: harbor-alerts
  namespace: harbor
spec:
  groups:
  - name: harbor
    interval: 30s
    rules:
    - alert: HarborHighVulnerabilities
      expr: |
        sum by (project_name) (
          harbor_artifact_vulnerabilities{severity="Critical"}
        ) > 5
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Harbor project {{ $labels.project_name }} has critical vulnerabilities"
        description: "{{ $value }} critical vulnerabilities detected"

    - alert: HarborDiskSpaceHigh
      expr: |
        harbor_project_quota_usage_byte / harbor_project_quota_hard_byte > 0.85
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "Harbor project quota almost full"
        description: "Project {{ $labels.project_name }} is using {{ $value | humanizePercentage }} of quota"

    - alert: HarborAPIErrors
      expr: |
        rate(harbor_api_request_total{code=~"5.."}[5m]) > 0.1
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High rate of Harbor API errors"
        description: "{{ $value }} errors per second"
```

## 📚 Bonnes Pratiques

### DO ✅

- Utiliser des tags sémantiques (v1.2.3, pas latest en prod)
- Activer le scan automatique de vulnérabilités
- Configurer une politique de rétention
- Utiliser des robot accounts pour l'automatisation
- Activer la réplication pour DR
- Monitorer l'espace disque
- Faire des backups réguliers de la base de données Harbor
- Utiliser TLS pour toutes les communications
- Implémenter le RBAC granulaire

### DON'T ❌

- Utiliser latest en production
- Désactiver le scan de vulnérabilités
- Donner des permissions admin à tous
- Oublier de configurer la rétention (explosion du stockage)
- Utiliser le compte admin pour les déploiements automatisés
- Ignorer les alertes de vulnérabilités
- Oublier de monitorer l'usage du stockage
- Utiliser HTTP (non chiffré)

## 🔗 Références

- [Harbor Documentation](https://goharbor.io/docs/)
- [Harbor API Reference](https://goharbor.io/docs/latest/working-with-projects/working-with-images/pulling-pushing-images/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Notary Documentation](https://github.com/notaryproject/notary)
- [OCI Distribution Spec](https://github.com/opencontainers/distribution-spec)

## Articles Complémentaires

- [Gestion de Cluster Sécurisé](SECURE_CLUSTER_MANAGEMENT.md)
- [Cycle de Vie des Applications](APPLICATION_LIFECYCLE.md)
- [Déploiement Air-Gapped](AIRGAP_DEPLOYMENT.md)
