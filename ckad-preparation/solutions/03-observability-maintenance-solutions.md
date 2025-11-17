# Solutions - Application Observability and Maintenance

## Exercice 1 : Liveness Probe HTTP

### Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-http
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 3
      periodSeconds: 3
```

### Vérification

```bash
k apply -f liveness-http.yaml
k get pods liveness-http
k describe pod liveness-http | grep -A 10 Liveness

# Le Pod devrait rester Running car nginx répond sur /
```

### 💡 Explications

- **httpGet** : Fait une requête HTTP GET
- **initialDelaySeconds: 3** : Attend 3s avant la première probe
- **periodSeconds: 3** : Vérifie toutes les 3s
- Si la probe échoue, Kubernetes redémarre le container

---

## Exercice 2 : Readiness Probe

### Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-ready
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
      containers:
      - name: nginx
        image: nginx:alpine
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
```

### Service

```bash
k expose deploy webapp-ready --port=80 --name=webapp-ready
```

### Vérification

```bash
k apply -f webapp-ready.yaml
k get pods -l app=webapp
k get endpoints webapp-ready

# Les endpoints ne contiennent que les Pods ready
k describe svc webapp-ready
```

### 💡 Explications

- **Readiness probe** : Détermine si le Pod peut recevoir du trafic
- Si la probe échoue, le Pod est retiré des endpoints du Service
- Le Pod n'est PAS redémarré (contrairement à liveness)

---

## Exercice 3 : Liveness Probe Exec

### Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-exec
spec:
  containers:
  - name: busybox
    image: busybox
    command: ['sh', '-c', 'touch /tmp/healthy; sleep 30; rm -f /tmp/healthy; sleep 600']
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5
```

### Observation

```bash
k apply -f liveness-exec.yaml
k get pods liveness-exec -w

# Après ~30 secondes, le fichier est supprimé
# La liveness probe échoue
# Le container redémarre (RESTARTS passe à 1, 2, 3...)
```

### Vérification du restart

```bash
k describe pod liveness-exec | grep -A 10 Events
# Vous verrez "Liveness probe failed" et "Container will be killed"
```

### 💡 Explications

- **exec probe** : Exécute une commande dans le container
- Exit code 0 = succès, autre = échec
- Simule une application qui devient "unhealthy" après un certain temps

---

## Exercice 4 : Liveness et Readiness combinées

### Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: probes-combined
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    livenessProbe:
      tcpSocket:
        port: 80
      initialDelaySeconds: 10
      periodSeconds: 5
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 3
```

### Vérification

```bash
k apply -f probes-combined.yaml
k get pods probes-combined
k describe pod probes-combined | grep -A 5 Liveness
k describe pod probes-combined | grep -A 5 Readiness
```

### 💡 Explications

- **tcpSocket** : Vérifie qu'un port est ouvert
- Les deux probes sont indépendantes
- Readiness vérifie plus fréquemment (tous les 3s vs 5s)

---

## Exercice 5 : Startup Probe

### Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: slow-start
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    startupProbe:
      httpGet:
        path: /
        port: 80
      failureThreshold: 30
      periodSeconds: 10
    livenessProbe:
      httpGet:
        path: /
        port: 80
      periodSeconds: 5
```

### 💡 Explications

- **startupProbe** : Utilisée pour les apps à démarrage lent
- Donne 300s (30 * 10) pour démarrer
- Une fois réussie, la liveness probe prend le relais
- La liveness probe ne démarre PAS tant que la startup probe n'a pas réussi

### Calcul du délai

- failureThreshold: 30
- periodSeconds: 10
- Délai max = 30 * 10 = 300 secondes

---

## Exercice 6 : Debugging - Pod CrashLoopBackOff

### Pod qui crash

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: crasher
spec:
  containers:
  - name: busybox
    image: busybox
    command: ['sh', '-c', 'echo Starting...; exit 1']
```

### Debug

```bash
k apply -f crasher.yaml
k get pods crasher -w
# STATUS: Running → Error → CrashLoopBackOff

# 1. Describe pour voir les events
k describe pod crasher
# Vous verrez: "Back-off restarting failed container"

# 2. Logs (container actuel)
k logs crasher
# Output: Starting...

# 3. Logs du container précédent
k logs crasher --previous
```

### Correction

```bash
k get pod crasher -o yaml > fix.yaml
vim fix.yaml
# Changer: command: ['sh', '-c', 'sleep 3600']
k delete pod crasher
k apply -f fix.yaml
```

### Alternative : replace --force

```bash
vim fix.yaml
k replace -f fix.yaml --force
```

---

## Exercice 7 : Logs Multi-Container

### Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-log
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'while true; do echo "App log"; sleep 5; done']
  - name: sidecar
    image: busybox
    command: ['sh', '-c', 'while true; do echo "Sidecar log"; sleep 3; done']
```

### Consultation des logs

```bash
k apply -f multi-log.yaml

# Logs du container app
k logs multi-log -c app

# Logs du container sidecar
k logs multi-log -c sidecar

# Suivre les logs en temps réel
k logs multi-log -c app -f

# Tous les containers (depuis k8s 1.26)
k logs multi-log --all-containers=true

# Dernières 10 lignes
k logs multi-log -c app --tail=10
```

---

## Exercice 8 : Events Debugging

### Pod avec image invalide

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: bad-image
spec:
  containers:
  - name: nginx
    image: nginx:doesnotexist
```

### Debug avec events

```bash
k apply -f bad-image.yaml

# 1. Events du Pod
k describe pod bad-image | grep -A 20 Events
# Output: "Failed to pull image", "ErrImagePull", "ImagePullBackOff"

# 2. Tous les events du namespace
k get events --sort-by=.metadata.creationTimestamp

# 3. Filtrer les warnings
k get events --field-selector type=Warning

# 4. Events liés au Pod
k get events --field-selector involvedObject.name=bad-image
```

### 💡 Explications

Events utiles pour :
- Image pull errors
- Scheduling problems
- Volume mount errors
- Resource quota exceeded

---

## Exercice 9 : Exec pour Debugging

### Pod à débugger

```bash
k run debug-pod --image=nginx:alpine
```

### Commandes de debug

```bash
# 1. Voir nginx.conf
k exec debug-pod -- cat /etc/nginx/nginx.conf

# 2. Lister les processus
k exec debug-pod -- ps aux

# 3. Variables d'environnement
k exec debug-pod -- env

# 4. Test réseau
k exec debug-pod -- wget -O- http://kubernetes.default.svc.cluster.local

# 5. Shell interactif
k exec -it debug-pod -- /bin/sh
```

### Debug réseau avancé

```bash
# Installer des outils de debug
k exec -it debug-pod -- sh
# Dans le Pod:
apk add --no-cache curl
apk add --no-cache bind-tools  # Pour nslookup, dig
curl http://kubernetes.default
nslookup kubernetes.default
```

---

## Exercice 10 : Port-Forward pour Testing

### Solution

```bash
# 1. Créer le Deployment
k create deploy test-app --image=nginx:alpine --replicas=2

# 2. Obtenir un Pod
POD=$(k get pods -l app=test-app -o jsonpath='{.items[0].metadata.name}')

# 3. Port-forward
k port-forward pod/$POD 8080:80

# Dans un autre terminal:
curl http://localhost:8080

# Alternative: port-forward depuis un service
k expose deploy test-app --port=80
k port-forward svc/test-app 8080:80
```

### 💡 Cas d'usage

- Tester un Service sans Ingress
- Accéder à une base de données pour debug
- Tester avant d'exposer publiquement

---

## Exercice 11 : Probe avec Custom Headers

### Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: custom-probe
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    readinessProbe:
      httpGet:
        path: /health
        port: 80
        httpHeaders:
        - name: X-Custom-Header
          value: HealthCheck
      initialDelaySeconds: 5
      periodSeconds: 10
```

### 💡 Explications

- Utile si votre endpoint de health check nécessite des headers spécifiques
- Par exemple: Authorization, API-Key, etc.

---

## Exercice 12 : Failure Threshold et Success Threshold

### Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: threshold-test
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 3
      failureThreshold: 3
      successThreshold: 2
```

### 💡 Explications

- **failureThreshold: 3** : Doit échouer 3 fois consécutives pour être "not ready"
- **successThreshold: 2** : Doit réussir 2 fois consécutives pour être "ready"
- `successThreshold > 1` uniquement pour readiness probe (pas liveness)

### Comportement

```
Check 1: ✓ (success count: 1/2)
Check 2: ✓ (success count: 2/2) → Pod devient Ready
Check 3: ✗ (failure count: 1/3)
Check 4: ✗ (failure count: 2/3)
Check 5: ✗ (failure count: 3/3) → Pod devient Not Ready
```

---

## Exercice 13 : Monitoring avec kubectl top

### Deployment avec ressources

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-hog
spec:
  replicas: 3
  selector:
    matchLabels:
      app: resource-hog
  template:
    metadata:
      labels:
        app: resource-hog
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
```

### Monitoring

```bash
k apply -f resource-hog.yaml

# Par node
k top nodes

# Par pod
k top pods

# Avec containers
k top pods --containers

# Filtrer par label
k top pods -l app=resource-hog

# Trier par CPU
k top pods --sort-by=cpu

# Trier par mémoire
k top pods --sort-by=memory
```

### ⚠️ Prérequis

Metrics Server doit être installé :
```bash
# Minikube
minikube addons enable metrics-server

# Cluster standard
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

---

## 🚀 Patterns de Debugging

### Pattern 1 : Pod ne démarre pas

```bash
k get pods
k describe pod <name>  # Voir Events
k logs <name>
k logs <name> --previous
```

### Pattern 2 : Pod CrashLoopBackOff

```bash
k logs <name> --previous
k describe pod <name>
k get events --field-selector involvedObject.name=<name>
```

### Pattern 3 : Service ne répond pas

```bash
k get svc
k get endpoints <service-name>
k describe svc <service-name>
k run tmp --image=busybox --rm -it -- wget -O- http://<service>
```

### Pattern 4 : Probe qui échoue

```bash
k describe pod <name> | grep -A 10 Events
k exec <name> -- curl http://localhost:<port><path>
k logs <name>
```

---

## 📚 Ressources

- [Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Debug Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/)
- [Debug Services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)
- [Logging](https://kubernetes.io/docs/concepts/cluster-administration/logging/)
