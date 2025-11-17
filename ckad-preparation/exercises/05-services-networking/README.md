# Exercices - Services and Networking (20%)

## Objectifs du domaine

- Comprendre et utiliser les Services (ClusterIP, NodePort, LoadBalancer)
- Créer et utiliser les Ingress
- Implémenter des NetworkPolicies
- Comprendre la connectivité réseau entre Pods

---

## Exercice 1 : Service ClusterIP

**Temps estimé : 6 minutes**

1. Créer un Deployment `web` avec :
   - Image: `nginx:alpine`
   - 3 replicas
   - Labels: `app=web`

2. Exposer le Deployment avec un Service ClusterIP nommé `web-svc` sur le port 80

3. Tester l'accès depuis un Pod temporaire avec curl

<details>
<summary>💡 Indice</summary>

```bash
k create deploy web --image=nginx:alpine --replicas=3
k expose deploy web --name=web-svc --port=80 --type=ClusterIP
k run tmp --image=busybox --rm -it -- wget -O- http://web-svc
```
</details>

---

## Exercice 2 : Service NodePort

**Temps estimé : 6 minutes**

1. Créer un Deployment `api` avec :
   - Image: `nginx:alpine`
   - 2 replicas
   - Labels: `app=api`, `tier=backend`

2. Créer un Service NodePort qui :
   - Expose le port 80 du container
   - NodePort: 30080
   - Nom: `api-nodeport`

3. Vérifier le service et les endpoints

<details>
<summary>💡 Indice</summary>

```bash
k create deploy api --image=nginx:alpine --replicas=2
k create service nodeport api-nodeport --tcp=80:80 --node-port=30080 $do > svc.yaml
# Éditer pour ajouter le bon selector
k apply -f svc.yaml
k get svc api-nodeport
k get endpoints api-nodeport
```
</details>

---

## Exercice 3 : Service avec Selector Personnalisé

**Temps estimé : 7 minutes**

1. Créer 3 Pods manuellement :
   - `pod-1` : labels `app=myapp`, `env=prod`
   - `pod-2` : labels `app=myapp`, `env=dev`
   - `pod-3` : labels `app=myapp`, `env=prod`
   - Tous utilisent l'image `nginx:alpine`

2. Créer un Service `prod-svc` qui ne sélectionne que les Pods avec `env=prod`

3. Vérifier que le Service a seulement 2 endpoints

<details>
<summary>💡 Indice</summary>

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

```bash
k get endpoints prod-svc
```
</details>

---

## Exercice 4 : Service Headless

**Temps estimé : 8 minutes**

1. Créer un Service Headless nommé `db-headless` avec :
   - `clusterIP: None`
   - Selector: `app=database`

2. Créer un StatefulSet (ou 2 Pods) avec label `app=database`

3. Faire un nslookup du service depuis un Pod pour voir tous les IPs des Pods

<details>
<summary>💡 Indice</summary>

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

```bash
k run tmp --image=busybox --rm -it -- nslookup db-headless
```
</details>

---

## Exercice 5 : NetworkPolicy - Deny All Ingress

**Temps estimé : 8 minutes**

1. Créer un namespace `secure`

2. Créer un Deployment `web` dans ce namespace avec 2 replicas (image: `nginx:alpine`)

3. Créer une NetworkPolicy qui deny tout le trafic ingress par défaut

4. Vérifier qu'on ne peut pas accéder aux Pods depuis un autre Pod

<details>
<summary>💡 Indice</summary>

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

Test :
```bash
k run tmp --image=busybox --rm -it -- wget --timeout=2 http://<pod-ip>
# Devrait timeout
```
</details>

---

## Exercice 6 : NetworkPolicy - Allow from Specific Pods

**Temps estimé : 12 minutes**

Dans le namespace `secure` :

1. Créer un Deployment `backend` avec label `app=backend` (image: `nginx:alpine`)

2. Créer un Deployment `frontend` avec label `app=frontend` (image: `busybox`, commande: `sleep 3600`)

3. Créer une NetworkPolicy qui :
   - S'applique aux Pods `app=backend`
   - Autorise le trafic ingress uniquement depuis les Pods `app=frontend`
   - Sur le port 80

4. Tester l'accès depuis frontend (devrait marcher) et depuis un autre Pod (devrait échouer)

<details>
<summary>💡 Indice</summary>

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
</details>

---

## Exercice 7 : NetworkPolicy - Allow from Specific Namespace

**Temps estimé : 10 minutes**

1. Créer deux namespaces : `app-ns` et `admin-ns`

2. Créer un Deployment `api` dans `app-ns` avec label `app=api`

3. Créer une NetworkPolicy dans `app-ns` qui :
   - S'applique aux Pods `app=api`
   - Autorise le trafic ingress uniquement depuis les Pods dans le namespace `admin-ns`

4. Tester depuis les deux namespaces

<details>
<summary>💡 Indice</summary>

```yaml
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        name: admin-ns
  ports:
  - protocol: TCP
    port: 80
```

Il faut labeller le namespace :
```bash
k label ns admin-ns name=admin-ns
```
</details>

---

## Exercice 8 : NetworkPolicy - Egress Rules

**Temps estimé : 10 minutes**

1. Créer un namespace `restricted`

2. Créer un Pod `app` (image: `busybox`, commande: `sleep 3600`)

3. Créer une NetworkPolicy qui :
   - S'applique à tous les Pods du namespace
   - Deny tout le trafic egress par défaut
   - Autorise uniquement le trafic egress vers le port 53 (DNS)

<details>
<summary>💡 Indice</summary>

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
</details>

---

## Exercice 9 : Service ExternalName

**Temps estimé : 6 minutes**

1. Créer un Service ExternalName nommé `external-db` qui pointe vers `database.example.com`

2. Tester la résolution DNS depuis un Pod

<details>
<summary>💡 Indice</summary>

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  type: ExternalName
  externalName: database.example.com
```

```bash
k run tmp --image=busybox --rm -it -- nslookup external-db
```
</details>

---

## Exercice 10 : Ingress Basique

**Temps estimé : 12 minutes**

1. Créer deux Deployments :
   - `app1` avec image `nginx:alpine`
   - `app2` avec image `nginx:alpine`

2. Exposer chacun avec un Service ClusterIP

3. Créer un Ingress qui route :
   - `/app1` → service `app1`
   - `/app2` → service `app2`
   - Host: `myapp.example.com`

<details>
<summary>💡 Indice</summary>

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
</details>

---

## Exercice 11 : Ingress avec TLS

**Temps estimé : 10 minutes**

1. Créer un Secret TLS nommé `tls-secret` (contenu fictif)

2. Créer un Service `web-svc` qui expose un Deployment

3. Créer un Ingress avec :
   - Host: `secure.example.com`
   - TLS activé avec le Secret `tls-secret`
   - Backend: `web-svc:80`

<details>
<summary>💡 Indice</summary>

```bash
k create secret tls tls-secret --cert=path/to/cert --key=path/to/key
```

```yaml
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
</details>

---

## Exercice 12 : NetworkPolicy - Combined Ingress and Egress

**Temps estimé : 15 minutes**

Créer un système trois-tiers :

1. **Frontend Pods** (`app=frontend`)
2. **Backend Pods** (`app=backend`)
3. **Database Pods** (`app=database`)

Créer des NetworkPolicies pour :
- Frontend peut parler au Backend sur port 8080
- Backend peut parler à Database sur port 5432
- Database n'accepte que le trafic du Backend
- Frontend n'a pas d'accès direct à Database

<details>
<summary>💡 Indice</summary>

Trois NetworkPolicies :

1. Frontend → Backend allowed
2. Backend → Database allowed
3. Database accepts only from Backend

Utilisez à la fois `ingress` et `egress` rules.
</details>

---

## Exercice 13 : Service avec Session Affinity

**Temps estimé : 7 minutes**

1. Créer un Deployment `sticky-app` avec 3 replicas

2. Créer un Service qui :
   - Expose le Deployment
   - A `sessionAffinity: ClientIP`
   - `sessionAffinityConfig.clientIP.timeoutSeconds: 300`

3. Comprendre l'effet sur la répartition de charge

<details>
<summary>💡 Indice</summary>

```yaml
spec:
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 300
```

Avec session affinity, les requêtes du même client IP vont toujours au même Pod.
</details>

---

## Exercice 14 : NetworkPolicy avec CIDR Blocks

**Temps estimé : 10 minutes**

Créer une NetworkPolicy qui :
- S'applique aux Pods `app=api`
- Autorise le trafic ingress uniquement depuis les IPs du range `192.168.1.0/24`
- Sur le port 8080

<details>
<summary>💡 Indice</summary>

```yaml
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
</details>

---

## Exercice 15 : DNS et Service Discovery

**Temps estimé : 8 minutes**

1. Créer un Service `my-service` dans le namespace `test-ns`

2. Depuis un Pod dans le même namespace, tester :
   - `my-service` (short name)
   - `my-service.test-ns` (avec namespace)
   - `my-service.test-ns.svc.cluster.local` (FQDN)

3. Depuis un Pod dans un autre namespace, tester l'accès

<details>
<summary>💡 Indice</summary>

```bash
k run tmp -n test-ns --image=busybox --rm -it -- nslookup my-service
k run tmp -n test-ns --image=busybox --rm -it -- nslookup my-service.test-ns
k run tmp -n other-ns --image=busybox --rm -it -- nslookup my-service.test-ns.svc.cluster.local
```

Le FQDN fonctionne depuis n'importe quel namespace.
</details>

---

## 🎯 Objectifs d'apprentissage

Après avoir complété ces exercices, vous devriez être capable de :

- ✅ Créer et utiliser des Services (ClusterIP, NodePort, LoadBalancer, ExternalName)
- ✅ Comprendre les Services headless
- ✅ Utiliser selectors et labels pour router le trafic
- ✅ Configurer session affinity
- ✅ Créer et configurer des Ingress (paths, hosts, TLS)
- ✅ Créer des NetworkPolicies (ingress, egress)
- ✅ Utiliser podSelector, namespaceSelector, ipBlock
- ✅ Comprendre le DNS Kubernetes et service discovery
- ✅ Déboguer les problèmes de connectivité réseau
- ✅ Implémenter une architecture réseau sécurisée

---

## 📚 Références

- [Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [Connecting Applications with Services](https://kubernetes.io/docs/tutorials/services/connect-applications-service/)

---

**💡 Conseil** : Les NetworkPolicies sont complexes. Dessinez des schémas pour visualiser les flux de trafic autorisés !
