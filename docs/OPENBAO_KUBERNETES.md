# Guide OpenBao avec Kubernetes

## Table des matières
1. [Introduction](#introduction)
2. [Installation d'OpenBao sur Kubernetes](#installation-dopenbao-sur-kubernetes)
3. [Configuration et initialisation](#configuration-et-initialisation)
4. [Intégration avec Kubernetes Auth](#intégration-avec-kubernetes-auth)
5. [Injection de secrets dans les Pods](#injection-de-secrets-dans-les-pods)
6. [Gestion des secrets](#gestion-des-secrets)
7. [Haute disponibilité](#haute-disponibilité)
8. [Cas d'usage pratiques](#cas-dusage-pratiques)
9. [Débogage et troubleshooting](#débogage-et-troubleshooting)
10. [Bonnes pratiques](#bonnes-pratiques)

## Introduction

**OpenBao** est un fork open-source de HashiCorp Vault, maintenu par la Linux Foundation. Il permet de gérer de manière sécurisée les secrets, les clés de chiffrement, et les certificats dans vos applications Kubernetes.

### Pourquoi OpenBao ?

- **Gestion centralisée des secrets** : Plus besoin de stocker des secrets dans les ConfigMaps ou en clair
- **Rotation automatique** : Les secrets peuvent être renouvelés automatiquement
- **Chiffrement des données** : Chiffrement au repos et en transit
- **Audit complet** : Traçabilité de tous les accès aux secrets
- **Intégration native avec Kubernetes** : Authentification via ServiceAccount

### Comparaison avec les Secrets Kubernetes natifs

| Fonctionnalité | Secrets K8s natifs | OpenBao |
|----------------|-------------------|---------|
| Chiffrement au repos | Optionnel (etcd) | Oui, toujours |
| Rotation automatique | Non | Oui |
| Audit des accès | Non | Oui, complet |
| Génération dynamique | Non | Oui |
| Révocation | Non | Oui |
| TTL (durée de vie) | Non | Oui |

---

## Installation d'OpenBao sur Kubernetes

### 1. Installation via Helm

OpenBao peut être installé facilement avec Helm.

**Prérequis :**
```bash
# Installer Helm si nécessaire
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Vérifier l'installation
helm version
```

**Installation d'OpenBao :**

```bash
# Ajouter le repository Helm d'OpenBao
helm repo add openbao https://openbao.github.io/openbao-helm
helm repo update

# Créer un namespace dédié
kubectl create namespace openbao

# Installer OpenBao en mode développement (pour tests)
helm install openbao openbao/openbao \
  --namespace openbao \
  --set server.dev.enabled=true

# Pour une installation en production (avec persistance)
helm install openbao openbao/openbao \
  --namespace openbao \
  --set server.ha.enabled=true \
  --set server.ha.replicas=3
```

**Vérifier l'installation :**

```bash
# Vérifier les Pods
kubectl get pods -n openbao

# Vérifier le service
kubectl get svc -n openbao

# Voir les logs
kubectl logs -n openbao -l app.kubernetes.io/name=openbao
```

### 2. Installation manuelle avec manifests YAML

**Créer `openbao-namespace.yaml` :**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: openbao
```

**Créer `openbao-service-account.yaml` :**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: openbao
  namespace: openbao
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: openbao-server-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
  - kind: ServiceAccount
    name: openbao
    namespace: openbao
```

**Créer `openbao-configmap.yaml` :**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: openbao-config
  namespace: openbao
data:
  openbao.hcl: |
    ui = true

    listener "tcp" {
      address = "[::]:8200"
      cluster_address = "[::]:8201"
      tls_disable = 1
    }

    storage "file" {
      path = "/openbao/data"
    }

    # Configuration pour Kubernetes auth
    api_addr = "http://openbao.openbao.svc:8200"
    cluster_addr = "http://openbao.openbao.svc:8201"
```

**Créer `openbao-deployment.yaml` :**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openbao
  namespace: openbao
  labels:
    app: openbao
spec:
  replicas: 1
  selector:
    matchLabels:
      app: openbao
  template:
    metadata:
      labels:
        app: openbao
    spec:
      serviceAccountName: openbao
      containers:
      - name: openbao
        image: quay.io/openbao/openbao:latest
        ports:
        - containerPort: 8200
          name: http
        - containerPort: 8201
          name: cluster
        env:
        - name: OPENBAO_ADDR
          value: "http://127.0.0.1:8200"
        - name: OPENBAO_API_ADDR
          value: "http://openbao.openbao.svc:8200"
        - name: OPENBAO_CONFIG_DIR
          value: "/openbao/config"
        args:
        - "server"
        - "-config=/openbao/config/openbao.hcl"
        volumeMounts:
        - name: config
          mountPath: /openbao/config
        - name: data
          mountPath: /openbao/data
        securityContext:
          capabilities:
            add:
            - IPC_LOCK
        readinessProbe:
          httpGet:
            path: /v1/sys/health?standbyok=true
            port: 8200
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /v1/sys/health?standbyok=true
            port: 8200
          initialDelaySeconds: 60
          periodSeconds: 10
      volumes:
      - name: config
        configMap:
          name: openbao-config
      - name: data
        emptyDir: {}
```

**Créer `openbao-service.yaml` :**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: openbao
  namespace: openbao
spec:
  selector:
    app: openbao
  ports:
  - name: http
    port: 8200
    targetPort: 8200
  - name: cluster
    port: 8201
    targetPort: 8201
  type: ClusterIP
```

**Déployer tous les manifests :**

```bash
kubectl apply -f openbao-namespace.yaml
kubectl apply -f openbao-service-account.yaml
kubectl apply -f openbao-configmap.yaml
kubectl apply -f openbao-deployment.yaml
kubectl apply -f openbao-service.yaml

# Vérifier le déploiement
kubectl get all -n openbao
```

---

## Configuration et initialisation

### 1. Initialiser OpenBao

OpenBao doit être initialisé avant la première utilisation.

```bash
# Port-forward vers le pod OpenBao
kubectl port-forward -n openbao svc/openbao 8200:8200 &

# Exporter l'adresse
export OPENBAO_ADDR='http://127.0.0.1:8200'

# Initialiser OpenBao (génère les clés de déverrouillage)
kubectl exec -n openbao openbao-0 -- bao operator init

# Exemple de sortie :
# Unseal Key 1: xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# Unseal Key 2: xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# Unseal Key 3: xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# Unseal Key 4: xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# Unseal Key 5: xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# Initial Root Token: s.xxxxxxxxxxxxxxxxxxxxx

# ⚠️ IMPORTANT : Sauvegarder ces clés dans un endroit sûr !
```

### 2. Déverrouiller (Unseal) OpenBao

Par défaut, OpenBao démarre "scellé" (sealed) et nécessite 3 clés parmi 5 pour être déverrouillé.

```bash
# Déverrouiller avec 3 clés différentes
kubectl exec -n openbao openbao-0 -- bao operator unseal <Unseal_Key_1>
kubectl exec -n openbao openbao-0 -- bao operator unseal <Unseal_Key_2>
kubectl exec -n openbao openbao-0 -- bao operator unseal <Unseal_Key_3>

# Vérifier le statut
kubectl exec -n openbao openbao-0 -- bao status
```

### 3. Se connecter avec le root token

```bash
# Se connecter
kubectl exec -n openbao openbao-0 -- bao login <Initial_Root_Token>

# Vérifier la connexion
kubectl exec -n openbao openbao-0 -- bao token lookup
```

---

## Intégration avec Kubernetes Auth

L'authentification Kubernetes permet aux Pods d'accéder à OpenBao en utilisant leur ServiceAccount.

### 1. Activer l'authentification Kubernetes

```bash
# Se connecter au pod OpenBao
kubectl exec -it -n openbao openbao-0 -- sh

# Dans le pod, activer Kubernetes auth
bao auth enable kubernetes

# Configurer l'authentification Kubernetes
bao write auth/kubernetes/config \
  kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token
```

### 2. Créer une policy pour les applications

**Créer une policy** (`app-policy.hcl`) :

```hcl
# Permet la lecture des secrets dans secret/data/myapp/*
path "secret/data/myapp/*" {
  capabilities = ["read", "list"]
}

# Permet la lecture des secrets de base de données
path "database/creds/myapp-role" {
  capabilities = ["read"]
}
```

**Appliquer la policy :**

```bash
# Dans le pod OpenBao
cat > /tmp/app-policy.hcl <<EOF
path "secret/data/myapp/*" {
  capabilities = ["read", "list"]
}
EOF

bao policy write myapp-policy /tmp/app-policy.hcl
```

### 3. Créer un rôle Kubernetes

```bash
# Créer un rôle qui lie le ServiceAccount à la policy
bao write auth/kubernetes/role/myapp \
  bound_service_account_names=myapp \
  bound_service_account_namespaces=default \
  policies=myapp-policy \
  ttl=1h
```

---

## Injection de secrets dans les Pods

### Méthode 1 : Annotations pour injection automatique

OpenBao peut injecter automatiquement des secrets dans les Pods via un sidecar.

**Installer l'agent injector :**

```bash
# Via Helm
helm upgrade openbao openbao/openbao \
  --namespace openbao \
  --set injector.enabled=true
```

**Exemple de Pod avec injection :**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: myapp
  namespace: default
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
      annotations:
        # Activer l'injection
        bao.openbao.org/agent-inject: "true"

        # Rôle à utiliser
        bao.openbao.org/role: "myapp"

        # Injecter un secret
        bao.openbao.org/agent-inject-secret-database: "secret/data/myapp/database"

        # Template pour formater le secret
        bao.openbao.org/agent-inject-template-database: |
          {{- with secret "secret/data/myapp/database" -}}
          export DB_HOST="{{ .Data.data.host }}"
          export DB_USER="{{ .Data.data.username }}"
          export DB_PASS="{{ .Data.data.password }}"
          {{- end }}
    spec:
      serviceAccountName: myapp
      containers:
      - name: app
        image: nginx:latest
        command:
        - sh
        - -c
        - |
          # Sourcer les secrets injectés
          source /openbao/secrets/database
          echo "Connecté à $DB_HOST en tant que $DB_USER"
          # Démarrer l'application
          nginx -g 'daemon off;'
```

**Les secrets sont montés dans** `/openbao/secrets/`

### Méthode 2 : Init container pour récupérer les secrets

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp-with-init
spec:
  serviceAccountName: myapp

  initContainers:
  - name: openbao-init
    image: quay.io/openbao/openbao:latest
    command:
    - sh
    - -c
    - |
      # Authentification avec Kubernetes
      KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
      OPENBAO_TOKEN=$(bao write -field=token auth/kubernetes/login \
        role=myapp jwt=$KUBE_TOKEN)

      export OPENBAO_TOKEN

      # Récupérer les secrets
      bao kv get -field=password secret/myapp/database > /secrets/db-password
      bao kv get -field=api-key secret/myapp/api > /secrets/api-key
    env:
    - name: OPENBAO_ADDR
      value: "http://openbao.openbao.svc:8200"
    volumeMounts:
    - name: secrets
      mountPath: /secrets

  containers:
  - name: app
    image: myapp:latest
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
    volumeMounts:
    - name: secrets
      mountPath: /secrets
      readOnly: true

  volumes:
  - name: secrets
    emptyDir:
      medium: Memory
```

### Méthode 3 : CSI Secret Store Driver

Pour une intégration plus native avec Kubernetes.

**Installation du CSI driver :**

```bash
# Installer le Secret Store CSI Driver
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
  --namespace kube-system

# Installer le provider OpenBao
kubectl apply -f https://raw.githubusercontent.com/openbao/openbao-csi-provider/main/deployment/openbao-csi-provider.yaml
```

**Exemple d'utilisation :**

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: openbao-database
spec:
  provider: openbao
  parameters:
    roleName: "myapp"
    openbaoAddress: "http://openbao.openbao.svc:8200"
    objects: |
      - objectName: "db-password"
        secretPath: "secret/data/myapp/database"
        secretKey: "password"
---
apiVersion: v1
kind: Pod
metadata:
  name: myapp-csi
spec:
  serviceAccountName: myapp
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: secrets-store
      mountPath: "/mnt/secrets"
      readOnly: true
  volumes:
  - name: secrets-store
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: "openbao-database"
```

---

## Gestion des secrets

### 1. KV Secrets Engine (Key-Value)

Le moteur KV v2 permet de stocker des secrets avec versioning.

**Activer le moteur KV :**

```bash
# Dans le pod OpenBao
kubectl exec -it -n openbao openbao-0 -- sh

# Activer KV v2 (par défaut au chemin 'secret/')
bao secrets enable -version=2 -path=secret kv

# Créer un secret
bao kv put secret/myapp/database \
  host=postgres.default.svc \
  username=appuser \
  password=SuperSecret123

# Lire un secret
bao kv get secret/myapp/database

# Lire uniquement un champ
bao kv get -field=password secret/myapp/database

# Lister les secrets
bao kv list secret/myapp/

# Mettre à jour un secret (crée une nouvelle version)
bao kv put secret/myapp/database password=NewPassword456

# Voir l'historique des versions
bao kv metadata get secret/myapp/database

# Lire une version spécifique
bao kv get -version=1 secret/myapp/database

# Supprimer la dernière version (soft delete)
bao kv delete secret/myapp/database

# Détruire une version (hard delete)
bao kv destroy -versions=2 secret/myapp/database

# Supprimer toutes les métadonnées et versions
bao kv metadata delete secret/myapp/database
```

### 2. Secrets dynamiques avec Database Engine

OpenBao peut générer des credentials de base de données à la volée.

**Activer et configurer le moteur Database :**

```bash
# Activer le moteur database
bao secrets enable database

# Configurer la connexion PostgreSQL
bao write database/config/postgresql \
  plugin_name=postgresql-database-plugin \
  allowed_roles="myapp-role" \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/mydb?sslmode=disable" \
  username="bao-admin" \
  password="AdminPassword"

# Créer un rôle qui génère des credentials
bao write database/roles/myapp-role \
  db_name=postgresql \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
    GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"
```

**Utiliser les credentials dynamiques dans un Pod :**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-dynamic-db
  annotations:
    bao.openbao.org/agent-inject: "true"
    bao.openbao.org/role: "myapp"
    bao.openbao.org/agent-inject-secret-db: "database/creds/myapp-role"
    bao.openbao.org/agent-inject-template-db: |
      {{- with secret "database/creds/myapp-role" -}}
      export DB_USER="{{ .Data.username }}"
      export DB_PASS="{{ .Data.password }}"
      {{- end }}
spec:
  serviceAccountName: myapp
  containers:
  - name: app
    image: myapp:latest
    command: ["/bin/sh", "-c", "source /openbao/secrets/db && ./start-app"]
```

### 3. Transit Engine pour le chiffrement

Le moteur Transit permet de chiffrer/déchiffrer des données sans exposer la clé.

```bash
# Activer Transit
bao secrets enable transit

# Créer une clé de chiffrement
bao write -f transit/keys/myapp

# Chiffrer des données
bao write transit/encrypt/myapp plaintext=$(echo "données sensibles" | base64)
# Retourne: ciphertext:openbao:v1:xxxxxx

# Déchiffrer
bao write transit/decrypt/myapp ciphertext="openbao:v1:xxxxxx"
# Décode le résultat: echo "base64string" | base64 -d

# Rotation de la clé
bao write -f transit/keys/myapp/rotate

# Le déchiffrement fonctionne toujours pour les anciennes versions
```

---

## Haute disponibilité

### Configuration HA avec Raft Storage

**Créer `openbao-ha.yaml` :**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: openbao-config
  namespace: openbao
data:
  openbao.hcl: |
    ui = true

    listener "tcp" {
      address = "[::]:8200"
      cluster_address = "[::]:8201"
      tls_disable = 1
    }

    storage "raft" {
      path = "/openbao/data"

      retry_join {
        leader_api_addr = "http://openbao-0.openbao-internal:8200"
      }
      retry_join {
        leader_api_addr = "http://openbao-1.openbao-internal:8200"
      }
      retry_join {
        leader_api_addr = "http://openbao-2.openbao-internal:8200"
      }
    }

    api_addr = "http://$(POD_IP):8200"
    cluster_addr = "http://$(POD_IP):8201"
---
apiVersion: v1
kind: Service
metadata:
  name: openbao-internal
  namespace: openbao
spec:
  clusterIP: None
  selector:
    app: openbao
  ports:
  - name: http
    port: 8200
  - name: cluster
    port: 8201
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: openbao
  namespace: openbao
spec:
  serviceName: openbao-internal
  replicas: 3
  selector:
    matchLabels:
      app: openbao
  template:
    metadata:
      labels:
        app: openbao
    spec:
      serviceAccountName: openbao
      containers:
      - name: openbao
        image: quay.io/openbao/openbao:latest
        ports:
        - containerPort: 8200
          name: http
        - containerPort: 8201
          name: cluster
        env:
        - name: POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        - name: OPENBAO_ADDR
          value: "http://127.0.0.1:8200"
        - name: OPENBAO_CONFIG_DIR
          value: "/openbao/config"
        args:
        - "server"
        - "-config=/openbao/config/openbao.hcl"
        volumeMounts:
        - name: config
          mountPath: /openbao/config
        - name: data
          mountPath: /openbao/data
        securityContext:
          capabilities:
            add:
            - IPC_LOCK
      volumes:
      - name: config
        configMap:
          name: openbao-config
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
```

**Initialiser le cluster Raft :**

```bash
# Appliquer la configuration
kubectl apply -f openbao-ha.yaml

# Initialiser le premier nœud
kubectl exec -n openbao openbao-0 -- bao operator init

# Unseal les 3 nœuds
for i in 0 1 2; do
  kubectl exec -n openbao openbao-$i -- bao operator unseal <key1>
  kubectl exec -n openbao openbao-$i -- bao operator unseal <key2>
  kubectl exec -n openbao openbao-$i -- bao operator unseal <key3>
done

# Joindre les nœuds au cluster (depuis le pod 1 et 2)
kubectl exec -n openbao openbao-1 -- bao operator raft join http://openbao-0.openbao-internal:8200
kubectl exec -n openbao openbao-2 -- bao operator raft join http://openbao-0.openbao-internal:8200

# Vérifier le cluster
kubectl exec -n openbao openbao-0 -- bao operator raft list-peers
```

---

## Cas d'usage pratiques

### 1. Application web avec secrets de base de données

**Déploiement complet :**

```yaml
# Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: webapp
  namespace: default
---
# Deployment avec injection de secrets
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
      annotations:
        bao.openbao.org/agent-inject: "true"
        bao.openbao.org/role: "webapp"
        bao.openbao.org/agent-inject-secret-config: "secret/data/webapp/config"
        bao.openbao.org/agent-inject-template-config: |
          {{- with secret "secret/data/webapp/config" -}}
          {
            "database": {
              "host": "{{ .Data.data.db_host }}",
              "port": 5432,
              "name": "{{ .Data.data.db_name }}"
            },
            "api_key": "{{ .Data.data.api_key }}"
          }
          {{- end }}
        bao.openbao.org/agent-inject-secret-db-creds: "database/creds/webapp-role"
        bao.openbao.org/agent-inject-template-db-creds: |
          {{- with secret "database/creds/webapp-role" -}}
          export DB_USER="{{ .Data.username }}"
          export DB_PASS="{{ .Data.password }}"
          {{- end }}
    spec:
      serviceAccountName: webapp
      containers:
      - name: webapp
        image: webapp:1.0
        command:
        - sh
        - -c
        - |
          source /openbao/secrets/db-creds
          export CONFIG_FILE=/openbao/secrets/config
          ./start-webapp
        ports:
        - containerPort: 8080
```

**Configurer OpenBao pour cette application :**

```bash
# Créer les secrets statiques
kubectl exec -n openbao openbao-0 -- bao kv put secret/webapp/config \
  db_host=postgres.default.svc \
  db_name=webapp_prod \
  api_key=sk_live_xxxxxxxxxxxxx

# Configurer le database engine (si pas déjà fait)
kubectl exec -n openbao openbao-0 -- bao secrets enable database
kubectl exec -n openbao openbao-0 -- bao write database/config/postgresql \
  plugin_name=postgresql-database-plugin \
  allowed_roles="webapp-role" \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/webapp_prod" \
  username="bao-admin" \
  password="AdminPassword"

kubectl exec -n openbao openbao-0 -- bao write database/roles/webapp-role \
  db_name=postgresql \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

# Créer la policy
kubectl exec -n openbao openbao-0 -- sh -c 'cat > /tmp/webapp-policy.hcl <<EOF
path "secret/data/webapp/*" {
  capabilities = ["read"]
}
path "database/creds/webapp-role" {
  capabilities = ["read"]
}
EOF
bao policy write webapp /tmp/webapp-policy.hcl'

# Créer le rôle Kubernetes
kubectl exec -n openbao openbao-0 -- bao write auth/kubernetes/role/webapp \
  bound_service_account_names=webapp \
  bound_service_account_namespaces=default \
  policies=webapp \
  ttl=1h
```

### 2. Job de backup avec credentials temporaires

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: database-backup
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        metadata:
          annotations:
            bao.openbao.org/agent-inject: "true"
            bao.openbao.org/role: "backup"
            bao.openbao.org/agent-inject-secret-creds: "database/creds/backup-role"
            bao.openbao.org/agent-inject-template-creds: |
              {{- with secret "database/creds/backup-role" -}}
              export PGUSER="{{ .Data.username }}"
              export PGPASSWORD="{{ .Data.password }}"
              {{- end }}
        spec:
          serviceAccountName: backup
          restartPolicy: OnFailure
          containers:
          - name: backup
            image: postgres:15-alpine
            command:
            - sh
            - -c
            - |
              source /openbao/secrets/creds
              export PGHOST=postgres.default.svc
              pg_dump webapp_prod | gzip > /backups/backup-$(date +%Y%m%d).sql.gz
              echo "Backup terminé"
            volumeMounts:
            - name: backups
              mountPath: /backups
          volumes:
          - name: backups
            persistentVolumeClaim:
              claimName: backup-pvc
```

### 3. Microservices avec secrets partagés et individuels

```yaml
# Policy pour secrets partagés entre microservices
# shared-policy.hcl
path "secret/data/shared/*" {
  capabilities = ["read"]
}

# Policy spécifique pour le service orders
# orders-policy.hcl
path "secret/data/shared/*" {
  capabilities = ["read"]
}
path "secret/data/orders/*" {
  capabilities = ["read"]
}
path "database/creds/orders-role" {
  capabilities = ["read"]
}

# Policy spécifique pour le service users
# users-policy.hcl
path "secret/data/shared/*" {
  capabilities = ["read"]
}
path "secret/data/users/*" {
  capabilities = ["read"]
}
path "database/creds/users-role" {
  capabilities = ["read"]
}
```

**Déploiement du service orders :**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: orders-service
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orders-service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: orders
  template:
    metadata:
      labels:
        app: orders
      annotations:
        bao.openbao.org/agent-inject: "true"
        bao.openbao.org/role: "orders"
        # Secrets partagés
        bao.openbao.org/agent-inject-secret-shared: "secret/data/shared/config"
        # Secrets spécifiques au service
        bao.openbao.org/agent-inject-secret-orders: "secret/data/orders/config"
        # Credentials de DB
        bao.openbao.org/agent-inject-secret-db: "database/creds/orders-role"
    spec:
      serviceAccountName: orders-service
      containers:
      - name: orders
        image: orders-service:1.0
        # L'application lit les secrets depuis /openbao/secrets/
```

---

## Débogage et troubleshooting

### 1. Vérifier l'état d'OpenBao

```bash
# Statut général
kubectl exec -n openbao openbao-0 -- bao status

# Vérifier si scellé (sealed)
kubectl exec -n openbao openbao-0 -- bao status | grep Sealed

# Vérifier le leader (en mode HA)
kubectl exec -n openbao openbao-0 -- bao operator raft list-peers

# Vérifier les auth methods actives
kubectl exec -n openbao openbao-0 -- bao auth list

# Vérifier les secrets engines
kubectl exec -n openbao openbao-0 -- bao secrets list
```

### 2. Problèmes d'authentification Kubernetes

```bash
# Tester l'authentification depuis un Pod
kubectl run test-auth --rm -it --image=quay.io/openbao/openbao:latest \
  --serviceaccount=myapp \
  --env="OPENBAO_ADDR=http://openbao.openbao.svc:8200" \
  -- sh

# Dans le pod de test
KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
bao write auth/kubernetes/login role=myapp jwt=$KUBE_TOKEN

# Vérifier la configuration Kubernetes auth
kubectl exec -n openbao openbao-0 -- bao read auth/kubernetes/config

# Lister les rôles
kubectl exec -n openbao openbao-0 -- bao list auth/kubernetes/role

# Voir un rôle spécifique
kubectl exec -n openbao openbao-0 -- bao read auth/kubernetes/role/myapp
```

### 3. Debugging de l'injection de secrets

```bash
# Vérifier que l'injector est déployé
kubectl get pods -n openbao -l app.kubernetes.io/name=openbao-agent-injector

# Voir les logs de l'injector
kubectl logs -n openbao -l app.kubernetes.io/name=openbao-agent-injector

# Dans un Pod avec injection, vérifier les containers
kubectl describe pod <pod-name>
# Doit montrer un init container "bao-agent-init" et un sidecar "bao-agent"

# Logs du init container
kubectl logs <pod-name> -c bao-agent-init

# Logs du sidecar
kubectl logs <pod-name> -c bao-agent -f

# Vérifier les secrets montés
kubectl exec <pod-name> -c <app-container> -- ls -la /openbao/secrets/
kubectl exec <pod-name> -c <app-container> -- cat /openbao/secrets/<secret-name>
```

### 4. Audit logs

**Activer les audit logs :**

```bash
kubectl exec -n openbao openbao-0 -- bao audit enable file file_path=/openbao/logs/audit.log

# Créer un PVC pour les logs
# Puis vérifier les logs
kubectl exec -n openbao openbao-0 -- tail -f /openbao/logs/audit.log | jq
```

### 5. Problèmes courants

**OpenBao est sealed après un redémarrage :**

```bash
# C'est normal, il faut unsealer à chaque redémarrage
# Solution : Utiliser auto-unseal avec un KMS (AWS, GCP, Azure)

# Configuration auto-unseal (exemple AWS KMS)
# Dans openbao.hcl:
seal "awskms" {
  region     = "eu-west-1"
  kms_key_id = "arn:aws:kms:eu-west-1:xxxxx:key/xxxxx"
}
```

**Erreur "permission denied" :**

```bash
# Vérifier les policies associées au token/rôle
kubectl exec -n openbao openbao-0 -- bao token lookup

# Vérifier les capabilities sur un path
kubectl exec -n openbao openbao-0 -- bao token capabilities secret/data/myapp/database

# Tester avec le root token pour confirmer que c'est bien un problème de permissions
```

**Les secrets ne sont pas injectés :**

```bash
# Vérifier les annotations du Pod
kubectl get pod <pod-name> -o yaml | grep bao.openbao.org

# Vérifier que le ServiceAccount existe et est correct
kubectl get sa <sa-name>

# Vérifier que le rôle OpenBao autorise ce ServiceAccount et namespace
kubectl exec -n openbao openbao-0 -- bao read auth/kubernetes/role/<role-name>
```

---

## Bonnes pratiques

### 1. Gestion des tokens et policies

**Principe du moindre privilège :**

```hcl
# ❌ Mauvais : trop permissif
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# ✅ Bon : accès limité
path "secret/data/myapp/prod/*" {
  capabilities = ["read"]
}

path "secret/metadata/myapp/prod/*" {
  capabilities = ["list"]
}
```

**Utiliser des TTL courts :**

```bash
# Pour les applications, 1-2h est suffisant
bao write auth/kubernetes/role/myapp \
  bound_service_account_names=myapp \
  bound_service_account_namespaces=default \
  policies=myapp-policy \
  ttl=1h \
  max_ttl=2h

# Pour les credentials de DB, encore plus court
bao write database/roles/myapp-role \
  db_name=postgresql \
  creation_statements="..." \
  default_ttl=15m \
  max_ttl=1h
```

### 2. Sécurité

**Toujours utiliser TLS en production :**

```yaml
listener "tcp" {
  address = "[::]:8200"
  tls_cert_file = "/openbao/tls/tls.crt"
  tls_key_file  = "/openbao/tls/tls.key"
}
```

**Activer l'audit logging :**

```bash
bao audit enable file file_path=/openbao/logs/audit.log

# Avec syslog
bao audit enable syslog tag="openbao" facility="LOCAL7"
```

**Utiliser des namespaces (Enterprise feature) :**

```bash
# Isoler les environnements
bao namespace create dev
bao namespace create staging
bao namespace create prod
```

**Network Policies pour limiter l'accès :**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: openbao-access
  namespace: openbao
spec:
  podSelector:
    matchLabels:
      app: openbao
  policyTypes:
  - Ingress
  ingress:
  # Autoriser seulement depuis les namespaces autorisés
  - from:
    - namespaceSelector:
        matchLabels:
          openbao-access: "true"
    ports:
    - protocol: TCP
      port: 8200
```

### 3. Haute disponibilité et disaster recovery

**Backup réguliers :**

```bash
# Snapshot Raft (en mode HA)
kubectl exec -n openbao openbao-0 -- bao operator raft snapshot save backup.snap

# Copier hors du cluster
kubectl cp openbao/openbao-0:backup.snap ./backup-$(date +%Y%m%d).snap

# Restore (si nécessaire)
kubectl exec -n openbao openbao-0 -- bao operator raft snapshot restore backup.snap
```

**Tester régulièrement le processus d'unseal :**

```bash
# Créer un script d'unseal
cat > unseal.sh <<'EOF'
#!/bin/bash
UNSEAL_KEYS=(
  "key1"
  "key2"
  "key3"
)

for pod in openbao-0 openbao-1 openbao-2; do
  for key in "${UNSEAL_KEYS[@]}"; do
    kubectl exec -n openbao $pod -- bao operator unseal $key
  done
done
EOF

chmod +x unseal.sh
```

### 4. Monitoring

**Métriques Prometheus :**

```yaml
# Dans la configuration OpenBao
telemetry {
  prometheus_retention_time = "30s"
  disable_hostname = true
}
```

**ServiceMonitor pour Prometheus Operator :**

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: openbao
  namespace: openbao
spec:
  selector:
    matchLabels:
      app: openbao
  endpoints:
  - port: http
    path: /v1/sys/metrics
    params:
      format: ['prometheus']
```

**Alertes importantes :**

```yaml
groups:
- name: openbao
  rules:
  - alert: OpenBaoSealed
    expr: bao_core_unsealed == 0
    for: 5m
    annotations:
      summary: "OpenBao is sealed"

  - alert: OpenBaoDown
    expr: up{job="openbao"} == 0
    for: 5m
    annotations:
      summary: "OpenBao is down"

  - alert: OpenBaoLeadershipLost
    expr: bao_core_leadership_lost_count > 0
    annotations:
      summary: "OpenBao lost leadership"
```

### 5. Rotation des secrets

**Rotation automatique avec Kubernetes :**

```bash
# Configurer la rotation automatique pour les DB credentials
bao write database/roles/myapp-role \
  db_name=postgresql \
  creation_statements="..." \
  default_ttl=1h \
  max_ttl=24h

# L'agent OpenBao renouvelle automatiquement le token
# et récupère de nouveaux credentials avant expiration
```

**Rotation manuelle des secrets statiques :**

```bash
# Mettre à jour un secret (crée une nouvelle version)
bao kv put secret/myapp/api-key value=new-key-xxx

# L'application doit être capable de recharger le secret
# Soit via un sidecar qui surveille les changements
# Soit via un SIGHUP pour recharger la config
```

### 6. Checklist pour la production

- [ ] TLS activé sur tous les endpoints
- [ ] Auto-unseal configuré (KMS)
- [ ] Haute disponibilité avec 3+ nœuds
- [ ] Backups automatiques quotidiens
- [ ] Audit logging activé et centralisé
- [ ] Monitoring et alerting en place
- [ ] Network Policies configurées
- [ ] Policies suivant le principe du moindre privilège
- [ ] TTL courts pour les credentials
- [ ] Documentation du processus d'unseal
- [ ] Plan de disaster recovery testé
- [ ] Rotation régulière des unseal keys
- [ ] ServiceAccounts dédiés par application
- [ ] Secrets sensibles (unseal keys, root token) stockés de manière sécurisée (HSM, cloud KMS)

---

## Exercices pratiques

### Exercice 1 : Première application avec OpenBao

Objectif : Déployer une application simple qui récupère un secret depuis OpenBao.

**Étapes :**
1. Installer OpenBao en mode dev
2. Créer un secret `secret/hello/message` avec la valeur "Hello from OpenBao!"
3. Configurer Kubernetes auth
4. Créer une policy et un rôle
5. Déployer un Pod qui affiche ce secret

<details>
<summary>Solution</summary>

```bash
# 1. Installer OpenBao en mode dev
helm install openbao openbao/openbao -n openbao --create-namespace --set server.dev.enabled=true

# 2. Port-forward et créer le secret
kubectl port-forward -n openbao svc/openbao 8200:8200 &
export OPENBAO_ADDR='http://127.0.0.1:8200'
kubectl exec -n openbao openbao-0 -- bao kv put secret/hello/message value="Hello from OpenBao!"

# 3. Configurer Kubernetes auth
kubectl exec -it -n openbao openbao-0 -- sh
bao auth enable kubernetes
bao write auth/kubernetes/config \
  kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"

# 4. Créer policy et rôle
cat > /tmp/hello-policy.hcl <<EOF
path "secret/data/hello/*" {
  capabilities = ["read"]
}
EOF
bao policy write hello-policy /tmp/hello-policy.hcl
bao write auth/kubernetes/role/hello \
  bound_service_account_names=hello \
  bound_service_account_namespaces=default \
  policies=hello-policy \
  ttl=1h
exit

# 5. Déployer le Pod
kubectl create sa hello
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: hello-openbao
  annotations:
    bao.openbao.org/agent-inject: "true"
    bao.openbao.org/role: "hello"
    bao.openbao.org/agent-inject-secret-message: "secret/data/hello/message"
    bao.openbao.org/agent-inject-template-message: |
      {{- with secret "secret/data/hello/message" -}}
      {{ .Data.data.value }}
      {{- end }}
spec:
  serviceAccountName: hello
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'cat /openbao/secrets/message && sleep 3600']
EOF

# Vérifier
kubectl logs hello-openbao -c app
```
</details>

### Exercice 2 : Credentials de base de données dynamiques

Objectif : Configurer OpenBao pour générer des credentials PostgreSQL à la demande.

**Prérequis :**
- PostgreSQL déployé dans le cluster
- Utilisateur admin dans PostgreSQL

<details>
<summary>Solution</summary>

```bash
# 1. Déployer PostgreSQL si nécessaire
helm install postgres oci://registry-1.docker.io/bitnamicharts/postgresql \
  --set auth.username=admin \
  --set auth.password=AdminPass123 \
  --set auth.database=myapp

# 2. Configurer le database engine
kubectl exec -n openbao openbao-0 -- sh <<'EOF'
bao secrets enable database

bao write database/config/mypostgres \
  plugin_name=postgresql-database-plugin \
  allowed_roles="myapp-role" \
  connection_url="postgresql://{{username}}:{{password}}@postgres-postgresql:5432/myapp?sslmode=disable" \
  username="admin" \
  password="AdminPass123"

bao write database/roles/myapp-role \
  db_name=mypostgres \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="10m" \
  max_ttl="1h"
EOF

# 3. Tester la génération de credentials
kubectl exec -n openbao openbao-0 -- bao read database/creds/myapp-role

# 4. Policy et rôle
kubectl exec -n openbao openbao-0 -- sh <<'EOF'
cat > /tmp/db-policy.hcl <<POLICY
path "database/creds/myapp-role" {
  capabilities = ["read"]
}
POLICY
bao policy write db-app /tmp/db-policy.hcl

bao write auth/kubernetes/role/db-app \
  bound_service_account_names=db-app \
  bound_service_account_namespaces=default \
  policies=db-app \
  ttl=1h
EOF

# 5. Déployer une app qui utilise ces credentials
kubectl create sa db-app
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: db-test
  annotations:
    bao.openbao.org/agent-inject: "true"
    bao.openbao.org/role: "db-app"
    bao.openbao.org/agent-inject-secret-db: "database/creds/myapp-role"
    bao.openbao.org/agent-inject-template-db: |
      {{- with secret "database/creds/myapp-role" -}}
      USERNAME={{ .Data.username }}
      PASSWORD={{ .Data.password }}
      {{- end }}
spec:
  serviceAccountName: db-app
  containers:
  - name: app
    image: postgres:15-alpine
    command:
    - sh
    - -c
    - |
      source /openbao/secrets/db
      echo "Credentials: $USERNAME"
      PGPASSWORD=$PASSWORD psql -h postgres-postgresql -U $USERNAME myapp -c "SELECT current_user;"
      sleep 3600
EOF

kubectl logs db-test -c app
```
</details>

### Exercice 3 : Rotation de secrets avec recharge automatique

Objectif : Configurer une application qui recharge ses secrets quand ils changent.

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: auto-reload
  annotations:
    bao.openbao.org/agent-inject: "true"
    bao.openbao.org/role: "myapp"
    bao.openbao.org/agent-inject-secret-config: "secret/data/myapp/config"
    # Le template utilise le format JSON pour faciliter la détection de changements
    bao.openbao.org/agent-inject-template-config: |
      {{- with secret "secret/data/myapp/config" -}}
      {
        "api_key": "{{ .Data.data.api_key }}",
        "updated_at": "{{ now }}"
      }
      {{- end }}
    # Commande à exécuter quand le secret change
    bao.openbao.org/agent-inject-command-config: "killall -HUP myapp"
spec:
  serviceAccountName: myapp
  containers:
  - name: app
    image: myapp:latest
    # L'application doit gérer le signal SIGHUP pour recharger la config
```

**Script de l'application pour gérer SIGHUP :**

```bash
#!/bin/bash
CONFIG_FILE=/openbao/secrets/config

# Fonction pour charger la config
load_config() {
  echo "Loading config from $CONFIG_FILE"
  export API_KEY=$(jq -r '.api_key' $CONFIG_FILE)
  echo "Config loaded: API_KEY=${API_KEY:0:10}..."
}

# Charger la config au démarrage
load_config

# Trap SIGHUP pour recharger
trap 'echo "SIGHUP received, reloading..."; load_config' HUP

# Application principale
while true; do
  echo "Running with API_KEY=${API_KEY:0:10}..."
  sleep 10
done
```
</details>

---

## Ressources supplémentaires

- [Documentation officielle OpenBao](https://openbao.org/docs/)
- [Repository GitHub OpenBao](https://github.com/openbao/openbao)
- [OpenBao Helm Chart](https://github.com/openbao/openbao-helm)
- [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/)
- [Kubernetes Auth Method](https://openbao.org/docs/auth/kubernetes/)
- [Best Practices for Kubernetes Secrets](https://kubernetes.io/docs/concepts/security/secrets-good-practices/)

---

**Prochaines étapes :**

Une fois OpenBao maîtrisé, explorez :
- **Cert-Manager** avec OpenBao pour la gestion automatique de certificats
- **External Secrets Operator** pour synchroniser les secrets OpenBao dans Kubernetes
- **Sealed Secrets** comme alternative pour les secrets chiffrés dans Git
- **ArgoCD** avec OpenBao pour des déploiements GitOps sécurisés
