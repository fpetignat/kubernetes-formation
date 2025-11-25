# Guide des Jobs et CronJobs Kubernetes

## Table des matières
1. [Introduction](#introduction)
2. [Les Jobs](#les-jobs)
3. [Les CronJobs](#les-cronjobs)
4. [Cas d'usage pratiques](#cas-dusage-pratiques)
5. [Débogage et monitoring](#débogage-et-monitoring)
6. [Bonnes pratiques](#bonnes-pratiques)

## Introduction

Les **Jobs** et **CronJobs** sont des ressources Kubernetes conçues pour exécuter des tâches ponctuelles ou planifiées, contrairement aux Deployments qui maintiennent des applications en continu.

### Quand utiliser un Job ?
- Traitements batch (traitement de données par lots)
- Migrations de bases de données
- Génération de rapports
- Tâches d'initialisation

### Quand utiliser un CronJob ?
- Sauvegardes régulières
- Nettoyage de fichiers temporaires
- Envoi de rapports périodiques
- Tâches de maintenance planifiées

---

## Les Jobs

### 1. Job simple (one-shot)

Un Job exécute une tâche jusqu'à sa complétion réussie.

**Exemple : Sauvegarde de base de données**

Créer `job-backup.yaml` :

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: database-backup
  labels:
    app: backup
    type: database
spec:
  # Nombre de complétions réussies souhaitées
  completions: 1

  # Nombre de Pods exécutés en parallèle
  parallelism: 1

  # Nombre de tentatives avant de marquer le Job comme échec
  backoffLimit: 3

  # Durée maximale d'exécution (10 minutes)
  activeDeadlineSeconds: 600

  # Template du Pod
  template:
    metadata:
      labels:
        app: backup
    spec:
      containers:
      - name: backup
        image: postgres:15-alpine
        env:
        - name: PGHOST
          value: "postgres-service"
        - name: PGUSER
          value: "admin"
        - name: PGPASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: password
        command:
        - /bin/sh
        - -c
        - |
          echo "Démarrage de la sauvegarde à $(date)"
          pg_dump mydatabase > /backup/db-$(date +%Y%m%d-%H%M%S).sql
          echo "Sauvegarde terminée avec succès"
        volumeMounts:
        - name: backup-storage
          mountPath: /backup

      # Important : les Pods de Jobs ne redémarrent pas automatiquement
      restartPolicy: OnFailure

      volumes:
      - name: backup-storage
        persistentVolumeClaim:
          claimName: backup-pvc
```

**Paramètres importants :**

| Paramètre | Description | Valeur par défaut |
|-----------|-------------|-------------------|
| `completions` | Nombre de complétions réussies attendues | 1 |
| `parallelism` | Nombre de Pods exécutés simultanément | 1 |
| `backoffLimit` | Nombre de tentatives en cas d'échec | 6 |
| `activeDeadlineSeconds` | Durée maximale d'exécution | Aucune |
| `ttlSecondsAfterFinished` | Durée avant suppression automatique | Aucune |

**Exercice pratique :**

```bash
# 1. Créer le Job
kubectl apply -f job-backup.yaml

# 2. Surveiller l'exécution
kubectl get jobs -w

# 3. Voir les Pods créés par le Job
kubectl get pods --selector=job-name=database-backup

# 4. Consulter les logs
kubectl logs job/database-backup

# 5. Vérifier le statut
kubectl describe job database-backup

# 6. Supprimer le Job (et ses Pods)
kubectl delete job database-backup
```

### 2. Job avec parallélisme

Pour traiter plusieurs éléments simultanément.

**Exemple : Traitement d'images en parallèle**

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: image-processor
spec:
  # Traiter 100 images
  completions: 100

  # 10 workers en parallèle
  parallelism: 10

  template:
    spec:
      containers:
      - name: processor
        image: my-image-processor:1.0
        env:
        - name: JOB_COMPLETION_INDEX
          valueFrom:
            fieldRef:
              fieldPath: metadata.annotations['batch.kubernetes.io/job-completion-index']
        command:
        - /bin/sh
        - -c
        - |
          echo "Processing image #${JOB_COMPLETION_INDEX}"
          python process_image.py --index ${JOB_COMPLETION_INDEX}
      restartPolicy: OnFailure
```

### 3. Job avec nettoyage automatique

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: cleanup-job
spec:
  # Suppression automatique après 1 heure (3600 secondes)
  ttlSecondsAfterFinished: 3600

  template:
    spec:
      containers:
      - name: cleanup
        image: busybox
        command:
        - /bin/sh
        - -c
        - |
          echo "Nettoyage des fichiers temporaires..."
          find /tmp -type f -mtime +7 -delete
          echo "Nettoyage terminé"
      restartPolicy: Never
```

---

## Les CronJobs

Les CronJobs créent des Jobs selon un planning défini (comme cron sous Linux).

### 1. CronJob basique

**Exemple : Sauvegarde quotidienne**

Créer `cronjob-daily-backup.yaml` :

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: daily-backup
spec:
  # Exécution tous les jours à 2h du matin
  schedule: "0 2 * * *"

  # Timezone (disponible depuis K8s 1.25+)
  timeZone: "Europe/Paris"

  # Politique de concurrence
  concurrencyPolicy: Forbid

  # Nombre de Jobs réussis à conserver
  successfulJobsHistoryLimit: 3

  # Nombre de Jobs échoués à conserver
  failedJobsHistoryLimit: 1

  # Deadline pour démarrer le Job (en secondes)
  startingDeadlineSeconds: 300

  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: busybox
            command:
            - /bin/sh
            - -c
            - |
              echo "Sauvegarde quotidienne - $(date)"
              # Votre logique de backup ici
              echo "Backup terminé"
          restartPolicy: OnFailure
```

### 2. Syntaxe du schedule (format cron)

```
┌───────────── minute (0 - 59)
│ ┌───────────── heure (0 - 23)
│ │ ┌───────────── jour du mois (1 - 31)
│ │ │ ┌───────────── mois (1 - 12)
│ │ │ │ ┌───────────── jour de la semaine (0 - 6) (Dimanche = 0)
│ │ │ │ │
* * * * *
```

**Exemples de schedules :**

| Schedule | Description |
|----------|-------------|
| `*/5 * * * *` | Toutes les 5 minutes |
| `0 * * * *` | Toutes les heures (à minute 0) |
| `0 2 * * *` | Tous les jours à 2h du matin |
| `0 2 * * 1` | Tous les lundis à 2h |
| `0 0 1 * *` | Le 1er de chaque mois à minuit |
| `30 3 * * 1-5` | Du lundi au vendredi à 3h30 |
| `0 */6 * * *` | Toutes les 6 heures |

### 3. Politique de concurrence

```yaml
spec:
  # Allow : Permet plusieurs Jobs simultanés (défaut)
  concurrencyPolicy: Allow

  # Forbid : Interdit l'exécution si le précédent n'est pas terminé
  concurrencyPolicy: Forbid

  # Replace : Remplace le Job en cours par le nouveau
  concurrencyPolicy: Replace
```

**Exemple avec Replace :**

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup-temp
spec:
  schedule: "*/10 * * * *"
  concurrencyPolicy: Replace  # Si un nettoyage est en cours, on le remplace

  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: cleanup
            image: busybox
            command: ["sh", "-c", "find /tmp -type f -mmin +60 -delete"]
          restartPolicy: OnFailure
```

### 4. Gestion des CronJobs

```bash
# Lister les CronJobs
kubectl get cronjobs

# Détails d'un CronJob
kubectl describe cronjob daily-backup

# Voir les Jobs créés par un CronJob
kubectl get jobs --selector=cronjob=daily-backup

# Suspendre un CronJob (sans supprimer)
kubectl patch cronjob daily-backup -p '{"spec":{"suspend":true}}'

# Réactiver un CronJob
kubectl patch cronjob daily-backup -p '{"spec":{"suspend":false}}'

# Déclencher manuellement un Job depuis un CronJob
kubectl create job --from=cronjob/daily-backup manual-backup-001

# Supprimer un CronJob (et tous ses Jobs)
kubectl delete cronjob daily-backup
```

---

## Cas d'usage pratiques

### 1. Nettoyage de logs applicatifs

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: log-cleanup
spec:
  schedule: "0 3 * * *"  # Tous les jours à 3h
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: cleanup
            image: busybox
            command:
            - sh
            - -c
            - |
              echo "Nettoyage des logs de plus de 7 jours"
              find /var/log/app -name "*.log" -mtime +7 -delete
              echo "Nettoyage terminé à $(date)"
            volumeMounts:
            - name: app-logs
              mountPath: /var/log/app
          restartPolicy: OnFailure
          volumes:
          - name: app-logs
            hostPath:
              path: /var/log/myapp
```

### 2. Export de métriques hebdomadaire

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: weekly-metrics-export
spec:
  schedule: "0 1 * * 1"  # Tous les lundis à 1h du matin
  successfulJobsHistoryLimit: 4  # Garder 4 semaines

  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: metrics-exporter
          containers:
          - name: exporter
            image: my-metrics-exporter:1.0
            env:
            - name: EXPORT_DATE
              value: "$(date -d 'last week' +%Y-%m-%d)"
            command:
            - python
            - export_metrics.py
            - --format=csv
            - --destination=s3://my-bucket/metrics/
          restartPolicy: OnFailure
```

### 3. Vérification de santé de services externes

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: health-check
spec:
  schedule: "*/15 * * * *"  # Toutes les 15 minutes
  concurrencyPolicy: Forbid

  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: checker
            image: curlimages/curl:latest
            command:
            - sh
            - -c
            - |
              if curl -f -s https://api.example.com/health > /dev/null; then
                echo "Service OK à $(date)"
                exit 0
              else
                echo "Service DOWN à $(date)"
                # Envoyer une alerte (webhook, etc.)
                curl -X POST https://alerts.example.com/webhook \
                  -d '{"status":"down","service":"api"}'
                exit 1
              fi
          restartPolicy: Never
```

### 4. Migration de base de données

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration-v2-3
spec:
  backoffLimit: 0  # Pas de retry pour une migration
  activeDeadlineSeconds: 1800  # Max 30 minutes

  template:
    spec:
      initContainers:
      # Backup avant migration
      - name: pre-migration-backup
        image: postgres:15-alpine
        command:
        - sh
        - -c
        - pg_dump -h $DB_HOST -U $DB_USER $DB_NAME > /backup/pre-migration.sql
        volumeMounts:
        - name: backup
          mountPath: /backup

      containers:
      - name: migration
        image: my-app:2.3-migration
        command:
        - python
        - manage.py
        - migrate
        env:
        - name: DB_HOST
          value: postgres-service
        - name: DB_NAME
          value: myapp
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username

      restartPolicy: Never
      volumes:
      - name: backup
        persistentVolumeClaim:
          claimName: migration-backup-pvc
```

---

## Débogage et monitoring

### 1. Vérifier l'état d'un Job

```bash
# Statut général
kubectl get jobs

# Détails complets
kubectl describe job my-job

# Voir les conditions
kubectl get job my-job -o jsonpath='{.status.conditions[*].type}'

# Nombre de succès/échecs
kubectl get job my-job -o jsonpath='{.status.succeeded}/{.status.failed}'
```

### 2. Consulter les logs

```bash
# Logs du Job (tous les Pods)
kubectl logs job/my-job

# Logs d'un Pod spécifique
kubectl logs my-job-xyz123

# Suivre les logs en temps réel
kubectl logs -f job/my-job

# Logs des Pods échoués
kubectl logs --previous job/my-job
```

### 3. Debugging d'un CronJob

```bash
# Vérifier le dernier schedule
kubectl get cronjob my-cronjob -o jsonpath='{.status.lastScheduleTime}'

# Voir si suspendu
kubectl get cronjob my-cronjob -o jsonpath='{.spec.suspend}'

# Historique des Jobs créés
kubectl get jobs --selector=cronjob=my-cronjob --sort-by=.metadata.creationTimestamp

# Events liés au CronJob
kubectl describe cronjob my-cronjob | grep Events -A 10
```

### 4. Problèmes courants

**Job ne démarre pas :**
```bash
# Vérifier les events
kubectl get events --field-selector involvedObject.name=my-job

# Vérifier les quotas de ressources
kubectl describe resourcequota

# Vérifier les limites du namespace
kubectl describe limitrange
```

**Job échoue en boucle :**
```bash
# Voir la raison de l'échec
kubectl describe pod my-job-xyz123 | grep -A 5 "State:"

# Vérifier le nombre de retries
kubectl get job my-job -o jsonpath='{.spec.backoffLimit}'

# Augmenter le backoffLimit si nécessaire
kubectl patch job my-job -p '{"spec":{"backoffLimit":5}}'
```

**CronJob ne s'exécute pas :**
```bash
# Vérifier le schedule
kubectl get cronjob my-cronjob -o jsonpath='{.spec.schedule}'

# Vérifier la suspension
kubectl get cronjob my-cronjob -o jsonpath='{.spec.suspend}'

# Vérifier startingDeadlineSeconds
kubectl get cronjob my-cronjob -o jsonpath='{.spec.startingDeadlineSeconds}'
```

---

## Bonnes pratiques

### 1. Gestion des ressources

```yaml
spec:
  template:
    spec:
      containers:
      - name: my-job
        image: my-image
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
```

### 2. Timeout et deadline

```yaml
spec:
  # Deadline globale du Job
  activeDeadlineSeconds: 600

  template:
    spec:
      containers:
      - name: my-container
        # Timeout du conteneur
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "sleep 10"]
```

### 3. Nettoyage automatique

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: my-job
spec:
  # Suppression automatique après 2 heures
  ttlSecondsAfterFinished: 7200

  template:
    spec:
      # ...
```

Pour les CronJobs :
```yaml
spec:
  successfulJobsHistoryLimit: 3  # Garder 3 succès
  failedJobsHistoryLimit: 1      # Garder 1 échec
```

### 4. Idempotence

Assurez-vous que vos Jobs peuvent être relancés sans effet de bord :

```bash
# ❌ Mauvais : Ajoute à chaque fois
echo "nouvelle ligne" >> /data/file.txt

# ✅ Bon : Remplace le contenu
echo "contenu final" > /data/file.txt

# ✅ Bon : Vérifier avant d'agir
if [ ! -f /data/migration-done ]; then
  run_migration.sh
  touch /data/migration-done
fi
```

### 5. Logs et monitoring

```yaml
spec:
  template:
    spec:
      containers:
      - name: my-job
        image: my-image
        # Toujours logger le début et la fin
        command:
        - /bin/sh
        - -c
        - |
          echo "Job démarré à $(date) - Version 1.2.3"
          # Votre code ici
          EXIT_CODE=$?
          echo "Job terminé à $(date) - Exit code: $EXIT_CODE"
          exit $EXIT_CODE
```

### 6. Sécurité

```yaml
spec:
  template:
    spec:
      # Utiliser un ServiceAccount dédié
      serviceAccountName: job-runner

      # Contexte de sécurité
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000

      containers:
      - name: my-job
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
```

### 7. Checklist pour Jobs en production

- [ ] `backoffLimit` défini selon le besoin
- [ ] `activeDeadlineSeconds` configuré pour éviter les jobs infinis
- [ ] `ttlSecondsAfterFinished` pour le nettoyage automatique
- [ ] `resources.requests` et `resources.limits` définis
- [ ] `restartPolicy` approprié (Never ou OnFailure)
- [ ] Logs structurés avec timestamps
- [ ] Gestion d'erreurs et exit codes appropriés
- [ ] Idempotence garantie
- [ ] Secrets gérés proprement (pas en clair)
- [ ] ServiceAccount avec permissions minimales

### 8. Checklist pour CronJobs en production

- [ ] `schedule` validé et testé
- [ ] `timeZone` configuré si nécessaire
- [ ] `concurrencyPolicy` adapté au use case
- [ ] `startingDeadlineSeconds` défini
- [ ] `successfulJobsHistoryLimit` et `failedJobsHistoryLimit` configurés
- [ ] Alerting en place pour les échecs
- [ ] Monitoring du temps d'exécution
- [ ] Documentation du comportement attendu

---

## Exercices pratiques

### Exercice 1 : Job de calcul

Créez un Job qui calcule les 10000 premières décimales de Pi.

<details>
<summary>Solution</summary>

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi-calculation
spec:
  completions: 1
  backoffLimit: 2
  activeDeadlineSeconds: 300

  template:
    spec:
      containers:
      - name: pi
        image: perl:5.34
        command:
        - perl
        - -Mbignum=bpi
        - -wle
        - print bpi(10000)
      restartPolicy: Never
```

```bash
kubectl apply -f pi-calculation.yaml
kubectl wait --for=condition=complete job/pi-calculation --timeout=300s
kubectl logs job/pi-calculation
```
</details>

### Exercice 2 : CronJob de monitoring

Créez un CronJob qui vérifie toutes les 5 minutes que votre service web répond correctement.

<details>
<summary>Solution</summary>

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: web-health-check
spec:
  schedule: "*/5 * * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 2
  failedJobsHistoryLimit: 3

  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: checker
            image: curlimages/curl:latest
            command:
            - sh
            - -c
            - |
              echo "Health check à $(date)"
              if curl -f -s -o /dev/null -w "%{http_code}" http://my-service:80/health | grep -q "200"; then
                echo "✓ Service OK"
                exit 0
              else
                echo "✗ Service KO"
                exit 1
              fi
          restartPolicy: Never
```
</details>

### Exercice 3 : Job parallèle

Créez un Job qui exécute 20 traitements (complétions) avec 5 workers en parallèle.

<details>
<summary>Solution</summary>

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: parallel-processing
spec:
  completions: 20
  parallelism: 5
  backoffLimit: 3

  template:
    spec:
      containers:
      - name: worker
        image: busybox
        command:
        - sh
        - -c
        - |
          echo "Worker démarré à $(date)"
          sleep $((RANDOM % 10 + 5))  # Simule un traitement de 5-15 secondes
          echo "Traitement terminé à $(date)"
      restartPolicy: OnFailure
```

```bash
# Observer les Pods démarrer par vagues de 5
kubectl get pods -w
```
</details>

---

## Ressources supplémentaires

- [Documentation officielle - Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
- [Documentation officielle - CronJobs](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)
- [Crontab Guru](https://crontab.guru/) - Aide pour les expressions cron
- [Patterns pour Jobs Kubernetes](https://kubernetes.io/docs/concepts/workloads/controllers/job/#job-patterns)

---

**Prochaines étapes :** Une fois que vous maîtrisez les Jobs et CronJobs, explorez :
- Les **DaemonSets** pour exécuter un Pod sur chaque nœud
- Les **StatefulSets** pour les applications avec état
- **Argo Workflows** pour des pipelines complexes
