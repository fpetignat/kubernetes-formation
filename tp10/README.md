# TP10 - Projet de Synthèse : Application TaskFlow avec Auto-scaling et Monitoring

## 🎯 Objectifs du TP

Ce TP de synthèse vous permet de mettre en pratique **toutes les notions importantes** vues dans les TPs précédents :

- ✅ **Deployments** : Déploiement d'une stack applicative complète multi-tiers
- ✅ **HPA (HorizontalPodAutoscaler)** : Auto-scaling basé sur les métriques CPU/mémoire
- ✅ **initContainers** : Initialisation de base de données avec données de test
- ✅ **Services** : ClusterIP, LoadBalancer pour l'exposition
- ✅ **Volumes (PVC)** : Persistance des données (PostgreSQL, Prometheus)
- ✅ **ConfigMaps/Secrets** : Configuration externalisée
- ✅ **Monitoring** : Prometheus + Grafana pour observer le comportement
- ✅ **Load Testing** : Générateur de charge pour tester l'autoscaling
- ✅ **RBAC** : ServiceAccounts pour Prometheus

À la fin de ce TP, vous aurez déployé une **application web complète** avec auto-scaling et monitoring en temps réel.

**Durée estimée :** 3-4 heures
**Niveau :** Synthèse (tous les TPs précédents)

## 📋 Prérequis

- Avoir complété les TP1 à TP9 (ou au minimum TP1, TP2, TP3, TP4)
- Cluster Kubernetes fonctionnel (**minikube** ou **kubeadm**)
- **Minimum 4 Go de RAM** disponibles pour le cluster
- kubectl installé et configuré
- Metrics Server installé (pour HPA)

## 🏗️ Architecture de l'application TaskFlow

### Vue d'ensemble

TaskFlow est une application web de gestion de tâches (Todo List) avec les composants suivants :

```
┌─────────────────────────────────────────────────────────────────┐
│                        Utilisateurs                              │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │  LoadBalancer (SVC)  │
              └──────────┬───────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
    ┌─────────┐    ┌─────────┐    ┌─────────┐
    │Frontend │    │Backend  │    │Backend  │  ◄── HPA (auto-scaling)
    │ (Nginx) │    │  API    │    │  API    │
    └────┬────┘    └────┬────┘    └────┬────┘
         │              │              │
         └──────────────┼──────────────┘
                        │
         ┌──────────────┼──────────────┐
         │              │              │
         ▼              ▼              ▼
    ┌─────────┐   ┌──────────┐   ┌─────────┐
    │  Redis  │   │PostgreSQL│   │Prometheus│
    │ (Cache) │   │   (DB)   │   │(Metrics)│
    └─────────┘   └────┬─────┘   └────┬────┘
                       │              │
                       ▼              ▼
                  ┌────────┐     ┌─────────┐
                  │  PVC   │     │   PVC   │
                  │  (DB)  │     │(Metrics)│
                  └────────┘     └─────────┘
                       ▲
                       │
                ┌──────┴──────┐
                │initContainer│
                │  (SQL Init) │
                └─────────────┘
```

### Composants de l'application

| Composant | Description | Type de Service | Réplicas | Scaling |
|-----------|-------------|-----------------|----------|---------|
| **Frontend** | Interface web (HTML/CSS/JS) | LoadBalancer | 1 | Fixe |
| **Backend API** | API REST Flask (Python) | ClusterIP | 2-10 | **HPA activé** |
| **PostgreSQL** | Base de données | ClusterIP | 1 | Fixe |
| **Redis** | Cache en mémoire | ClusterIP | 1 | Fixe |
| **Prometheus** | Collecte de métriques | ClusterIP | 1 | Fixe |
| **Grafana** | Visualisation | LoadBalancer | 1 | Fixe |
| **Load Generator** | Générateur de charge | Job | - | On-demand |

### Flux de données

1. **Initialisation** :
   - L'**initContainer** de PostgreSQL crée le schéma de la base de données
   - Il charge **1000 tâches de test** pour simuler une application en production

2. **Fonctionnement normal** :
   - Les utilisateurs accèdent au **Frontend** via LoadBalancer
   - Le Frontend envoie les requêtes à l'**API Backend**
   - L'API interroge **PostgreSQL** pour les données
   - L'API utilise **Redis** pour mettre en cache les résultats fréquents

3. **Auto-scaling** :
   - Le **HPA** surveille l'utilisation CPU/mémoire des pods Backend
   - Quand la charge augmente, le HPA **scale automatiquement** de 2 à 10 replicas
   - Quand la charge diminue, il **descale** progressivement

4. **Monitoring** :
   - **Prometheus** collecte les métriques des pods (CPU, mémoire, requêtes)
   - **Grafana** affiche des dashboards en temps réel
   - Vous pouvez observer l'autoscaling en action

## 🚀 Partie 1 : Préparation de l'environnement

### 1.1 Vérifier Metrics Server

Le HPA nécessite Metrics Server pour obtenir les métriques CPU/mémoire :

```bash
# Vérifier si Metrics Server est installé
kubectl get deployment metrics-server -n kube-system
```

**Si non installé (minikube)** :
```bash
minikube addons enable metrics-server
```

**Si non installé (kubeadm)** :
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Attendre que Metrics Server soit prêt :
```bash
kubectl wait --for=condition=available --timeout=300s deployment/metrics-server -n kube-system
```

Vérifier que les métriques sont disponibles :
```bash
kubectl top nodes
kubectl top pods -A
```

### 1.2 Créer le namespace du projet

```bash
kubectl create namespace taskflow
kubectl config set-context --current --namespace=taskflow
```

### 1.3 Vérifier les ressources disponibles

```bash
# Vérifier la RAM disponible
kubectl top nodes

# Minimum recommandé : 4 Go de RAM libre
```

### 1.4 Construire l'image Docker Backend (REQUIS)

**IMPORTANT** : Le deployment backend utilise maintenant une image Docker construite localement avec toutes les dépendances pré-installées.

**Avant de déployer l'application**, vous devez construire l'image :

```bash
cd tp10

# Construire l'image backend avec le script automatisé
./build-image.sh
```

Le script `build-image.sh` effectue les opérations suivantes :
1. ✅ Détecte automatiquement si Minikube est disponible et démarré
2. ✅ Configure l'environnement Docker approprié (Minikube ou Docker local)
3. ✅ Construit l'image `taskflow-backend:latest` avec le Dockerfile
4. ✅ Rend l'image disponible directement dans Minikube

**Vérifier que l'image est construite** :
```bash
# Configurer le shell pour utiliser Docker de Minikube
eval $(minikube docker-env)

# Lister les images disponibles
docker images | grep taskflow-backend
```

**Avantages de cette approche** :
- ✅ **Démarrage instantané** des pods (dépendances déjà installées)
- ✅ **Pas d'installation à la volée** : pas de `pip install` au démarrage
- ✅ **Image optimisée** : ~250 MB avec toutes les dépendances
- ✅ **Sécurité renforcée** : utilisateur non-root (UID 1000) pré-configuré
- ✅ **Conforme aux bonnes pratiques de production**

**Structure des fichiers** :
```
tp10/
├── Dockerfile                   # Définition de l'image backend
├── app.py                       # Code Python de l'API backend
├── requirements.txt             # Dépendances Python
├── build-image.sh               # Script de build automatisé
└── 09-backend-deployment.yaml   # Utilise taskflow-backend:latest
```

**Configuration du Deployment** :
Le fichier `09-backend-deployment.yaml` est configuré pour utiliser l'image locale :
```yaml
containers:
- name: api
  image: taskflow-backend:latest  # Image construite localement
  imagePullPolicy: Never           # Ne pas chercher sur Docker Hub
```

## 📦 Partie 2 : Déploiement de la base de données PostgreSQL avec initContainer

### 2.1 Comprendre l'objectif

Nous allons déployer PostgreSQL avec un **initContainer** qui :
- Crée le schéma de la base de données (table `tasks`)
- Insère **1000 tâches de test** pour simuler une application en production
- S'exécute **avant** le démarrage du conteneur principal PostgreSQL

Ceci illustre un cas d'usage réel : **initialiser une base de données** avant le démarrage de l'application.

### 2.2 ConfigMap pour le script d'initialisation

Créer `01-postgres-init-script.yaml` :

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-init-script
  namespace: taskflow
data:
  init.sql: |
    -- Créer la table tasks
    CREATE TABLE IF NOT EXISTS tasks (
        id SERIAL PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        description TEXT,
        completed BOOLEAN DEFAULT FALSE,
        priority VARCHAR(20) DEFAULT 'medium',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- Créer un index pour les performances
    CREATE INDEX IF NOT EXISTS idx_tasks_completed ON tasks(completed);
    CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(priority);

    -- Générer 1000 tâches de test
    INSERT INTO tasks (title, description, completed, priority)
    SELECT
        'Task ' || generate_series,
        'Description for task ' || generate_series,
        (random() > 0.7)::boolean,  -- 30% de tâches complétées
        CASE
            WHEN random() < 0.2 THEN 'low'
            WHEN random() < 0.7 THEN 'medium'
            ELSE 'high'
        END
    FROM generate_series(1, 1000);

    -- Afficher les statistiques
    SELECT
        COUNT(*) as total_tasks,
        SUM(CASE WHEN completed THEN 1 ELSE 0 END) as completed_tasks,
        SUM(CASE WHEN NOT completed THEN 1 ELSE 0 END) as pending_tasks
    FROM tasks;
```

Appliquer :
```bash
kubectl apply -f 01-postgres-init-script.yaml
```

### 2.3 Secret pour les credentials PostgreSQL

Créer `02-postgres-secret.yaml` :

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: taskflow
type: Opaque
stringData:
  POSTGRES_USER: taskflow
  POSTGRES_PASSWORD: taskflow2024
  POSTGRES_DB: taskflow_db
```

Appliquer :
```bash
kubectl apply -f 02-postgres-secret.yaml
```

### 2.4 PersistentVolumeClaim pour PostgreSQL

Créer `03-postgres-pvc.yaml` :

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: taskflow
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
  storageClassName: standard  # Ajuster selon votre environnement
```

Appliquer :
```bash
kubectl apply -f 03-postgres-pvc.yaml
```

### 2.5 Deployment PostgreSQL avec initContainer

Créer `04-postgres-deployment.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: taskflow
  labels:
    app: postgres
    tier: database
spec:
  replicas: 1  # IMPORTANT : Une seule instance pour éviter la corruption de données
  selector:
    matchLabels:
      app: postgres
  strategy:
    type: Recreate  # IMPORTANT : Arrêter l'ancien pod avant de démarrer le nouveau
  template:
    metadata:
      labels:
        app: postgres
        tier: database
    spec:
      # initContainer : s'exécute AVANT le conteneur principal
      initContainers:
      - name: init-db-schema
        image: postgres:16-alpine
        command:
        - sh
        - -c
        - |
          echo "Waiting for PostgreSQL to be ready..."
          # Attendre que PostgreSQL soit prêt dans le conteneur principal
          # (ce script s'exécute en premier mais le volume est partagé)
          sleep 10
          echo "InitContainer completed successfully"
        volumeMounts:
        - name: init-script
          mountPath: /docker-entrypoint-initdb.d
        envFrom:
        - secretRef:
            name: postgres-secret

      # Conteneur principal PostgreSQL
      containers:
      - name: postgres
        image: postgres:16-alpine
        ports:
        - containerPort: 5432
          name: postgres
        envFrom:
        - secretRef:
            name: postgres-secret
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
          subPath: postgres  # Éviter les problèmes de permissions
        - name: init-script
          mountPath: /docker-entrypoint-initdb.d
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - taskflow
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - taskflow
          initialDelaySeconds: 5
          periodSeconds: 5

      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
      - name: init-script
        configMap:
          name: postgres-init-script
```

**Points clés à comprendre** :
- Le **initContainer** `init-db-schema` s'exécute en premier
- Il monte le même script SQL que le conteneur principal
- PostgreSQL exécute automatiquement les scripts dans `/docker-entrypoint-initdb.d/`
- Les **1000 tâches** sont créées au premier démarrage
- Le **PVC** garantit la persistance des données

**⚠️ Important sur `replicas: 1` et `strategy: Recreate`** :

**Pourquoi une seule replica ?**
- PostgreSQL est une base de données **stateful** (avec état)
- Plusieurs replicas écrivant sur le **même PVC** causeraient une **corruption de données**
- PostgreSQL ne supporte pas nativement l'écriture multi-master
- Pour la haute disponibilité, il faut configurer une réplication PostgreSQL complexe (streaming replication, patroni, etc.)

**Pourquoi `strategy: Recreate` ?**
- `Recreate` **arrête** l'ancien pod **avant** de démarrer le nouveau
- Évite que 2 pods PostgreSQL tentent d'accéder au même PVC simultanément
- Garantit qu'un seul pod écrit dans la base à la fois
- Alternative : `RollingUpdate` causerait des erreurs car le nouveau pod ne pourrait pas démarrer tant que l'ancien utilise le volume

**Pour la production** :
- ✅ PostgreSQL en `replicas: 1` avec PVC pour un TP/dev
- ✅ Pour la production : utiliser un **StatefulSet** avec réplication PostgreSQL
- ✅ Ou utiliser un service managé (AWS RDS, Google Cloud SQL, Azure Database)
- ❌ Ne JAMAIS mettre `replicas: 2+` avec un Deployment + PVC unique

Appliquer :
```bash
kubectl apply -f 04-postgres-deployment.yaml
```

### 2.6 Service PostgreSQL

Créer `05-postgres-service.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: taskflow
  labels:
    app: postgres
spec:
  type: ClusterIP
  ports:
  - port: 5432
    targetPort: 5432
    protocol: TCP
    name: postgres
  selector:
    app: postgres
```

Appliquer :
```bash
kubectl apply -f 05-postgres-service.yaml
```

### 2.7 Vérifier le déploiement PostgreSQL

```bash
# Voir le déploiement
kubectl get deployment postgres

# Voir les pods (y compris l'initContainer)
kubectl get pods -l app=postgres

# Voir les logs de l'initContainer
kubectl logs -l app=postgres -c init-db-schema

# Voir les logs du conteneur principal
kubectl logs -l app=postgres -c postgres

# Se connecter à PostgreSQL et vérifier les données
kubectl exec -it deployment/postgres -- psql -U taskflow -d taskflow_db -c "SELECT COUNT(*) FROM tasks;"
```

Vous devriez voir **1000 tâches** dans la base de données !

## 📦 Partie 3 : Déploiement de Redis (Cache)

### 3.1 Deployment Redis

Créer `06-redis-deployment.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: taskflow
  labels:
    app: redis
    tier: cache
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
        tier: cache
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
          name: redis
        command:
        - redis-server
        - --maxmemory
        - "128mb"
        - --maxmemory-policy
        - "allkeys-lru"
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        livenessProbe:
          tcpSocket:
            port: 6379
          initialDelaySeconds: 15
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 5
          periodSeconds: 5
```

Appliquer :
```bash
kubectl apply -f 06-redis-deployment.yaml
```

### 3.2 Service Redis

Créer `07-redis-service.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: taskflow
  labels:
    app: redis
spec:
  type: ClusterIP
  ports:
  - port: 6379
    targetPort: 6379
    protocol: TCP
    name: redis
  selector:
    app: redis
```

Appliquer :
```bash
kubectl apply -f 07-redis-service.yaml
```

## 🔧 Partie 4 : Backend API avec HPA (Auto-scaling)

### 4.1 ConfigMap pour la configuration API

Créer `08-backend-config.yaml` :

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
  namespace: taskflow
data:
  DATABASE_HOST: postgres
  DATABASE_PORT: "5432"
  DATABASE_NAME: taskflow_db
  REDIS_HOST: redis
  REDIS_PORT: "6379"
  CACHE_TTL: "300"
  LOG_LEVEL: "INFO"
```

Appliquer :
```bash
kubectl apply -f 08-backend-config.yaml
```

### 4.2 Deployment Backend API

Créer `09-backend-deployment.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-api
  namespace: taskflow
  labels:
    app: backend-api
    tier: application
spec:
  replicas: 2  # Nombre initial (HPA va ajuster)
  selector:
    matchLabels:
      app: backend-api
  template:
    metadata:
      labels:
        app: backend-api
        tier: application
    spec:
      containers:
      - name: api
        image: python:3.11-slim  # Image de base (ou taskflow-backend-api:latest si construite localement)
        ports:
        - containerPort: 5000
          name: http
        env:
        - name: DATABASE_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_USER
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_PASSWORD
        envFrom:
        - configMapRef:
            name: backend-config
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"  # Important pour HPA
          limits:
            memory: "256Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 5000
          initialDelaySeconds: 5
          periodSeconds: 5
```

**Note** : Les `requests.cpu` et `requests.memory` sont **essentiels** pour le HPA.

Appliquer :
```bash
kubectl apply -f 09-backend-deployment.yaml
```

### 4.3 Service Backend API

Créer `10-backend-service.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-api
  namespace: taskflow
  labels:
    app: backend-api
spec:
  type: ClusterIP
  ports:
  - port: 5000
    targetPort: 5000
    protocol: TCP
    name: http
  selector:
    app: backend-api
```

Appliquer :
```bash
kubectl apply -f 10-backend-service.yaml
```

### 4.4 HorizontalPodAutoscaler (HPA)

**C'est ici que la magie opère !** Le HPA va surveiller l'utilisation CPU/mémoire et scaler automatiquement.

Créer `11-backend-hpa.yaml` :

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-api-hpa
  namespace: taskflow
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend-api
  minReplicas: 2   # Minimum de pods
  maxReplicas: 10  # Maximum de pods
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50  # Scale quand CPU > 50%
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70  # Scale quand mémoire > 70%
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 60  # Attendre 60s avant de descaler
      policies:
      - type: Percent
        value: 50  # Descaler max 50% des pods à la fois
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0  # Scaler immédiatement
      policies:
      - type: Percent
        value: 100  # Doubler le nombre de pods si nécessaire
        periodSeconds: 15
      - type: Pods
        value: 4  # Ajouter max 4 pods à la fois
        periodSeconds: 15
      selectPolicy: Max  # Choisir la politique la plus agressive
```

**Explication des paramètres** :
- **minReplicas: 2** : Jamais moins de 2 pods (haute disponibilité)
- **maxReplicas: 10** : Maximum 10 pods (limite de ressources)
- **CPU 50%** : Si l'utilisation CPU moyenne dépasse 50%, scale up
- **Memory 70%** : Si l'utilisation mémoire dépasse 70%, scale up
- **scaleUp** : Réaction rapide (15 secondes, max 4 pods à la fois)
- **scaleDown** : Réaction lente (60 secondes, max 50% à la fois)

Appliquer :
```bash
kubectl apply -f 11-backend-hpa.yaml
```

Vérifier le HPA :
```bash
# Voir l'état du HPA
kubectl get hpa backend-api-hpa

# Observer en temps réel (watch mode)
kubectl get hpa backend-api-hpa -w
```

## 🌐 Partie 5 : Frontend et Exposition

**📌 Note importante sur l'architecture Frontend/Backend** :

Le frontend est une application HTML/JavaScript statique servie par Nginx. Lorsqu'un utilisateur accède au frontend depuis son navigateur, le JavaScript s'exécute **côté client** (dans le navigateur).

**Problème** : Les URLs internes Kubernetes (comme `http://backend-api.taskflow.svc.cluster.local:5000`) ne sont pas accessibles depuis le navigateur du client car :
- Le navigateur ne peut pas résoudre les DNS `.svc.cluster.local` (internes à Kubernetes)
- Le navigateur ne peut pas atteindre les IPs internes du cluster

**Solution** : Nous configurons **Nginx comme reverse proxy**. Le frontend utilise une URL relative (`/api`) et Nginx redirige les requêtes vers le service backend interne.

```
Navigateur → /api → Nginx (reverse proxy) → http://backend-api:5000
```

### 5.1 Configuration Nginx avec Reverse Proxy

Créer `12-frontend-nginx-config.yaml` :

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-nginx-config
  namespace: taskflow
  labels:
    app: frontend
data:
  nginx.conf: |
    user nginx;
    worker_processes auto;
    pid /var/run/nginx.pid;

    events {
        worker_connections 1024;
    }

    http {
        include /etc/nginx/mime.types;
        default_type application/octet-stream;

        access_log /dev/stdout;
        error_log /dev/stderr warn;

        sendfile on;
        tcp_nopush on;
        keepalive_timeout 65;

        gzip on;
        gzip_vary on;
        gzip_min_length 1000;
        gzip_types text/plain text/css application/json application/javascript text/xml;

        server {
            listen 80;
            server_name _;

            root /usr/share/nginx/html;
            index index.html;

            # Frontend - Servir l'application HTML/JS
            location / {
                try_files $uri $uri/ /index.html;
                add_header X-Content-Type-Options "nosniff" always;
                add_header X-Frame-Options "SAMEORIGIN" always;
                add_header X-XSS-Protection "1; mode=block" always;
            }

            # API Backend - Reverse proxy vers le service backend-api
            location /api/ {
                # Supprimer le préfixe /api avant de transférer
                rewrite ^/api/(.*) /$1 break;

                # Proxy vers le service Kubernetes backend-api
                proxy_pass http://backend-api:5000;

                # Headers de proxy standards
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;

                # Timeouts
                proxy_connect_timeout 30s;
                proxy_send_timeout 30s;
                proxy_read_timeout 30s;
            }

            # Health check endpoint
            location /health {
                access_log off;
                return 200 "healthy\n";
                add_header Content-Type text/plain;
            }
        }
    }
```

**Explication de la configuration** :
- `location /` : Sert les fichiers statiques du frontend (HTML/CSS/JS)
- `location /api/` : Reverse proxy vers le backend
  - `rewrite ^/api/(.*) /$1 break` : Supprime le préfixe `/api` (ex: `/api/tasks` → `/tasks`)
  - `proxy_pass http://backend-api:5000` : Redirige vers le service backend interne
  - Headers de proxy pour préserver l'information du client

Appliquer :
```bash
kubectl apply -f 12-frontend-nginx-config.yaml
```

### 5.2 ConfigMap pour le Frontend HTML

Créer `12-frontend-config.yaml` :

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-html
  namespace: taskflow
data:
  index.html: |
    <!DOCTYPE html>
    <html lang="fr">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>TaskFlow - Gestion de Tâches</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                padding: 20px;
            }
            .container {
                max-width: 1200px;
                margin: 0 auto;
                background: white;
                border-radius: 15px;
                box-shadow: 0 20px 60px rgba(0,0,0,0.3);
                overflow: hidden;
            }
            header {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                padding: 30px;
                text-align: center;
            }
            h1 { font-size: 2.5em; margin-bottom: 10px; }
            .stats {
                display: flex;
                justify-content: space-around;
                padding: 20px;
                background: #f8f9fa;
                border-bottom: 1px solid #dee2e6;
            }
            .stat-box {
                text-align: center;
                padding: 15px;
            }
            .stat-number {
                font-size: 2em;
                font-weight: bold;
                color: #667eea;
            }
            .stat-label {
                color: #6c757d;
                margin-top: 5px;
            }
            .tasks {
                padding: 20px;
                max-height: 600px;
                overflow-y: auto;
            }
            .task {
                background: white;
                border: 1px solid #dee2e6;
                border-radius: 8px;
                padding: 15px;
                margin-bottom: 10px;
                display: flex;
                justify-content: space-between;
                align-items: center;
                transition: all 0.3s;
            }
            .task:hover {
                box-shadow: 0 4px 12px rgba(0,0,0,0.1);
                transform: translateY(-2px);
            }
            .task.completed {
                opacity: 0.6;
                text-decoration: line-through;
            }
            .priority {
                display: inline-block;
                padding: 4px 12px;
                border-radius: 12px;
                font-size: 0.85em;
                font-weight: bold;
                margin-left: 10px;
            }
            .priority-high { background: #dc3545; color: white; }
            .priority-medium { background: #ffc107; color: black; }
            .priority-low { background: #28a745; color: white; }
            .loading {
                text-align: center;
                padding: 40px;
                font-size: 1.2em;
                color: #6c757d;
            }
            .error {
                background: #f8d7da;
                color: #721c24;
                padding: 20px;
                margin: 20px;
                border-radius: 8px;
                border: 1px solid #f5c6cb;
            }
            .controls {
                padding: 20px;
                background: #f8f9fa;
                border-top: 1px solid #dee2e6;
                text-align: center;
            }
            button {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                border: none;
                padding: 12px 30px;
                border-radius: 25px;
                font-size: 1em;
                cursor: pointer;
                margin: 5px;
                transition: transform 0.2s;
            }
            button:hover {
                transform: scale(1.05);
            }
            button:active {
                transform: scale(0.95);
            }
        </style>
    </head>
    <body>
        <div class="container">
            <header>
                <h1>📋 TaskFlow</h1>
                <p>Projet de Synthèse Kubernetes - Auto-scaling et Monitoring</p>
            </header>

            <div class="stats" id="stats">
                <div class="stat-box">
                    <div class="stat-number" id="totalTasks">-</div>
                    <div class="stat-label">Total Tâches</div>
                </div>
                <div class="stat-box">
                    <div class="stat-number" id="completedTasks">-</div>
                    <div class="stat-label">Complétées</div>
                </div>
                <div class="stat-box">
                    <div class="stat-number" id="pendingTasks">-</div>
                    <div class="stat-label">En cours</div>
                </div>
                <div class="stat-box">
                    <div class="stat-number" id="apiPods">-</div>
                    <div class="stat-label">Pods API (HPA)</div>
                </div>
            </div>

            <div class="controls">
                <button onclick="loadTasks()">🔄 Rafraîchir</button>
                <button onclick="loadTasks('high')">🔴 Priorité Haute</button>
                <button onclick="loadTasks('medium')">🟡 Priorité Moyenne</button>
                <button onclick="loadTasks('low')">🟢 Priorité Basse</button>
            </div>

            <div class="tasks" id="tasksList">
                <div class="loading">Chargement des tâches...</div>
            </div>
        </div>

        <script>
            // Utiliser une URL relative car Nginx proxie /api vers le backend
            const API_URL = '/api';

            async function loadTasks(priority = null) {
                const tasksList = document.getElementById('tasksList');
                tasksList.innerHTML = '<div class="loading">Chargement...</div>';

                try {
                    const url = priority ? `${API_URL}/tasks?priority=${priority}` : `${API_URL}/tasks`;
                    const response = await fetch(url);

                    if (!response.ok) {
                        throw new Error(`HTTP ${response.status}`);
                    }

                    const data = await response.json();
                    displayTasks(data.tasks);
                    updateStats(data.stats);
                } catch (error) {
                    tasksList.innerHTML = `
                        <div class="error">
                            <strong>Erreur de connexion à l'API</strong><br>
                            ${error.message}<br>
                            <small>Vérifiez que le backend est déployé et accessible</small>
                        </div>
                    `;
                }
            }

            function displayTasks(tasks) {
                const tasksList = document.getElementById('tasksList');

                if (!tasks || tasks.length === 0) {
                    tasksList.innerHTML = '<div class="loading">Aucune tâche trouvée</div>';
                    return;
                }

                tasksList.innerHTML = tasks.map(task => `
                    <div class="task ${task.completed ? 'completed' : ''}">
                        <div>
                            <strong>${task.title}</strong>
                            <span class="priority priority-${task.priority}">${task.priority}</span>
                            <div style="color: #6c757d; margin-top: 5px; font-size: 0.9em;">
                                ${task.description}
                            </div>
                        </div>
                        <div>
                            ${task.completed ? '✅' : '⏳'}
                        </div>
                    </div>
                `).join('');
            }

            function updateStats(stats) {
                if (stats) {
                    document.getElementById('totalTasks').textContent = stats.total || 0;
                    document.getElementById('completedTasks').textContent = stats.completed || 0;
                    document.getElementById('pendingTasks').textContent = stats.pending || 0;
                }

                // Simuler le nombre de pods (en production, récupérer via une API)
                document.getElementById('apiPods').textContent = '~';
            }

            // Charger les tâches au démarrage
            loadTasks();

            // Auto-refresh toutes les 30 secondes
            setInterval(() => loadTasks(), 30000);
        </script>
    </body>
    </html>
```

Appliquer :
```bash
kubectl apply -f 12-frontend-config.yaml
```

### 5.3 Deployment Frontend

Créer `13-frontend-deployment.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: taskflow
  labels:
    app: frontend
    tier: presentation
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        tier: presentation
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
        fsGroup: 101
        seccompProfile:
          type: RuntimeDefault

      containers:
      - name: nginx
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
          name: http
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 101
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
        - name: nginx-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
        - name: cache
          mountPath: /var/cache/nginx
        - name: run
          mountPath: /var/run
        - name: tmp
          mountPath: /tmp
        resources:
          requests:
            memory: "32Mi"
            cpu: "50m"
          limits:
            memory: "64Mi"
            cpu: "100m"

      volumes:
      - name: html
        configMap:
          name: frontend-html
      - name: nginx-config
        configMap:
          name: frontend-nginx-config
      - name: cache
        emptyDir: {}
      - name: run
        emptyDir: {}
      - name: tmp
        emptyDir: {}
```

**Points importants** :
- Le volume `nginx-config` monte la configuration Nginx personnalisée avec le reverse proxy
- Les volumes `emptyDir` sont nécessaires car `readOnlyRootFilesystem: true` est activé pour la sécurité
- Le securityContext suit les meilleures pratiques Kubernetes (voir `.claude/SECURITY.md`)

Appliquer :
```bash
kubectl apply -f 13-frontend-deployment.yaml
```

### 5.4 Service Frontend (LoadBalancer)

Créer `14-frontend-service.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: taskflow
  labels:
    app: frontend
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
  selector:
    app: frontend
```

Appliquer :
```bash
kubectl apply -f 14-frontend-service.yaml
```

Obtenir l'URL du frontend :
```bash
# Minikube
minikube service frontend -n taskflow --url

# Kubeadm (NodePort)
kubectl get svc frontend -n taskflow
```

## 📊 Partie 6 : Monitoring avec Prometheus et Grafana

### 6.1 Déployer Prometheus

Nous allons utiliser une configuration simplifiée de Prometheus pour ce TP.

Créer `15-prometheus-config.yaml` :

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: taskflow
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    scrape_configs:
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
        - role: pod
          namespaces:
            names:
            - taskflow
        relabel_configs:
        - source_labels: [__meta_kubernetes_pod_label_app]
          action: keep
          regex: backend-api|postgres|redis
        - source_labels: [__meta_kubernetes_pod_name]
          target_label: pod
        - source_labels: [__meta_kubernetes_pod_label_app]
          target_label: app
```

Appliquer :
```bash
kubectl apply -f 15-prometheus-config.yaml
```

### 6.2 RBAC pour Prometheus

Créer `16-prometheus-rbac.yaml` :

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: taskflow
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/proxy
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups:
  - extensions
  resources:
  - ingresses
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: taskflow
```

Appliquer :
```bash
kubectl apply -f 16-prometheus-rbac.yaml
```

### 6.3 PVC pour Prometheus

Créer `17-prometheus-pvc.yaml` :

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-pvc
  namespace: taskflow
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: standard
```

Appliquer :
```bash
kubectl apply -f 17-prometheus-pvc.yaml
```

### 6.4 Deployment Prometheus

Créer `18-prometheus-deployment.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: taskflow
  labels:
    app: prometheus
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      serviceAccountName: prometheus
      containers:
      - name: prometheus
        image: prom/prometheus:v2.48.0
        args:
        - '--config.file=/etc/prometheus/prometheus.yml'
        - '--storage.tsdb.path=/prometheus'
        - '--storage.tsdb.retention.time=7d'
        ports:
        - containerPort: 9090
          name: http
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        - name: storage
          mountPath: /prometheus
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
      volumes:
      - name: config
        configMap:
          name: prometheus-config
      - name: storage
        persistentVolumeClaim:
          claimName: prometheus-pvc
```

Appliquer :
```bash
kubectl apply -f 18-prometheus-deployment.yaml
```

### 6.5 Service Prometheus

Créer `19-prometheus-service.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: taskflow
  labels:
    app: prometheus
spec:
  type: ClusterIP
  ports:
  - port: 9090
    targetPort: 9090
    protocol: TCP
    name: http
  selector:
    app: prometheus
```

Appliquer :
```bash
kubectl apply -f 19-prometheus-service.yaml
```

### 6.6 Déployer Grafana

Créer `20-grafana-deployment.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: taskflow
  labels:
    app: grafana
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:10.2.0
        ports:
        - containerPort: 3000
          name: http
        env:
        - name: GF_SECURITY_ADMIN_USER
          value: admin
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: admin2024
        - name: GF_SERVER_ROOT_URL
          value: "%(protocol)s://%(domain)s:%(http_port)s/"
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
        volumeMounts:
        - name: grafana-storage
          mountPath: /var/lib/grafana
      volumes:
      - name: grafana-storage
        emptyDir: {}
```

Appliquer :
```bash
kubectl apply -f 20-grafana-deployment.yaml
```

### 6.7 Service Grafana (LoadBalancer)

Créer `21-grafana-service.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: taskflow
  labels:
    app: grafana
spec:
  type: LoadBalancer
  ports:
  - port: 3000
    targetPort: 3000
    protocol: TCP
    name: http
  selector:
    app: grafana
```

Appliquer :
```bash
kubectl apply -f 21-grafana-service.yaml
```

Obtenir l'URL de Grafana :
```bash
# Minikube
minikube service grafana -n taskflow --url

# Kubeadm
kubectl get svc grafana -n taskflow
```

**Credentials par défaut** :
- Username: `admin`
- Password: `admin2024`

## 🚀 Partie 7 : Load Generator (Générateur de Charge)

### 7.1 Comprendre l'objectif

Le Load Generator va **simuler du trafic** vers l'API Backend pour :
- Augmenter l'utilisation CPU/mémoire des pods
- **Déclencher l'autoscaling** du HPA
- Observer le comportement en temps réel dans Grafana

### 7.2 Job Load Generator

Créer `22-load-generator.yaml` :

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: load-generator
  namespace: taskflow
spec:
  parallelism: 5  # 5 pods en parallèle pour générer de la charge
  completions: 5
  template:
    metadata:
      labels:
        app: load-generator
    spec:
      restartPolicy: Never
      containers:
      - name: load-generator
        image: busybox:1.36
        command:
        - /bin/sh
        - -c
        - |
          echo "Starting load generator..."
          API_URL="http://backend-api.taskflow.svc.cluster.local:5000"

          # Boucle infinie de requêtes
          while true; do
            # GET /tasks
            wget -q -O- $API_URL/tasks > /dev/null 2>&1

            # GET /tasks?priority=high
            wget -q -O- $API_URL/tasks?priority=high > /dev/null 2>&1

            # GET /tasks?completed=false
            wget -q -O- $API_URL/tasks?completed=false > /dev/null 2>&1

            # GET /stats
            wget -q -O- $API_URL/stats > /dev/null 2>&1

            # Petite pause pour ne pas surcharger immédiatement
            sleep 0.1
          done
        resources:
          requests:
            memory: "32Mi"
            cpu: "100m"
          limits:
            memory: "64Mi"
            cpu: "200m"
```

**Ne PAS appliquer tout de suite** ! Nous allons d'abord tout vérifier.

## ✅ Partie 8 : Vérification et Tests

### 8.1 Vérifier tous les composants

```bash
# Voir tous les déploiements
kubectl get deployments -n taskflow

# Voir tous les pods
kubectl get pods -n taskflow

# Voir tous les services
kubectl get svc -n taskflow

# Voir le HPA
kubectl get hpa -n taskflow

# Voir les PVC
kubectl get pvc -n taskflow
```

Tous les pods doivent être en état **Running** :
- `postgres-xxx`
- `redis-xxx`
- `backend-api-xxx` (2 replicas initialement)
- `frontend-xxx`
- `prometheus-xxx`
- `grafana-xxx`

### 8.2 Tester l'API Backend

```bash
# Port-forward pour tester localement
kubectl port-forward -n taskflow svc/backend-api 5000:5000 &

# Tester l'API
curl http://localhost:5000/health
curl http://localhost:5000/tasks | jq '.tasks | length'
curl http://localhost:5000/stats

# Arrêter le port-forward
pkill -f "kubectl.*port-forward.*backend-api"
```

Vous devriez voir **1000 tâches** dans la base de données.

### 8.3 Accéder au Frontend

```bash
# Minikube
minikube service frontend -n taskflow

# Kubeadm
kubectl get svc frontend -n taskflow
# Puis naviguer vers http://<NODE-IP>:<NODE-PORT>
```

Vous devriez voir l'interface web avec les 1000 tâches.

### 8.4 Configurer Grafana

1. Accéder à Grafana :
```bash
minikube service grafana -n taskflow
# Ou kubectl port-forward svc/grafana 3000:3000 -n taskflow
```

2. Se connecter :
   - Username: `admin`
   - Password: `admin2024`

3. Ajouter Prometheus comme Data Source :
   - Aller dans **Configuration** → **Data Sources**
   - Cliquer **Add data source**
   - Sélectionner **Prometheus**
   - URL: `http://prometheus.taskflow.svc.cluster.local:9090`
   - Cliquer **Save & Test**

4. Créer un dashboard :
   - Aller dans **Dashboards** → **New** → **New Dashboard**
   - Ajouter des panels pour :
     - CPU usage des pods backend
     - Memory usage des pods backend
     - Nombre de replicas du deployment backend-api
     - Requêtes par seconde

### 8.5 Observer le HPA (avant charge)

```bash
# Voir l'état actuel du HPA
kubectl get hpa backend-api-hpa -n taskflow

# Devrait afficher quelque chose comme :
# NAME               REFERENCE                TARGETS         MINPODS   MAXPODS   REPLICAS
# backend-api-hpa    Deployment/backend-api   5%/50%, 12%/70%   2         10        2
```

Les 2 métriques affichées sont :
- `5%/50%` : CPU actuel / cible (5% sur 50%)
- `12%/70%` : Memory actuel / cible (12% sur 70%)

## 🔥 Partie 9 : Test de l'Auto-scaling

### 9.1 Lancer le Load Generator

```bash
# Déployer le générateur de charge
kubectl apply -f 22-load-generator.yaml

# Vérifier qu'il tourne
kubectl get jobs -n taskflow
kubectl get pods -n taskflow -l app=load-generator
```

Vous devriez voir **5 pods** de load-generator en état Running.

### 9.2 Observer l'autoscaling en temps réel

**Terminal 1** : Observer le HPA
```bash
watch -n 2 'kubectl get hpa backend-api-hpa -n taskflow'
```

**Terminal 2** : Observer les pods
```bash
watch -n 2 'kubectl get pods -n taskflow -l app=backend-api'
```

**Terminal 3** : Observer les métriques
```bash
watch -n 5 'kubectl top pods -n taskflow -l app=backend-api'
```

### 9.3 Ce que vous devriez observer

**Phase 1 : Montée en charge (0-2 minutes)**
- L'utilisation CPU des pods backend passe de ~5% à 60-80%
- Le HPA détecte la charge excessive

**Phase 2 : Scale up (2-5 minutes)**
- Le HPA crée de nouveaux pods (3, 4, 5, 6...)
- Les nouveaux pods démarrent et deviennent Ready
- La charge se répartit sur plus de pods
- L'utilisation CPU par pod redescend

**Phase 3 : Stabilisation (5-10 minutes)**
- Le nombre de pods se stabilise (généralement 6-8 pods)
- L'utilisation CPU se maintient autour de 50%

**Phase 4 : Arrêt du load generator**
```bash
# Arrêter la charge
kubectl delete job load-generator -n taskflow
```

**Phase 5 : Scale down (10-15 minutes)**
- L'utilisation CPU chute
- Le HPA attend 60 secondes (stabilizationWindow)
- Il réduit progressivement le nombre de pods
- Retour à 2 pods (minReplicas)

### 9.4 Observer dans Grafana

Pendant le test, observer dans Grafana :
1. Le **CPU usage** monter puis se stabiliser
2. Le **nombre de pods** augmenter de 2 à 8-10
3. Les **requêtes par seconde** augmenter
4. La **latence** rester stable grâce à l'autoscaling

## 📊 Partie 10 : Analyse et Nettoyage

### 10.1 Analyser les logs

```bash
# Logs du HPA (events)
kubectl describe hpa backend-api-hpa -n taskflow

# Logs des pods backend
kubectl logs -n taskflow -l app=backend-api --tail=100

# Events du namespace
kubectl get events -n taskflow --sort-by='.lastTimestamp'
```

### 10.2 Questions de réflexion

1. **Combien de temps le HPA a-t-il mis pour scaler de 2 à 10 pods ?**
2. **Pourquoi le scale-down est-il plus lent que le scale-up ?**
3. **Quelle est l'utilisation CPU moyenne par pod pendant la charge ?**
4. **Combien de requêtes par seconde l'API peut-elle gérer avec 10 pods ?**

### 10.3 Nettoyer les ressources

```bash
# Option 1 : Supprimer tout le namespace (tout effacer)
kubectl delete namespace taskflow

# Option 2 : Supprimer ressource par ressource
kubectl delete -f 22-load-generator.yaml
kubectl delete -f 21-grafana-service.yaml
kubectl delete -f 20-grafana-deployment.yaml
kubectl delete -f 19-prometheus-service.yaml
kubectl delete -f 18-prometheus-deployment.yaml
kubectl delete -f 17-prometheus-pvc.yaml
kubectl delete -f 16-prometheus-rbac.yaml
kubectl delete -f 15-prometheus-config.yaml
kubectl delete -f 14-frontend-service.yaml
kubectl delete -f 13-frontend-deployment.yaml
kubectl delete -f 12-frontend-config.yaml
kubectl delete -f 11-backend-hpa.yaml
kubectl delete -f 10-backend-service.yaml
kubectl delete -f 09-backend-deployment.yaml
kubectl delete -f 08-backend-config.yaml
kubectl delete -f 07-redis-service.yaml
kubectl delete -f 06-redis-deployment.yaml
kubectl delete -f 05-postgres-service.yaml
kubectl delete -f 04-postgres-deployment.yaml
kubectl delete -f 03-postgres-pvc.yaml
kubectl delete -f 02-postgres-secret.yaml
kubectl delete -f 01-postgres-init-script.yaml
```

## 🎓 Concepts clés appris

### 1. initContainers
- S'exécutent **avant** les conteneurs principaux
- Utiles pour l'initialisation (DB schema, configuration, téléchargements)
- Doivent se terminer avec succès pour que le pod démarre

### 2. HorizontalPodAutoscaler (HPA)
- Scale automatiquement basé sur CPU/mémoire
- Paramètres importants : `minReplicas`, `maxReplicas`, `targetAverageUtilization`
- Comportements : `scaleUp` (rapide) vs `scaleDown` (lent et prudent)

### 3. LoadBalancer Services
- Exposent l'application à l'extérieur du cluster
- Sur Minikube : utiliser `minikube tunnel` ou `minikube service`
- Sur cloud providers : créent automatiquement un load balancer externe

### 4. Monitoring avec Prometheus
- **Prometheus** collecte les métriques (scraping)
- **Grafana** visualise les données
- RBAC nécessaire pour que Prometheus interroge l'API Kubernetes

### 5. PersistentVolumeClaim (PVC)
- Permettent la persistance des données
- PostgreSQL : stocke la base de données
- Prometheus : stocke les métriques historiques

### 6. ConfigMaps et Secrets
- **ConfigMap** : configuration non sensible (URLs, ports)
- **Secret** : données sensibles (passwords, tokens)
- Montés comme volumes ou variables d'environnement

## 📚 Exercices supplémentaires

### Exercice 1 : Modifier les seuils du HPA
Modifier `11-backend-hpa.yaml` pour scaler plus agressivement :
- CPU target: 30% (au lieu de 50%)
- MaxReplicas: 15 (au lieu de 10)

Observer la différence de comportement.

### Exercice 2 : Ajouter une NetworkPolicy
Créer une NetworkPolicy qui :
- Permet uniquement au frontend de contacter le backend
- Permet uniquement au backend de contacter PostgreSQL et Redis
- Bloque tout le reste

### Exercice 3 : Monitoring avancé
Ajouter au dashboard Grafana :
- Taux d'erreur HTTP (4xx, 5xx)
- Latence P50, P95, P99
- Nombre de connexions à PostgreSQL

### Exercice 4 : Haute disponibilité
Modifier pour avoir :
- 3 replicas de PostgreSQL (avec réplication)
- 3 replicas de Redis (Redis Cluster)
- PodDisruptionBudget pour garantir la disponibilité

## 🎯 Checklist de réussite

- [ ] Tous les pods sont en état Running
- [ ] La base de données contient 1000 tâches
- [ ] Le frontend est accessible via LoadBalancer
- [ ] Le HPA montre 2 replicas au repos
- [ ] Prometheus collecte les métriques
- [ ] Grafana affiche les dashboards
- [ ] Le load generator augmente la charge
- [ ] Le HPA scale de 2 à 8-10 pods
- [ ] L'utilisation CPU se stabilise autour de 50%
- [ ] Le scale-down fonctionne après arrêt de la charge

## 📖 Ressources

- [HPA Documentation](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)

## 🎉 Conclusion

Félicitations ! Vous avez déployé une application complète avec :
- ✅ **Auto-scaling** intelligent basé sur les métriques réelles
- ✅ **Initialisation** automatique avec initContainers
- ✅ **Monitoring** en temps réel avec Prometheus et Grafana
- ✅ **Persistance** des données avec PVC
- ✅ **Exposition** sécurisée avec Services et LoadBalancer

Ce projet de synthèse démontre votre maîtrise de Kubernetes et des concepts avancés nécessaires pour déployer des applications en production.

**Prochaines étapes** :
- Ajouter un Ingress pour gérer le routage HTTP
- Implémenter un CI/CD avec ArgoCD (TP6)
- Ajouter des Network Policies (TP5, TP8)
- Déployer sur un cluster multi-nœuds (TP9)
