# Guide de Sécurité Kubernetes - Checklist Claude

## 🎯 Objectif

Ce document contient une **checklist exhaustive de sécurité** à appliquer **systématiquement dès la première itération** lors de la création de manifests Kubernetes.

## 📊 Historique des Vulnérabilités

### Analyse du TP10 (30 vulnérabilités HIGH corrigées)

| ID Vulnérabilité | Nombre d'occurrences | Sévérité | Cause |
|------------------|---------------------|----------|-------|
| **KSV118** | 17 | HIGH | securityContext manquant ou incomplet |
| **KSV014** | 12 | HIGH | Root filesystem en écriture |
| **KSV047** | 1 | HIGH | RBAC trop permissif (nodes/proxy) |

### Autres vulnérabilités récurrentes dans le projet

- **KSV104** : Conteneurs s'exécutant en root
- **KSV003** : Absence de limites de ressources
- **KSV012** : allowPrivilegeEscalation non défini
- **KSV020** : Capabilities Linux non restreintes
- **KSV030** : seccompProfile non défini

## ✅ CHECKLIST DE SÉCURITÉ OBLIGATOIRE

### 🛡️ 1. SecurityContext (POD Level) - TOUJOURS REQUIS

```yaml
spec:
  securityContext:
    # OBLIGATOIRE : Ne jamais exécuter en root
    runAsNonRoot: true

    # OBLIGATOIRE : Spécifier un UID non-root (> 0)
    # Utiliser l'UID natif de l'image si possible
    runAsUser: 1000  # Exemples : nginx=101, postgres=70, redis=999

    # OBLIGATOIRE : Définir le groupe propriétaire des volumes
    fsGroup: 1000

    # OBLIGATOIRE : Profil seccomp pour limiter les syscalls
    seccompProfile:
      type: RuntimeDefault
```

**UIDs recommandés par image** :
- `nginx:alpine` → 101
- `postgres:alpine` → 70
- `redis:alpine` → 999
- `grafana` → 472
- `prometheus` → 65534 (nobody)
- `python:slim` → 1000 (créer utilisateur non-root)

### 🔒 2. SecurityContext (CONTAINER Level) - TOUJOURS REQUIS

```yaml
containers:
- name: mon-conteneur
  securityContext:
    # OBLIGATOIRE : Désactiver l'escalade de privilèges
    allowPrivilegeEscalation: false

    # OBLIGATOIRE : Système de fichiers racine en lecture seule
    readOnlyRootFilesystem: true

    # OBLIGATOIRE : Confirmer non-root au niveau conteneur
    runAsNonRoot: true
    runAsUser: 1000

    # OBLIGATOIRE : Supprimer toutes les capabilities Linux
    capabilities:
      drop:
      - ALL
```

### 📁 3. Volumes pour readOnlyRootFilesystem

Quand `readOnlyRootFilesystem: true`, ajouter des volumes `emptyDir` pour les répertoires temporaires :

```yaml
volumeMounts:
  # OBLIGATOIRE : Répertoire temporaire
  - name: tmp
    mountPath: /tmp

volumes:
  - name: tmp
    emptyDir: {}
```

**Répertoires temporaires courants par application** :

| Application | Répertoires à monter en emptyDir |
|-------------|----------------------------------|
| **PostgreSQL** | `/tmp`, `/var/run/postgresql` |
| **Redis** | `/data` (si pas de PVC) |
| **Nginx** | `/var/cache/nginx`, `/var/run`, `/tmp` |
| **Python/pip** | `/home/nonroot`, `/tmp` (pip --user) |
| **Grafana** | `/var/lib/grafana`, `/var/log/grafana`, `/tmp` |
| **Prometheus** | `/tmp` |

### 🎯 4. Resources Limits - TOUJOURS REQUIS

```yaml
resources:
  # OBLIGATOIRE : Définir les requêtes
  requests:
    memory: "128Mi"
    cpu: "100m"

  # OBLIGATOIRE : Définir les limites
  limits:
    memory: "256Mi"
    cpu: "200m"
```

**Valeurs recommandées par type d'application** :

| Type | Requests | Limits |
|------|----------|--------|
| **Frontend/Nginx** | 32Mi/50m | 64Mi/100m |
| **API Backend** | 128Mi/100m | 256Mi/200m |
| **Base de données** | 256Mi/250m | 512Mi/500m |
| **Cache (Redis)** | 64Mi/50m | 128Mi/100m |
| **Monitoring** | 256Mi/100m | 512Mi/200m |
| **Job/Batch** | 32Mi/50m | 64Mi/200m |

### ❤️ 5. Health Checks - FORTEMENT RECOMMANDÉ

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 3
```

### 🔐 6. Secrets et ConfigMaps

```yaml
# ✅ BON : Utiliser des Secrets pour les données sensibles
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: password

# ❌ MAUVAIS : Jamais de mots de passe en clair
env:
- name: DB_PASSWORD
  value: "password123"  # ❌ INTERDIT
```

### 🎭 7. RBAC - Principe du Moindre Privilège

```yaml
# ✅ BON : Permissions minimales
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]

# ❌ MAUVAIS : Permissions trop larges
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]  # ❌ INTERDIT

# ❌ ÉVITER : Accès à nodes/proxy (KSV047)
- apiGroups: [""]
  resources: ["nodes/proxy"]  # ❌ Escalade de privilèges possible
  verbs: ["get"]
```

### 🏷️ 8. Labels et Annotations

```yaml
metadata:
  labels:
    app: mon-app
    tier: backend
    version: v1.0.0
  annotations:
    description: "Application backend API"
```

## 📋 TEMPLATE DE DEPLOYMENT SÉCURISÉ

Utilisez ce template comme point de départ :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mon-app
  namespace: mon-namespace
  labels:
    app: mon-app
    tier: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: mon-app
  template:
    metadata:
      labels:
        app: mon-app
        tier: backend
    spec:
      # ═══════════════════════════════════════════════════════
      # SECURITY CONTEXT POD (OBLIGATOIRE)
      # ═══════════════════════════════════════════════════════
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault

      containers:
      - name: mon-app
        image: mon-image:latest

        ports:
        - containerPort: 8080
          name: http

        # ═══════════════════════════════════════════════════════
        # SECURITY CONTEXT CONTAINER (OBLIGATOIRE)
        # ═══════════════════════════════════════════════════════
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
          capabilities:
            drop:
            - ALL

        # ═══════════════════════════════════════════════════════
        # RESOURCES (OBLIGATOIRE)
        # ═══════════════════════════════════════════════════════
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"

        # ═══════════════════════════════════════════════════════
        # HEALTH CHECKS (RECOMMANDÉ)
        # ═══════════════════════════════════════════════════════
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10

        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5

        # ═══════════════════════════════════════════════════════
        # VOLUMES (SI readOnlyRootFilesystem: true)
        # ═══════════════════════════════════════════════════════
        volumeMounts:
        - name: tmp
          mountPath: /tmp

      volumes:
      - name: tmp
        emptyDir: {}
```

## 🔍 VALIDATION AUTOMATIQUE

### Trivy (Scanner de sécurité)

```bash
# Scanner un manifest
trivy config mon-deployment.yaml

# Scanner avec sévérité HIGH et CRITICAL uniquement
trivy config --severity HIGH,CRITICAL mon-deployment.yaml

# Scanner un répertoire entier
trivy config --severity HIGH,CRITICAL tp10/
```

### kubeconform (Validation schéma)

```bash
# Valider un manifest
kubeconform -strict mon-deployment.yaml

# Valider tous les YAML d'un TP
kubeconform -strict tp10/*.yaml
```

### kubectl (Dry-run)

```bash
# Tester le déploiement sans l'appliquer
kubectl apply --dry-run=server -f mon-deployment.yaml
```

## 📚 RÉFÉRENCE : Pod Security Standards

Kubernetes définit 3 niveaux de sécurité :

### 1. Privileged (non recommandé)
- Aucune restriction
- À éviter en production

### 2. Baseline (minimum acceptable)
- Empêche les escalades de privilèges connues
- Minimum pour la production

### 3. Restricted (recommandé) ⭐
- **Standard recommandé pour ce projet**
- Suit les meilleures pratiques de sécurité
- Toutes les checklist ci-dessus

## 🎓 CAS SPÉCIAUX

### Conteneurs qui doivent écrire

Si l'application DOIT écrire dans le système de fichiers :

```yaml
# Option 1 : Monter un volume persistant
volumeMounts:
- name: data
  mountPath: /app/data
volumes:
- name: data
  persistentVolumeClaim:
    claimName: mon-pvc

# Option 2 : Utiliser emptyDir (données éphémères)
volumeMounts:
- name: data
  mountPath: /app/data
volumes:
- name: data
  emptyDir: {}
```

### Images qui s'exécutent en root par défaut

```yaml
# Exemple : PostgreSQL officielle
# L'image utilise UID 70 par défaut

securityContext:
  runAsNonRoot: true
  runAsUser: 70      # UID natif de l'image
  fsGroup: 70
```

### Bases de données (PostgreSQL, MySQL, MongoDB, etc.)

**Important** : Les bases de données sont un cas spécial où `readOnlyRootFilesystem: true` n'est **pas approprié**.

**Raisons** :
- Les bases de données doivent initialiser leur répertoire de données (`initdb` pour PostgreSQL)
- Elles doivent créer des fichiers de configuration et modifier les permissions
- Le processus de démarrage nécessite un accès en écriture légitime

**Configuration sécurisée pour PostgreSQL** :
```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 70       # UID postgres
    fsGroup: 70
    seccompProfile:
      type: RuntimeDefault

  containers:
  - name: postgres
    image: postgres:16-alpine
    securityContext:
      allowPrivilegeEscalation: false
      # Note: readOnlyRootFilesystem is NOT set
      # PostgreSQL needs write access to manage its data directory
      runAsNonRoot: true
      runAsUser: 70
      capabilities:
        drop:
        - ALL

    volumeMounts:
    - name: postgres-data
      mountPath: /var/lib/postgresql/data
    - name: run
      mountPath: /var/run/postgresql
    - name: tmp
      mountPath: /tmp

  volumes:
  - name: postgres-data
    persistentVolumeClaim:
      claimName: postgres-pvc
  - name: run
    emptyDir: {}
  - name: tmp
    emptyDir: {}
```

**Sécurité maintenue par** :
- ✅ Exécution en tant qu'utilisateur non-root (UID 70)
- ✅ Aucune escalade de privilèges
- ✅ Toutes les capabilities supprimées
- ✅ Profil seccomp actif
- ✅ Isolation via volumes dédiés (PVC + emptyDir)
- ✅ Resources limits définis

**Autres bases de données** :
- **MySQL** : Même approche, utiliser UID 999
- **MongoDB** : Même approche, utiliser UID 999
- **Redis** : Peut fonctionner avec `readOnlyRootFilesystem: true` si données en emptyDir

### Applications Python avec pip

```yaml
containers:
- name: python-app
  command:
  - /bin/bash
  - -c
  - |
    # Installer les packages en mode utilisateur
    pip install --user --no-cache-dir flask gunicorn
    exec gunicorn app:app

  securityContext:
    runAsUser: 1000
    readOnlyRootFilesystem: true

  env:
  # Définir HOME pour pip --user
  - name: HOME
    value: /home/nonroot

  volumeMounts:
  - name: home
    mountPath: /home/nonroot
  - name: tmp
    mountPath: /tmp

volumes:
- name: home
  emptyDir: {}
- name: tmp
  emptyDir: {}
```

## 🚨 ERREURS COURANTES À ÉVITER

### ❌ 1. Oublier le securityContext

```yaml
# ❌ MAUVAIS
spec:
  containers:
  - name: app
    image: nginx:latest
    # Pas de securityContext = vulnérabilité
```

```yaml
# ✅ BON
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 101
    fsGroup: 101
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx:latest
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      runAsUser: 101
      capabilities:
        drop:
        - ALL
```

### ❌ 2. readOnlyRootFilesystem sans volumes

```yaml
# ❌ MAUVAIS : Le conteneur va crasher
securityContext:
  readOnlyRootFilesystem: true
# Pas de volume pour /tmp
```

```yaml
# ✅ BON
securityContext:
  readOnlyRootFilesystem: true
volumeMounts:
- name: tmp
  mountPath: /tmp
volumes:
- name: tmp
  emptyDir: {}
```

### ❌ 3. Mots de passe en clair

```yaml
# ❌ MAUVAIS
env:
- name: DATABASE_PASSWORD
  value: "SuperSecret123"
```

```yaml
# ✅ BON
env:
- name: DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: password
```

### ❌ 4. Absence de resource limits

```yaml
# ❌ MAUVAIS : Peut consommer toutes les ressources du nœud
containers:
- name: app
  image: my-app:latest
  # Pas de resources
```

```yaml
# ✅ BON
containers:
- name: app
  image: my-app:latest
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "256Mi"
      cpu: "200m"
```

### ❌ 5. RBAC trop permissif

```yaml
# ❌ MAUVAIS
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
```

```yaml
# ✅ BON : Permissions minimales
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get"]
```

## 🔄 WORKFLOW DE CRÉATION D'UN MANIFEST

### Étape 1 : Utiliser le template sécurisé
Partir du template de ce document (section "TEMPLATE DE DEPLOYMENT SÉCURISÉ")

### Étape 2 : Adapter le securityContext
- Identifier l'UID natif de l'image Docker
- Ajuster `runAsUser` et `fsGroup`

### Étape 3 : Ajouter les volumes nécessaires
- Pour `/tmp` (toujours)
- Pour d'autres répertoires temporaires (selon l'application)

### Étape 4 : Configurer les resources
- Estimer les besoins réels
- Ajouter requests et limits

### Étape 5 : Ajouter les health checks
- livenessProbe (santé du conteneur)
- readinessProbe (prêt à recevoir du trafic)

### Étape 6 : Valider
```bash
# Validation syntaxe
kubeconform mon-manifest.yaml

# Scan de sécurité
trivy config --severity HIGH,CRITICAL mon-manifest.yaml

# Dry-run
kubectl apply --dry-run=server -f mon-manifest.yaml
```

## 📊 MÉTRIQUES DE QUALITÉ

### Objectifs de sécurité pour chaque manifest

| Critère | Objectif |
|---------|----------|
| securityContext (pod) | 100% |
| securityContext (container) | 100% |
| readOnlyRootFilesystem | 100% |
| runAsNonRoot | 100% |
| capabilities.drop: ALL | 100% |
| resources.requests | 100% |
| resources.limits | 100% |
| health checks | 80%+ |
| Vulnérabilités HIGH | 0 |
| Vulnérabilités CRITICAL | 0 |

## 🔗 RESSOURCES

### Documentation officielle
- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Security Context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
- [Configure a Security Context for a Pod](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
- [Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/)

### Outils de sécurité
- [Trivy](https://github.com/aquasecurity/trivy) - Scanner de vulnérabilités
- [kubeconform](https://github.com/yannh/kubeconform) - Validation de schémas
- [kube-bench](https://github.com/aquasecurity/kube-bench) - CIS Kubernetes Benchmark

### Références CIS
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)

## ✨ CONCLUSION

**En appliquant systématiquement cette checklist dès la première itération, nous évitons :**
- ✅ 30 vulnérabilités HIGH corrigées a posteriori (comme dans TP10)
- ✅ Multiples cycles de correction
- ✅ Perte de temps et frustration
- ✅ Code de meilleure qualité dès le départ

**Principe d'or** : "Security by Design, not Security by Patch"

---

**Dernière mise à jour** : 2025-12-16
**Version** : 1.0
**Auteur** : Claude (basé sur l'analyse des 30+ vulnérabilités corrigées)
