# Solutions - Application Design and Build

## Exercice 1 : Multi-Container Pod - Sidecar Pattern

### Solution rapide (kubectl)

```bash
# Générer le Pod de base
k run web-app --image=nginx:alpine $do > web-app.yaml

# Éditer pour ajouter le sidecar
vim web-app.yaml
```

### Fichier YAML complet

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-app
spec:
  containers:
  - name: nginx
    image: nginx:alpine
  - name: logger
    image: busybox
    command: ['/bin/sh', '-c', 'while true; do date >> /var/log/app.log; sleep 5; done']
    volumeMounts:
    - name: logs
      mountPath: /var/log
  volumes:
  - name: logs
    emptyDir: {}
```

### Application et vérification

```bash
k apply -f web-app.yaml
k get pods web-app
k logs web-app -c logger
k exec web-app -c nginx -- cat /var/log/app.log
```

### 💡 Explications

- **Sidecar pattern** : Le container `logger` est un sidecar qui accompagne le container principal
- **emptyDir** : Volume temporaire partagé entre les containers du même Pod
- **volumeMounts** : Chaque container monte le volume sur `/var/log`

### ⚠️ Pièges courants

- Oublier de monter le volume dans les deux containers
- Ne pas mettre le volume dans `spec.volumes`
- Syntaxe de la commande : utiliser `command:` et non `args:` seul

---

## Exercice 2 : Init Container

### Solution rapide

```bash
# Générer le Pod
k run myapp --image=nginx:alpine $do > myapp.yaml

# Créer le Service en parallèle
k create service clusterip myservice --tcp=80:80 $do > myservice.yaml
```

### Pod avec Init Container

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  initContainers:
  - name: init-myservice
    image: busybox
    command: ['sh', '-c', 'until nslookup myservice; do echo waiting; sleep 2; done']
  containers:
  - name: myapp-container
    image: nginx:alpine
```

### Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myservice
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: myservice  # Il faudra un Pod avec ce label pour que le Service ait des endpoints
```

### Vérification

```bash
k apply -f myservice.yaml
k apply -f myapp.yaml

# Observer l'init container en attente
k get pods -w

# Le Pod restera en Init jusqu'à ce que le Service soit résolvable
k describe pod myapp
```

### 💡 Explications

- **initContainers** : S'exécutent AVANT les containers principaux
- **nslookup** : Vérifie que le nom DNS du Service est résolvable
- Les init containers doivent se terminer avec succès pour que le Pod démarre

---

## Exercice 3 : Job - Calcul Parallèle

### Solution rapide

```bash
k create job compute --image=perl:5.34 $do -- perl -Mbignum=bpi -wle 'print bpi(2000)' > job.yaml
vim job.yaml  # Ajouter completions, parallelism, backoffLimit
```

### Job complet

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: compute
spec:
  completions: 5
  parallelism: 2
  backoffLimit: 3
  template:
    spec:
      containers:
      - name: compute
        image: perl:5.34
        command: ["perl", "-Mbignum=bpi", "-wle", "print bpi(2000)"]
      restartPolicy: Never
```

### Vérification

```bash
k apply -f job.yaml
k get jobs -w
k get pods -l job-name=compute

# Voir les logs d'un Pod
k logs <pod-name>

# Voir le statut du Job
k describe job compute
```

### 💡 Explications

- **completions: 5** : Le Job doit réussir 5 fois
- **parallelism: 2** : Max 2 Pods en parallèle
- **backoffLimit: 3** : Max 3 tentatives en cas d'échec
- **restartPolicy: Never** : Obligatoire pour les Jobs

---

## Exercice 4 : CronJob - Nettoyage Périodique

### Solution rapide

```bash
k create cronjob cleanup --image=busybox --schedule="0 * * * *" $do -- /bin/sh -c 'echo "Cleaning up at $(date)"' > cronjob.yaml
vim cronjob.yaml  # Ajouter successfulJobsHistoryLimit et failedJobsHistoryLimit
```

### CronJob complet

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup
spec:
  schedule: "0 * * * *"
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: cleanup
            image: busybox
            command: ["/bin/sh", "-c", "echo \"Cleaning up at $(date)\""]
          restartPolicy: OnFailure
```

### Vérification

```bash
k apply -f cronjob.yaml
k get cronjobs
k describe cronjob cleanup

# Créer un Job manuellement pour tester
k create job test-cleanup --from=cronjob/cleanup

# Voir les Jobs créés
k get jobs
```

### 💡 Explications

- **schedule: "0 * * * *"** : Format cron standard (minute heure jour mois jour-semaine)
- **successfulJobsHistoryLimit: 3** : Garde les 3 derniers Jobs réussis
- **failedJobsHistoryLimit: 1** : Garde le dernier Job échoué

### 🚀 Astuce Rapide

Schedule cron courants :
- `*/5 * * * *` : Toutes les 5 minutes
- `0 2 * * *` : Tous les jours à 2h
- `0 0 * * 0` : Tous les dimanches à minuit

---

## Exercice 5 : Multi-Container - Adapter Pattern

### Solution complète

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: legacy-app
spec:
  containers:
  - name: app
    image: busybox
    command: ['/bin/sh', '-c']
    args:
    - while true; do
        echo "$(date)|INFO|Application running" >> /var/log/app.log;
        sleep 3;
      done
    volumeMounts:
    - name: logs
      mountPath: /var/log

  - name: log-adapter
    image: busybox
    command: ['/bin/sh', '-c']
    args:
    - while true; do
        if [ -f /var/log/app.log ]; then
          tail -1 /var/log/app.log | sed 's/|/","/g' | sed 's/^/{"timestamp":"/' | sed 's/$/}/';
        fi;
        sleep 3;
      done
    volumeMounts:
    - name: logs
      mountPath: /var/log

  volumes:
  - name: logs
    emptyDir: {}
```

### Vérification

```bash
k apply -f legacy-app.yaml
k logs legacy-app -c app
k logs legacy-app -c log-adapter -f
```

### 💡 Explications

- **Adapter pattern** : Transforme le format de sortie sans modifier l'application principale
- Le container `log-adapter` lit les logs bruts et les convertit en JSON

---

## Exercice 6 : Job avec TTL

### Solution

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: short-lived
spec:
  ttlSecondsAfterFinished: 30
  template:
    spec:
      containers:
      - name: job
        image: alpine
        command: ["echo", "Job completed"]
      restartPolicy: Never
```

### Vérification

```bash
k apply -f short-lived.yaml
k get jobs -w

# Attendre 30 secondes après completion
# Le Job sera automatiquement supprimé
```

### 💡 Explications

- **ttlSecondsAfterFinished: 30** : Le Job sera supprimé 30s après sa complétion
- Utile pour éviter l'accumulation de Jobs terminés

---

## Exercice 7 : Ambassador Pattern

### Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: redis-client
spec:
  containers:
  - name: app
    image: alpine
    command: ["sleep", "3600"]

  - name: redis-proxy
    image: redis:alpine
```

### 💡 Explications

- **Ambassador pattern** : Le proxy local (`redis-proxy`) fait office d'intermédiaire
- Les deux containers partagent `localhost` car ils sont dans le même Pod
- L'app peut se connecter à `localhost:6379`

---

## Exercice 8 : Init Container - Préchargement

### Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-preload
spec:
  initContainers:
  - name: data-fetcher
    image: busybox
    command: ['sh', '-c', 'wget -O /data/index.html https://kubernetes.io']
    volumeMounts:
    - name: web-content
      mountPath: /data

  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - name: web-content
      mountPath: /usr/share/nginx/html

  volumes:
  - name: web-content
    emptyDir: {}
```

### Vérification

```bash
k apply -f web-preload.yaml
k get pods -w
k exec web-preload -- cat /usr/share/nginx/html/index.html
```

---

## Exercice 9 : CronJob avec activeDeadlineSeconds

### Solution

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: timeout-job
spec:
  schedule: "*/5 * * * *"
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      activeDeadlineSeconds: 60
      template:
        spec:
          containers:
          - name: job
            image: busybox
            command: ['/bin/sh', '-c', 'for i in $(seq 1 100); do echo $i; sleep 2; done']
          restartPolicy: Never
```

### 💡 Explications

- **activeDeadlineSeconds: 60** : Le Job sera tué après 60s
- **concurrencyPolicy: Forbid** : Ne lance pas un nouveau Job si l'ancien tourne encore

---

## Exercice 10 : Multi-Container avec resources

### Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: resource-demo
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 200m
        memory: 256Mi

  - name: busybox
    image: busybox
    command: ["sleep", "3600"]
    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        cpu: 100m
        memory: 128Mi
```

### Vérification

```bash
k apply -f resource-demo.yaml
k describe pod resource-demo | grep -A 10 "Requests:"
```

---

## 📚 Ressources

- [Multi-container Pods](https://kubernetes.io/docs/concepts/workloads/pods/#how-pods-manage-multiple-containers)
- [Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)
- [Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
- [CronJobs](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)
