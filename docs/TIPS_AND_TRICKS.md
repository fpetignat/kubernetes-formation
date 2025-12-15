# Kubernetes Tips & Tricks 🚀

Ce guide compile les astuces, bonnes pratiques et techniques avancées pour être plus productif et efficace avec Kubernetes au quotidien.

## Table des matières

1. [Productivité et Configuration](#productivité-et-configuration)
2. [Astuces kubectl](#astuces-kubectl)
3. [Debugging et Troubleshooting](#debugging-et-troubleshooting)
4. [Gestion des Ressources](#gestion-des-ressources)
5. [Sécurité](#sécurité)
6. [Performance et Optimisation](#performance-et-optimisation)
7. [Patterns Avancés](#patterns-avancés)
8. [Outils Essentiels](#outils-essentiels)
9. [Astuces Minikube](#astuces-minikube)
10. [Tips pour la Production](#tips-pour-la-production)

---

## Productivité et Configuration

### Alias et Raccourcis Essentiels

```bash
# Ajouter à ~/.bashrc ou ~/.zshrc

# Alias kubectl de base
alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias kdel='kubectl delete'
alias kl='kubectl logs'
alias kex='kubectl exec -it'
alias ka='kubectl apply -f'

# Alias pour les ressources courantes
alias kgp='kubectl get pods'
alias kgd='kubectl get deployments'
alias kgs='kubectl get services'
alias kgn='kubectl get nodes'
alias kgns='kubectl get namespaces'
alias kga='kubectl get all'

# Alias avec options utiles
alias kgpw='kubectl get pods -o wide'
alias kgpa='kubectl get pods --all-namespaces'
alias kgpoy='kubectl get pods -o yaml'

# Shortcuts pour dry-run
export do="--dry-run=client -o yaml"
export now="--force --grace-period=0"

# Exemples d'utilisation
# k run nginx --image=nginx $do > pod.yaml
# k delete pod nginx $now
```

### Autocomplétion

```bash
# Bash
source <(kubectl completion bash)
echo 'source <(kubectl completion bash)' >>~/.bashrc
complete -o default -F __start_kubectl k

# Zsh
source <(kubectl completion zsh)
echo 'source <(kubectl completion zsh)' >>~/.zshrc
compdef __start_kubectl k

# Fish
kubectl completion fish | source
echo 'kubectl completion fish | source' >> ~/.config/fish/config.fish
```

### Configuration kubectl personnalisée

```bash
# Changer le namespace par défaut
kubectl config set-context --current --namespace=dev

# Créer un alias de contexte
kubectl config set-context dev --cluster=minikube --user=minikube --namespace=dev
kubectl config use-context dev

# Afficher la config sans les secrets
kubectl config view --minify

# Fusionner plusieurs kubeconfig
KUBECONFIG=~/.kube/config:~/.kube/config-cluster2 kubectl config view --flatten > ~/.kube/merged-config

# Variables d'environnement utiles
export KUBECONFIG=~/.kube/config
export KUBE_EDITOR=vim  # ou nano, code, etc.
```

### Fichier .vimrc optimisé pour YAML

```vim
" Ajouter à ~/.vimrc
set number              " Numéros de ligne
set tabstop=2          " Largeur des tabs
set shiftwidth=2       " Indentation
set expandtab          " Convertir tabs en espaces
set autoindent         " Auto-indentation
set smartindent        " Indentation intelligente
syntax on              " Coloration syntaxique
set paste              " Mode paste pour éviter auto-indent

" Raccourcis utiles
" >> pour indenter à droite
" << pour indenter à gauche
" V puis >> pour indenter plusieurs lignes
```

---

## Astuces kubectl

### Génération Rapide de YAML

```bash
# Pod simple
kubectl run nginx --image=nginx $do > pod.yaml

# Pod avec port et labels
kubectl run nginx --image=nginx --port=80 --labels="app=web,env=prod" $do > pod.yaml

# Deployment avec replicas
kubectl create deploy nginx --image=nginx --replicas=3 $do > deploy.yaml

# Service ClusterIP
kubectl create service clusterip my-svc --tcp=80:80 $do > svc.yaml

# Service NodePort
kubectl expose deployment nginx --port=80 --type=NodePort $do > svc.yaml

# ConfigMap depuis literals
kubectl create configmap app-config --from-literal=DB_HOST=mysql $do > cm.yaml

# Secret
kubectl create secret generic app-secret --from-literal=password=secret $do > secret.yaml

# Job
kubectl create job hello --image=busybox -- echo "Hello" $do > job.yaml

# CronJob
kubectl create cronjob hello --image=busybox --schedule="*/5 * * * *" -- echo "Hello" $do > cronjob.yaml
```

### Commandes Avancées

```bash
# Obtenir tous les pods qui ne sont pas Running
kubectl get pods --field-selector=status.phase!=Running

# Trier les pods par création
kubectl get pods --sort-by=.metadata.creationTimestamp

# Trier par nombre de restarts
kubectl get pods --sort-by=.status.containerStatuses[0].restartCount

# Obtenir les images utilisées
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}'

# Lister les pods avec leur node
kubectl get pods -o wide --sort-by=.spec.nodeName

# Obtenir tous les secrets décodés (attention en prod!)
kubectl get secrets -o json | jq '.items[] | {name: .metadata.name, data: .data | map_values(@base64d)}'

# Lister toutes les ressources dans un namespace
kubectl api-resources --verbs=list --namespaced -o name | xargs -n 1 kubectl get --show-kind --ignore-not-found -n <namespace>

# Compter les pods par namespace
kubectl get pods -A --no-headers | awk '{print $1}' | sort | uniq -c

# Trouver les pods sans limits
kubectl get pods -A -o json | jq '.items[] | select(.spec.containers[].resources.limits == null) | .metadata.name'
```

### JSONPath et Formatage

```bash
# Obtenir seulement le nom des pods
kubectl get pods -o jsonpath='{.items[*].metadata.name}'

# Pods avec leur IP
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\n"}{end}'

# Node capacity
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.capacity.cpu}{"\t"}{.status.capacity.memory}{"\n"}{end}'

# Custom columns
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName,IP:.status.podIP

# Secrets décodés
kubectl get secret my-secret -o jsonpath='{.data.password}' | base64 -d

# Obtenir les événements d'un pod
kubectl get events --field-selector involvedObject.name=pod-name --sort-by=.lastTimestamp
```

### Watch et Monitoring en Temps Réel

```bash
# Watch sur les pods
kubectl get pods -w

# Watch avec sortie wide
kubectl get pods -o wide -w

# Surveiller les events
kubectl get events -w

# Suivre le rollout
kubectl rollout status deployment/nginx -w

# Logs en temps réel avec label selector
kubectl logs -f -l app=nginx --all-containers=true

# Logs de tous les pods d'un deployment
kubectl logs -f deployment/nginx

# Combiner watch avec grep
kubectl get pods -w | grep --line-buffered "nginx"
```

---

## Debugging et Troubleshooting

### Diagnostic Rapide

```bash
# Le plus important : describe!
kubectl describe pod <pod-name>

# Vérifier les events récents
kubectl get events --sort-by=.metadata.creationTimestamp

# Events d'un namespace spécifique
kubectl get events -n <namespace> --sort-by=.lastTimestamp

# Warnings seulement
kubectl get events --field-selector type=Warning

# Logs du conteneur précédent (crashé)
kubectl logs <pod-name> --previous

# Logs de tous les conteneurs d'un pod
kubectl logs <pod-name> --all-containers=true

# Logs avec timestamps
kubectl logs <pod-name> --timestamps

# Dernières 100 lignes
kubectl logs <pod-name> --tail=100

# Logs depuis les 5 dernières minutes
kubectl logs <pod-name> --since=5m
```

### Pod Temporaire de Debug

```bash
# Pod busybox éphémère
kubectl run tmp --image=busybox --rm -it -- /bin/sh

# Pod avec network tools
kubectl run netshoot --image=nicolaka/netshoot --rm -it -- /bin/bash

# Pod curl pour tester les services
kubectl run curl --image=curlimages/curl --rm -it -- sh

# Tester un service interne
kubectl run tmp --image=nginx:alpine --rm -it -- curl http://my-service:80

# Debug avec alpine
kubectl run alpine --image=alpine --rm -it -- /bin/sh
```

### Debug de Réseau

```bash
# Tester la résolution DNS
kubectl run dnsutils --image=gcr.io/kubernetes-e2e-test-images/dnsutils:1.3 --rm -it -- nslookup kubernetes.default

# Tester la connectivité
kubectl run tmp --image=busybox --rm -it -- wget -O- http://my-service:80

# Debug réseau avancé
kubectl run netshoot --image=nicolaka/netshoot --rm -it -- /bin/bash
# Puis dans le pod :
# traceroute google.com
# tcpdump
# iperf3

# Vérifier les endpoints d'un service
kubectl get endpoints my-service

# Voir la config DNS d'un pod
kubectl exec <pod-name> -- cat /etc/resolv.conf

# Test de connectivité entre namespaces
kubectl run tmp -n namespace1 --image=busybox --rm -it -- wget -O- http://service.namespace2.svc.cluster.local
```

### Port-Forward et Proxy

```bash
# Port-forward simple
kubectl port-forward pod/nginx 8080:80

# Port-forward d'un service
kubectl port-forward service/nginx 8080:80

# Port-forward d'un deployment
kubectl port-forward deployment/nginx 8080:80

# Port-forward avec toutes les interfaces
kubectl port-forward --address 0.0.0.0 pod/nginx 8080:80

# Proxy vers l'API Kubernetes
kubectl proxy --port=8001

# Accéder à l'API via le proxy
# http://localhost:8001/api/v1/namespaces/default/pods
```

### Inspection de Ressources

```bash
# Vérifier la définition d'une ressource
kubectl explain pod
kubectl explain pod.spec
kubectl explain pod.spec.containers
kubectl explain deployment.spec.strategy

# Comparer un manifest avec l'état actuel
kubectl diff -f deployment.yaml

# Dry-run côté client (validation syntaxe)
kubectl apply -f deployment.yaml --dry-run=client

# Dry-run côté serveur (validation + admission)
kubectl apply -f deployment.yaml --dry-run=server

# Vérifier les permissions
kubectl auth can-i create deployments
kubectl auth can-i delete pods --as=user@example.com
kubectl auth can-i '*' '*' --all-namespaces
```

### Debug de Problèmes Courants

```bash
# Pod en CrashLoopBackOff
kubectl describe pod <pod-name>  # Voir les events
kubectl logs <pod-name> --previous  # Logs du crash
kubectl get pod <pod-name> -o yaml  # Config complète

# ImagePullBackOff
kubectl describe pod <pod-name>  # Vérifier l'erreur exacte
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[*].state.waiting.message}'

# Pending pods
kubectl describe pod <pod-name>  # Voir pourquoi pas schedulé
kubectl get events --field-selector involvedObject.name=<pod-name>

# Service ne route pas le trafic
kubectl get endpoints <service-name>  # Vérifier les endpoints
kubectl describe service <service-name>
kubectl get pods -l app=<label>  # Vérifier les labels

# Node NotReady
kubectl describe node <node-name>
kubectl get nodes -o wide
kubectl top nodes
```

---

## Gestion des Ressources

### Resource Requests et Limits

```bash
# Pod avec resources
kubectl run nginx --image=nginx \
  --requests='cpu=100m,memory=256Mi' \
  --limits='cpu=200m,memory=512Mi' \
  $do > pod.yaml

# Vérifier la consommation
kubectl top pods
kubectl top pods --containers
kubectl top nodes

# Pods sans limits (risqué!)
kubectl get pods -A -o json | \
  jq -r '.items[] | select(.spec.containers[].resources.limits == null) | "\(.metadata.namespace)/\(.metadata.name)"'

# Voir l'utilisation par namespace
kubectl top pods -A --sort-by=memory
kubectl top pods -A --sort-by=cpu
```

### LimitRange et ResourceQuota

```bash
# Créer un LimitRange
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
spec:
  limits:
  - default:
      memory: 512Mi
      cpu: 500m
    defaultRequest:
      memory: 256Mi
      cpu: 250m
    type: Container
EOF

# Créer un ResourceQuota
kubectl create quota my-quota \
  --hard=pods=10,requests.cpu=4,requests.memory=4Gi,limits.cpu=10,limits.memory=10Gi

# Vérifier les quotas
kubectl get resourcequota
kubectl describe resourcequota my-quota
```

### Auto-scaling

```bash
# HPA simple
kubectl autoscale deployment nginx --min=2 --max=10 --cpu-percent=80

# HPA avec metrics personnalisées
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nginx-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nginx
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 80
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
EOF

# Vérifier le HPA
kubectl get hpa
kubectl describe hpa nginx-hpa

# Vertical Pod Autoscaler (nécessite installation)
# Recommande les bonnes valeurs de requests/limits
```

---

## Sécurité

### Secrets et ConfigMaps Sécurisés

```bash
# Créer un secret depuis un fichier sans l'afficher
kubectl create secret generic db-creds \
  --from-file=username=./username.txt \
  --from-file=password=./password.txt

# Secret TLS
kubectl create secret tls tls-secret \
  --cert=path/to/cert.pem \
  --key=path/to/key.pem

# Docker registry secret
kubectl create secret docker-registry regcred \
  --docker-server=<registry-url> \
  --docker-username=<username> \
  --docker-password=<password> \
  --docker-email=<email>

# Sceller un secret (avec sealed-secrets)
# https://github.com/bitnami-labs/sealed-secrets
kubeseal --format=yaml < secret.yaml > sealed-secret.yaml

# Encoder/décoder base64
echo -n 'my-password' | base64
echo 'bXktcGFzc3dvcmQ=' | base64 -d

# Rotation des secrets
kubectl delete secret app-secret
kubectl create secret generic app-secret --from-literal=password=new-password
kubectl rollout restart deployment/app
```

### Security Context

```yaml
# Au niveau du Pod
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 2000
  seccompProfile:
    type: RuntimeDefault

# Au niveau du Container
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000
  capabilities:
    drop:
    - ALL
    add:
    - NET_BIND_SERVICE
```

### RBAC Rapide

```bash
# Créer un ServiceAccount
kubectl create serviceaccount app-sa

# Créer un Role
kubectl create role pod-reader \
  --verb=get,list,watch \
  --resource=pods

# Créer un RoleBinding
kubectl create rolebinding app-pod-reader \
  --role=pod-reader \
  --serviceaccount=default:app-sa

# ClusterRole
kubectl create clusterrole node-reader \
  --verb=get,list \
  --resource=nodes

# ClusterRoleBinding
kubectl create clusterrolebinding app-node-reader \
  --clusterrole=node-reader \
  --serviceaccount=default:app-sa

# Vérifier les permissions
kubectl auth can-i get pods --as=system:serviceaccount:default:app-sa
kubectl auth can-i create deployments --as=system:serviceaccount:default:app-sa

# Voir les permissions d'un ServiceAccount
kubectl describe clusterrolebinding | grep app-sa
```

### Network Policies

```bash
# Deny all ingress
kubectl create networkpolicy deny-all \
  --pod-selector='' \
  --ingress

# Allow from specific namespace
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-frontend
spec:
  podSelector:
    matchLabels:
      app: backend
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
EOF

# Tester les network policies
# Avant : kubectl run tmp --image=busybox --rm -it -- wget -O- http://backend:8080
# Après : devrait être bloqué si la policy est active
```

### Scan de Sécurité

```bash
# Scanner les images avec Trivy
trivy image nginx:latest
trivy image --severity HIGH,CRITICAL nginx:latest

# Scanner un cluster complet
trivy k8s --report summary cluster

# Scanner les manifests
trivy config deployment.yaml

# Audit de sécurité avec kube-bench
kube-bench run --targets master,node

# Audit avec kubeaudit
kubeaudit all

# Vérifier les Pod Security Standards
kubectl label namespace default pod-security.kubernetes.io/enforce=restricted
kubectl label namespace default pod-security.kubernetes.io/warn=restricted
```

---

## Performance et Optimisation

### Optimisation des Images

```bash
# Utiliser des images minimales
# ❌ FROM ubuntu:latest (80 MB+)
# ✅ FROM alpine:latest (~5 MB)
# ✅ FROM scratch (0 MB, pour binaires statiques)

# Multi-stage builds
FROM golang:1.21 AS builder
WORKDIR /app
COPY . .
RUN go build -o app

FROM alpine:latest
COPY --from=builder /app/app /app
CMD ["/app"]

# Layer caching : ordonnez les commandes du moins au plus changeant
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./     # Copier d'abord les deps
RUN npm install           # Install en cache si package.json inchangé
COPY . .                  # Code source change souvent
RUN npm run build
```

### Optimisation des Deployments

```yaml
# Strategy Rolling Update optimisée
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # 1 pod de plus pendant update
      maxUnavailable: 0  # Pas de downtime

  # PodDisruptionBudget pour la disponibilité
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: myapp

# Préférer les readiness probes
readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5

# Liveness probe plus tolérant
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3

# Resource limits appropriés
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

### Optimisation du Réseau

```bash
# Utiliser headless services pour la découverte
# Évite le load balancing quand non nécessaire
apiVersion: v1
kind: Service
metadata:
  name: db
spec:
  clusterIP: None  # Headless
  selector:
    app: db

# Utiliser des services de type appropriate
# ClusterIP : communication interne seulement
# NodePort : exposition basique
# LoadBalancer : production avec cloud provider

# DNS caching avec NodeLocal DNSCache
# Réduit la latence DNS de 50-80%

# Activer topology-aware routing (Kubernetes 1.21+)
service.kubernetes.io/topology-aware-hints: auto
```

### Optimisation du Stockage

```bash
# Utiliser des volumeClaimTemplates pour StatefulSets
# Permet un stockage dédié par pod

# Préférer les storageClass avec provisionnement dynamique
kubectl get storageclass

# Utiliser des PVC avec bonne accessMode
# ReadWriteOnce (RWO) : 1 node
# ReadOnlyMany (ROX) : plusieurs nodes en lecture
# ReadWriteMany (RWX) : plusieurs nodes en écriture (rare, coûteux)

# Expansion de volumes (si supporté)
kubectl patch pvc my-pvc -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'

# Snapshots pour backups rapides
kubectl get volumesnapshot
```

---

## Patterns Avancés

### Init Containers

```yaml
# Attendre qu'un service soit disponible
spec:
  initContainers:
  - name: wait-for-db
    image: busybox:1.36
    command: ['sh', '-c', 'until nslookup db-service; do echo waiting for db; sleep 2; done']

  # Précharger des données
  - name: data-loader
    image: busybox:1.36
    command: ['sh', '-c', 'wget -O /data/config.json http://config-server/config']
    volumeMounts:
    - name: data
      mountPath: /data

  containers:
  - name: app
    image: myapp:latest
    volumeMounts:
    - name: data
      mountPath: /data

  volumes:
  - name: data
    emptyDir: {}
```

### Sidecar Pattern

```yaml
# Log shipping sidecar
spec:
  containers:
  - name: app
    image: myapp:latest
    volumeMounts:
    - name: logs
      mountPath: /var/log/app

  - name: log-shipper
    image: fluent/fluent-bit:latest
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
      readOnly: true

  volumes:
  - name: logs
    emptyDir: {}

# Service mesh sidecar (Istio)
# Injecté automatiquement avec :
# kubectl label namespace default istio-injection=enabled
```

### Jobs et CronJobs

```bash
# Job avec retry
apiVersion: batch/v1
kind: Job
metadata:
  name: backup-job
spec:
  backoffLimit: 3  # Retry 3 fois
  completions: 1
  parallelism: 1
  template:
    spec:
      containers:
      - name: backup
        image: backup-tool:latest
      restartPolicy: OnFailure

# CronJob avec timezone
apiVersion: batch/v1
kind: CronJob
metadata:
  name: daily-backup
spec:
  schedule: "0 2 * * *"  # Tous les jours à 2h
  timeZone: "Europe/Paris"
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: backup-tool:latest
          restartPolicy: OnFailure

# Cleanup manuel des jobs
kubectl delete jobs --field-selector status.successful=1
kubectl delete jobs --field-selector status.failed=1
```

### StatefulSets

```yaml
# StatefulSet avec volumeClaimTemplate
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: mysql
  replicas: 3
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
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: "standard"
      resources:
        requests:
          storage: 10Gi

# Headless service pour StatefulSet
---
apiVersion: v1
kind: Service
metadata:
  name: mysql
spec:
  clusterIP: None
  selector:
    app: mysql
  ports:
  - port: 3306
```

---

## Outils Essentiels

### kubectl plugins (krew)

```bash
# Installer krew
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)

export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# Plugins utiles
kubectl krew install ctx        # Changer de contexte rapidement
kubectl krew install ns         # Changer de namespace rapidement
kubectl krew install tree       # Voir la hiérarchie des ressources
kubectl krew install tail       # Tail logs de plusieurs pods
kubectl krew install images     # Lister toutes les images
kubectl krew install outdated   # Trouver les images outdated
kubectl krew install doctor     # Diagnostics cluster
kubectl krew install resource-capacity  # Capacité des resources
kubectl krew install neat       # Nettoyer les yamls

# Utilisation
kubectl ctx                     # Lister les contextes
kubectl ctx minikube           # Changer de contexte
kubectl ns default             # Changer de namespace
kubectl tree deployment nginx  # Voir toutes les ressources liées
```

### k9s - Terminal UI

```bash
# Installer k9s
brew install derailed/k9s/k9s  # macOS
# ou télécharger depuis https://github.com/derailed/k9s/releases

# Lancer k9s
k9s

# Raccourcis dans k9s
# :pods     -> Voir les pods
# :deploy   -> Voir les deployments
# :svc      -> Voir les services
# /         -> Filtrer
# l         -> Logs
# d         -> Describe
# e         -> Edit
# Ctrl-d    -> Delete
# ?         -> Help
```

### stern - Multi-pod logs

```bash
# Installer stern
brew install stern  # macOS

# Logs de tous les pods avec label
stern -l app=nginx

# Logs de plusieurs namespaces
stern -n namespace1,namespace2 nginx

# Avec regex
stern "^nginx-"

# Depuis 5 minutes
stern nginx --since 5m

# Avec template de sortie
stern nginx --template '{{.PodName}} {{.Message}}'
```

### kubectx et kubens

```bash
# Installer
brew install kubectx  # macOS

# Changer de contexte
kubectx                    # Lister
kubectx minikube          # Changer
kubectx -                 # Contexte précédent

# Changer de namespace
kubens                    # Lister
kubens dev               # Changer
kubens -                 # Namespace précédent
```

### Autres outils utiles

```bash
# lens - Kubernetes IDE
# https://k8slens.dev/

# helm - Package manager
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# kustomize - Configuration management
kubectl apply -k ./kustomize/

# kubeval - Valider les manifests
kubeval deployment.yaml

# yamllint - Linter YAML
yamllint deployment.yaml

# kube-capacity - Voir la capacité
kube-capacity

# popeye - Scan du cluster
popeye

# kubent - Détecter les APIs deprecated
kubent
```

---

## Astuces Minikube

### Configuration Optimale

```bash
# Démarrer avec bonne config
minikube start --cpus=4 --memory=8192 --disk-size=50g --driver=docker

# Profils multiples
minikube start -p dev --cpus=2 --memory=4096
minikube start -p staging --cpus=4 --memory=8192
minikube profile list
minikube profile dev

# Addons essentiels
minikube addons enable metrics-server
minikube addons enable ingress
minikube addons enable dashboard
minikube addons enable registry
minikube addons enable storage-provisioner

# Config par défaut
minikube config set cpus 4
minikube config set memory 8192
minikube config set driver docker
```

### Utiliser le Docker de Minikube

```bash
# Pointer vers le Docker de minikube
eval $(minikube docker-env)

# Maintenant docker build va construire dans minikube
docker build -t myapp:latest .

# Plus besoin de push vers un registry!
kubectl run myapp --image=myapp:latest --image-pull-policy=Never

# Revenir au Docker local
eval $(minikube docker-env -u)
```

### Accès aux Services

```bash
# URL d'un service
minikube service myapp --url

# Ouvrir dans le browser
minikube service myapp

# Tunnel pour LoadBalancer
minikube tunnel  # Nécessite sudo

# Dashboard
minikube dashboard
minikube dashboard --url  # Juste l'URL
```

### Cache et Performance

```bash
# Cache des images
minikube cache add nginx:latest
minikube cache add mysql:8.0
minikube cache list

# Pause pour économiser des ressources
minikube pause
# ... faire autre chose ...
minikube unpause

# Snapshot (Docker driver seulement)
minikube pause
# Docker snapshot...
```

### Multi-node Local

```bash
# Cluster 3 nodes
minikube start --nodes=3

# Ajouter un node
minikube node add

# Lister les nodes
minikube node list

# SSH dans un node
minikube ssh
minikube ssh -n minikube-m02

# Supprimer un node
minikube node delete minikube-m03
```

---

## Tips pour la Production

### Pre-deployment Checklist

```bash
# ✅ Resource limits définis
kubectl get pods -A -o json | jq '.items[] | select(.spec.containers[].resources.limits == null)'

# ✅ Health checks configurés
# Vérifier que liveness et readiness probes sont définis

# ✅ Replicas multiples
kubectl get deployments -A -o jsonpath='{range .items[?(@.spec.replicas==1)]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}'

# ✅ PodDisruptionBudget
kubectl get pdb -A

# ✅ NetworkPolicies
kubectl get networkpolicies -A

# ✅ SecurityContext
# Vérifier runAsNonRoot, readOnlyRootFilesystem

# ✅ Resource quotas par namespace
kubectl get resourcequota -A

# ✅ Images scannées
trivy k8s --report summary cluster

# ✅ Backups configurés
# Vérifier velero ou autre solution de backup
```

### Monitoring et Alerting

```bash
# Metrics Server (minimum)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Prometheus Stack (recommandé)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack

# Alertes essentielles à configurer :
# - Pod CrashLoopBackOff
# - Node NotReady
# - High memory/CPU usage
# - Disk pressure
# - PVC nearly full
# - Certificate expiration
```

### Stratégies de Déploiement

```yaml
# Rolling Update (défaut)
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0

# Blue-Green (avec Argo Rollouts ou Flagger)
# Déployer nouvelle version à côté
# Switcher le service
# Supprimer l'ancienne version

# Canary (avec Argo Rollouts ou Flagger)
# Déployer 10% nouvelle version
# Monitorer
# Progressivement augmenter à 100%
```

### Backup et Disaster Recovery

```bash
# Velero pour backup complet
velero install --provider aws --bucket my-backup-bucket

# Backup d'un namespace
velero backup create my-backup --include-namespaces=production

# Restore
velero restore create --from-backup my-backup

# Backup etcd (clusters kubeadm)
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Backup manifests
kubectl get all --all-namespaces -o yaml > all-resources-backup.yaml
```

### GitOps

```bash
# ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Flux
flux bootstrap github \
  --owner=my-org \
  --repository=my-repo \
  --path=clusters/production

# Avantages GitOps :
# - Git comme source de vérité
# - Audit trail automatique
# - Rollback facile
# - Déploiement déclaratif
```

### Cost Optimization

```bash
# Identifier les ressources sous-utilisées
kubectl top pods -A --containers | sort -k 4 -n

# Vertical Pod Autoscaler (recommandations)
# Installe VPA puis :
kubectl describe vpa my-app-vpa

# Node autoscaling (cloud)
# GKE : Configure cluster autoscaler
# EKS : Configure CA dans aws-auth
# AKS : Configure VMSS autoscaling

# Utiliser spot/preemptible instances
# Avec node affinity et tolerations
nodeSelector:
  node.kubernetes.io/lifecycle: spot
```

---

## Bonnes Pratiques Générales

### Organisation des Manifests

```bash
# Structure recommandée
myapp/
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   └── kustomization.yaml
├── overlays/
│   ├── dev/
│   │   └── kustomization.yaml
│   ├── staging/
│   │   └── kustomization.yaml
│   └── prod/
│       └── kustomization.yaml
└── README.md
```

### Conventions de Nommage

```yaml
# Utiliser des noms descriptifs
# ✅ web-frontend-deployment
# ❌ deployment1

# Labels standards
labels:
  app.kubernetes.io/name: myapp
  app.kubernetes.io/instance: myapp-prod
  app.kubernetes.io/version: "1.0.0"
  app.kubernetes.io/component: frontend
  app.kubernetes.io/part-of: myplatform
  app.kubernetes.io/managed-by: helm

# Annotations utiles
annotations:
  description: "Frontend web application"
  owner: "team-frontend@company.com"
  pager-duty: "https://..."
  runbook: "https://wiki/runbooks/myapp"
```

### Documentation

```bash
# README par application
# Doit inclure :
# - Description
# - Prérequis
# - Installation
# - Configuration
# - Troubleshooting
# - Contacts

# Runbooks pour incidents
# - Symptômes
# - Diagnostic
# - Résolution
# - Prévention
```

---

## Ressources Complémentaires

### Documentation

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Kubernetes Best Practices](https://learnk8s.io/production-best-practices)

### Outils et Plugins

- [krew](https://krew.sigs.k8s.io/) - Plugin manager
- [k9s](https://k9scli.io/) - Terminal UI
- [stern](https://github.com/stern/stern) - Multi-pod logs
- [kubectx/kubens](https://github.com/ahmetb/kubectx) - Context/namespace switcher
- [lens](https://k8slens.dev/) - Kubernetes IDE

### Learning Resources

- [Kubernetes Patterns](https://k8spatterns.io/)
- [CKAD Preparation](../ckad-preparation/README.md)
- [Awesome Kubernetes](https://github.com/ramitsurana/awesome-kubernetes)

---

**💡 Astuce finale :** Bookmarkez cette page et revenez-y régulièrement. Les meilleures pratiques Kubernetes évoluent constamment !
