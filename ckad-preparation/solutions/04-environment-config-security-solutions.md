# Solutions - Application Environment, Configuration and Security

## Exercice 1 : ConfigMap depuis Literals

### Solution rapide

```bash
# 1. Créer ConfigMap
k create cm app-config \
  --from-literal=DB_HOST=mysql \
  --from-literal=DB_PORT=3306 \
  --from-literal=APP_MODE=production

# 2. Créer Pod
k run app --image=busybox $do -- sleep 3600 > app.yaml
vim app.yaml  # Ajouter envFrom
```

### Pod avec envFrom

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: busybox
    image: busybox
    command: ["sleep", "3600"]
    envFrom:
    - configMapRef:
        name: app-config
```

### Vérification

```bash
k apply -f app.yaml
k exec app -- env | grep DB
# Output:
# DB_HOST=mysql
# DB_PORT=3306
# APP_MODE=production
```

### 💡 Explications

- **envFrom** : Charge TOUTES les clés du ConfigMap comme variables d'env
- Alternative : **env** avec `valueFrom` pour des clés spécifiques

---

## Exercice 2 : ConfigMap depuis Fichier

### Création du fichier

```bash
cat > app.properties <<EOF
server.port=8080
server.host=0.0.0.0
log.level=INFO
EOF
```

### ConfigMap

```bash
k create cm app-properties --from-file=app.properties
```

### Pod avec volume

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: config-file-pod
spec:
  containers:
  - name: app
    image: nginx:alpine
    volumeMounts:
    - name: config-volume
      mountPath: /config
  volumes:
  - name: config-volume
    configMap:
      name: app-properties
```

### Vérification

```bash
k apply -f config-file-pod.yaml
k exec config-file-pod -- cat /config/app.properties
k exec config-file-pod -- ls -la /config
```

### 💡 Explications

- Le ConfigMap est monté comme un répertoire
- Chaque clé devient un fichier
- Fichier = `/config/app.properties`

---

## Exercice 3 : Secret Générique

### Solution rapide

```bash
# 1. Créer Secret
k create secret generic db-secret \
  --from-literal=username=admin \
  --from-literal=password=SuperSecret123

# 2. Créer Pod
k run secure-app --image=nginx:alpine $do > secure-app.yaml
vim secure-app.yaml
```

### Pod complet

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    env:
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: username
    - name: DB_PASS
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: password
```

### Vérification

```bash
k apply -f secure-app.yaml
k exec secure-app -- env | grep DB_
# DB_USER=admin
# DB_PASS=SuperSecret123

# Voir le Secret (encodé en base64)
k get secret db-secret -o yaml
k get secret db-secret -o jsonpath='{.data.password}' | base64 -d
```

---

## Exercice 4 : Secret comme Volume

### Création des fichiers

```bash
echo "CERTIFICATE DATA" > tls.crt
echo "PRIVATE KEY DATA" > tls.key
```

### Secret

```bash
k create secret generic tls-secret --from-file=tls.crt --from-file=tls.key
```

### Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: tls-app
spec:
  containers:
  - name: app
    image: nginx:alpine
    volumeMounts:
    - name: tls-volume
      mountPath: /etc/tls
      readOnly: true
  volumes:
  - name: tls-volume
    secret:
      secretName: tls-secret
```

### Vérification

```bash
k apply -f tls-app.yaml
k exec tls-app -- ls -la /etc/tls
k exec tls-app -- cat /etc/tls/tls.crt
k exec tls-app -- cat /etc/tls/tls.key
```

### 💡 Explications

- **readOnly: true** : Bonne pratique de sécurité
- Les Secrets montés comme volumes sont automatiquement décodés de base64

---

## Exercice 5 : Resource Requests et Limits

### Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: resource-pod
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "256Mi"
        cpu: "200m"
```

### Vérification

```bash
k apply -f resource-pod.yaml
k describe pod resource-pod | grep -A 10 "Requests:"

# Output:
#   Requests:
#     cpu:     100m
#     memory:  128Mi
#   Limits:
#     cpu:     200m
#     memory:  256Mi
```

### 💡 Explications

- **requests** : Ressources garanties, utilisées pour le scheduling
- **limits** : Max de ressources que le Pod peut utiliser
- **m** : millicores (100m = 0.1 CPU)
- **Mi** : Mebibytes (128Mi ≈ 134 MB)

---

## Exercice 6 : ResourceQuota

### Namespace et Quota

```bash
# 1. Créer namespace
k create ns quota-test

# 2. Créer ResourceQuota
k create quota my-quota -n quota-test \
  --hard=pods=5,requests.cpu=2,requests.memory=2Gi,limits.cpu=10,limits.memory=10Gi
```

### Alternative YAML

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: my-quota
  namespace: quota-test
spec:
  hard:
    pods: "5"
    requests.cpu: "2"
    requests.memory: 2Gi
    limits.cpu: "10"
    limits.memory: 10Gi
```

### Test du quota

```bash
# Pod qui respecte le quota
k run pod1 -n quota-test --image=nginx \
  --requests='cpu=100m,memory=256Mi' \
  --limits='cpu=200m,memory=512Mi'

# Essayer de créer trop de Pods
for i in {2..6}; do
  k run pod$i -n quota-test --image=nginx \
    --requests='cpu=100m,memory=256Mi' \
    --limits='cpu=200m,memory=512Mi'
done

# Le 6ème Pod échouera avec:
# Error: exceeded quota
```

### Vérifier le quota

```bash
k describe quota my-quota -n quota-test
k get resourcequota -n quota-test
```

---

## Exercice 7 : LimitRange

### Namespace

```bash
k create ns limit-test
```

### LimitRange

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: limit-range
  namespace: limit-test
spec:
  limits:
  - default:
      memory: 256Mi
      cpu: 200m
    defaultRequest:
      memory: 128Mi
      cpu: 100m
    max:
      memory: 512Mi
      cpu: 500m
    min:
      memory: 64Mi
      cpu: 50m
    type: Container
```

### Test

```bash
k apply -f limitrange.yaml

# Créer Pod SANS spécifier de ressources
k run test -n limit-test --image=nginx

# Vérifier que les defaults sont appliqués
k describe pod test -n limit-test | grep -A 10 "Requests:"

# Output:
#   Requests:
#     cpu:     100m  (default)
#     memory:  128Mi (default)
#   Limits:
#     cpu:     200m  (default)
#     memory:  256Mi (default)
```

---

## Exercice 8 : SecurityContext - runAsUser

### Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
  containers:
  - name: busybox
    image: busybox
    command: ["sleep", "3600"]
```

### Vérification

```bash
k apply -f secure-pod.yaml
k exec secure-pod -- id

# Output:
# uid=1000 gid=3000 groups=3000
```

### 💡 Explications

- **runAsUser: 1000** : Exécute avec UID 1000 (non-root)
- **runAsGroup: 3000** : Groupe primaire GID 3000
- Bonne pratique : ne jamais exécuter en tant que root (UID 0)

---

## Exercice 9 : SecurityContext - Filesystem ReadOnly

### Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: readonly-pod
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: cache-volume
      mountPath: /var/cache/nginx
    - name: run-volume
      mountPath: /var/run
  volumes:
  - name: cache-volume
    emptyDir: {}
  - name: run-volume
    emptyDir: {}
```

### Vérification

```bash
k apply -f readonly-pod.yaml
k get pods readonly-pod

# Tester l'écriture (devrait échouer)
k exec readonly-pod -- touch /test.txt
# Error: Read-only file system

# Mais peut écrire dans les volumes montés
k exec readonly-pod -- touch /var/cache/nginx/test.txt
# Succès
```

### 💡 Explications

- **readOnlyRootFilesystem** : Le filesystem root est en lecture seule
- nginx a besoin d'écrire dans `/var/cache/nginx` et `/var/run`
- On monte des volumes `emptyDir` sur ces chemins

---

## Exercice 10 : SecurityContext - Capabilities

### Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cap-pod
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    securityContext:
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE
```

### 💡 Explications

- **drop: ALL** : Supprime toutes les capabilities
- **add: NET_BIND_SERVICE** : Permet de bind sur ports < 1024
- Principle of least privilege

### Capabilities communes

- `NET_BIND_SERVICE` : Bind sur ports privilégiés
- `SYS_TIME` : Modifier l'horloge système
- `NET_ADMIN` : Configuration réseau
- `CHOWN` : Changer propriétaire de fichiers

---

## Exercice 11 : ServiceAccount

### Solution rapide

```bash
# 1. Créer ServiceAccount
k create sa app-sa

# 2. Créer Pod
k run sa-pod --image=nginx:alpine $do > sa-pod.yaml
vim sa-pod.yaml
```

### Pod avec ServiceAccount

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sa-pod
spec:
  serviceAccountName: app-sa
  containers:
  - name: nginx
    image: nginx:alpine
```

### Vérification

```bash
k apply -f sa-pod.yaml

# Vérifier le ServiceAccount monté
k exec sa-pod -- ls /var/run/secrets/kubernetes.io/serviceaccount/
# Output:
# ca.crt
# namespace
# token

k exec sa-pod -- cat /var/run/secrets/kubernetes.io/serviceaccount/token
```

### 💡 Explications

- Chaque Pod a un ServiceAccount (par défaut: "default")
- Le ServiceAccount donne une identité au Pod
- Utilisé pour RBAC et authentification à l'API Kubernetes

---

## Exercice 12 : ConfigMap et Secret combinés

### ConfigMap

```bash
k create cm app-env \
  --from-literal=APP_NAME=MyApp \
  --from-literal=APP_VERSION=1.0.0
```

### Secret

```bash
k create secret generic app-creds --from-literal=api-key=secret123
```

### Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: full-config
spec:
  containers:
  - name: busybox
    image: busybox
    command: ["sleep", "3600"]
    envFrom:
    - configMapRef:
        name: app-env
    volumeMounts:
    - name: secret-volume
      mountPath: /secrets
  volumes:
  - name: secret-volume
    secret:
      secretName: app-creds
```

### Vérification

```bash
k apply -f full-config.yaml
k exec full-config -- env | grep APP
k exec full-config -- cat /secrets/api-key
```

---

## Exercice 13 : SecurityContext au niveau Pod et Container

### Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-security
spec:
  securityContext:
    fsGroup: 2000
    runAsUser: 1000
  containers:
  - name: nginx
    image: nginx:alpine
  - name: busybox
    image: busybox
    command: ["sleep", "3600"]
    securityContext:
      runAsUser: 3000
```

### Vérification

```bash
k apply -f multi-security.yaml
k exec multi-security -c nginx -- id
# uid=1000 (du Pod)

k exec multi-security -c busybox -- id
# uid=3000 (override du container)
```

### 💡 Explications

- SecurityContext au niveau Pod s'applique à tous les containers
- SecurityContext au niveau container override celui du Pod
- **fsGroup** : Tous les fichiers créés auront ce GID

---

## Exercice 14 : Immutable ConfigMap et Secret

### ConfigMap Immutable

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: immutable-config
data:
  key: value
immutable: true
```

### Secret Immutable

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: immutable-secret
type: Opaque
data:
  password: c2VjcmV0  # "secret" en base64
immutable: true
```

### Test

```bash
k apply -f immutable-config.yaml
k apply -f immutable-secret.yaml

# Essayer de modifier
k edit cm immutable-config
# Changer "value" par "newvalue" → Erreur

# Error from server: configmaps "immutable-config" is immutable
```

### 💡 Avantages

- Protection contre modifications accidentelles
- Performance : kubelet ne watch pas les changements
- Utilisez pour config qui ne doit jamais changer

---

## Exercice 15 : Variables d'environnement avec FieldRef

### Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: fieldref-pod
spec:
  containers:
  - name: busybox
    image: busybox
    command: ["sleep", "3600"]
    env:
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    - name: POD_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    - name: NODE_NAME
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
```

### Vérification

```bash
k apply -f fieldref-pod.yaml
k exec fieldref-pod -- env | grep POD
k exec fieldref-pod -- env | grep NODE

# Output:
# POD_NAME=fieldref-pod
# POD_NAMESPACE=default
# POD_IP=10.244.0.5
# NODE_NAME=minikube
```

### 💡 Champs disponibles

```yaml
fieldPath: metadata.name
fieldPath: metadata.namespace
fieldPath: metadata.labels['<KEY>']
fieldPath: metadata.annotations['<KEY>']
fieldPath: spec.nodeName
fieldPath: spec.serviceAccountName
fieldPath: status.podIP
fieldPath: status.hostIP
```

---

## 🚀 Patterns Rapides

### Pattern 1 : ConfigMap + Pod en 2 commandes

```bash
k create cm config --from-literal=key=value
k run app --image=nginx --env="KEY=$(k get cm config -o jsonpath='{.data.key}')"
```

### Pattern 2 : Secret + Deployment

```bash
k create secret generic creds --from-literal=pass=secret
k create deploy app --image=nginx $do | \
  sed '/containers:/a\        env:\n        - name: PASSWORD\n          valueFrom:\n            secretKeyRef:\n              name: creds\n              key: pass' | k apply -f -
```

### Pattern 3 : Debug SecurityContext

```bash
k exec <pod> -- id
k exec <pod> -- ps aux
k exec <pod> -- cat /proc/1/status | grep -i uid
```

---

## 📚 Ressources

- [ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Security Context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
- [Service Accounts](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)
