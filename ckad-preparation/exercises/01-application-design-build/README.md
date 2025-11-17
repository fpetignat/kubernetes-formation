# Exercices - Application Design and Build (20%)

## Objectifs du domaine

- Définir et construire des images de conteneurs
- Choisir et utiliser un Job ou CronJob approprié
- Comprendre les stratégies de déploiement multi-conteneurs (sidecar, init, adapter)

---

## Exercice 1 : Multi-Container Pod - Sidecar Pattern

**Temps estimé : 8 minutes**

Créer un Pod nommé `web-app` avec deux conteneurs :
- Container principal `nginx` (image: `nginx:alpine`)
- Container sidecar `logger` (image: `busybox`) qui exécute : `while true; do date >> /var/log/app.log; sleep 5; done`
- Les deux conteneurs doivent partager un volume `emptyDir` monté sur `/var/log`

<details>
<summary>💡 Indice</summary>

Utilisez `k run` avec `$do` puis éditez le YAML pour ajouter le deuxième container et le volume.
</details>

---

## Exercice 2 : Init Container

**Temps estimé : 7 minutes**

Créer un Pod nommé `myapp` qui :
- Utilise un init container `init-myservice` (image: `busybox`) qui attend que le service `myservice` soit disponible avec la commande : `until nslookup myservice; do echo waiting; sleep 2; done`
- Container principal `myapp-container` (image: `nginx:alpine`)

Créer également le Service `myservice` de type ClusterIP sur le port 80.

<details>
<summary>💡 Indice</summary>

L'init container doit se trouver dans `spec.initContainers[]` et non dans `spec.containers[]`.
</details>

---

## Exercice 3 : Job - Calcul Parallèle

**Temps estimé : 6 minutes**

Créer un Job nommé `compute` qui :
- Utilise l'image `perl:5.34`
- Exécute : `perl -Mbignum=bpi -wle 'print bpi(2000)'`
- Doit s'exécuter 5 fois avec succès (`completions: 5`)
- Maximum 2 Pods en parallèle (`parallelism: 2`)
- Maximum 3 tentatives en cas d'échec (`backoffLimit: 3`)

<details>
<summary>💡 Indice</summary>

```bash
k create job compute --image=perl:5.34 $do -- perl -Mbignum=bpi -wle 'print bpi(2000)' > job.yaml
# Puis éditer pour ajouter completions, parallelism, backoffLimit
```
</details>

---

## Exercice 4 : CronJob - Nettoyage Périodique

**Temps estimé : 6 minutes**

Créer un CronJob nommé `cleanup` qui :
- S'exécute toutes les heures à la minute 0 (schedule: `"0 * * * *"`)
- Utilise l'image `busybox`
- Exécute : `echo "Cleaning up at $(date)"`
- Conserve les 3 derniers Jobs réussis (`successfulJobsHistoryLimit: 3`)
- Conserve le dernier Job échoué (`failedJobsHistoryLimit: 1`)

<details>
<summary>💡 Indice</summary>

```bash
k create cronjob cleanup --image=busybox --schedule="0 * * * *" $do -- /bin/sh -c 'echo "Cleaning up at $(date)"' > cronjob.yaml
```
</details>

---

## Exercice 5 : Multi-Container - Adapter Pattern

**Temps estimé : 10 minutes**

Créer un Pod nommé `legacy-app` avec :
- Container principal `app` (image: `busybox`) qui génère des logs dans un format custom : `while true; do echo "$(date)|INFO|Application running" >> /var/log/app.log; sleep 3; done`
- Container adapter `log-adapter` (image: `busybox`) qui lit les logs et les convertit en JSON : `while true; do tail -1 /var/log/app.log | sed 's/|/","/g' | sed 's/^/{"timestamp":"/' | sed 's/$/}/' ; sleep 3; done`
- Volume partagé `emptyDir` monté sur `/var/log` pour les deux containers

Vérifier que les logs du container `log-adapter` affichent bien du JSON.

<details>
<summary>💡 Indice</summary>

Créez d'abord le Pod avec un container, puis ajoutez le deuxième container manuellement dans le YAML.
</details>

---

## Exercice 6 : Job avec TTL

**Temps estimé : 5 minutes**

Créer un Job nommé `short-lived` qui :
- Exécute `echo "Job completed"` avec l'image `alpine`
- Se supprime automatiquement 30 secondes après sa complétion (`ttlSecondsAfterFinished: 30`)
- Utilise `restartPolicy: Never`

Vérifier la suppression automatique après complétion.

<details>
<summary>💡 Indice</summary>

Le champ `ttlSecondsAfterFinished` se trouve dans `spec.ttlSecondsAfterFinished` du Job.
</details>

---

## Exercice 7 : Ambassador Pattern

**Temps estimé : 12 minutes**

Créer un Pod nommé `redis-client` avec :
- Container principal `app` (image: `alpine`) qui essaie de se connecter à Redis sur localhost:6379
- Container ambassador `redis-proxy` (image: `redis:alpine`) qui fait office de proxy local vers un service Redis externe

Commande pour le container `app` : `sleep 3600`

<details>
<summary>💡 Indice</summary>

Les deux containers partagent le même network namespace, donc `app` peut accéder à `redis-proxy` via `localhost`.
</details>

---

## Exercice 8 : Init Container - Préchargement de données

**Temps estimé : 10 minutes**

Créer un Pod nommé `web-preload` qui :
- Utilise un init container `data-fetcher` (image: `busybox`) qui télécharge un fichier : `wget -O /data/index.html https://kubernetes.io`
- Container principal `nginx` qui sert les fichiers depuis `/usr/share/nginx/html`
- Volume partagé `emptyDir` entre les deux containers

<details>
<summary>💡 Indice</summary>

L'init container monte le volume sur `/data`, le container nginx le monte sur `/usr/share/nginx/html`.
</details>

---

## Exercice 9 : CronJob avec activeDeadlineSeconds

**Temps estimé : 7 minutes**

Créer un CronJob nommé `timeout-job` qui :
- S'exécute toutes les 5 minutes (`*/5 * * * *`)
- Utilise l'image `busybox`
- Exécute un script qui prend du temps : `for i in $(seq 1 100); do echo $i; sleep 2; done`
- Timeout après 60 secondes (`activeDeadlineSeconds: 60`)
- Concurrency policy: Forbid (ne pas lancer un nouveau Job si l'ancien tourne encore)

<details>
<summary>💡 Indice</summary>

`activeDeadlineSeconds` va dans `spec.jobTemplate.spec.activeDeadlineSeconds`
`concurrencyPolicy` va dans `spec.concurrencyPolicy`
</details>

---

## Exercice 10 : Multi-Container avec resources

**Temps estimé : 8 minutes**

Créer un Pod nommé `resource-demo` avec :
- Container `nginx` (image: `nginx:alpine`)
  - requests: cpu=100m, memory=128Mi
  - limits: cpu=200m, memory=256Mi
- Container `busybox` (image: `busybox`) qui exécute : `sleep 3600`
  - requests: cpu=50m, memory=64Mi
  - limits: cpu=100m, memory=128Mi

Vérifier les ressources allouées avec `k describe pod resource-demo`.

<details>
<summary>💡 Indice</summary>

Chaque container a son propre bloc `resources` dans le YAML.
</details>

---

## 🎯 Objectifs d'apprentissage

Après avoir complété ces exercices, vous devriez être capable de :

- ✅ Créer des Pods multi-conteneurs avec différents patterns (sidecar, init, adapter, ambassador)
- ✅ Comprendre les use cases de chaque pattern
- ✅ Créer et configurer des Jobs (completions, parallelism, backoffLimit)
- ✅ Créer et configurer des CronJobs (schedule, historyLimits, concurrencyPolicy)
- ✅ Utiliser des volumes partagés entre containers
- ✅ Configurer des ressources pour chaque container
- ✅ Utiliser TTL et activeDeadlineSeconds

---

## 📚 Références

- [Multi-container Pods](https://kubernetes.io/docs/concepts/workloads/pods/#how-pods-manage-multiple-containers)
- [Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)
- [Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
- [CronJobs](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)

---

**💡 Conseil** : Ces patterns multi-conteneurs reviennent souvent à l'examen CKAD. Pratiquez jusqu'à pouvoir les créer rapidement sans regarder la documentation !
