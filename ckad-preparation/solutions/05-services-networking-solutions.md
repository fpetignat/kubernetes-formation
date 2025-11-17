# Solutions - Services and Networking

## Exercice 1 : Service ClusterIP

### Solution rapide

```bash
# 1. Créer Deployment
k create deploy web --image=nginx:alpine --replicas=3

# 2. Exposer avec Service
k expose deploy web --name=web-svc --port=80 --type=ClusterIP

# 3. Tester
k run tmp --image=busybox --rm -it -- wget -O- http://web-svc
```

### Alternative YAML

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-svc
spec:
  type: ClusterIP
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
```

### Vérification

```bash
k get svc web-svc
k get endpoints web-svc
k describe svc web-svc
```

### 💡 Explications

- **ClusterIP** : IP interne au cluster uniquement
- Le Service load-balance entre les 3 Pods
- DNS automatique : `web-svc.default.svc.cluster.local`

---

## Exercice 2 : Service NodePort

### Solution rapide

```bash
# 1. Créer Deployment
k create deploy api --image=nginx:alpine --replicas=2
k label deploy api app=api tier=backend

# 2. Créer Service NodePort
k create service nodeport api-nodeport --tcp=80:80 --node-port=30080 $do > svc.yaml
vim svc.yaml  # Changer selector pour app=api
```

### Service NodePort

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api-nodeport
spec:
  type: NodePort
  selector:
    app: api
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
```

### Vérification

```bash
k apply -f svc.yaml
k get svc api-nodeport

# Tester via NodePort (minikube)
minikube service api-nodeport
# Ou
curl http://$(minikube ip):30080
```

### 💡 Explications

- **NodePort** : Expose le Service sur un port de chaque node
- Range NodePort : 30000-32767
- Utilisé pour accès externe sans LoadBalancer

---

## Exercice 3 : Service avec Selector Personnalisé

### Pods

```bash
# Pod 1
k run pod-1 --image=nginx:alpine --labels="app=myapp,env=prod"

# Pod 2
k run pod-2 --image=nginx:alpine --labels="app=myapp,env=dev"

# Pod 3
k run pod-3 --image=nginx:alpine --labels="app=myapp,env=prod"
```

### Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: prod-svc
spec:
  selector:
    app: myapp
    env: prod
  ports:
  - port: 80
    targetPort: 80
```

### Vérification

```bash
k apply -f prod-svc.yaml
k get endpoints prod-svc

# Devrait montrer seulement pod-1 et pod-3
k describe svc prod-svc
```

### 💡 Explications

- Le selector utilise un AND logique
- Seuls les Pods avec TOUS les labels matchent
- `env=dev` (pod-2) est exclu

---

## Exercice 4 : Service Headless

### Service Headless

```yaml
apiVersion: v1
kind: Service
metadata:
  name: db-headless
spec:
  clusterIP: None
  selector:
    app: database
  ports:
  - port: 3306
```

### Pods

```bash
# Créer 2 Pods avec label app=database
k run db-1 --image=nginx:alpine --labels="app=database"
k run db-2 --image=nginx:alpine --labels="app=database"
```

### Vérification

```bash
k apply -f db-headless.yaml

# DNS lookup
k run tmp --image=busybox --rm -it -- nslookup db-headless

# Output: Retourne les IPs des 2 Pods directement
# (pas une seule IP ClusterIP)
```

### 💡 Explications

- **clusterIP: None** = Headless Service
- Pas de load balancing
- DNS retourne toutes les IPs des Pods
- Utilisé pour StatefulSets, découverte de services

---

## Exercice 5 : NetworkPolicy - Deny All Ingress

### Namespace et Deployment

```bash
k create ns secure
k create deploy web -n secure --image=nginx:alpine --replicas=2
```

### NetworkPolicy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: secure
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

### Test

```bash
k apply -f deny-all.yaml

# Obtenir IP d'un Pod
POD_IP=$(k get pod -n secure -o jsonpath='{.items[0].status.podIP}')

# Essayer d'accéder (devrait timeout)
k run tmp --image=busybox --rm -it -- wget --timeout=2 http://$POD_IP
# Error: download timed out
```

### 💡 Explications

- **podSelector: {}** : S'applique à TOUS les Pods du namespace
- **policyTypes: [Ingress]** : Deny tout le trafic entrant
- Egress reste autorisé par défaut

---

## Exercice 6 : NetworkPolicy - Allow from Specific Pods

### Deployments

```bash
k create ns secure
k create deploy backend -n secure --image=nginx:alpine
k label deploy backend -n secure app=backend

k create deploy frontend -n secure --image=busybox --replicas=1 -- sleep 3600
k label deploy frontend -n secure app=frontend
```

### NetworkPolicy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
  namespace: secure
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 80
```

### Test

```bash
k apply -f allow-frontend.yaml

# Depuis frontend (devrait marcher)
BACKEND_IP=$(k get pod -n secure -l app=backend -o jsonpath='{.items[0].status.podIP}')
FRONTEND_POD=$(k get pod -n secure -l app=frontend -o jsonpath='{.items[0].metadata.name}')
k exec -n secure $FRONTEND_POD -- wget -O- http://$BACKEND_IP

# Depuis autre Pod (devrait échouer)
k run tmp -n secure --image=busybox --rm -it -- wget --timeout=2 http://$BACKEND_IP
```

### 💡 Explications

- Seuls les Pods avec `app=frontend` peuvent accéder au backend
- Sur le port 80 uniquement
- Autres Pods sont bloqués

---

## Exercice 7 : NetworkPolicy - Allow from Specific Namespace

### Namespaces et Deployments

```bash
k create ns app-ns
k create ns admin-ns

# Labeller le namespace
k label ns admin-ns name=admin-ns

# Deployment dans app-ns
k create deploy api -n app-ns --image=nginx:alpine
k label deploy api -n app-ns app=api
```

### NetworkPolicy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-admin-ns
  namespace: app-ns
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: admin-ns
    ports:
    - protocol: TCP
      port: 80
```

### Test

```bash
k apply -f allow-admin-ns.yaml

# Depuis admin-ns (devrait marcher)
API_IP=$(k get pod -n app-ns -l app=api -o jsonpath='{.items[0].status.podIP}')
k run tmp -n admin-ns --image=busybox --rm -it -- wget -O- http://$API_IP

# Depuis autre namespace (devrait échouer)
k run tmp -n default --image=busybox --rm -it -- wget --timeout=2 http://$API_IP
```

### ⚠️ Important

Il faut labeller le namespace ! `k label ns admin-ns name=admin-ns`

---

## Exercice 8 : NetworkPolicy - Egress Rules

### Namespace et Pod

```bash
k create ns restricted
k run app -n restricted --image=busybox -- sleep 3600
```

### NetworkPolicy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-only
  namespace: restricted
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: UDP
      port: 53
```

### Test

```bash
k apply -f allow-dns-only.yaml

# DNS devrait marcher
k exec -n restricted app -- nslookup kubernetes.default

# Mais pas HTTP
k exec -n restricted app -- wget --timeout=2 google.com
# Error: timeout
```

### 💡 Explications

- **policyTypes: [Egress]** : Contrôle le trafic sortant
- Autorise uniquement DNS (port 53 UDP)
- Tout autre trafic sortant est bloqué

---

## Exercice 9 : Service ExternalName

### Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  type: ExternalName
  externalName: database.example.com
```

### Test

```bash
k apply -f external-db.yaml
k run tmp --image=busybox --rm -it -- nslookup external-db

# Output: CNAME vers database.example.com
```

### 💡 Explications

- **ExternalName** : Crée un alias DNS CNAME
- Pas de proxy, pas de load balancing
- Utilisé pour référencer des services externes

---

## Exercice 10 : Ingress Basique

### Deployments et Services

```bash
# App1
k create deploy app1 --image=nginx:alpine
k expose deploy app1 --name=app1-svc --port=80

# App2
k create deploy app2 --image=nginx:alpine
k expose deploy app2 --name=app2-svc --port=80
```

### Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-app
spec:
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /app1
        pathType: Prefix
        backend:
          service:
            name: app1-svc
            port:
              number: 80
      - path: /app2
        pathType: Prefix
        backend:
          service:
            name: app2-svc
            port:
              number: 80
```

### Vérification

```bash
k apply -f ingress.yaml
k get ingress multi-app
k describe ingress multi-app
```

### Test (avec minikube)

```bash
minikube addons enable ingress
minikube tunnel  # Dans un autre terminal

# Obtenir l'IP de l'Ingress
INGRESS_IP=$(k get ingress multi-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Tester
curl -H "Host: myapp.example.com" http://$INGRESS_IP/app1
curl -H "Host: myapp.example.com" http://$INGRESS_IP/app2
```

---

## Exercice 11 : Ingress avec TLS

### Secret TLS

```bash
# Créer certificat auto-signé (pour test)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt -subj "/CN=secure.example.com"

k create secret tls tls-secret --cert=tls.crt --key=tls.key
```

### Ingress avec TLS

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
spec:
  tls:
  - hosts:
    - secure.example.com
    secretName: tls-secret
  rules:
  - host: secure.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-svc
            port:
              number: 80
```

### Test

```bash
k apply -f tls-ingress.yaml
curl -k -H "Host: secure.example.com" https://$INGRESS_IP
```

---

## Exercice 12 : NetworkPolicy - Combined Ingress and Egress

### Architecture 3-tiers

```bash
k create deploy frontend --image=nginx:alpine
k label deploy frontend app=frontend

k create deploy backend --image=nginx:alpine --port=8080
k label deploy backend app=backend

k create deploy database --image=nginx:alpine --port=5432
k label deploy database app=database
```

### NetworkPolicy Frontend → Backend

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-to-backend
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 8080
  - to:  # DNS
    - namespaceSelector: {}
    ports:
    - protocol: UDP
      port: 53
```

### NetworkPolicy Backend → Database

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-to-database
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
  - to:  # DNS
    - namespaceSelector: {}
    ports:
    - protocol: UDP
      port: 53
```

### NetworkPolicy Database Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-ingress
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 5432
```

### 💡 Explications

Architecture:
```
Frontend → Backend → Database
   ✓         ✓         ✓
   ✗ ←  →  ← ✗  →  ←  ✓
```

- Frontend peut appeler Backend (8080)
- Backend peut appeler Database (5432)
- Frontend NE PEUT PAS appeler Database directement

---

## Exercice 13 : Service avec Session Affinity

### Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: sticky-svc
spec:
  selector:
    app: sticky-app
  ports:
  - port: 80
    targetPort: 80
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 300
```

### Deployment

```bash
k create deploy sticky-app --image=nginx:alpine --replicas=3
k label deploy sticky-app app=sticky-app
```

### 💡 Explications

- **sessionAffinity: ClientIP** : Les requêtes du même IP vont au même Pod
- **timeoutSeconds: 300** : L'affinité dure 5 minutes
- Par défaut: load balancing round-robin

---

## Exercice 14 : NetworkPolicy avec CIDR Blocks

### NetworkPolicy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-cidr
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - ipBlock:
        cidr: 192.168.1.0/24
        except:
        - 192.168.1.10/32
    ports:
    - protocol: TCP
      port: 8080
```

### 💡 Explications

- **ipBlock** : Permet de filtrer par range d'IPs
- **except** : Exclut des IPs spécifiques du range
- Autorise 192.168.1.0/24 SAUF 192.168.1.10

---

## Exercice 15 : DNS et Service Discovery

### Service

```bash
k create ns test-ns
k create deploy my-service -n test-ns --image=nginx:alpine
k expose deploy my-service -n test-ns --port=80
```

### Tests DNS

```bash
# Depuis le même namespace
k run tmp -n test-ns --image=busybox --rm -it -- sh
# Dans le Pod:
nslookup my-service
# Output: my-service.test-ns.svc.cluster.local

# Avec namespace
nslookup my-service.test-ns

# FQDN complet
nslookup my-service.test-ns.svc.cluster.local
```

### Depuis autre namespace

```bash
k run tmp -n default --image=busybox --rm -it -- sh
# my-service ne marche PAS (pas dans le même namespace)
# my-service.test-ns marche
# my-service.test-ns.svc.cluster.local marche
```

### 💡 Format DNS

```
<service-name>.<namespace>.svc.cluster.local
```

Raccourcis depuis le même namespace:
- `<service-name>`
- `<service-name>.<namespace>`

Depuis autre namespace:
- `<service-name>.<namespace>`
- `<service-name>.<namespace>.svc.cluster.local`

---

## 🚀 Patterns Rapides

### Pattern 1 : Créer Service rapidement

```bash
# ClusterIP
k expose deploy <name> --port=80

# NodePort
k expose deploy <name> --type=NodePort --port=80

# LoadBalancer
k expose deploy <name> --type=LoadBalancer --port=80
```

### Pattern 2 : Debug NetworkPolicy

```bash
# 1. Vérifier labels
k get pods --show-labels

# 2. Test connectivité
k run tmp --image=busybox --rm -it -- wget --timeout=2 http://<pod-ip>

# 3. Voir NetworkPolicies
k get networkpolicies
k describe networkpolicy <name>
```

### Pattern 3 : Debug Service

```bash
k get svc <name>
k get endpoints <name>
k describe svc <name>

# Test DNS
k run tmp --image=busybox --rm -it -- nslookup <service-name>

# Test connectivité
k run tmp --image=busybox --rm -it -- wget -O- http://<service-name>
```

---

## 📚 Ressources

- [Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [DNS](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
