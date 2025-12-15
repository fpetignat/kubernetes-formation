# Gestion d'un Cluster Kubernetes en Environnement Sécurisé

## Vue d'ensemble

Ce document couvre les meilleures pratiques pour gérer un cluster Kubernetes dans un environnement hautement sécurisé, notamment en DMZ (Zone Démilitarisée) ou dans des environnements isolés du réseau.

## 🔒 Principes de Sécurité en Environnement Hermétique

### Caractéristiques d'un Environnement Sécurisé

Un environnement Kubernetes sécurisé présente généralement les caractéristiques suivantes :

- **Isolation réseau stricte** : Accès limité à Internet et aux réseaux externes
- **DMZ** : Cluster déployé dans une zone démilitarisée
- **Air-gapped** : Environnement totalement déconnecté d'Internet
- **Contrôle des flux** : Tous les flux réseau doivent être explicitement autorisés
- **Traçabilité** : Logging et audit complets de toutes les opérations

### Architecture Typique en DMZ

```
┌─────────────────────────────────────────────────────────────┐
│                      Internet                                │
└──────────────────────────┬──────────────────────────────────┘
                           │
                      [Firewall]
                           │
┌──────────────────────────┼──────────────────────────────────┐
│                          │                                   │
│                     [Proxy/WAF]                              │
│                          │                                   │
│  ┌───────────────────────┼────────────────────────┐         │
│  │                  DMZ (Zone 1)                   │         │
│  │                       │                         │         │
│  │              [Ingress Controllers]              │         │
│  └───────────────────────┼────────────────────────┘         │
│                          │                                   │
│                    [Firewall Interne]                        │
│                          │                                   │
│  ┌───────────────────────┼────────────────────────┐         │
│  │             Cluster Kubernetes                  │         │
│  │                  (Zone Sécurisée)               │         │
│  │                                                  │         │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐     │         │
│  │  │  Master  │  │  Master  │  │  Master  │     │         │
│  │  │   Node   │  │   Node   │  │   Node   │     │         │
│  │  └──────────┘  └──────────┘  └──────────┘     │         │
│  │                                                  │         │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐     │         │
│  │  │  Worker  │  │  Worker  │  │  Worker  │     │         │
│  │  │   Node   │  │   Node   │  │   Node   │     │         │
│  │  └──────────┘  └──────────┘  └──────────┘     │         │
│  │                                                  │         │
│  └──────────────────────────────────────────────────┘        │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

## 🎯 Stratégies de Déploiement en Environnement Sécurisé

### 1. Registre d'Images Privé

**Obligatoire** : Un registre d'images privé est essentiel en environnement sécurisé.

#### Solutions Recommandées

| Solution | Avantages | Inconvénients | Cas d'usage |
|----------|-----------|---------------|-------------|
| **Harbor** | - Open source<br>- Scan de vulnérabilités intégré<br>- Réplication<br>- Gestion RBAC | - Ressources importantes | Production enterprise |
| **Nexus Repository** | - Multi-format (Docker, Helm, Maven, etc.)<br>- Proxy cache<br>- Maturité | - Interface moins moderne | Environnements polyvalents |
| **JFrog Artifactory** | - Performant<br>- Intégration CI/CD<br>- Support commercial | - Coût élevé | Grandes entreprises |
| **Docker Registry** | - Simple<br>- Léger<br>- Facile à déployer | - Fonctionnalités limitées<br>- Pas de UI | Dev/test, petits clusters |
| **GitLab Container Registry** | - Intégré à GitLab<br>- CI/CD natif | - Dépendance à GitLab | Si déjà utilisateur GitLab |

#### Exemple de Déploiement Harbor en DMZ

```yaml
# harbor-values.yaml
expose:
  type: loadBalancer
  tls:
    enabled: true
    certSource: secret
    secret:
      secretName: harbor-tls

externalURL: https://harbor.internal.company.com

persistence:
  enabled: true
  persistentVolumeClaim:
    registry:
      size: 500Gi
    database:
      size: 10Gi
    redis:
      size: 1Gi

trivy:
  enabled: true

clair:
  enabled: false

notary:
  enabled: true

chartmuseum:
  enabled: true
```

Déploiement :
```bash
helm repo add harbor https://helm.goharbor.io
helm install harbor harbor/harbor \
  --namespace harbor \
  --create-namespace \
  -f harbor-values.yaml
```

### 2. Gestion des Certificats TLS

En environnement sécurisé, les certificats TLS sont cruciaux.

#### Solutions de Gestion des Certificats

**Option 1 : PKI Interne avec cert-manager**

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: internal-ca-issuer
spec:
  ca:
    secretName: internal-ca-key-pair
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: harbor-tls
  namespace: harbor
spec:
  secretName: harbor-tls
  issuerRef:
    name: internal-ca-issuer
    kind: ClusterIssuer
  dnsNames:
    - harbor.internal.company.com
  duration: 2160h  # 90 jours
  renewBefore: 360h  # 15 jours avant expiration
```

**Option 2 : Vault pour la Gestion des Secrets**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-vault-auth
  namespace: production
---
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultAuth
metadata:
  name: vault-auth
  namespace: production
spec:
  method: kubernetes
  mount: kubernetes
  kubernetes:
    role: production-role
    serviceAccount: app-vault-auth
```

### 3. Network Policies Strictes

En DMZ, tous les flux doivent être explicitement autorisés.

#### Policy par Défaut : Deny All

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

#### Autoriser uniquement les flux nécessaires

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    ports:
    - protocol: TCP
      port: 8080
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-database
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: database
    ports:
    - protocol: TCP
      port: 5432
  # DNS resolution
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

### 4. Contrôle d'Accès RBAC Strict

#### Principe du Moindre Privilège

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: production
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: production
subjects:
- kind: ServiceAccount
  name: monitoring-sa
  namespace: production
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

#### Audit des Permissions

```bash
# Vérifier les permissions d'un ServiceAccount
kubectl auth can-i --list \
  --as=system:serviceaccount:production:app-sa \
  -n production

# Trouver tous les ClusterRoleBindings avec des permissions admin
kubectl get clusterrolebindings -o json | \
  jq '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name'
```

## 🔐 Sécurité au Niveau du Cluster

### 1. API Server Sécurisé

Configuration recommandée pour le kube-apiserver :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
  namespace: kube-system
spec:
  containers:
  - name: kube-apiserver
    command:
    - kube-apiserver
    # Authentification
    - --client-ca-file=/etc/kubernetes/pki/ca.crt
    - --tls-cert-file=/etc/kubernetes/pki/apiserver.crt
    - --tls-private-key-file=/etc/kubernetes/pki/apiserver.key

    # Audit
    - --audit-log-path=/var/log/kubernetes/audit.log
    - --audit-log-maxage=30
    - --audit-log-maxbackup=10
    - --audit-log-maxsize=100
    - --audit-policy-file=/etc/kubernetes/audit-policy.yaml

    # Sécurité
    - --enable-admission-plugins=NodeRestriction,PodSecurityPolicy,ServiceAccount
    - --authorization-mode=Node,RBAC
    - --anonymous-auth=false

    # Encryption at rest
    - --encryption-provider-config=/etc/kubernetes/encryption-config.yaml
```

### 2. Encryption at Rest

```yaml
# /etc/kubernetes/encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
      - configmaps
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <base64-encoded-secret>
      - identity: {}
```

### 3. Pod Security Standards

**Utiliser Pod Security Admission (PSA)** au lieu de PodSecurityPolicy (déprécié)

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

Niveaux de sécurité :
- **Privileged** : Non restreint
- **Baseline** : Empêche les escalations de privilèges connues
- **Restricted** : Fortement restreint (best practices)

## 📊 Monitoring et Logging en Environnement Sécurisé

### Stack de Monitoring Recommandée

```yaml
# Prometheus dans un namespace dédié
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    name: monitoring
---
# ServiceMonitor pour scraper les métriques
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: kubernetes-apiservers
  namespace: monitoring
spec:
  endpoints:
  - bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
    interval: 30s
    port: https
    scheme: https
    tlsConfig:
      caFile: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      serverName: kubernetes
  jobLabel: component
  namespaceSelector:
    matchNames:
    - default
  selector:
    matchLabels:
      component: apiserver
      provider: kubernetes
```

### Centralisation des Logs

**Option 1 : Stack EFK (Elasticsearch, Fluentd, Kibana)**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-config
  namespace: kube-system
data:
  fluent.conf: |
    <source>
      @type tail
      path /var/log/containers/*.log
      pos_file /var/log/fluentd-containers.log.pos
      tag kubernetes.*
      read_from_head true
      <parse>
        @type json
        time_format %Y-%m-%dT%H:%M:%S.%NZ
      </parse>
    </source>

    <filter kubernetes.**>
      @type kubernetes_metadata
    </filter>

    <match **>
      @type elasticsearch
      host elasticsearch.logging.svc.cluster.local
      port 9200
      logstash_format true
      logstash_prefix kubernetes
      <buffer>
        @type file
        path /var/log/fluentd-buffers/kubernetes.system.buffer
        flush_mode interval
        retry_type exponential_backoff
        flush_interval 5s
        retry_max_interval 30
        chunk_limit_size 2M
        total_limit_size 500M
        overflow_action block
      </buffer>
    </match>
```

**Option 2 : Loki (plus léger)**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: promtail-config
  namespace: logging
data:
  promtail.yaml: |
    server:
      http_listen_port: 3101

    clients:
      - url: http://loki.logging.svc.cluster.local:3100/loki/api/v1/push

    positions:
      filename: /tmp/positions.yaml

    scrape_configs:
      - job_name: kubernetes-pods
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_node_name]
            target_label: node_name
          - source_labels: [__meta_kubernetes_namespace]
            target_label: namespace
          - source_labels: [__meta_kubernetes_pod_name]
            target_label: pod
          - source_labels: [__meta_kubernetes_pod_container_name]
            target_label: container
```

## 🔄 Mise à Jour et Maintenance

### Stratégie de Mise à Jour en Production

**Approche Blue/Green pour les Applications Critiques**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: production
spec:
  selector:
    app: frontend
    version: blue  # Switcher entre blue/green
  ports:
  - port: 80
    targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-blue
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
      version: blue
  template:
    metadata:
      labels:
        app: frontend
        version: blue
    spec:
      containers:
      - name: frontend
        image: harbor.internal/app/frontend:v1.2.0
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-green
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
      version: green
  template:
    metadata:
      labels:
        app: frontend
        version: green
    spec:
      containers:
      - name: frontend
        image: harbor.internal/app/frontend:v1.3.0
```

Switch de version :
```bash
# Basculer vers green
kubectl patch service frontend -n production \
  -p '{"spec":{"selector":{"version":"green"}}}'

# Rollback vers blue si problème
kubectl patch service frontend -n production \
  -p '{"spec":{"selector":{"version":"blue"}}}'
```

### Mise à Jour du Cluster

**Ordre recommandé** :
1. Backup etcd
2. Mise à jour des masters (un par un)
3. Mise à jour des workers (par groupes)
4. Validation post-upgrade

```bash
# 1. Backup etcd
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot-$(date +%Y%m%d-%H%M%S).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# 2. Drain node
kubectl drain node1 --ignore-daemonsets --delete-emptydir-data

# 3. Upgrade kubeadm
apt-mark unhold kubeadm && \
apt-get update && apt-get install -y kubeadm=1.29.0-00 && \
apt-mark hold kubeadm

# 4. Upgrade node
kubeadm upgrade apply v1.29.0  # Sur master
kubeadm upgrade node           # Sur workers

# 5. Upgrade kubelet et kubectl
apt-mark unhold kubelet kubectl && \
apt-get update && apt-get install -y kubelet=1.29.0-00 kubectl=1.29.0-00 && \
apt-mark hold kubelet kubectl

# 6. Restart kubelet
systemctl daemon-reload
systemctl restart kubelet

# 7. Uncordon node
kubectl uncordon node1
```

## 📋 Checklist de Sécurité

### Niveau Cluster

- [ ] API server accessible uniquement via VPN/bastion
- [ ] Certificats TLS pour tous les composants
- [ ] Encryption at rest activée
- [ ] Audit logging activé
- [ ] RBAC configuré avec principe du moindre privilège
- [ ] Pod Security Standards appliqués
- [ ] Network Policies par défaut (deny all)
- [ ] Secrets chiffrés avec KMS ou Vault

### Niveau Application

- [ ] Images provenant uniquement du registre privé
- [ ] Scan de vulnérabilités automatique
- [ ] Pas de privileged containers
- [ ] Resource limits définis
- [ ] Health checks configurés
- [ ] Service mesh pour mTLS (optionnel)
- [ ] NetworkPolicies spécifiques à l'application

### Niveau Opérationnel

- [ ] Monitoring complet (métriques + logs + traces)
- [ ] Alerting configuré
- [ ] Backup automatique etcd
- [ ] Plan de reprise d'activité (DRP)
- [ ] Procédure de mise à jour documentée
- [ ] Tests de sécurité réguliers (pentests)

## 📚 Références

- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [NSA Kubernetes Hardening Guide](https://www.nsa.gov/Press-Room/News-Highlights/Article/Article/2716980/nsa-cisa-release-kubernetes-hardening-guidance/)
- [OWASP Kubernetes Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Kubernetes_Security_Cheat_Sheet.html)
- [Kubernetes Network Policy Recipes](https://github.com/ahmetb/kubernetes-network-policy-recipes)

## Articles Complémentaires

- [Gestion des Registres d'Images en DMZ](IMAGE_REGISTRY_DMZ.md)
- [Cycle de Vie des Applications](APPLICATION_LIFECYCLE.md)
- [Déploiement Air-Gapped](AIRGAP_DEPLOYMENT.md)
