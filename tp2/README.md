# TP2 - Maîtriser les Manifests Kubernetes

## Objectifs du TP

À la fin de ce TP, vous serez capable de :
- Comprendre la structure des fichiers YAML Kubernetes
- Écrire vos propres manifests pour différentes ressources
- Valider et tester vos configurations YAML
- Utiliser les labels et selectors efficacement
- Gérer la configuration avec ConfigMaps et Secrets
- Appliquer les bonnes pratiques de rédaction de manifests

## Prérequis

- Avoir complété le TP1
- Un cluster Kubernetes fonctionnel (**minikube** ou **kubeadm**)
- Un éditeur de texte (vim, nano, VS Code, etc.)

**Note :** Les manifests YAML sont identiques que vous utilisiez minikube ou kubeadm. Les différences se situent uniquement au niveau de l'accès aux services (voir TP1, Partie 5.2).

## Partie 1 : Anatomie d'un manifest Kubernetes

### 1.1 Structure de base

Tous les manifests Kubernetes suivent la même structure de base :

```yaml
apiVersion: <groupe>/<version>  # Version de l'API Kubernetes
kind: <Type>                    # Type de ressource
metadata:                       # Métadonnées
  name: <nom>
  labels:
    key: value
spec:                          # Spécification de la ressource
  # Configuration spécifique au type
```

### 1.2 Les champs essentiels

**apiVersion** : Détermine quelle version de l'API utiliser
- `v1` : pour Pod, Service, ConfigMap, Secret
- `apps/v1` : pour Deployment, StatefulSet, DaemonSet
- `batch/v1` : pour Job, CronJob

**kind** : Type de ressource à créer
- Pod, Service, Deployment, ConfigMap, Secret, etc.

**metadata** : Informations sur la ressource
- `name` : Nom unique dans le namespace
- `labels` : Paires clé-valeur pour identifier et sélectionner les ressources
- `namespace` : Namespace où créer la ressource (défaut: default)
- `annotations` : Métadonnées non-identifiantes

**spec** : Définit l'état désiré de la ressource

### 1.3 Validation d'un manifest

```bash
# Vérifier la syntaxe sans créer la ressource
kubectl apply -f mon-fichier.yaml --dry-run=client

# Valider côté serveur
kubectl apply -f mon-fichier.yaml --dry-run=server

# Afficher le YAML d'une ressource existante
kubectl get deployment nginx-demo -o yaml

# Expliquer la structure d'une ressource
kubectl explain pod
kubectl explain pod.spec
kubectl explain pod.spec.containers
```

## Partie 2 : Les Pods - La plus petite unité

### 2.1 Pod simple

Créer un fichier `01-simple-pod.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
    env: dev
spec:
  containers:
  - name: nginx
    image: nginx:1.24
    ports:
    - containerPort: 80
```

**Exercice 1 : Votre premier Pod**

1. Créez le fichier ci-dessus
2. Validez-le avec `--dry-run=client`
3. Appliquez-le avec `kubectl apply`
4. Vérifiez son statut avec `kubectl get pods`
5. Consultez ses détails avec `kubectl describe pod nginx-pod`

```bash
# Commandes à exécuter
kubectl apply -f 01-simple-pod.yaml --dry-run=client
kubectl apply -f 01-simple-pod.yaml
kubectl get pods
kubectl describe pod nginx-pod
```

### 2.2 Pod avec ressources limitées

Créer `02-pod-with-resources.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: webapp-pod
  labels:
    app: webapp
spec:
  containers:
  - name: webapp
    image: httpd:2.4
    ports:
    - containerPort: 80
    resources:
      requests:      # Ressources minimales garanties
        memory: "64Mi"
        cpu: "250m"
      limits:        # Ressources maximales
        memory: "128Mi"
        cpu: "500m"
```

**Exercice 2 : Pod avec contraintes de ressources**

1. Créez ce fichier
2. Appliquez-le
3. Vérifiez les ressources allouées : `kubectl describe pod webapp-pod`
4. Observez la section "Requests" et "Limits"

### 2.3 Pod multi-conteneurs

Créer `03-multi-container-pod.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-pod
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
    volumeMounts:
    - name: shared-data
      mountPath: /usr/share/nginx/html

  - name: content-generator
    image: busybox
    command: ["/bin/sh"]
    args:
      - -c
      - >
        while true; do
          echo "Hello from Kubernetes - $(date)" > /data/index.html;
          sleep 10;
        done
    volumeMounts:
    - name: shared-data
      mountPath: /data

  volumes:
  - name: shared-data
    emptyDir: {}
```

**Exercice 3 : Pod avec sidecar**

1. Créez et appliquez ce manifest
2. Vérifiez que les 2 conteneurs tournent : `kubectl get pod multi-container-pod`
3. Consultez les logs de chaque conteneur :
   ```bash
   kubectl logs multi-container-pod -c nginx
   kubectl logs multi-container-pod -c content-generator
   ```
4. Testez l'application avec un port-forward :
   ```bash
   kubectl port-forward pod/multi-container-pod 8080:80
   curl localhost:8080
   ```

## Partie 3 : Deployments - Gestion des réplicas

### 3.1 Deployment de base

Créer `04-deployment-basic.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-deployment
  labels:
    app: web
spec:
  replicas: 3
  selector:
    matchLabels:      # DOIT correspondre aux labels du template
      app: web
  template:           # Template du Pod
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.24
        ports:
        - containerPort: 80
```

**Exercice 4 : Déploiement avec réplicas**

1. Créez ce deployment
2. Vérifiez les pods créés : `kubectl get pods -l app=web`
3. Supprimez un pod manuellement et observez la recréation automatique
4. Modifiez le nombre de replicas dans le fichier à 5
5. Réappliquez : `kubectl apply -f 04-deployment-basic.yaml`

### 3.2 Deployment avec stratégie de mise à jour

Créer `05-deployment-strategy.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rolling-deployment
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # Nombre de pods supplémentaires pendant la mise à jour
      maxUnavailable: 1  # Nombre de pods indisponibles pendant la mise à jour
  selector:
    matchLabels:
      app: rolling-app
  template:
    metadata:
      labels:
        app: rolling-app
        version: v1
    spec:
      containers:
      - name: app
        image: nginx:1.24
        ports:
        - containerPort: 80
        livenessProbe:    # Vérification que le conteneur est vivant
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        readinessProbe:   # Vérification que le conteneur est prêt
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
```

**Exercice 5 : Rolling Update**

1. Créez ce deployment
2. Surveillez les pods : `kubectl get pods -l app=rolling-app -w`
3. Dans un autre terminal, mettez à jour l'image :
   ```bash
   kubectl set image deployment/rolling-deployment app=nginx:1.25
   ```
4. Observez le rolling update en cours
5. Consultez l'historique : `kubectl rollout history deployment/rolling-deployment`
6. Effectuez un rollback : `kubectl rollout undo deployment/rolling-deployment`

## Partie 4 : Services - Exposition des applications

### 4.1 Service ClusterIP

Créer `06-service-clusterip.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: internal-service
spec:
  type: ClusterIP    # Accessible uniquement dans le cluster
  selector:
    app: web
  ports:
  - protocol: TCP
    port: 80         # Port du service
    targetPort: 80   # Port du conteneur
```

### 4.2 Service NodePort

Créer `07-service-nodeport.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-service
spec:
  type: NodePort
  selector:
    app: web
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
    nodePort: 30080  # Port accessible sur chaque nœud (30000-32767)
```

### 4.3 Service avec annotations

Créer `08-service-complete.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: app-service
  annotations:
    description: "Service principal de l'application"
  labels:
    env: production
spec:
  type: NodePort
  selector:
    app: web
    env: prod
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 8080
  - name: https
    protocol: TCP
    port: 443
    targetPort: 8443
  sessionAffinity: ClientIP  # Maintenir la session sur le même pod
```

**Exercice 6 : Création de services**

1. Créez les trois types de services ci-dessus
2. Vérifiez avec : `kubectl get services`
3. Testez l'accès au service NodePort :

   **Avec minikube :**
   ```bash
   curl http://$(minikube ip):30080
   ```

   **Avec kubeadm :**
   ```bash
   # Récupérer l'IP d'un nœud
   NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
   curl http://$NODE_IP:30080
   ```

4. Affichez les endpoints : `kubectl get endpoints`
5. Décrivez le service : `kubectl describe service app-service`

## Partie 5 : ConfigMaps et Secrets

### 5.1 ConfigMap simple

Créer `09-configmap.yaml` :

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  # Données de configuration sous forme clé-valeur
  database_url: "postgres://db:5432/myapp"
  log_level: "info"
  max_connections: "100"

  # Configuration multi-lignes
  app.conf: |
    server {
      listen 80;
      server_name localhost;

      location / {
        root /usr/share/nginx/html;
        index index.html;
      }
    }
```

### 5.2 Secret

Créer `10-secret.yaml` :

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
stringData:  # Les données seront automatiquement encodées en base64
  username: admin
  password: supersecret123
  api-key: abcd1234efgh5678
```

### 5.3 Pod utilisant ConfigMap et Secret

Créer `11-pod-with-config.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: configured-app
spec:
  containers:
  - name: app
    image: nginx:alpine

    # Variables d'environnement depuis ConfigMap
    env:
    - name: DATABASE_URL
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: database_url

    - name: LOG_LEVEL
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: log_level

    # Variables d'environnement depuis Secret
    - name: USERNAME
      valueFrom:
        secretKeyRef:
          name: app-secret
          key: username

    - name: PASSWORD
      valueFrom:
        secretKeyRef:
          name: app-secret
          key: password

    # Monter le ConfigMap comme volume
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config

    # Monter le Secret comme volume
    - name: secret-volume
      mountPath: /etc/secret
      readOnly: true

  volumes:
  - name: config-volume
    configMap:
      name: app-config

  - name: secret-volume
    secret:
      secretName: app-secret
```

**Exercice 7 : Configuration externalisée**

1. Créez le ConfigMap et le Secret
2. Créez le Pod qui les utilise
3. Vérifiez les variables d'environnement :
   ```bash
   kubectl exec configured-app -- env | grep -E "(DATABASE_URL|USERNAME)"
   ```
4. Vérifiez les fichiers montés :
   ```bash
   kubectl exec configured-app -- ls /etc/config
   kubectl exec configured-app -- cat /etc/config/app.conf
   kubectl exec configured-app -- ls /etc/secret
   ```

## Partie 6 : Labels et Selectors

### 6.1 Utilisation avancée des labels

Créer `12-labeled-resources.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    app: myapp
    tier: frontend
    environment: production
    version: v1.0.0
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
      tier: frontend
  template:
    metadata:
      labels:
        app: myapp
        tier: frontend
        environment: production
        version: v1.0.0
    spec:
      containers:
      - name: nginx
        image: nginx:alpine

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels:
    app: myapp
    tier: backend
    environment: production
    version: v1.0.0
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      tier: backend
  template:
    metadata:
      labels:
        app: myapp
        tier: backend
        environment: production
        version: v1.0.0
    spec:
      containers:
      - name: api
        image: httpd:alpine

---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
spec:
  selector:
    app: myapp
    tier: frontend
  ports:
  - port: 80
    targetPort: 80

---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  selector:
    app: myapp
    tier: backend
  ports:
  - port: 80
    targetPort: 80
```

**Exercice 8 : Manipulation avec les labels**

1. Créez toutes les ressources ci-dessus
2. Listez toutes les ressources de l'application :
   ```bash
   kubectl get all -l app=myapp
   ```
3. Listez uniquement le frontend :
   ```bash
   kubectl get all -l tier=frontend
   ```
4. Listez le backend :
   ```bash
   kubectl get all -l tier=backend
   ```
5. Filtrez par environnement :
   ```bash
   kubectl get all -l environment=production
   ```
6. Utilisez des sélecteurs multiples :
   ```bash
   kubectl get pods -l 'app=myapp,tier in (frontend,backend)'
   ```
7. Ajoutez un label à un pod existant :
   ```bash
   kubectl label pod <pod-name> tested=true
   ```

## Partie 7 : Namespaces et organisation

### 7.1 Création de namespaces

Créer `13-namespaces.yaml` :

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: development
  labels:
    environment: dev

---
apiVersion: v1
kind: Namespace
metadata:
  name: staging
  labels:
    environment: staging

---
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    environment: prod
```

### 7.2 Ressources dans un namespace spécifique

Créer `14-app-in-namespace.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: development  # Spécifier le namespace
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: nginx:alpine

---
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
  namespace: development
spec:
  selector:
    app: myapp
  ports:
  - port: 80
```

**Exercice 9 : Travailler avec les namespaces**

1. Créez les namespaces
2. Listez-les : `kubectl get namespaces`
3. Déployez l'application dans development
4. Listez les pods dans ce namespace :
   ```bash
   kubectl get pods -n development
   ```
5. Définissez development comme namespace par défaut :
   ```bash
   kubectl config set-context --current --namespace=development
   ```
6. Maintenant les commandes utilisent ce namespace automatiquement :
   ```bash
   kubectl get pods  # Affiche les pods de development
   ```

## Partie 8 : Exercices pratiques complets

### Exercice 10 : Application complète WordPress

Créez une application WordPress avec MySQL en écrivant les manifests pour :

1. **Namespace** : `wordpress-app`

2. **Secret** pour MySQL :
   - Nom : `mysql-secret`
   - Clés : `password` avec valeur `wordpress123`

3. **PersistentVolumeClaim** pour MySQL :
   ```yaml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: mysql-pvc
     namespace: wordpress-app
   spec:
     accessModes:
       - ReadWriteOnce
     resources:
       requests:
         storage: 1Gi
   ```

4. **Deployment MySQL** :
   - Image : `mysql:8.0`
   - 1 replica
   - Variables d'environnement : `MYSQL_ROOT_PASSWORD`, `MYSQL_DATABASE=wordpress`
   - Volume monté sur `/var/lib/mysql`
   - Port : 3306

5. **Service MySQL** :
   - Type : ClusterIP
   - Port : 3306

6. **PersistentVolumeClaim** pour WordPress

7. **Deployment WordPress** :
   - Image : `wordpress:latest`
   - 2 replicas
   - Variables d'environnement : `WORDPRESS_DB_HOST=mysql-service`, `WORDPRESS_DB_PASSWORD` (depuis le secret)
   - Port : 80

8. **Service WordPress** :
   - Type : NodePort
   - Port : 80

**Validation :**
```bash
kubectl apply -f wordpress-namespace.yaml
kubectl apply -f wordpress-secret.yaml
kubectl apply -f wordpress-mysql.yaml
kubectl apply -f wordpress-app.yaml

# Attendre que tout soit prêt
kubectl wait --for=condition=ready pod -l app=mysql -n wordpress-app --timeout=120s
kubectl wait --for=condition=ready pod -l app=wordpress -n wordpress-app --timeout=120s
```

**Accès à WordPress :**

Avec minikube :
```bash
minikube service wordpress-service -n wordpress-app
```

Avec kubeadm :
```bash
# Récupérer le NodePort et l'IP d'un nœud
NODE_PORT=$(kubectl get svc wordpress-service -n wordpress-app -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "WordPress accessible à : http://$NODE_IP:$NODE_PORT"
```

### Exercice 11 : Application avec microservices

Créez une stack applicative complète :

**Architecture :**
- Frontend (Nginx) → Backend API (Node.js) → Database (PostgreSQL) → Cache (Redis)

**Contraintes :**
- Utiliser des labels cohérents pour l'ensemble
- Le frontend doit être accessible via NodePort
- Backend, Database et Redis doivent être en ClusterIP
- Utiliser des ConfigMaps pour la configuration
- Utiliser des Secrets pour les mots de passe
- Définir des ressources requests/limits
- Ajouter des probes (liveness et readiness)
- Organiser dans un namespace dédié

**Structure suggérée :**
```
microservices/
├── 00-namespace.yaml
├── 01-configmaps.yaml
├── 02-secrets.yaml
├── 03-redis.yaml
├── 04-database.yaml
├── 05-backend.yaml
└── 06-frontend.yaml
```

### Exercice 12 : Job et CronJob

Créer `15-job.yaml` :

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: database-backup
spec:
  template:
    spec:
      containers:
      - name: backup
        image: busybox
        command: ["/bin/sh"]
        args:
          - -c
          - >
            echo "Starting backup..." &&
            echo "Backing up database..." &&
            sleep 10 &&
            echo "Backup completed successfully!"
      restartPolicy: OnFailure
  backoffLimit: 3
```

Créer `16-cronjob.yaml` :

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup-job
spec:
  schedule: "*/5 * * * *"  # Toutes les 5 minutes
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: cleanup
            image: busybox
            command: ["/bin/sh"]
            args:
              - -c
              - >
                echo "Running cleanup at $(date)" &&
                echo "Cleaning temporary files..." &&
                sleep 5 &&
                echo "Cleanup done!"
          restartPolicy: OnFailure
```

**Exercice :**
1. Créez le Job et surveillez son exécution : `kubectl get jobs -w`
2. Consultez les logs : `kubectl logs job/database-backup`
3. Créez le CronJob
4. Listez les CronJobs : `kubectl get cronjobs`
5. Attendez quelques minutes et listez les jobs créés : `kubectl get jobs`
6. Suspendez le CronJob : `kubectl patch cronjob cleanup-job -p '{"spec":{"suspend":true}}'`

## Partie 9 : Validation et bonnes pratiques

### 9.1 Outils de validation

**Validation avec kubectl :**
```bash
# Dry-run côté client
kubectl apply -f manifest.yaml --dry-run=client -o yaml

# Dry-run côté serveur (validation plus stricte)
kubectl apply -f manifest.yaml --dry-run=server

# Validation de la syntaxe YAML
kubectl apply -f manifest.yaml --validate=true

# Diff avant application
kubectl diff -f manifest.yaml
```

**Validation avec kubeval :**
```bash
# Installation
wget https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz
tar xf kubeval-linux-amd64.tar.gz
sudo mv kubeval /usr/local/bin

# Utilisation
kubeval manifest.yaml
kubeval *.yaml
```

**Validation avec kube-score :**
```bash
# Installation
wget https://github.com/zegl/kube-score/releases/download/v1.17.0/kube-score_1.17.0_linux_amd64
chmod +x kube-score_1.17.0_linux_amd64
sudo mv kube-score_1.17.0_linux_amd64 /usr/local/bin/kube-score

# Utilisation
kube-score score manifest.yaml
```

### 9.2 Bonnes pratiques

**1. Toujours spécifier les versions d'images**
```yaml
# Mauvais
image: nginx

# Bon
image: nginx:1.24.0
```

**2. Définir les ressources requests et limits**
```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "250m"
  limits:
    memory: "128Mi"
    cpu: "500m"
```

**3. Utiliser des labels cohérents**
```yaml
labels:
  app.kubernetes.io/name: myapp
  app.kubernetes.io/instance: myapp-prod
  app.kubernetes.io/version: "1.0.0"
  app.kubernetes.io/component: frontend
  app.kubernetes.io/part-of: ecommerce
  app.kubernetes.io/managed-by: kubectl
```

**4. Ajouter des health checks**
```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
```

**5. Utiliser des namespaces pour l'isolation**

**6. Ne jamais commiter les secrets en clair**

**7. Documenter avec des annotations**
```yaml
metadata:
  annotations:
    description: "Service principal pour l'API backend"
    contact: "team-backend@example.com"
    documentation: "https://docs.example.com/api"
```

### 9.3 Template de manifest complet

Créer `template-complete.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: complete-app
  namespace: production
  labels:
    app.kubernetes.io/name: complete-app
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/component: api
  annotations:
    description: "Template complet d'une application Kubernetes"
spec:
  replicas: 3

  # Stratégie de déploiement
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0

  selector:
    matchLabels:
      app.kubernetes.io/name: complete-app

  template:
    metadata:
      labels:
        app.kubernetes.io/name: complete-app
        app.kubernetes.io/version: "1.0.0"

    spec:
      # Contraintes de placement
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app.kubernetes.io/name
                  operator: In
                  values:
                  - complete-app
              topologyKey: kubernetes.io/hostname

      containers:
      - name: app
        image: nginx:1.24.0

        ports:
        - name: http
          containerPort: 80
          protocol: TCP

        # Variables d'environnement
        env:
        - name: LOG_LEVEL
          value: "info"
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: database_url
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secret
              key: password

        # Ressources
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"

        # Health checks
        livenessProbe:
          httpGet:
            path: /healthz
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3

        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3

        # Security context
        securityContext:
          runAsNonRoot: true
          runAsUser: 1000
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL

        # Volumes
        volumeMounts:
        - name: config
          mountPath: /etc/config
          readOnly: true
        - name: cache
          mountPath: /var/cache/nginx
        - name: run
          mountPath: /var/run

      volumes:
      - name: config
        configMap:
          name: app-config
      - name: cache
        emptyDir: {}
      - name: run
        emptyDir: {}
```

## Partie 10 : Tests et debugging

### 10.1 Commandes de test

```bash
# Appliquer et surveiller
kubectl apply -f manifest.yaml && kubectl get pods -w

# Tester la connectivité
kubectl run test-pod --image=busybox -it --rm -- wget -qO- http://service-name

# Port-forward pour tester localement
kubectl port-forward deployment/myapp 8080:80

# Exécuter des commandes dans un pod
kubectl exec -it pod-name -- /bin/sh

# Copier des fichiers depuis/vers un pod
kubectl cp pod-name:/path/to/file ./local-file
kubectl cp ./local-file pod-name:/path/to/file

# Afficher les événements
kubectl get events --sort-by='.lastTimestamp'

# Debug d'un pod qui ne démarre pas
kubectl describe pod pod-name
kubectl logs pod-name
kubectl logs pod-name --previous  # Logs du conteneur précédent
```

### 10.2 Exercice de debugging

**Fichier avec erreurs** `17-buggy-manifest.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: buggy-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: buggy
  template:
    metadata:
      labels:
        app: wrong-label  # Bug 1: Label ne correspond pas au selector
    spec:
      containers:
      - name: app
        image: ngin:latest  # Bug 2: Image incorrecte
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "1Gi"
            cpu: "2000m"  # Bug 3: Ressources trop élevées (unrealistic)
          limits:
            memory: "512Mi"  # Bug 4: Limit < Request
            cpu: "1000m"
```

**Mission :**
1. Essayez d'appliquer ce manifest
2. Identifiez toutes les erreurs
3. Corrigez-les une par une
4. Validez que l'application fonctionne

### 10.3 Checklist de validation

Avant d'appliquer un manifest, vérifiez :

- [ ] La syntaxe YAML est correcte (indentation, guillemets)
- [ ] Les labels du selector correspondent aux labels des pods
- [ ] Les versions d'images sont spécifiées
- [ ] Les ressources requests sont définies
- [ ] Les limits sont >= aux requests
- [ ] Les ports sont corrects
- [ ] Les noms de ConfigMaps/Secrets existent
- [ ] Les volumes montés correspondent aux volumes déclarés
- [ ] Les probes sont configurées si nécessaire
- [ ] Le namespace existe (si spécifié)
- [ ] Validation avec `--dry-run=server` réussit

## Solutions des exercices

<details>
<summary>Solution Exercice 10 : WordPress complet</summary>

**wordpress-namespace.yaml**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: wordpress-app
```

**wordpress-secret.yaml**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
  namespace: wordpress-app
type: Opaque
stringData:
  password: wordpress123
```

**wordpress-mysql.yaml**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
  namespace: wordpress-app
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  namespace: wordpress-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: password
        - name: MYSQL_DATABASE
          value: wordpress
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mysql-storage
          mountPath: /var/lib/mysql
      volumes:
      - name: mysql-storage
        persistentVolumeClaim:
          claimName: mysql-pvc

---
apiVersion: v1
kind: Service
metadata:
  name: mysql-service
  namespace: wordpress-app
spec:
  type: ClusterIP
  selector:
    app: mysql
  ports:
  - port: 3306
```

**wordpress-app.yaml**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wordpress-pvc
  namespace: wordpress-app
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  namespace: wordpress-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: wordpress
  template:
    metadata:
      labels:
        app: wordpress
    spec:
      containers:
      - name: wordpress
        image: wordpress:latest
        env:
        - name: WORDPRESS_DB_HOST
          value: mysql-service
        - name: WORDPRESS_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: password
        - name: WORDPRESS_DB_NAME
          value: wordpress
        ports:
        - containerPort: 80
        volumeMounts:
        - name: wordpress-storage
          mountPath: /var/www/html
      volumes:
      - name: wordpress-storage
        persistentVolumeClaim:
          claimName: wordpress-pvc

---
apiVersion: v1
kind: Service
metadata:
  name: wordpress-service
  namespace: wordpress-app
spec:
  type: NodePort
  selector:
    app: wordpress
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
```

**Déploiement :**
```bash
kubectl apply -f wordpress-namespace.yaml
kubectl apply -f wordpress-secret.yaml
kubectl apply -f wordpress-mysql.yaml
kubectl apply -f wordpress-app.yaml

# Attendre que tout soit prêt
kubectl wait --for=condition=ready pod -l app=mysql -n wordpress-app --timeout=120s
kubectl wait --for=condition=ready pod -l app=wordpress -n wordpress-app --timeout=120s

# Accéder à WordPress
# Avec minikube :
minikube service wordpress-service -n wordpress-app

# Avec kubeadm :
NODE_PORT=$(kubectl get svc wordpress-service -n wordpress-app -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "http://$NODE_IP:$NODE_PORT"
```
</details>

<details>
<summary>Solution Exercice de debugging</summary>

**Version corrigée** `17-buggy-manifest-fixed.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: buggy-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: buggy  # Correction 1: Doit correspondre au label du pod
  template:
    metadata:
      labels:
        app: buggy  # Correction 1: Label corrigé
    spec:
      containers:
      - name: app
        image: nginx:latest  # Correction 2: Nom d'image corrigé
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "128Mi"  # Correction 3: Ressources réalistes
            cpu: "100m"
          limits:
            memory: "256Mi"  # Correction 4: Limits > Requests
            cpu: "500m"
```
</details>

## Ressources complémentaires

### Documentation
- API Reference Kubernetes : https://kubernetes.io/docs/reference/kubernetes-api/
- YAML Specification : https://yaml.org/spec/
- Best Practices : https://kubernetes.io/docs/concepts/configuration/overview/

### Outils utiles
- **kubectl explain** : Documentation intégrée
- **kubeval** : Validation de manifests
- **kube-score** : Analyse de qualité
- **yamllint** : Linter YAML
- **VS Code** : Extension Kubernetes pour l'auto-complétion

### Exemples de manifests
```bash
# Obtenir le YAML d'une ressource existante
kubectl get deployment nginx -o yaml > example-deployment.yaml

# Générer un template
kubectl create deployment test --image=nginx --dry-run=client -o yaml
kubectl create service clusterip test --tcp=80:80 --dry-run=client -o yaml
```

## Points clés à retenir

1. **Structure** : Tous les manifests suivent apiVersion, kind, metadata, spec
2. **Labels** : Essentiels pour lier les ressources (Services → Pods)
3. **Validation** : Toujours utiliser `--dry-run` avant d'appliquer
4. **Ressources** : Définir requests et limits pour une meilleure gestion
5. **Health checks** : Liveness et readiness probes pour la fiabilité
6. **Configuration** : Externaliser avec ConfigMaps et Secrets
7. **Namespaces** : Organiser et isoler les ressources
8. **Documentation** : Utiliser labels et annotations pour la traçabilité
9. **Versions** : Toujours spécifier les versions d'images
10. **Tests** : Valider avec plusieurs outils avant de déployer en production

## Prochaines étapes

Après avoir maîtrisé les manifests, vous pouvez explorer :
- **Helm** : Gestionnaire de packages pour Kubernetes
- **Kustomize** : Personnalisation de manifests
- **GitOps** : Déploiement automatisé avec ArgoCD ou Flux
- **StatefulSets** : Pour les applications avec état
- **DaemonSets** : Déploiement sur tous les nœuds
- **Ingress** : Gestion avancée du trafic HTTP/HTTPS
- **Network Policies** : Sécurité réseau
- **RBAC** : Contrôle d'accès
