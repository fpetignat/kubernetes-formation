# TP5 - Sécurité et RBAC dans Kubernetes

## Objectifs du TP

À la fin de ce TP, vous serez capable de :
- Comprendre les principes de sécurité dans Kubernetes
- Créer et gérer des ServiceAccounts
- Implémenter RBAC (Role-Based Access Control)
- Configurer les Security Contexts et Pod Security Standards
- Mettre en place des Network Policies
- Gérer les Secrets de manière sécurisée
- Appliquer les bonnes pratiques de sécurité
- Auditer et sécuriser un cluster Kubernetes

## Prérequis

- Avoir complété les TP1, TP2, TP3 et TP4
- Un cluster minikube fonctionnel
- Connaissance des Pods, Deployments et Services
- Compréhension des concepts de réseau de base

## Partie 1 : Introduction à la sécurité Kubernetes

### 1.1 Les 4C de la sécurité Cloud Native

```
┌─────────────────────────────────────┐
│           Code                      │
├─────────────────────────────────────┤
│           Container                 │
├─────────────────────────────────────┤
│           Cluster                   │
├─────────────────────────────────────┤
│           Cloud/Infrastructure      │
└─────────────────────────────────────┘
```

1. **Cloud** : Sécurité de l'infrastructure
2. **Cluster** : Sécurité du cluster Kubernetes
3. **Container** : Sécurité des conteneurs
4. **Code** : Sécurité applicative

### 1.2 Principes de sécurité

- **Least Privilege** : Donner uniquement les permissions nécessaires
- **Defense in Depth** : Plusieurs couches de sécurité
- **Separation of Duties** : Séparation des rôles et responsabilités
- **Audit Logging** : Traçabilité de toutes les actions
- **Immutability** : Conteneurs immuables

### 1.3 Surface d'attaque Kubernetes

**Composants à sécuriser** :
- API Server
- etcd
- kubelet
- Container Runtime
- Network
- Workloads

## Partie 2 : ServiceAccounts

### 2.1 Qu'est-ce qu'un ServiceAccount ?

Un ServiceAccount fournit une identité pour les processus qui s'exécutent dans un Pod.

**Différence avec User Account** :
- **User Account** : Humains (administrateurs, développeurs)
- **Service Account** : Applications, pods, processus

### 2.2 ServiceAccount par défaut

```bash
# Voir les ServiceAccounts
kubectl get serviceaccounts

# Chaque namespace a un ServiceAccount 'default'
kubectl get sa -n default

# Décrire le ServiceAccount par défaut
kubectl describe sa default
```

### 2.3 Créer un ServiceAccount

Créer `01-serviceaccount.yaml` :

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
  namespace: default
```

**Exercice 1 : Créer et utiliser un ServiceAccount**

```bash
# Créer le ServiceAccount
kubectl apply -f 01-serviceaccount.yaml

# Vérifier
kubectl get sa my-app-sa
kubectl describe sa my-app-sa

# Voir le token secret associé (Kubernetes < 1.24)
kubectl get secrets

# Pour Kubernetes >= 1.24, créer un token manuellement
kubectl create token my-app-sa
```

### 2.4 Utiliser un ServiceAccount dans un Pod

Créer `02-pod-with-sa.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-sa
spec:
  serviceAccountName: my-app-sa
  containers:
  - name: app
    image: nginx:alpine
    command: ['sh', '-c', 'sleep 3600']
```

```bash
# Créer le pod
kubectl apply -f 02-pod-with-sa.yaml

# Vérifier le ServiceAccount utilisé
kubectl describe pod pod-with-sa | grep "Service Account"

# Accéder au pod et vérifier le token
kubectl exec -it pod-with-sa -- sh
# Dans le pod :
# ls /var/run/secrets/kubernetes.io/serviceaccount/
# cat /var/run/secrets/kubernetes.io/serviceaccount/token
# exit
```

## Partie 3 : RBAC (Role-Based Access Control)

### 3.1 Concepts RBAC

**4 types de ressources** :

1. **Role** : Permissions dans un namespace
2. **ClusterRole** : Permissions cluster-wide
3. **RoleBinding** : Lie un Role à un user/SA dans un namespace
4. **ClusterRoleBinding** : Lie un ClusterRole à un user/SA cluster-wide

```
User/ServiceAccount → RoleBinding → Role → Resources
```

### 3.2 Vérifier l'état RBAC

```bash
# RBAC est activé dans minikube par défaut
kubectl api-versions | grep rbac

# Voir les ClusterRoles existants
kubectl get clusterroles

# Voir les Roles dans le namespace default
kubectl get roles

# Voir les RoleBindings
kubectl get rolebindings
```

### 3.3 Créer un Role

Créer `03-role-pod-reader.yaml` :

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: default
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
```

**Verbs disponibles** :
- **get** : Lire une ressource spécifique
- **list** : Lister les ressources
- **watch** : Observer les changements
- **create** : Créer une ressource
- **update** : Mettre à jour une ressource
- **patch** : Modifier partiellement
- **delete** : Supprimer une ressource
- **deletecollection** : Supprimer plusieurs ressources

**Exercice 2 : Créer un Role**

```bash
# Créer le Role
kubectl apply -f 03-role-pod-reader.yaml

# Vérifier
kubectl get role pod-reader
kubectl describe role pod-reader
```

### 3.4 Créer un RoleBinding

Créer `04-rolebinding-pod-reader.yaml` :

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods-binding
  namespace: default
subjects:
- kind: ServiceAccount
  name: my-app-sa
  namespace: default
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

**Exercice 3 : Tester les permissions**

```bash
# Créer le RoleBinding
kubectl apply -f 04-rolebinding-pod-reader.yaml

# Tester avec kubectl auth can-i
kubectl auth can-i list pods --as=system:serviceaccount:default:my-app-sa
# Should return: yes

kubectl auth can-i create pods --as=system:serviceaccount:default:my-app-sa
# Should return: no

kubectl auth can-i delete pods --as=system:serviceaccount:default:my-app-sa
# Should return: no

# Tester depuis un pod
kubectl run test-permissions --image=alpine/k8s:1.28.3 --rm -it \
  --overrides='{"spec":{"serviceAccountName":"my-app-sa"}}' -- sh

# Dans le pod :
# kubectl get pods    # Should work
# kubectl get services  # Should fail (no permission)
# kubectl delete pod pod-with-sa  # Should fail
# exit
```

### 3.5 ClusterRole et ClusterRoleBinding

Créer `05-clusterrole-secret-reader.yaml` :

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: read-secrets-global
subjects:
- kind: ServiceAccount
  name: my-app-sa
  namespace: default
roleRef:
  kind: ClusterRole
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
```

```bash
# Appliquer
kubectl apply -f 05-clusterrole-secret-reader.yaml

# Tester
kubectl auth can-i list secrets --as=system:serviceaccount:default:my-app-sa
kubectl auth can-i list secrets -n kube-system --as=system:serviceaccount:default:my-app-sa
```

### 3.6 Exemple pratique : Role pour développeur

Créer `06-developer-role.yaml` :

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: developer-sa
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-role
  namespace: default
rules:
# Pods
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create"]
# Deployments
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
# Services
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list", "watch", "create", "update"]
# ConfigMaps et Secrets
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch", "create", "update"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: default
subjects:
- kind: ServiceAccount
  name: developer-sa
  namespace: default
roleRef:
  kind: Role
  name: developer-role
  apiGroup: rbac.authorization.k8s.io
```

**Exercice 4 : Tester le role développeur**

```bash
# Appliquer
kubectl apply -f 06-developer-role.yaml

# Tester les permissions
kubectl auth can-i create deployments --as=system:serviceaccount:default:developer-sa
kubectl auth can-i delete deployments --as=system:serviceaccount:default:developer-sa
kubectl auth can-i create secrets --as=system:serviceaccount:default:developer-sa
```

## Partie 4 : Security Context

### 4.1 Qu'est-ce qu'un Security Context ?

Le Security Context définit les paramètres de sécurité pour un Pod ou un Conteneur :
- User/Group ID
- Capabilities Linux
- SELinux
- Read-only filesystem
- Privilege escalation

### 4.2 Security Context au niveau Pod

Créer `07-pod-security-context.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-context-demo
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
  containers:
  - name: demo
    image: busybox
    command: ['sh', '-c', 'sleep 3600']
    volumeMounts:
    - name: demo-volume
      mountPath: /data/demo
  volumes:
  - name: demo-volume
    emptyDir: {}
```

**Exercice 5 : Tester le Security Context**

```bash
# Créer le pod
kubectl apply -f 07-pod-security-context.yaml

# Vérifier les permissions
kubectl exec -it security-context-demo -- sh
# Dans le pod :
# id    # Should show uid=1000 gid=3000
# cd /data/demo
# echo "test" > test.txt
# ls -l test.txt  # Should show group 2000
# exit
```

### 4.3 Security Context au niveau Conteneur

Créer `08-container-security-context.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-context-container
spec:
  containers:
  - name: secure-container
    image: nginx:alpine
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE
    volumeMounts:
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
  volumes:
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
```

**Exercice 6 : Conteneur sécurisé**

```bash
# Créer le pod
kubectl apply -f 08-container-security-context.yaml

# Vérifier
kubectl get pod security-context-container
kubectl describe pod security-context-container

# Tester le filesystem read-only
kubectl exec -it security-context-container -- sh
# Dans le pod :
# touch /test.txt  # Should fail: Read-only file system
# exit
```

### 4.4 Bonnes pratiques Security Context

Créer `09-best-practices-security.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        fsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: app
        image: nginx:alpine
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
            add:
            - NET_BIND_SERVICE
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: cache
          mountPath: /var/cache/nginx
        - name: run
          mountPath: /var/run
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
      volumes:
      - name: cache
        emptyDir: {}
      - name: run
        emptyDir: {}
```

## Partie 5 : Pod Security Standards

### 5.1 Trois niveaux de sécurité

Kubernetes définit trois standards de sécurité :

1. **Privileged** : Non restrictif, permissions maximales
2. **Baseline** : Prévention des escalades de privilèges connues
3. **Restricted** : Très restrictif, bonnes pratiques strictes

### 5.2 Pod Security Admission

Depuis Kubernetes 1.25, Pod Security Admission remplace Pod Security Policies.

**Modes d'application** :
- **enforce** : Rejeter les pods non conformes
- **audit** : Logger les violations
- **warn** : Avertir l'utilisateur

### 5.3 Appliquer Pod Security Standards

Créer `10-namespace-pss.yaml` :

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: secure-namespace
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

**Exercice 7 : Tester Pod Security Standards**

```bash
# Créer le namespace
kubectl apply -f 10-namespace-pss.yaml

# Tenter de créer un pod privileged (devrait échouer)
kubectl run privileged-pod --image=nginx --privileged -n secure-namespace
# Should fail with security policy violation

# Créer un pod conforme
kubectl apply -f 09-best-practices-security.yaml -n secure-namespace

# Vérifier
kubectl get pods -n secure-namespace
```

### 5.4 Niveaux de sécurité par namespace

Créer `11-namespace-levels.yaml` :

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: dev-namespace
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/warn: restricted
---
apiVersion: v1
kind: Namespace
metadata:
  name: prod-namespace
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

## Partie 6 : Network Policies

### 6.1 Qu'est-ce qu'une Network Policy ?

Les Network Policies contrôlent le trafic réseau entre les pods.

**Par défaut** :
- Tous les pods peuvent communiquer avec tous les pods
- Network Policies permettent de restreindre ce trafic

### 6.2 Activer Network Policies

```bash
# Dans minikube, utiliser le CNI Calico
minikube start --cni=calico

# Ou dans un cluster existant
minikube stop
minikube delete
minikube start --cni=calico --memory=4096

# Vérifier que Calico est installé
kubectl get pods -n kube-system | grep calico
```

### 6.3 Network Policy : Deny All

Créer `12-network-policy-deny-all.yaml` :

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

**Exercice 8 : Tester Deny All**

```bash
# Créer deux pods de test
kubectl run pod-a --image=nginx
kubectl run pod-b --image=busybox --command -- sleep 3600

# Vérifier la connectivité avant Network Policy
kubectl exec pod-b -- wget -O- --timeout=2 http://pod-a

# Appliquer la Network Policy
kubectl apply -f 12-network-policy-deny-all.yaml

# Tester à nouveau (devrait échouer)
kubectl exec pod-b -- wget -O- --timeout=2 http://pod-a
# Should timeout

# Supprimer pour les tests suivants
kubectl delete networkpolicy deny-all
```

### 6.4 Network Policy : Allow spécifique

Créer `13-network-policy-allow-specific.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
        tier: backend
    spec:
      containers:
      - name: backend
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        tier: frontend
    spec:
      containers:
      - name: frontend
        image: busybox
        command: ['sh', '-c', 'sleep 3600']
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-network-policy
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

**Exercice 9 : Tester Allow Specific**

```bash
# Appliquer
kubectl apply -f 13-network-policy-allow-specific.yaml

# Attendre que les pods soient prêts
kubectl wait --for=condition=ready pod -l app=backend --timeout=60s
kubectl wait --for=condition=ready pod -l app=frontend --timeout=60s

# Tester depuis frontend (devrait marcher)
kubectl exec -it deployment/frontend -- wget -O- --timeout=2 http://backend

# Créer un pod non autorisé
kubectl run unauthorized --image=busybox --command -- sleep 3600

# Tester depuis unauthorized (devrait échouer)
kubectl exec unauthorized -- wget -O- --timeout=2 http://backend
# Should timeout
```

### 6.5 Network Policy : Egress

Créer `14-network-policy-egress.yaml` :

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-egress
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Egress
  egress:
  # Autoriser DNS
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
  # Autoriser backend
  - to:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 80
```

### 6.6 Network Policy avancée

Créer `15-network-policy-advanced.yaml` :

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: multi-tier-network-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # Autoriser frontend
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    - namespaceSelector:
        matchLabels:
          project: myproject
    ports:
    - protocol: TCP
      port: 8080
  egress:
  # Autoriser database
  - to:
    - podSelector:
        matchLabels:
          tier: database
    ports:
    - protocol: TCP
      port: 5432
  # Autoriser DNS
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

## Partie 7 : Gestion sécurisée des Secrets

### 7.1 Secrets Kubernetes

```bash
# Créer un Secret de type Opaque
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password='S3cureP@ssw0rd'

# Voir les secrets
kubectl get secrets

# Décoder un secret
kubectl get secret my-secret -o jsonpath='{.data.username}' | base64 -d
```

### 7.2 Secrets dans les Pods

Créer `16-pod-with-secrets.yaml` :

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
stringData:
  db-username: "dbuser"
  db-password: "dbP@ssw0rd123"
  api-key: "sk-1234567890abcdef"
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-secrets
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'sleep 3600']
    env:
    # Secret comme variable d'environnement
    - name: DB_USERNAME
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: db-username
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: db-password
    # Secret monté comme fichier
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: app-secrets
```

**Exercice 10 : Utiliser les Secrets**

```bash
# Appliquer
kubectl apply -f 16-pod-with-secrets.yaml

# Vérifier les variables d'environnement
kubectl exec pod-with-secrets -- env | grep DB_

# Vérifier les fichiers montés
kubectl exec pod-with-secrets -- ls /etc/secrets
kubectl exec pod-with-secrets -- cat /etc/secrets/api-key
```

### 7.3 Secrets et RBAC

Créer `17-secret-rbac.yaml` :

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["app-secrets"]  # Limiter à un secret spécifique
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-secret-binding
subjects:
- kind: ServiceAccount
  name: app-sa
roleRef:
  kind: Role
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
```

### 7.4 Bonnes pratiques pour les Secrets

1. **Ne jamais commiter les secrets dans Git**
2. **Utiliser des outils de gestion des secrets**
   - HashiCorp Vault
   - AWS Secrets Manager
   - Azure Key Vault
   - External Secrets Operator
3. **Chiffrer les secrets au repos**
4. **Rotation régulière des secrets**
5. **Limiter l'accès avec RBAC**

Créer `18-sealed-secrets-example.yaml` :

```yaml
# Exemple avec Sealed Secrets (nécessite installation)
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: sealed-secret-example
  namespace: default
spec:
  encryptedData:
    password: AgBqF7V8h+RjT...  # Chiffré, peut être commité
    username: AgCUF3G9i+SkU...  # Chiffré, peut être commité
```

## Partie 8 : Audit et Logging

### 8.1 Audit Logs

Kubernetes peut logger toutes les requêtes API pour l'audit.

```bash
# Vérifier si l'audit est activé
kubectl get pods -n kube-system | grep kube-apiserver

# Dans minikube, les logs d'audit ne sont pas activés par défaut
# Pour activer (redémarre minikube) :
minikube start --extra-config=apiserver.audit-log-path=/var/log/audit.log \
  --extra-config=apiserver.audit-log-maxage=30
```

### 8.2 Auditer les accès RBAC

```bash
# Voir qui peut faire quoi
kubectl auth can-i --list

# Voir les permissions d'un ServiceAccount
kubectl auth can-i --list --as=system:serviceaccount:default:my-app-sa

# Identifier les ressources accessibles
kubectl auth can-i get pods --as=system:serviceaccount:default:my-app-sa
kubectl auth can-i delete pods --as=system:serviceaccount:default:my-app-sa
```

### 8.3 Audit avec kubectl-who-can

```bash
# Installer kubectl-who-can (optionnel)
# kubectl krew install who-can

# Exemples d'utilisation
# kubectl who-can create pods
# kubectl who-can delete secrets -n kube-system
```

## Partie 9 : Sécurité des images

### 9.1 Scanner les vulnérabilités

```bash
# Utiliser Trivy pour scanner les images
# Installation de Trivy
wget https://github.com/aquasecurity/trivy/releases/download/v0.48.0/trivy_0.48.0_Linux-64bit.tar.gz
tar zxvf trivy_0.48.0_Linux-64bit.tar.gz
sudo mv trivy /usr/local/bin/

# Scanner une image
trivy image nginx:alpine

# Scanner avec sévérité critique uniquement
trivy image --severity CRITICAL,HIGH nginx:alpine

# Scanner les images dans le cluster
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].image}' | \
  tr ' ' '\n' | sort -u | xargs -I {} trivy image {}
```

### 9.2 Image Pull Secrets

Créer `19-image-pull-secret.yaml` :

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: registry-credentials
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-docker-config>
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-with-registry
imagePullSecrets:
- name: registry-credentials
---
apiVersion: v1
kind: Pod
metadata:
  name: private-image-pod
spec:
  serviceAccountName: app-with-registry
  containers:
  - name: app
    image: private-registry.example.com/my-app:v1.0
```

### 9.3 Admission Controllers

**Admission Controllers** valident et modifient les requêtes avant leur persistance.

Exemples d'Admission Controllers :
- **PodSecurity** : Applique les Pod Security Standards
- **LimitRanger** : Applique les limites de ressources
- **ResourceQuota** : Applique les quotas
- **ImagePolicyWebhook** : Valide les images

```bash
# Voir les admission controllers activés
kubectl describe pod kube-apiserver -n kube-system | grep admission
```

### 9.4 Open Policy Agent (OPA) Gatekeeper

Créer `20-gatekeeper-constraint.yaml` :

```yaml
# Exemple de contrainte OPA Gatekeeper
# (Nécessite l'installation de Gatekeeper)
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: require-owner-label
spec:
  match:
    kinds:
    - apiGroups: ["apps"]
      kinds: ["Deployment"]
  parameters:
    labels:
    - key: "owner"
      allowedRegex: "^[a-zA-Z]+$"
```

## Partie 10 : Sécuriser l'API Server

### 10.1 Contrôle d'accès API

```bash
# Voir les endpoints API
kubectl api-resources

# Tester l'accès anonyme (devrait être désactivé)
curl -k https://$(minikube ip):8443/api/v1/namespaces

# Accéder avec authentification
kubectl config view --raw -o jsonpath='{.users[0].user.client-certificate-data}' | base64 -d > client.crt
kubectl config view --raw -o jsonpath='{.users[0].user.client-key-data}' | base64 -d > client.key

curl --cert client.crt --key client.key -k https://$(minikube ip):8443/api/v1/namespaces
```

### 10.2 Rate Limiting

Créer `21-resource-quota.yaml` :

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: default
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 10Gi
    limits.cpu: "20"
    limits.memory: 20Gi
    pods: "50"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: limit-range
  namespace: default
spec:
  limits:
  - max:
      cpu: "2"
      memory: 2Gi
    min:
      cpu: "100m"
      memory: 128Mi
    default:
      cpu: "500m"
      memory: 512Mi
    defaultRequest:
      cpu: "250m"
      memory: 256Mi
    type: Container
```

## Partie 11 : Bonnes pratiques de sécurité

### 11.1 Checklist de sécurité

**Infrastructure** :
- [ ] Chiffrer etcd au repos
- [ ] Activer l'audit logging
- [ ] Mettre à jour régulièrement Kubernetes
- [ ] Utiliser des versions stables
- [ ] Limiter l'accès au control plane

**RBAC** :
- [ ] Principe du moindre privilège
- [ ] ServiceAccount dédié par application
- [ ] Éviter ClusterRole si Role suffit
- [ ] Auditer régulièrement les permissions
- [ ] Pas d'utilisation du ServiceAccount default

**Pods** :
- [ ] runAsNonRoot: true
- [ ] readOnlyRootFilesystem: true
- [ ] allowPrivilegeEscalation: false
- [ ] Drop ALL capabilities
- [ ] Définir seccompProfile
- [ ] Resource limits définis

**Network** :
- [ ] Network Policies par défaut
- [ ] Isoler les namespaces
- [ ] Limiter l'exposition externe
- [ ] Utiliser TLS pour la communication inter-services

**Secrets** :
- [ ] Ne jamais hardcoder les secrets
- [ ] Utiliser un gestionnaire de secrets externe
- [ ] Chiffrer les secrets au repos
- [ ] Rotation régulière
- [ ] Limiter l'accès avec RBAC

**Images** :
- [ ] Scanner les vulnérabilités
- [ ] Utiliser des images de confiance
- [ ] Images minimales (alpine, distroless)
- [ ] Tags immutables (pas :latest)
- [ ] Registry privé avec authentification

### 11.2 Exemple complet : Application sécurisée

Créer `22-secure-application-complete.yaml` :

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: secure-app
  labels:
    pod-security.kubernetes.io/enforce: restricted
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: secure-app-sa
  namespace: secure-app
automountServiceAccountToken: false
---
apiVersion: v1
kind: Secret
metadata:
  name: app-config
  namespace: secure-app
type: Opaque
stringData:
  database-url: "postgresql://db:5432/myapp"
  api-key: "sk-production-key-12345"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-role
  namespace: secure-app
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-rolebinding
  namespace: secure-app
subjects:
- kind: ServiceAccount
  name: secure-app-sa
roleRef:
  kind: Role
  name: app-role
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
  namespace: secure-app
  labels:
    app: secure-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
    spec:
      serviceAccountName: secure-app-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        fsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: app
        image: nginx:1.25-alpine
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
            add:
            - NET_BIND_SERVICE
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: app-config
              key: database-url
        volumeMounts:
        - name: cache
          mountPath: /var/cache/nginx
        - name: run
          mountPath: /var/run
        - name: tmp
          mountPath: /tmp
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
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
      volumes:
      - name: cache
        emptyDir: {}
      - name: run
        emptyDir: {}
      - name: tmp
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: secure-app-service
  namespace: secure-app
spec:
  selector:
    app: secure-app
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: secure-app-network-policy
  namespace: secure-app
spec:
  podSelector:
    matchLabels:
      app: secure-app
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
  egress:
  # DNS
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
  # Database
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: app-quota
  namespace: secure-app
spec:
  hard:
    requests.cpu: "5"
    requests.memory: 5Gi
    limits.cpu: "10"
    limits.memory: 10Gi
    pods: "20"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: app-limits
  namespace: secure-app
spec:
  limits:
  - max:
      cpu: "1"
      memory: 1Gi
    min:
      cpu: "50m"
      memory: 64Mi
    type: Container
```

## Partie 12 : Exercices pratiques

### Exercice Final 1 : Créer un environnement multi-tenant

**Objectif** : Créer deux namespaces isolés avec des équipes différentes

```bash
# Créer deux namespaces
kubectl create namespace team-a
kubectl create namespace team-b

# Créer des ServiceAccounts
kubectl create sa team-a-sa -n team-a
kubectl create sa team-b-sa -n team-b

# Créer des Roles permettant de gérer leurs ressources
# Créer des RoleBindings
# Appliquer des Network Policies pour isoler les namespaces
# Appliquer des ResourceQuotas

# Tester l'isolation
```

**Mission** : Aucune équipe ne doit pouvoir accéder aux ressources de l'autre.

### Exercice Final 2 : Audit de sécurité

**Scénario** : Voici un déploiement non sécurisé

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: insecure-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: insecure
  template:
    metadata:
      labels:
        app: insecure
    spec:
      containers:
      - name: app
        image: nginx:latest
        ports:
        - containerPort: 80
```

**Mission** :
1. Identifier tous les problèmes de sécurité
2. Corriger le déploiement
3. Appliquer toutes les bonnes pratiques

**Indices des problèmes** :
- Image :latest (non immutable)
- Pas de SecurityContext
- Pas de ServiceAccount dédié
- Pas de limites de ressources
- Root user
- Filesystem writable
- Capabilities non limitées

### Exercice Final 3 : Sécuriser une application web

**Architecture** :
- Frontend (React)
- Backend API (Node.js)
- Database (PostgreSQL)

**Mission** :
1. Créer des ServiceAccounts pour chaque composant
2. Définir des Roles RBAC appropriés
3. Configurer des Security Contexts stricts
4. Implémenter des Network Policies
5. Gérer les secrets de manière sécurisée
6. Appliquer les Pod Security Standards

## Partie 13 : Nettoyage

```bash
# Supprimer les pods de test
kubectl delete pod pod-a pod-b pod-with-sa security-context-demo \
  security-context-container pod-with-secrets unauthorized test-permissions

# Supprimer les déploiements
kubectl delete deployment backend frontend secure-app buggy-app

# Supprimer les services
kubectl delete service backend

# Supprimer les Network Policies
kubectl delete networkpolicy --all

# Supprimer les Roles et RoleBindings
kubectl delete role --all
kubectl delete rolebinding --all

# Supprimer les ServiceAccounts personnalisés
kubectl delete sa my-app-sa developer-sa app-sa

# Supprimer les namespaces de test
kubectl delete namespace secure-namespace dev-namespace prod-namespace secure-app

# Supprimer les secrets de test
kubectl delete secret my-secret app-secrets

# Vérifier
kubectl get all
kubectl get networkpolicies
kubectl get roles
kubectl get rolebindings
```

## Résumé

Dans ce TP, vous avez appris à :

- Créer et gérer des ServiceAccounts
- Implémenter RBAC avec Roles, ClusterRoles et Bindings
- Configurer des Security Contexts pour les Pods et Conteneurs
- Appliquer les Pod Security Standards
- Mettre en place des Network Policies
- Gérer les Secrets de manière sécurisée
- Scanner les vulnérabilités des images
- Auditer les permissions RBAC
- Appliquer les bonnes pratiques de sécurité Kubernetes

### Concepts clés

- **ServiceAccount** : Identité pour les processus dans les pods
- **RBAC** : Contrôle d'accès basé sur les rôles
- **Security Context** : Configuration de sécurité des pods/conteneurs
- **Network Policy** : Firewall entre les pods
- **Pod Security Standards** : Niveaux de sécurité (privileged, baseline, restricted)
- **Secrets** : Stockage sécurisé des données sensibles
- **Least Privilege** : Principe du moindre privilège
- **Defense in Depth** : Sécurité en profondeur

## Ressources complémentaires

### Documentation officielle

- [Kubernetes Security](https://kubernetes.io/docs/concepts/security/)
- [RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)

### Guides de sécurité

- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [NSA/CISA Kubernetes Hardening Guide](https://media.defense.gov/2022/Aug/29/2003066362/-1/-1/0/CTR_KUBERNETES_HARDENING_GUIDANCE_1.2_20220829.PDF)
- [OWASP Kubernetes Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Kubernetes_Security_Cheat_Sheet.html)

### Outils de sécurité

- **Trivy** : Scanner de vulnérabilités
- **Falco** : Détection d'anomalies runtime
- **OPA Gatekeeper** : Policy enforcement
- **Kube-bench** : Audit CIS Benchmark
- **Kubesec** : Analyse de sécurité des manifests
- **Vault** : Gestion des secrets
- **Sealed Secrets** : Chiffrement des secrets pour Git
- **External Secrets Operator** : Synchronisation avec secret managers

### Certifications

- **Certified Kubernetes Security Specialist (CKS)**
- **Certified Kubernetes Administrator (CKA)**

## Prochaines étapes

Félicitations ! Vous maîtrisez maintenant la sécurité Kubernetes.

Pour aller plus loin :
- **TP6** (à venir) : Mise en production et CI/CD
- **Helm** : Gestionnaire de packages
- **GitOps** : ArgoCD, FluxCD
- **Service Mesh** : Istio, Linkerd (sécurité mTLS)
- **Policy as Code** : OPA, Kyverno

## Questions de révision

1. Quelle est la différence entre un Role et un ClusterRole ?
2. Quels sont les trois niveaux de Pod Security Standards ?
3. Pourquoi utiliser runAsNonRoot: true ?
4. Comment fonctionne une Network Policy ?
5. Quelle est la différence entre Secret et ConfigMap ?
6. Qu'est-ce que le principe du moindre privilège ?
7. Comment auditer les permissions RBAC d'un ServiceAccount ?
8. Pourquoi readOnlyRootFilesystem est-il recommandé ?
9. Qu'est-ce qu'un Admission Controller ?
10. Comment sécuriser les secrets au repos ?

## Solutions des questions

<details>
<summary>Cliquez pour voir les réponses</summary>

1. **Role** : Permissions dans un namespace spécifique. **ClusterRole** : Permissions cluster-wide (tous les namespaces).

2. Les trois niveaux sont : **Privileged** (pas de restrictions), **Baseline** (prévient les escalades connues), **Restricted** (très restrictif, bonnes pratiques strictes).

3. **runAsNonRoot: true** empêche l'exécution en tant que root (UID 0), réduisant les risques en cas de compromission du conteneur.

4. Une **Network Policy** fonctionne comme un firewall pour les pods. Elle définit quels pods peuvent communiquer avec quels autres pods en utilisant des sélecteurs de labels.

5. **Secret** : Données sensibles (mots de passe, tokens), encodées en base64, peuvent être chiffrées au repos. **ConfigMap** : Configuration non sensible, en clair.

6. Le **principe du moindre privilège** signifie donner uniquement les permissions minimales nécessaires pour accomplir une tâche, rien de plus.

7. Avec `kubectl auth can-i --list --as=system:serviceaccount:<namespace>:<sa-name>` ou en examinant les RoleBindings/ClusterRoleBindings.

8. **readOnlyRootFilesystem: true** empêche l'écriture sur le filesystem du conteneur, limitant la capacité d'un attaquant à persister des modifications ou installer des malwares.

9. Un **Admission Controller** est un plugin qui intercepte les requêtes à l'API Server avant la persistance des objets, pour les valider ou les modifier (ex: PodSecurity, ResourceQuota).

10. Pour sécuriser les secrets au repos : chiffrer etcd, utiliser un gestionnaire externe (Vault, AWS Secrets Manager), utiliser Sealed Secrets, activer le chiffrement Kubernetes natif, limiter l'accès RBAC.

</details>

---

**Durée estimée du TP :** 6-7 heures
**Niveau :** Avancé

**Excellent travail ! Vous êtes maintenant capable de sécuriser des clusters Kubernetes en production !**
