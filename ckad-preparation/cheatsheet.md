# CKAD Cheatsheet - Commandes Essentielles

## ⚙️ Configuration Initiale (À faire en premier à l'examen)

```bash
# Aliases essentiels
alias k=kubectl
export do="--dry-run=client -o yaml"
export now="--force --grace-period=0"

# Autocompletion
source <(kubectl completion bash)
complete -F __start_kubectl k

# Vérifier le contexte
k config get-contexts
k config use-context <context-name>

# Configurer vim
echo "set number" >> ~/.vimrc
echo "set tabstop=2" >> ~/.vimrc
echo "set shiftwidth=2" >> ~/.vimrc
echo "set expandtab" >> ~/.vimrc
```

## 📦 Pods

### Création rapide
```bash
# Pod simple
k run nginx --image=nginx

# Pod avec port
k run nginx --image=nginx --port=80

# Pod avec labels
k run nginx --image=nginx --labels="app=web,env=prod"

# Pod avec commande
k run busybox --image=busybox -- sleep 3600

# Pod avec variables d'environnement
k run nginx --image=nginx --env="VAR1=value1" --env="VAR2=value2"

# Générer YAML sans créer
k run nginx --image=nginx $do > pod.yaml

# Pod avec restart policy
k run nginx --image=nginx --restart=Never
k run nginx --image=nginx --restart=OnFailure
```

### Gestion
```bash
# Lister
k get pods
k get pods -o wide
k get pods --all-namespaces
k get pods -l app=nginx
k get pods --show-labels

# Détails
k describe pod <pod-name>

# Logs
k logs <pod-name>
k logs <pod-name> -f                    # Follow
k logs <pod-name> -c <container-name>   # Multi-container
k logs <pod-name> --previous            # Logs du container précédent

# Exécuter commande
k exec <pod-name> -- ls /
k exec -it <pod-name> -- /bin/sh
k exec <pod-name> -c <container> -- env

# Supprimer
k delete pod <pod-name>
k delete pod <pod-name> $now            # Force delete
k delete pods --all
```

## 🚀 Deployments

### Création
```bash
# Deployment simple
k create deploy nginx --image=nginx

# Avec replicas
k create deploy nginx --image=nginx --replicas=3

# Générer YAML
k create deploy nginx --image=nginx --replicas=3 $do > deploy.yaml

# Avec port
k create deploy nginx --image=nginx --port=80
```

### Gestion
```bash
# Lister
k get deployments
k get deploy
k get rs                # ReplicaSets
k get all               # Tout

# Scaler
k scale deploy nginx --replicas=5
k autoscale deploy nginx --min=2 --max=10 --cpu-percent=80

# Mettre à jour l'image
k set image deploy/nginx nginx=nginx:1.20
k set image deploy/nginx nginx=nginx:1.20 --record

# Rollout
k rollout status deploy/nginx
k rollout history deploy/nginx
k rollout undo deploy/nginx
k rollout undo deploy/nginx --to-revision=2
k rollout restart deploy/nginx

# Éditer
k edit deploy nginx
```

## 🌐 Services

### Création
```bash
# ClusterIP (par défaut)
k expose pod nginx --port=80 --target-port=80
k create service clusterip nginx --tcp=80:80

# NodePort
k expose pod nginx --port=80 --type=NodePort
k create service nodeport nginx --tcp=80:80 --node-port=30080

# LoadBalancer
k expose deploy nginx --port=80 --type=LoadBalancer

# Depuis Deployment
k expose deploy nginx --port=80 --target-port=80

# Générer YAML
k create service clusterip nginx --tcp=80:80 $do > svc.yaml
k expose deploy nginx --port=80 $do > svc.yaml
```

### Gestion
```bash
# Lister
k get svc
k get svc -o wide
k get endpoints

# Détails
k describe svc nginx

# Tester
k run tmp --image=nginx:alpine --rm -it -- curl http://service-name:80
```

## 🗂️ ConfigMaps

### Création
```bash
# Depuis literals
k create cm app-config --from-literal=key1=value1 --from-literal=key2=value2

# Depuis fichier
k create cm app-config --from-file=config.txt
k create cm app-config --from-file=app-config=/path/to/config.txt

# Depuis répertoire
k create cm app-config --from-file=/path/to/dir/

# Depuis env file
k create cm app-config --from-env-file=config.env

# Générer YAML
k create cm app-config --from-literal=key=value $do > cm.yaml
```

### Utilisation dans Pod
```yaml
# Comme variables d'environnement
env:
- name: KEY1
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: key1

# Toutes les clés comme env
envFrom:
- configMapRef:
    name: app-config

# Comme volume
volumes:
- name: config-volume
  configMap:
    name: app-config
volumeMounts:
- name: config-volume
  mountPath: /etc/config
```

### Gestion
```bash
# Lister
k get cm
k describe cm app-config
k get cm app-config -o yaml
```

## 🔐 Secrets

### Création
```bash
# Generic secret depuis literals
k create secret generic app-secret --from-literal=username=admin --from-literal=password=secret123

# Depuis fichier
k create secret generic app-secret --from-file=ssh-key=/path/to/key

# TLS secret
k create secret tls tls-secret --cert=/path/to/cert --key=/path/to/key

# Docker registry
k create secret docker-registry regcred \
  --docker-server=<server> \
  --docker-username=<user> \
  --docker-password=<pass> \
  --docker-email=<email>

# Générer YAML
k create secret generic app-secret --from-literal=password=secret $do > secret.yaml
```

### Utilisation dans Pod
```yaml
# Comme variables d'environnement
env:
- name: PASSWORD
  valueFrom:
    secretKeyRef:
      name: app-secret
      key: password

# Toutes les clés comme env
envFrom:
- secretRef:
    name: app-secret

# Comme volume
volumes:
- name: secret-volume
  secret:
    secretName: app-secret
volumeMounts:
- name: secret-volume
  mountPath: /etc/secrets
  readOnly: true
```

## 💉 Probes (Health Checks)

### Liveness Probe
```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 3
  periodSeconds: 3

# Ou avec exec
livenessProbe:
  exec:
    command:
    - cat
    - /tmp/healthy
  initialDelaySeconds: 5
  periodSeconds: 5

# Ou avec tcpSocket
livenessProbe:
  tcpSocket:
    port: 8080
  initialDelaySeconds: 15
  periodSeconds: 20
```

### Readiness Probe
```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
```

### Startup Probe
```yaml
startupProbe:
  httpGet:
    path: /startup
    port: 8080
  failureThreshold: 30
  periodSeconds: 10
```

## 📊 Resources (Requests & Limits)

```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "250m"
  limits:
    memory: "128Mi"
    cpu: "500m"
```

```bash
# Avec kubectl run
k run nginx --image=nginx --requests='cpu=100m,memory=256Mi' --limits='cpu=200m,memory=512Mi'
```

## 🎫 ResourceQuota

```bash
# Créer quota
k create quota my-quota --hard=pods=10,requests.cpu=4,requests.memory=4Gi,limits.cpu=10,limits.memory=10Gi
```

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 4Gi
    limits.cpu: "10"
    limits.memory: 10Gi
    pods: "10"
```

## 📏 LimitRange

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: limit-range
spec:
  limits:
  - default:
      memory: 512Mi
      cpu: 500m
    defaultRequest:
      memory: 256Mi
      cpu: 250m
    max:
      memory: 1Gi
      cpu: 1000m
    min:
      memory: 128Mi
      cpu: 100m
    type: Container
```

## 🔒 NetworkPolicy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
```

```bash
# Deny all ingress
k create networkpolicy deny-all --pod-selector='' --ingress
```

## 🔄 Jobs & CronJobs

### Job
```bash
# Job simple
k create job hello --image=busybox -- echo "Hello World"

# Générer YAML
k create job hello --image=busybox $do -- echo "Hello" > job.yaml
```

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi
spec:
  completions: 3
  parallelism: 2
  backoffLimit: 4
  template:
    spec:
      containers:
      - name: pi
        image: perl:5.34
        command: ["perl", "-Mbignum=bpi", "-wle", "print bpi(2000)"]
      restartPolicy: Never
```

### CronJob
```bash
# CronJob
k create cronjob hello --image=busybox --schedule="*/5 * * * *" -- echo "Hello"

# Générer YAML
k create cronjob hello --image=busybox --schedule="*/5 * * * *" $do -- echo "Hello" > cronjob.yaml
```

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hello
spec:
  schedule: "*/5 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: hello
            image: busybox
            command: ["/bin/sh", "-c", "date; echo Hello from Kubernetes"]
          restartPolicy: OnFailure
```

## 🏷️ Labels & Selectors

```bash
# Ajouter label
k label pod nginx env=prod
k label pod nginx tier=frontend

# Modifier label
k label pod nginx env=dev --overwrite

# Supprimer label
k label pod nginx env-

# Filtrer par label
k get pods -l env=prod
k get pods -l 'env in (prod,dev)'
k get pods -l env=prod,tier=frontend
k get pods -l env!=prod

# Annotations
k annotate pod nginx description="My nginx pod"
```

## 🧩 Multi-Container Patterns

### Sidecar Pattern
```yaml
spec:
  containers:
  - name: main-app
    image: nginx
  - name: sidecar-logger
    image: busybox
    command: ['/bin/sh', '-c', 'tail -f /var/log/app.log']
    volumeMounts:
    - name: logs
      mountPath: /var/log
  volumes:
  - name: logs
    emptyDir: {}
```

### Init Container
```yaml
spec:
  initContainers:
  - name: init-service
    image: busybox
    command: ['sh', '-c', 'until nslookup myservice; do sleep 2; done']
  containers:
  - name: main-app
    image: nginx
```

## 🔍 Debugging

```bash
# Events
k get events
k get events --sort-by=.metadata.creationTimestamp
k get events --field-selector type=Warning

# Describe (le plus important!)
k describe pod <pod-name>
k describe node <node-name>

# Logs
k logs <pod-name>
k logs <pod-name> --previous
k logs <pod-name> -c <container>
k logs -l app=nginx

# Exec
k exec -it <pod-name> -- /bin/sh
k exec <pod-name> -- env
k exec <pod-name> -- cat /etc/resolv.conf

# Port-forward (tester service)
k port-forward pod/<pod-name> 8080:80
k port-forward svc/<service-name> 8080:80

# Top (ressources)
k top nodes
k top pods
k top pods --containers

# Temporary pod for testing
k run tmp --image=busybox --rm -it -- /bin/sh
k run tmp --image=nginx:alpine --rm -it -- curl http://service:80
```

## 🎯 Contextes et Namespaces

```bash
# Contextes
k config get-contexts
k config current-context
k config use-context <context-name>

# Namespaces
k get ns
k create ns dev
k get pods -n dev
k get pods --all-namespaces
k get pods -A

# Changer namespace par défaut
k config set-context --current --namespace=dev

# Supprimer namespace
k delete ns dev
```

## 📝 YAML Manipulation rapide

### Générer puis éditer
```bash
# Pattern standard pour l'examen
k run nginx --image=nginx $do > pod.yaml
vim pod.yaml
k apply -f pod.yaml
k get pods
```

### Vim tips
```vim
# En mode normal
:set number          " Numéros de ligne
:set paste           " Mode paste
dd                   " Supprimer ligne
yy                   " Copier ligne
p                    " Coller
u                    " Undo
Ctrl+r               " Redo
/searchterm          " Chercher
:wq                  " Sauver et quitter
:q!                  " Quitter sans sauver

# Indentation
>>                   " Indenter à droite
<<                   " Indenter à gauche
V puis >>            " Indenter plusieurs lignes
```

## ⚡ Raccourcis Temps Réel

```bash
# Toujours vérifier après création
k apply -f file.yaml && k get pods

# Forcer suppression
k delete pod nginx $now

# Remplacer manifest
k replace -f file.yaml --force

# Édition rapide
k edit pod nginx

# Copier ressource existante
k get pod nginx -o yaml > new-pod.yaml
# Éditer new-pod.yaml (changer name, etc.)
k apply -f new-pod.yaml

# Dry-run pour validation
k apply -f file.yaml --dry-run=client
k apply -f file.yaml --dry-run=server

# Explain pour référence API
k explain pod.spec
k explain pod.spec.containers
k explain deployment.spec.strategy
```

## 🎓 Pattern type Examen

### Pattern 1 : Créer Pod avec ConfigMap
```bash
# 1. Créer ConfigMap
k create cm app-config --from-literal=DB_HOST=mysql --from-literal=DB_PORT=3306

# 2. Créer Pod YAML
k run app --image=nginx $do > pod.yaml

# 3. Éditer pour ajouter envFrom
vim pod.yaml
# Ajouter:
#   envFrom:
#   - configMapRef:
#       name: app-config

# 4. Appliquer et vérifier
k apply -f pod.yaml
k exec app -- env | grep DB
```

### Pattern 2 : Fix Pod qui crash
```bash
# 1. Voir l'erreur
k describe pod broken-pod

# 2. Vérifier logs
k logs broken-pod
k logs broken-pod --previous

# 3. Éditer ou recréer
k get pod broken-pod -o yaml > fix.yaml
vim fix.yaml
k replace -f fix.yaml --force
```

### Pattern 3 : Exposer Deployment
```bash
# 1. Créer Deployment
k create deploy web --image=nginx --replicas=3

# 2. Exposer comme Service
k expose deploy web --port=80 --type=NodePort

# 3. Vérifier
k get svc web
k get endpoints web
```

---

**💡 Astuce Finale** : Imprimez cette cheatsheet et gardez les patterns en tête. À l'examen, vitesse = `kubectl` + `--dry-run` + `vim` !
