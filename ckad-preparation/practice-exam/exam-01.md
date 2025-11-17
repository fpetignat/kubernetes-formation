# Practice Exam CKAD - Session 01

**Durée** : 2 heures
**Questions** : 17
**Score minimum** : 66/100

---

## Instructions

1. Lisez attentivement chaque question
2. Vérifiez le **contexte** et le **namespace** avant chaque question
3. Validez votre réponse avec `kubectl get/describe` avant de passer à la suivante
4. Gérez votre temps : ~7 minutes par question en moyenne
5. Marquez les questions difficiles et revenez-y plus tard

---

## Question 1 (4%) - Pod Multi-Container

**Context**: `kubectl config use-context main`
**Namespace**: `default`

Créer un Pod nommé `log-processor` avec :
- Container `app` : image `nginx:alpine`, écoute sur port 80
- Container `logger` : image `busybox`, commande qui log la date toutes les 5s dans `/var/log/app.log`
- Volume `emptyDir` partagé entre les deux containers monté sur `/var/log`

Vérifier que les logs sont générés.

---

## Question 2 (7%) - Deployment et Service

**Context**: `kubectl config use-context main`
**Namespace**: `production`

1. Créer un Deployment nommé `web-app` :
   - Image: `nginx:1.21`
   - 4 replicas
   - Labels: `app=web`, `tier=frontend`, `env=production`

2. Exposer ce Deployment avec un Service NodePort :
   - Nom: `web-svc`
   - Port: 80
   - NodePort: 30080

3. Vérifier que le Service a 4 endpoints

---

## Question 3 (3%) - ConfigMap

**Context**: `kubectl config use-context main`
**Namespace**: `default`

1. Créer un ConfigMap nommé `app-config` avec les données suivantes :
   ```
   DATABASE_URL=postgresql://db.example.com:5432/mydb
   CACHE_ENABLED=true
   LOG_LEVEL=info
   ```

2. Créer un Pod `config-test` (image: `busybox`, commande: `sleep 3600`) qui charge toutes ces variables d'environnement depuis le ConfigMap

3. Vérifier que les variables sont présentes avec `kubectl exec`

---

## Question 4 (8%) - Health Checks

**Context**: `kubectl config use-context main`
**Namespace**: `default`

Créer un Deployment nommé `api-server` avec :
- Image: `nginx:alpine`
- 3 replicas
- Liveness probe :
  - Type: HTTP GET sur `/healthz` au port 80
  - `initialDelaySeconds: 10`
  - `periodSeconds: 5`
- Readiness probe :
  - Type: HTTP GET sur `/ready` au port 80
  - `initialDelaySeconds: 5`
  - `periodSeconds: 3`

---

## Question 5 (5%) - Secret et Volume

**Context**: `kubectl config use-context main`
**Namespace**: `secure`

1. Créer un Secret nommé `db-credentials` avec :
   - `username=admin`
   - `password=P@ssw0rd123!`

2. Créer un Pod `secure-app` qui :
   - Utilise l'image `nginx:alpine`
   - Monte le Secret comme volume dans `/etc/secrets`
   - Le volume doit être en lecture seule

---

## Question 6 (7%) - NetworkPolicy

**Context**: `kubectl config use-context main`
**Namespace**: `restricted`

Dans le namespace `restricted`, il existe un Deployment `backend` avec label `app=backend`.

Créer une NetworkPolicy nommé `backend-policy` qui :
- S'applique aux Pods avec label `app=backend`
- Autorise le trafic ingress uniquement depuis les Pods avec label `app=frontend`
- Sur le port 8080 en TCP
- Deny tout autre trafic ingress

---

## Question 7 (2%) - Scaling

**Context**: `kubectl config use-context main`
**Namespace**: `production`

Le Deployment `web-app` (créé en Question 2) doit être scalé à 6 replicas.

Effectuer cette opération et vérifier que 6 Pods sont en Running.

---

## Question 8 (6%) - Rolling Update et Rollback

**Context**: `kubectl config use-context main`
**Namespace**: `production`

1. Mettre à jour le Deployment `web-app` vers l'image `nginx:1.22` avec `--record`

2. Consulter l'historique des rollouts

3. Une erreur a été détectée, effectuer un rollback vers la version précédente

4. Vérifier que l'image est revenue à `nginx:1.21`

---

## Question 9 (5%) - Job

**Context**: `kubectl config use-context main`
**Namespace**: `batch`

Créer un Job nommé `data-import` qui :
- Utilise l'image `busybox`
- Commande: `echo "Processing data..." && sleep 10 && echo "Done"`
- Doit s'exécuter avec succès 3 fois (`completions: 3`)
- Maximum 2 Pods en parallèle (`parallelism: 2`)
- Maximum 4 tentatives en cas d'échec (`backoffLimit: 4`)

---

## Question 10 (8%) - Resource Limits et LimitRange

**Context**: `kubectl config use-context main`
**Namespace**: `limited`

1. Créer un LimitRange dans le namespace `limited` qui impose :
   - Default requests: cpu=100m, memory=128Mi
   - Default limits: cpu=200m, memory=256Mi
   - Max: cpu=500m, memory=512Mi

2. Créer un Pod `resource-test` (image: `nginx:alpine`) sans spécifier de ressources

3. Vérifier que les limites par défaut ont été appliquées

---

## Question 11 (6%) - Ingress

**Context**: `kubectl config use-context main`
**Namespace**: `web`

Dans le namespace `web`, deux Services existent : `app1-svc` et `app2-svc` (tous deux sur port 80).

Créer un Ingress nommé `web-ingress` qui :
- Host: `myapp.local`
- Route `/app1` vers `app1-svc:80`
- Route `/app2` vers `app2-svc:80`

---

## Question 12 (4%) - CronJob

**Context**: `kubectl config use-context main`
**Namespace**: `default`

Créer un CronJob nommé `backup` qui :
- S'exécute tous les jours à 2h du matin (schedule: `"0 2 * * *"`)
- Utilise l'image `busybox`
- Commande: `echo "Backup started at $(date)"`
- Conserve les 3 derniers Jobs réussis
- Conserve le dernier Job échoué

---

## Question 13 (7%) - SecurityContext

**Context**: `kubectl config use-context main`
**Namespace**: `secure`

Créer un Pod nommé `hardened-app` qui :
- Utilise l'image `nginx:alpine`
- S'exécute en tant qu'utilisateur non-root (UID: 1000, GID: 3000)
- Filesystem en lecture seule (`readOnlyRootFilesystem: true`)
- Monte un volume `emptyDir` sur `/var/cache/nginx` (nginx a besoin d'écrire ici)
- Monte un volume `emptyDir` sur `/var/run`

---

## Question 14 (3%) - Labels et Selectors

**Context**: `kubectl config use-context main`
**Namespace**: `default`

Il existe plusieurs Pods dans le namespace avec différents labels.

1. Ajouter le label `version=v2` à tous les Pods qui ont le label `app=web`

2. Lister tous les Pods qui ont `env=production` ET `tier=frontend`

3. Supprimer le label `temporary` de tous les Pods

---

## Question 15 (8%) - Init Container et ServiceAccount

**Context**: `kubectl config use-context main`
**Namespace**: `default`

1. Créer un ServiceAccount nommé `app-sa`

2. Créer un Pod nommé `init-demo` qui :
   - Utilise le ServiceAccount `app-sa`
   - A un init container `init-wait` (image: `busybox`) qui attend 10 secondes : `sleep 10`
   - Container principal `nginx` (image: `nginx:alpine`)

3. Observer le comportement du Pod pendant le démarrage

---

## Question 16 (6%) - Debugging

**Context**: `kubectl config use-context main`
**Namespace**: `troubleshoot`

Un Pod nommé `broken-app` existe dans le namespace `troubleshoot` mais ne démarre pas correctement.

1. Identifier la cause du problème
2. Corriger le Pod pour qu'il démarre correctement
3. Vérifier que le Pod est en état Running

**Indice** : Utilisez `describe`, `logs`, et `events`

---

## Question 17 (7%) - Persistent Storage et StatefulSet Basics

**Context**: `kubectl config use-context main`
**Namespace**: `data`

Créer un Pod nommé `data-pod` qui :
- Utilise l'image `nginx:alpine`
- A un volume `emptyDir` nommé `data-volume`
- Monte ce volume sur `/data` dans le container
- A une liveness probe qui vérifie l'existence du fichier `/data/healthy`
  - Type: exec
  - Commande: `test -f /data/healthy`
  - `initialDelaySeconds: 5`
  - `periodSeconds: 5`

Créer manuellement le fichier `/data/healthy` dans le Pod pour qu'il reste en Running.

---

## Grille de notation

| Question | Points | Validé |
|----------|--------|--------|
| Q1       | 4      | ☐      |
| Q2       | 7      | ☐      |
| Q3       | 3      | ☐      |
| Q4       | 8      | ☐      |
| Q5       | 5      | ☐      |
| Q6       | 7      | ☐      |
| Q7       | 2      | ☐      |
| Q8       | 6      | ☐      |
| Q9       | 5      | ☐      |
| Q10      | 8      | ☐      |
| Q11      | 6      | ☐      |
| Q12      | 4      | ☐      |
| Q13      | 7      | ☐      |
| Q14      | 3      | ☐      |
| Q15      | 8      | ☐      |
| Q16      | 6      | ☐      |
| Q17      | 7      | ☐      |
| **TOTAL**| **100**| **__** |

---

## Tips pour l'examen

1. ✅ **Toujours vérifier le contexte et namespace** avant de commencer une question
2. ✅ **Utiliser --dry-run=client -o yaml** pour générer les manifests rapidement
3. ✅ **Valider avec kubectl get/describe** après chaque création
4. ✅ **Marquer les questions difficiles** et y revenir plus tard
5. ✅ **Garder 20-30 minutes** pour réviser à la fin
6. ✅ **Ne pas perdre de temps** sur une question bloquée
7. ✅ **Utiliser la documentation** Kubernetes si nécessaire

---

**Bon courage ! 🚀**

*Passez à la correction dans `solutions/exam-01-solutions.md` une fois terminé.*
