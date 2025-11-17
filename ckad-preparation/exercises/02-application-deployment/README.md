# Exercices - Application Deployment (20%)

## Objectifs du domaine

- Utiliser les primitives Kubernetes pour déployer des applications
- Comprendre les Deployments et les stratégies de rollout/rollback
- Gérer les mises à jour d'applications
- Utiliser les labels et selectors

---

## Exercice 1 : Deployment Basique

**Temps estimé : 5 minutes**

Créer un Deployment nommé `webapp` qui :
- Utilise l'image `nginx:1.19`
- A 3 replicas
- Labels : `app=webapp`, `tier=frontend`

Vérifier que tous les Pods sont Running.

<details>
<summary>💡 Indice</summary>

```bash
k create deploy webapp --image=nginx:1.19 --replicas=3 $do > deploy.yaml
# Ajouter les labels dans metadata.labels et spec.template.metadata.labels
```
</details>

---

## Exercice 2 : Rolling Update

**Temps estimé : 8 minutes**

En utilisant le Deployment `webapp` de l'exercice précédent :
1. Mettre à jour l'image vers `nginx:1.20` avec l'option `--record`
2. Vérifier le status du rollout
3. Consulter l'historique des rollouts
4. Créer une nouvelle mise à jour vers `nginx:1.21`

<details>
<summary>💡 Indice</summary>

```bash
k set image deploy/webapp nginx=nginx:1.20 --record
k rollout status deploy/webapp
k rollout history deploy/webapp
```
</details>

---

## Exercice 3 : Rollback

**Temps estimé : 6 minutes**

Continuer avec le Deployment `webapp` :
1. Mettre à jour vers une image invalide `nginx:invalid-tag`
2. Observer l'échec du rollout
3. Effectuer un rollback vers la version précédente
4. Vérifier que les Pods sont revenus à l'état stable

<details>
<summary>💡 Indice</summary>

```bash
k set image deploy/webapp nginx=nginx:invalid-tag
k rollout status deploy/webapp  # Observer que ça bloque
k rollout undo deploy/webapp
```
</details>

---

## Exercice 4 : Stratégie RollingUpdate Personnalisée

**Temps estimé : 10 minutes**

Créer un Deployment nommé `api-server` qui :
- Utilise l'image `nginx:alpine`
- A 6 replicas
- Stratégie de mise à jour :
  - Type: RollingUpdate
  - maxSurge: 2 (max 2 Pods supplémentaires pendant la mise à jour)
  - maxUnavailable: 1 (max 1 Pod indisponible pendant la mise à jour)

Mettre à jour l'image et observer le comportement du rollout.

<details>
<summary>💡 Indice</summary>

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2
      maxUnavailable: 1
```
</details>

---

## Exercice 5 : Stratégie Recreate

**Temps estimé : 7 minutes**

Créer un Deployment nommé `db-migrate` qui :
- Utilise l'image `postgres:13`
- A 1 replica
- Stratégie de mise à jour : `Recreate` (supprime tous les Pods avant d'en créer de nouveaux)

Mettre à jour vers `postgres:14` et observer la différence avec RollingUpdate.

<details>
<summary>💡 Indice</summary>

```yaml
spec:
  strategy:
    type: Recreate
```
</details>

---

## Exercice 6 : Scaling Horizontal

**Temps estimé : 5 minutes**

Avec le Deployment `webapp` :
1. Scaler à 5 replicas
2. Vérifier que les 5 Pods sont créés
3. Scaler à 2 replicas
4. Vérifier que des Pods sont terminés

<details>
<summary>💡 Indice</summary>

```bash
k scale deploy webapp --replicas=5
k get pods -w
k scale deploy webapp --replicas=2
```
</details>

---

## Exercice 7 : Labels et Selectors

**Temps estimé : 8 minutes**

1. Créer un Deployment `frontend` avec 3 replicas (image: `nginx:alpine`) et labels `app=frontend`, `env=prod`
2. Créer un Deployment `backend` avec 2 replicas (image: `nginx:alpine`) et labels `app=backend`, `env=prod`
3. Lister uniquement les Pods du frontend
4. Lister tous les Pods en production
5. Ajouter le label `version=v1` à tous les Pods du frontend

<details>
<summary>💡 Indice</summary>

```bash
k get pods -l app=frontend
k get pods -l env=prod
k label pods -l app=frontend version=v1
```
</details>

---

## Exercice 8 : Rollout Pause et Resume

**Temps estimé : 10 minutes**

Créer un Deployment `canary-app` avec 4 replicas (image: `nginx:1.19`), puis :
1. Mettre en pause le rollout
2. Mettre à jour l'image vers `nginx:1.20`
3. Observer qu'aucun nouveau Pod n'est créé
4. Reprendre le rollout
5. Vérifier que la mise à jour se termine

<details>
<summary>💡 Indice</summary>

```bash
k rollout pause deploy/canary-app
k set image deploy/canary-app nginx=nginx:1.20
k rollout resume deploy/canary-app
k rollout status deploy/canary-app
```
</details>

---

## Exercice 9 : Rollback vers une révision spécifique

**Temps estimé : 8 minutes**

Avec le Deployment `webapp` :
1. Effectuer 3 mises à jour successives (nginx:1.19 → 1.20 → 1.21 → 1.22)
2. Consulter l'historique complet
3. Effectuer un rollback vers la révision 2
4. Vérifier l'image utilisée

<details>
<summary>💡 Indice</summary>

```bash
k rollout history deploy/webapp
k rollout undo deploy/webapp --to-revision=2
k describe deploy webapp | grep Image
```
</details>

---

## Exercice 10 : Deployment avec minReadySeconds

**Temps estimé : 7 minutes**

Créer un Deployment nommé `slow-start` qui :
- Utilise l'image `nginx:alpine`
- A 3 replicas
- `minReadySeconds: 30` (attend 30s avant de considérer un Pod comme disponible)

Créer le Deployment et observer le délai entre la création des Pods.

<details>
<summary>💡 Indice</summary>

```yaml
spec:
  minReadySeconds: 30
  replicas: 3
```

Regardez avec `k rollout status` et `k get pods -w`.
</details>

---

## Exercice 11 : ReplicaSet manuel

**Temps estimé : 6 minutes**

Créer directement un ReplicaSet (sans Deployment) nommé `rs-nginx` qui :
- Utilise l'image `nginx:alpine`
- A 3 replicas
- Selector: `app=nginx-rs`

Supprimer un Pod et observer la recréation automatique.

<details>
<summary>💡 Indice</summary>

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
</details>

---

## Exercice 12 : Deployment avec Annotations

**Temps estimé : 5 minutes**

Créer un Deployment `annotated-app` avec :
- Image: `nginx:alpine`
- 2 replicas
- Annotations dans les Pods :
  - `description: "Production nginx server"`
  - `owner: "platform-team"`
  - `version: "1.0.0"`

<details>
<summary>💡 Indice</summary>

Les annotations vont dans `spec.template.metadata.annotations`.
</details>

---

## 🎯 Objectifs d'apprentissage

Après avoir complété ces exercices, vous devriez être capable de :

- ✅ Créer et gérer des Deployments
- ✅ Effectuer des rolling updates et rollbacks
- ✅ Comprendre les stratégies de déploiement (RollingUpdate vs Recreate)
- ✅ Configurer maxSurge et maxUnavailable
- ✅ Utiliser labels et selectors efficacement
- ✅ Scaler des applications horizontalement
- ✅ Consulter et naviguer dans l'historique des rollouts
- ✅ Utiliser pause/resume pour des déploiements progressifs (canary)
- ✅ Comprendre la différence entre Deployment et ReplicaSet

---

## 📚 Références

- [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Rolling Updates](https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/)
- [Labels and Selectors](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)
- [ReplicaSet](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/)

---

**💡 Conseil** : Les stratégies de déploiement et le rollback sont des sujets fréquents à l'examen. Maîtrisez `kubectl rollout` !
