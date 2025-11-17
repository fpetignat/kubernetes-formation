# Solutions - Application Deployment

## Exercice 1 : Deployment Basique

### Solution rapide

```bash
k create deploy webapp --image=nginx:1.19 --replicas=3 $do > webapp.yaml
vim webapp.yaml  # Ajouter les labels
```

### Deployment complet

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  labels:
    app: webapp
    tier: frontend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
        tier: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:1.19
```

### Vérification

```bash
k apply -f webapp.yaml
k get deploy webapp
k get pods -l app=webapp
k describe deploy webapp
```

### ⚠️ Pièges courants

- Les labels dans `spec.template.metadata.labels` DOIVENT matcher `spec.selector.matchLabels`
- Les labels dans `metadata.labels` sont pour le Deployment lui-même (optionnels)

---

## Exercice 2 : Rolling Update

### Solution

```bash
# 1. Créer le Deployment (depuis exercice 1)
k apply -f webapp.yaml

# 2. Update avec --record
k set image deploy/webapp nginx=nginx:1.20 --record

# 3. Vérifier le rollout
k rollout status deploy/webapp

# 4. Voir l'historique
k rollout history deploy/webapp

# 5. Nouvelle mise à jour
k set image deploy/webapp nginx=nginx:1.21 --record
```

### Vérification

```bash
k rollout status deploy/webapp
k rollout history deploy/webapp
k describe deploy webapp | grep Image
```

### 💡 Explications

- **--record** : Enregistre la commande dans l'historique (déprécié mais utile pour CKAD)
- **rollout status** : Suit la progression du déploiement
- **rollout history** : Affiche toutes les révisions

---

## Exercice 3 : Rollback

### Solution

```bash
# 1. Update vers image invalide
k set image deploy/webapp nginx=nginx:invalid-tag

# 2. Observer l'échec
k rollout status deploy/webapp
k get pods  # Certains Pods seront en ImagePullBackOff

# 3. Rollback
k rollout undo deploy/webapp

# 4. Vérifier le retour à l'état stable
k rollout status deploy/webapp
k get pods
k describe deploy webapp | grep Image
```

### 💡 Explications

- Le rollout s'arrête automatiquement si les nouveaux Pods ne démarrent pas
- `rollout undo` revient à la révision précédente
- Les anciens ReplicaSets sont conservés pour permettre le rollback

---

## Exercice 4 : Stratégie RollingUpdate Personnalisée

### Solution

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
spec:
  replicas: 6
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2
      maxUnavailable: 1
  selector:
    matchLabels:
      app: api-server
  template:
    metadata:
      labels:
        app: api-server
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
```

### Test du rollout

```bash
k apply -f api-server.yaml

# Update et observer
k set image deploy/api-server nginx=nginx:1.21
k get pods -w

# Pendant le rollout, vous verrez:
# - Max 8 Pods (6 + maxSurge:2)
# - Min 5 Pods disponibles (6 - maxUnavailable:1)
```

### 💡 Explications

- **maxSurge: 2** : Peut créer jusqu'à 2 Pods supplémentaires pendant le rollout
- **maxUnavailable: 1** : Max 1 Pod peut être indisponible
- Calcul : 6 replicas + 2 surge - 1 unavailable = entre 5 et 8 Pods pendant le rollout

---

## Exercice 5 : Stratégie Recreate

### Solution

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db-migrate
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: db-migrate
  template:
    metadata:
      labels:
        app: db-migrate
    spec:
      containers:
      - name: postgres
        image: postgres:13
        env:
        - name: POSTGRES_PASSWORD
          value: example
```

### Test

```bash
k apply -f db-migrate.yaml

# Update
k set image deploy/db-migrate postgres=postgres:14
k get pods -w

# Vous verrez:
# 1. Le Pod existant se termine
# 2. Le nouveau Pod démarre (pas de pods en parallèle)
```

### 💡 Explications

- **Recreate** : Supprime TOUS les Pods avant d'en créer de nouveaux
- Downtime inévitable
- Utile pour des applications qui ne supportent pas plusieurs versions en parallèle

---

## Exercice 6 : Scaling Horizontal

### Solution

```bash
# Scale up à 5
k scale deploy webapp --replicas=5
k get pods -l app=webapp -w

# Scale down à 2
k scale deploy webapp --replicas=2
k get pods -l app=webapp -w
```

### Alternative : Édition directe

```bash
k edit deploy webapp
# Modifier spec.replicas dans l'éditeur
```

### Alternative : Patch

```bash
k patch deploy webapp -p '{"spec":{"replicas":5}}'
```

---

## Exercice 7 : Labels et Selectors

### Solution

```bash
# 1. Créer les Deployments
k create deploy frontend --image=nginx:alpine --replicas=3
k create deploy backend --image=nginx:alpine --replicas=2

# 2. Ajouter les labels aux Deployments
k label deploy frontend app=frontend env=prod
k label deploy backend app=backend env=prod

# 3. Lister Pods du frontend
k get pods -l app=frontend

# 4. Lister tous les Pods en prod
k get pods -l env=prod

# 5. Ajouter label version=v1 aux Pods frontend
k label pods -l app=frontend version=v1

# Vérifier
k get pods --show-labels
```

### 💡 Explications

- Les labels sur le Deployment ne sont PAS hérités par les Pods
- Il faut labeller les Pods directement avec `-l` pour filter

---

## Exercice 8 : Rollout Pause et Resume

### Solution

```bash
# 1. Créer le Deployment
k create deploy canary-app --image=nginx:1.19 --replicas=4

# 2. Pause
k rollout pause deploy/canary-app

# 3. Update l'image
k set image deploy/canary-app nginx=nginx:1.20

# 4. Observer qu'aucun nouveau Pod n'est créé
k get pods
k rollout status deploy/canary-app  # Stuck

# 5. Resume
k rollout resume deploy/canary-app

# 6. Observer le rollout
k rollout status deploy/canary-app
k get pods -w
```

### 💡 Cas d'usage

- **Canary deployment** : Déployer progressivement
- Pause → Update → Test quelques Pods → Resume si OK

---

## Exercice 9 : Rollback vers révision spécifique

### Solution

```bash
# 1. Créer et faire plusieurs updates
k create deploy webapp --image=nginx:1.19 --replicas=3
k set image deploy/webapp nginx=nginx:1.20 --record
k set image deploy/webapp nginx=nginx:1.21 --record
k set image deploy/webapp nginx=nginx:1.22 --record

# 2. Voir l'historique
k rollout history deploy/webapp

# Sortie:
# REVISION  CHANGE-CAUSE
# 1         <none>
# 2         kubectl set image deploy/webapp nginx=nginx:1.20 --record=true
# 3         kubectl set image deploy/webapp nginx=nginx:1.21 --record=true
# 4         kubectl set image deploy/webapp nginx=nginx:1.22 --record=true

# 3. Rollback vers révision 2
k rollout undo deploy/webapp --to-revision=2

# 4. Vérifier l'image
k describe deploy webapp | grep Image
# Devrait afficher nginx:1.20
```

---

## Exercice 10 : Deployment avec minReadySeconds

### Solution

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: slow-start
spec:
  replicas: 3
  minReadySeconds: 30
  selector:
    matchLabels:
      app: slow-start
  template:
    metadata:
      labels:
        app: slow-start
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
```

### Observation

```bash
k apply -f slow-start.yaml
k rollout status deploy/slow-start -w

# Vous verrez que chaque Pod attend 30s avant d'être considéré disponible
# Le rollout prend ~90s au lieu de quelques secondes
```

### 💡 Explications

- **minReadySeconds** : Temps d'attente avant de considérer un Pod comme disponible
- Utile pour détecter des problèmes qui apparaissent après le démarrage

---

## Exercice 11 : ReplicaSet manuel

### Solution

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: rs-nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-rs
  template:
    metadata:
      labels:
        app: nginx-rs
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
```

### Test

```bash
k apply -f rs-nginx.yaml
k get rs
k get pods -l app=nginx-rs

# Supprimer un Pod
POD=$(k get pods -l app=nginx-rs -o jsonpath='{.items[0].metadata.name}')
k delete pod $POD

# Observer la recréation immédiate
k get pods -l app=nginx-rs -w
```

### 💡 Explications

- ReplicaSet assure qu'il y a toujours 3 Pods
- En production, utilisez Deployment (qui gère les ReplicaSets)

---

## Exercice 12 : Deployment avec Annotations

### Solution

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: annotated-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: annotated
  template:
    metadata:
      labels:
        app: annotated
      annotations:
        description: "Production nginx server"
        owner: "platform-team"
        version: "1.0.0"
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
```

### Vérification

```bash
k apply -f annotated-app.yaml
k describe pod -l app=annotated | grep -A 5 Annotations
```

### 💡 Différence Labels vs Annotations

- **Labels** : Pour sélectionner (Services, NetworkPolicies)
- **Annotations** : Pour stocker des métadonnées (descriptions, URLs, etc.)

---

## 🚀 Patterns de commandes rapides

### Pattern 1 : Créer et exposer rapidement

```bash
k create deploy app --image=nginx --replicas=3
k expose deploy app --port=80
k scale deploy app --replicas=5
```

### Pattern 2 : Update et rollback

```bash
k set image deploy/app nginx=nginx:1.21 --record
k rollout status deploy/app
# Si problème:
k rollout undo deploy/app
```

### Pattern 3 : Debug Deployment

```bash
k get deploy
k get rs
k get pods
k describe deploy <name>
k logs deploy/<name>
```

---

## 📚 Ressources

- [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Rolling Updates](https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/)
- [ReplicaSet](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/)
